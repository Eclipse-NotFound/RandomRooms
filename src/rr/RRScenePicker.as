package rr
{
   import flash.display.Sprite;
   import flash.display.Stage;
   import flash.events.Event;
   import flash.events.KeyboardEvent;
   import flash.events.MouseEvent;
   import flash.text.TextField;
   import flash.text.TextFieldType;
   import flash.text.TextFormat;

   /** A modal owns input and restores the pause state it found. */
   public class RRScenePicker extends Sprite
   {
      private var host:Stage;
      private var world:*;
      private var paused:Boolean;
      private var done:Function;
      private var panel:Sprite=new Sprite();
      private var closed:Boolean=false;
      private var version:String;
      private var versions:Array=[];
      private var seedInput:TextField;
      private var notice:TextField;
      public function RRScenePicker(w:*,s:Stage,show:Boolean,cfg:RRConfig,callback:Function)
      {
         world=w; host=s; done=callback; paused=Boolean(w.onPause);
         version=cfg.version;
         w.ctr.clearAll(); w.onPause=true;
         addChild(panel);
         panel.graphics.beginFill(0x17201C,0.98); panel.graphics.lineStyle(1,0x809C81);
         panel.graphics.drawRoundRect(0,0,640,505,12); panel.graphics.endFill();
         label(panel,show?"选择展示场景":"下一次探索，去哪里？",26,20,590,36,24,0xD8E8C9);
         label(panel,"从第 1 层开始；版本和场景在扩张、深入时保持不变。",26,62,590,30,15,0xA5BAA6);
         versionButton("12.2",26,"矩形分区 · 房间较多");
         versionButton("12.3",326,"厚墙塑形 · 合并房间");
         label(panel,"对照种子",26,172,85,29,16,0xD8E8C9);
         seedInput=new TextField(); seedInput.name="rrComparisonSeed";
         seedInput.type=TextFieldType.INPUT; seedInput.restrict="0-9"; seedInput.maxChars=10;
         seedInput.defaultTextFormat=new TextFormat("Microsoft YaHei",17,0xE0EBCF);
         seedInput.background=true; seedInput.backgroundColor=0x0B1510; seedInput.border=true; seedInput.borderColor=0x809C81;
         seedInput.x=115; seedInput.y=169; seedInput.width=185; seedInput.height=30;
         seedInput.text=String(cfg.seed || 20260818); panel.addChild(seedInput);
         var roll:Sprite=new Sprite(); roll.x=326; roll.y=169; roll.buttonMode=true; roll.mouseChildren=false;
         roll.graphics.beginFill(0x283A2F); roll.graphics.drawRoundRect(0,0,135,30,5); roll.graphics.endFill();
         label(roll,"换一组种子",12,2,122,28,16,0xD8E8C9); panel.addChild(roll);
         roll.addEventListener(MouseEvent.CLICK,function(e:MouseEvent):void { e.stopImmediatePropagation(); seedInput.text=String(1+uint(Math.random()*4294967294)); });
         notice=new TextField(); notice.defaultTextFormat=new TextFormat("Microsoft YaHei",13,0xA5BAA6);
         notice.x=26; notice.y=206; notice.width=590; notice.height=24; notice.selectable=false;
         notice.text="比较时保持种子、场景和层数相同，再切换版本。"; panel.addChild(notice);
         var hints:Array=["高大厂房 · 设备与库房","金属隔间 · 居住与公共空间","污水渠池 · 干燥检修通路","破损楼层 · 街道与屋顶"];
         for (var i:int=0;i<4;i++) button(i,26+(i%2)*300,236+int(i/2)*81,288,72,RRScene.NAMES[i],hints[i]);
         button(4,26,400,288,61,"随机选择","同一种子会选中同一场景");
         button(-1,326,400,288,61,"返回","Esc 取消，保留当前进度");
         label(panel,"1–4 选择场景，5 随机；F2 回城后可换版本重进。",26,475,590,22,13,0x8DA08F);
         host.addChild(this);
         host.addEventListener(KeyboardEvent.KEY_DOWN,key,true,10000);
         host.addEventListener(KeyboardEvent.KEY_UP,keyUp,true,10000);
         host.addEventListener(Event.RESIZE,layout);
         layout(null);
      }
      private function versionButton(v:String,x:int,subtitle:String):void
      {
         var b:Sprite=new Sprite(); b.name="rrVersion"+v.replace(".",""); b.x=x; b.y=99;
         b.buttonMode=true; b.mouseChildren=false; panel.addChild(b); versions.push({button:b,version:v});
         label(b,"v"+v,13,5,260,27,20,0xE0EBCF);
         label(b,subtitle,13,33,260,23,13,0xADBFAE);
         b.addEventListener(MouseEvent.CLICK,function(e:MouseEvent):void { e.stopImmediatePropagation(); version=v; paintVersions(); host.focus=null; });
         paintVersions();
      }
      private function paintVersions():void
      {
         for each(var item:Object in versions)
         {
            var b:Sprite=item.button;
            b.graphics.clear(); b.graphics.lineStyle(2,item.version==version?0xD1E996:0x586E59);
            b.graphics.beginFill(item.version==version?0x3D5035:0x283A2F);
            b.graphics.drawRoundRect(0,0,288,61,6); b.graphics.endFill();
         }
      }
      private function label(parent:Sprite,text:String,x:int,y:int,w:int,h:int,size:int,color:uint):void
      {
         var t:TextField=new TextField(); t.defaultTextFormat=new TextFormat("Microsoft YaHei",size,color);
         t.text=text; t.x=x; t.y=y; t.width=w; t.height=h; t.selectable=false; t.mouseEnabled=false;
         parent.addChild(t);
      }
      private function button(index:int,x:int,y:int,w:int,h:int,title:String,subtitle:String):void
      {
         var b:Sprite=new Sprite(); b.x=x; b.y=y; b.buttonMode=true; b.mouseChildren=false;
         b.graphics.beginFill(0x283A2F); b.graphics.lineStyle(1,0x586E59);
         b.graphics.drawRoundRect(0,0,w,h,6); b.graphics.endFill();
         label(b,(index>=0?String(index+1)+"  ":"")+title,13,7,w-22,29,19,0xE0EBCF);
         label(b,subtitle,13,38,w-22,26,13,0xADBFAE);
         b.addEventListener(MouseEvent.CLICK,function(e:MouseEvent):void { e.stopImmediatePropagation(); finish(index); });
         panel.addChild(b);
      }
      private function layout(e:Event):void
      {
         graphics.clear(); graphics.beginFill(0x000000,0.65);
         graphics.drawRect(0,0,host.stageWidth,host.stageHeight); graphics.endFill();
         var scale:Number=Math.min(1,(host.stageWidth-24)/640,(host.stageHeight-24)/505);
         panel.scaleX=panel.scaleY=scale;
         panel.x=(host.stageWidth-640*scale)/2; panel.y=(host.stageHeight-505*scale)/2;
      }
      private function key(e:KeyboardEvent):void
      {
         e.stopImmediatePropagation();
         if(host.focus===seedInput && e.keyCode!=27) return;
         e.preventDefault();
         if (e.keyCode==27) finish(-1);
         else if (e.keyCode>=49 && e.keyCode<=53) finish(e.keyCode-49);
         else if (e.keyCode>=97 && e.keyCode<=101) finish(e.keyCode-97);
      }
      private function keyUp(e:KeyboardEvent):void { e.stopImmediatePropagation(); }
      private function finish(index:int):void
      {
         if (closed) return;
         var seed:Number=Number(seedInput.text);
         if(index>=0 && (seed<1 || seed>4294967295 || isNaN(seed)))
         { notice.text="请输入 1 到 4294967295 的整数作为种子。"; return; }
         closed=true;
         host.removeEventListener(KeyboardEvent.KEY_DOWN,key,true);
         host.removeEventListener(KeyboardEvent.KEY_UP,keyUp,true);
         host.removeEventListener(Event.RESIZE,layout);
         if (parent) parent.removeChild(this);
         world.ctr.clearAll(); world.onPause=paused;
         done(index<0?null:(index==4?"random":String(RRScene.IDS[index])),version,uint(seed));
      }
   }
}
