package rr
{
   import flash.display.Sprite;
   import flash.display.Graphics;
   import flash.display.Stage;
   import flash.geom.Point;
   import flash.text.TextField;
   import flash.text.TextFormat;
   import flash.utils.getQualifiedClassName;

   /** Read-only overlay. Native weapon rotation and current collision tiles are
    * sampled; it never aims units, calls getBulXY, hacks, or moves the player. */
   public class RRDebugOverlay
   {
      public var enabled:Boolean=false;
      private var root:Sprite=new Sprite();
      private var layout:Sprite=new Sprite();
      private var live:Sprite=new Sprite();
      private var hud:Sprite=new Sprite();
      private var summary:TextField;
      private var status:TextField;
      private var cached:*;
      private var host:Stage;
      private var ticks:int=0;
      private var mirror:Boolean;
      private var width:Number=1920;
      private var record:Object={enabled:false};
      private static const ROLES:Object={workshop:"车间",warehouse:"仓储",service:"检修",control:"控制室",store:"储物",living:"居住",medical:"医疗",office:"办公",corridor:"通道",canal:"水渠",kitchen:"厨房",hall:"大厅"};
      public function RRDebugOverlay(stage:Stage)
      {
         host=stage; root.name="RandomRooms_DebugWorld"; hud.name="RandomRooms_DebugHUD";
         root.mouseEnabled=false; root.mouseChildren=false; hud.mouseEnabled=false; hud.mouseChildren=false;
         root.addChild(layout); root.addChild(live);
         hud.graphics.beginFill(0x08131B,0.86); hud.graphics.lineStyle(1,0x688C91); hud.graphics.drawRoundRect(0,0,615,87,8); hud.graphics.endFill();
         summary=label(hud,"",10,5,595,23,15,0xE4F5D5);
         status=label(hud,"",10,29,595,54,12,0xBDCCD4);
      }
      private static function label(parent:Sprite,text:String,x:Number,y:Number,w:Number,h:Number,size:int,color:uint):TextField
      {
         var field:TextField=new TextField(); field.defaultTextFormat=new TextFormat("Microsoft YaHei",size,color);
         field.multiline=true;
         field.text=text; field.x=x; field.y=y; field.width=w; field.height=h; field.selectable=false; field.mouseEnabled=false;
         parent.addChild(field); return field;
      }
      private function tx(x:Number):Number { return mirror?width-x:x; }
      private function point(x:Number,y:Number):Point { return new Point(tx(x*40),y*40); }
      private static function color(kind:String):uint
      {
         if(kind=="security") return 0xF296FF;
         if(kind=="enemy") return 0xFF6B73;
         if(["special","hazard","trigger","damager"].indexOf(kind)>=0) return 0xFFB65C;
         if(kind=="ambient") return 0xB6EAA0;
         if(kind=="terminal") return 0x6FDDE8;
         return 0xECDC83;
      }
      private static function dashed(g:Graphics,a:Point,b:Point,c:uint,alpha:Number=0.65):void
      {
         var d:Number=Point.distance(a,b),steps:int=Math.ceil(d/10);
         g.lineStyle(1.5,c,alpha);
         for(var i:int=0;i<steps;i+=2)
         { g.moveTo(a.x+(b.x-a.x)*i/steps,a.y+(b.y-a.y)*i/steps); g.lineTo(a.x+(b.x-a.x)*Math.min(i+1,steps)/steps,a.y+(b.y-a.y)*Math.min(i+1,steps)/steps); }
      }
      private function rebuild(w:*):void
      {
         cached=w.loc; mirror=Boolean(cached.mirror); width=Number(cached.limX);
         layout.graphics.clear(); while(layout.numChildren) layout.removeChildAt(0);
         var xml:XML=cached.room.xml,meta:XML=xml.rrPlan[0],g:Graphics=layout.graphics;
         record={enabled:true,version:String(xml.@rrVersion),mirror:mirror,room:String(cached.room.id),spaces:[],spawns:[],guns:[],units:[],rays:[],errors:[]};
         if(!meta) return;
         for each(var space:XML in meta.space)
         {
            var x:Number=Number(space.@x0)*40,y:Number=Number(space.@top)*40;
            var sw:Number=(Number(space.@x1)-Number(space.@x0)+1)*40,sh:Number=(Number(space.@floor)-Number(space.@top)+1)*40;
            if(mirror) x=width-x-sw;
            var hasValues:Boolean=String(space.@danger).length>0,d:int=int(space.@danger),v:int=int(space.@value);
            var tint:uint=d>=65?0xED6871:(v>=65?0xDBC766:0x70B0A8);
            g.lineStyle(1,tint,0.65); g.beginFill(tint,0.045); g.drawRect(x+1,y+1,sw-2,sh-2); g.endFill();
            if(String(space.@kind)!="gallery")
            {
               var text:String=(ROLES[String(space.@role)] || String(space.@role))+(hasValues?"\nD "+d+"   V "+v:"\n旧版，无 D/V");
               var name:TextField=label(layout,text,x+5,y+3,Math.min(215,Math.max(110,sw-10)),68,22,tint);
               name.background=true; name.backgroundColor=0x142026;
            }
            record.spaces.push({zone:String(space.@zone),role:String(space.@role),danger:hasValues?d:null,value:hasValues?v:null,x:x,y:y,width:sw,height:sh,
               labelLines:String(space.@kind)!="gallery"?name.numLines:0,labelHeight:String(space.@kind)!="gallery"?name.textHeight:0});
         }
         for each(var mark:XML in meta.point)
         {
            var size:Array=RRPopulation.SIZES[String(mark.@id)] || [1,1];
            var pos:Point=point(Number(mark.@x)+Number(size[0])/2,Number(mark.@y)+0.5);
            var c:uint=color(String(mark.@kind));
            g.lineStyle(2,c,0.8); g.drawCircle(pos.x,pos.y,7);
            g.moveTo(pos.x-11,pos.y); g.lineTo(pos.x+11,pos.y); g.moveTo(pos.x,pos.y-11); g.lineTo(pos.x,pos.y+11);
            if(mark.@kind=="security" || String(mark.@id)=="term1")
               label(layout,String(mark.@id)=="term1"?"安保终端":"炮塔 · "+(mark.@mount=="ceiling"?"顶装":"地面"),pos.x-50,
                  pos.y+(mark.@kind=="security" && mark.@mount=="ceiling"?54:9),160,31,20,c);
            record.spawns.push({uid:String(mark.@uid),id:String(mark.@id),kind:String(mark.@kind),x:pos.x,y:pos.y,zone:String(mark.@zone)});
         }
         for each(var gun:XML in meta.gun)
         {
            var from:Point=point(Number(gun.@x),Number(gun.@y)),to:Point=point(Number(gun.@targetX),Number(gun.@targetY));
            dashed(g,from,to,0xF296FF); record.guns.push({uid:String(gun.@uid),fromX:from.x,fromY:from.y,toX:to.x,toY:to.y});
         }
         for each(var control:XML in meta.control)
         {
            var path:Array=String(control.@path).split(","),last:Point=null;
            for each(var index:String in path)
            {
               var node:int=int(index); pos=point(node%48+1,int(node/48)+0.3);
               if(last) dashed(g,last,pos,0x6FDDE8,0.45); last=pos;
            }
         }
      }
      public function update(w:*,force:Boolean=false):void
      {
         if(!enabled || !w || !w.loc || !w.loc.room || !RRSynth.isGenerated(w.loc.room.xml) || (w.pip && w.pip.active)) { hide(); return; }
         if(cached!==w.loc) rebuild(w);
         if(root.parent!==w.visual) { if(root.parent) root.parent.removeChild(root); w.visual.addChild(root); }
         if(hud.parent!==host) host.addChild(hud);
         root.visible=true; hud.visible=true; hud.x=12; hud.y=Math.max(90,host.stageHeight-105);
         // 20 Hz is enough for a readable debug ray, without work while disabled.
         if(!force && ++ticks%3!=0) return;
         record.enabled=true; record.units=[]; record.rays=[]; record.errors=[];
         var g:Graphics=live.graphics; g.clear(); var sleeping:int=0;
         for each(var u:* in w.loc.units)
         {
            if(!u || u===w.gg) continue;
            try
            {
               if(u.sost>=3 || u.hp<=0) continue;
               var turret:Boolean=getQualifiedClassName(u)=="fe.unit::UnitTurret",off:Boolean=false;
               if(turret) { var save:Object=u.save(); off=Boolean(save.off); if(off) sleeping++; }
               var friendly:Boolean=u.fraction==w.gg.fraction;
               var c:uint=off?0x9BA8AD:(friendly?0x9CED9E:(turret?0xF296FF:0xFF6B73));
               var x:Number=u.X,y:Number=u.Y-u.scY*0.5;
               g.lineStyle(1,c,0.95); g.beginFill(c,0.9); g.drawCircle(x,y,4); g.endFill();
               record.units.push({id:String(u.id),x:x,y:y,turret:turret,off:off,friendly:friendly});
               var weapon:*=u.currentWeapon;
               if(!weapon || weapon.tip==1 || off || u.disabled) continue;
               var angle:Number=Number(weapon.rot),origin:Point=new Point(Number(weapon.X),Number(weapon.Y));
               // Equivalent read-only coordinate calculation to native getBulXY.
               try
               {
                  if(weapon.vis && weapon.vis.emit && weapon.vis.parent)
                     origin=w.visual.globalToLocal(weapon.vis.localToGlobal(new Point(weapon.vis.emit.x,weapon.vis.emit.y)));
               }
               catch(visualError:*) {}
               if(!isFinite(angle) || !isFinite(origin.x) || !isFinite(origin.y)) continue;
               var hit:Point=clip(w.loc,origin,angle),aiming:Boolean=Boolean(weapon.findCel);
               g.lineStyle(aiming?2:1,c,aiming?0.9:0.5); g.moveTo(origin.x,origin.y); g.lineTo(hit.x,hit.y);
               g.drawCircle(hit.x,hit.y,2);
               record.rays.push({id:String(u.id),turret:turret,fromX:origin.x,fromY:origin.y,toX:hit.x,toY:hit.y,rot:angle,aiming:aiming});
            }
            catch(error:*) { if(record.errors.length<3) record.errors.push(String(error)); }
         }
         var xml:XML=w.loc.room.xml;
         summary.text="RandomRooms v"+xml.@rrVersion+"  ["+w.land.locX+", "+w.land.locY+"]  "+
            (String(xml.@rrDanger).length?"合成房基调 D "+xml.@rrDanger+" / V "+xml.@rrValue:"旧版布局")+"    Shift+F3 关闭";
         status.text="空心＋：刷新点   实心：当前单位   紫虚线：炮塔防守目标   青虚线：终端候选接近路\n"+
            "实线：当前枪口朝向（遇实体截断，非命中预测）   炮塔停机 "+sleeping+"   活动枪线 "+record.rays.length+
            "\nD/V 影响生成机会；容器原生暗雷、开箱事件与战斗后变化另计。";
      }
      private function clip(loc:*,from:Point,angle:Number):Point
      {
         var dx:Number=Math.cos(angle),dy:Number=Math.sin(angle),last:Point=from.clone();
         for(var distance:int=4;distance<=1920;distance+=4)
         {
            var x:Number=from.x+dx*distance,y:Number=from.y+dy*distance;
            if(x<0 || y<0 || x>=loc.limX || y>=loc.limY) return last;
            var tile:*=loc.getAbsTile(x,y);
            if(tile.phis==1 && x>=tile.phX1 && x<=tile.phX2 && y>=tile.phY1 && y<=tile.phY2) return new Point(x,y);
            last.x=x; last.y=y;
         }
         return last;
      }
      private function hide():void { root.visible=false; hud.visible=false; record.enabled=false; }
      public function snapshot():Object { return JSON.parse(JSON.stringify(record)); }
   }
}
