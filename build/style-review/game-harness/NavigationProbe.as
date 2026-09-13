package
{
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;

   /** Read actual native tiles, then drive only ordinary movement/action keys.
    * No unit position writes, collision changes, flight, or terrain edits. */
   public class NavigationProbe
   {
      public static var done:Boolean=false;
      public static var success:Boolean=false;
      public static var reason:String="";
      private static var root:File;
      private static var name:String;
      private static var logger:Function;
      private static var action:Function;
      private static var capture:Function;
      private static var targets:Array;
      private static var records:Array;
      private static var route:Array;
      private static var local:*;
      private static var graph:Array;
      private static var clear:Array;
      private static var support:Array;
      private static var climb:Array;
      private static var at:int;
      private static var ticks:int;
      private static var legTicks:int;
      private static var stuck:int;
      private static var lastX:Number;
      private static var lastY:Number;
      private static var originX:int;
      private static var originY:int;

      public static function begin(w:*,directory:File,caseName:String,log:Function,doorAction:Function,screen:Function):void
      {
         root=directory; name=caseName; logger=log; action=doorAction; capture=screen;
         done=success=false; reason=""; ticks=legTicks=at=stuck=0;
         local=null; records=[]; targets=[]; route=[];
         originX=w.land.locX; originY=w.land.locY;
         var open:Array=[];
         for (var p:int=0;p<22;p++)
         {
            if (int(w.loc.doors[p])<2) continue;
            var cells:Array=StyleDriver.portCells(p,int(w.loc.doors[p]));
            var valid:Boolean=true;
            for each (var c:Object in cells) if (w.loc.space[c.x][c.y].phis!=0) valid=false;
            if (valid) open.push(p);
         }
         // After entering through EACH actual port, visit each functional space
         // before leaving again. A single source flood is not the game test.
         addSpaces(w,"initial");
         for each (p in open)
         {
            var nx:int=originX+(p<6?1:(p>=11 && p<17?-1:0));
            var ny:int=originY+(p>=17?-1:(p>=6 && p<=10?1:0));
            targets.push({kind:"cross",x:originX,y:originY,port:p,toX:nx,toY:ny});
            targets.push({kind:"cross",x:nx,y:ny,port:p<11?p+11:p-11,toX:originX,toY:originY});
            addSpaces(w,"entry-"+p);
         }
         w.gg.invulner=true;
         logger("NAV-BEGIN "+name+" origin="+originX+","+originY+" ports="+open+" targets="+targets.length+" natural spawn; no coordinate writes");
      }
      private static function addSpaces(w:*,entry:String):void
      {
         var i:int=0;
         for each (var r:XML in w.loc.room.xml.rrPlan.space)
         {
            var x0:int=int(r.@x0),x1:int=int(r.@x1);
            if (w.loc.mirror) { var old:int=x0; x0=47-x1; x1=47-old; }
            targets.push({kind:"space",x:originX,y:originY,x0:x0,x1:x1,floor:int(r.@floor),entry:entry,space:i++});
         }
      }
      private static function tileSolid(t:*):Boolean
      {
         // Operable doors are obstacles handled through the normal action key.
         return t.phis!=0 && !(t.door!=null && t.door.inter!=null && t.door.inter.active);
      }
      private static function rebuild(w:*):void
      {
         local=w.loc; graph=[]; clear=[]; support=[]; climb=[];
         var solid:Array=[];
         for (var y:int=0;y<25;y++) for (var x:int=0;x<48;x++) solid[y*48+x]=tileSolid(local.space[x][y]);
         for (y=1;y<25;y++) for (x=0;x<47;x++)
         {
            var i:int=y*48+x;
            clear[i]=!solid[i] && !solid[i+1] && !solid[i-48] && !solid[i-47];
            if (!clear[i]) continue;
            graph[i]=[];
            climb[i]=local.space[x][y].stair<0 || local.space[x+1][y].stair>0;
            support[i]=y<24 && (solid[i+48] || solid[i+49] || local.space[x][y+1].shelf || local.space[x+1][y+1].shelf);
         }
         for (y=1;y<25;y++) for (x=0;x<47;x++)
         {
            i=y*48+x; if (!clear[i]) continue;
            for each (var dx:int in [-1,1])
            {
               var n:int=i+dx;
               if (x+dx>=0 && x+dx<47 && clear[n] && (support[i] || support[n] || climb[i] || climb[n])) graph[i].push(n);
            }
            if (clear[i-48] && (climb[i] || climb[i-48])) graph[i].push(i-48);
            if (clear[i+48] && !solid[i+48] && !solid[i+49]) graph[i].push(i+48);
         }
      }
      private static function nearest(w:*,target:Object=null):int
      {
         var best:int=-1,score:Number=1e10;
         for (var i:int=0;i<clear.length;i++) if (clear[i])
         {
            var x:int=i%48,y:int=int(i/48);
            if (target!=null && (y!=target.floor || x<target.x0 || x+1>target.x1 || !support[i])) continue;
            var cost:Number=target==null?Math.abs((x+1)*40-w.gg.X)+Math.abs((y+1)*40-1-w.gg.Y)*2:
               Math.abs(x-(target.x0+target.x1-1)/2);
            if (cost<score) { score=cost; best=i; }
         }
         return best;
      }
      private static function path(w:*,goal:int):Array
      {
         var start:int=nearest(w),prev:Object={},q:Array=[start]; prev[start]=-1;
         for (var k:int=0;k<q.length;k++)
         {
            var i:int=q[k]; if (i==goal) break;
            for each (var n:int in graph[i]) if (prev[n]===undefined) { prev[n]=i; q.push(n); }
         }
         if (prev[goal]===undefined) throw new Error("No native tile route "+start+" -> "+goal);
         var full:Array=[];
         for (i=goal;i!=start;i=int(prev[i])) full.unshift(i);
         // Keep turns; combine straight runs so animation does not have to stop
         // at every tile, especially while falling or stepping off a ladder.
         var out:Array=[];
         for (k=0;k<full.length;k++) if (k==full.length-1 || full[k+1]-full[k]!=(k==0?full[k]-start:full[k]-full[k-1])) out.push(full[k]);
         return out;
      }
      private static function goalFor(t:Object):int
      {
         var p:int=t.port,cells:Array=StyleDriver.portCells(p,2),pt:Object=cells[0];
         if (p>=17) return 48+pt.x;
         if (p>=6 && p<=10) return 24*48+pt.x;
         return cells[cells.length-1].y*48+(p>=11?0:46);
      }
      public static function step(w:*):void
      {
         if (done) return;
         try
         {
            ticks++; legTicks++; w.ctr.clearAll(); w.ctr.keyAction=false;
            if (at>=targets.length) { finish(true,"All spaces visited after each actual port entry"); return; }
            var t:Object=targets[at];
            if (t.kind=="cross" && w.land.locX==t.toX && w.land.locY==t.toY)
            {
               records.push({kind:"cross",from:t.x+","+t.y,to:t.toX+","+t.toY,port:t.port,success:true,x:w.gg.X,y:w.gg.Y,frames:legTicks});
               logger("NAV-CROSS "+JSON.stringify(records[records.length-1]));
               at++; route=[]; legTicks=0; local=null; return;
            }
            if (w.land.locX!=t.x || w.land.locY!=t.y) throw new Error("Unexpected room while aiming for "+JSON.stringify(t));
            if (local!==w.loc) { rebuild(w); w.pers.healAll(); }
            if (t.crossing)
            {
               w.ctr.keyRight=t.port<6;
               w.ctr.keyLeft=t.port>=11 && t.port<17;
               w.ctr.keyBeUp=t.port>=17;
               w.ctr.keySit=t.port>=6 && t.port<=10;
               if (legTicks>900) throw new Error("Boundary crossing timed out "+t.port);
               return;
            }
            if (ticks%60==1) logger("NAV-SAMPLE "+JSON.stringify({target:at,task:t,x:w.gg.X,y:w.gg.Y,ladder:w.gg.isLaz,stay:w.gg.stay,route:route,frame:legTicks}));
            if (legTicks>900) throw new Error("Movement timed out at "+JSON.stringify(t));
            if (!route.length)
            {
               var goal:int=t.kind=="space"?nearest(w,t):goalFor(t);
               if (goal<0) throw new Error("No supported space target "+JSON.stringify(t));
               route=path(w,goal);
               if (!route.length) route=[goal];
            }
            // A normal fall can reach the next landing before the controller
            // samples the preceding edge of a ledge. Accept the observed later
            // waypoint instead of trying to walk back up into empty air.
            for (var ahead:int=route.length-1;ahead>0;ahead--)
            {
               var later:int=route[ahead];
               if (Math.abs((later%48+1)*40-w.gg.X)<22 && Math.abs((int(later/48)+1)*40-1-w.gg.Y)<(support[later]?6:22) &&
                   (!support[later] || w.gg.stay || w.gg.isLaz))
               { route=route.slice(ahead); break; }
            }
            var step:int=route[0],tx:Number=(step%48+1)*40,ty:Number=(int(step/48)+1)*40-1;
            var dx:Number=tx-w.gg.X,dy:Number=ty-w.gg.Y;
            if (Math.abs(dx)<19 && Math.abs(dy)<(support[step]?6:20) && (!support[step] || w.gg.stay || w.gg.isLaz))
            {
               route.shift();
               if (route.length) return;
               if (t.kind=="space")
               {
                  records.push({kind:"space",entry:t.entry,space:t.space,success:true,x:w.gg.X,y:w.gg.Y,frames:legTicks});
                  at++; legTicks=0; return;
               }
               w.ctr.keyRight=t.port<6;
               w.ctr.keyLeft=t.port>=11 && t.port<17;
               w.ctr.keyBeUp=t.port>=17;
               w.ctr.keySit=t.port>=6 && t.port<=10;
               t.crossing=true;
               return;
            }
            if (action(w,dx<0?-1:1)) return;
            if (Math.abs(w.gg.X-lastX)<0.5 && Math.abs(w.gg.Y-lastY)<0.5) stuck++; else stuck=0;
            lastX=w.gg.X; lastY=w.gg.Y;
            w.ctr.keyLeft=dx<-12; w.ctr.keyRight=dx>12;
            if (Math.abs(dx)<24)
            {
               w.ctr.keyBeUp=dy<-5;
               w.ctr.keySit=dy>5;
               if (dy>20 && stuck>15 && w.gg.stay) w.ctr.keyDubSit=true;
            }
            // Native jumping releases a ladder onto its adjacent landing and
            // steps over movable furniture. Never move or delete the obstacle.
            if (Math.abs(dx)>18 && Math.abs(dy)<50 && w.gg.isLaz || stuck>24 && w.gg.stay)
            { w.ctr.keyJump=true; w.ctr.keyBeUp=false; stuck=0; }
            if (w.gg.stay && Math.abs(dx)>25 && Math.abs(dy)<45)
            {
               var aheadX:int=int((w.gg.X+(dx<0?-70:70))/40);
               var belowY:int=int((w.gg.Y+2)/40);
               if (aheadX>=0 && aheadX<48 && belowY<25)
               {
                  var aheadTile:*=w.loc.space[aheadX][belowY];
                  if (aheadTile.phis==0 && !aheadTile.shelf)
                  { w.ctr.keyJump=true; w.ctr.keyBeUp=false; }
               }
            }
         }
         catch (e:*)
         {
            w.ctr.clearAll(); capture(w,name+"-nav-failure",true);
            finish(false,String(e));
         }
      }
      private static function finish(ok:Boolean,message:String):void
      {
         done=true; success=ok; reason=message;
         var result:Object={success:ok,reason:message,caseId:name,targets:targets.length,completed:at,frames:ticks,records:records};
         var stream:FileStream=new FileStream();
         stream.open(root.resolvePath("captures/"+name+"-navigation.json"),FileMode.WRITE);
         stream.writeUTFBytes(JSON.stringify(result)); stream.close();
         logger("NAV-END "+JSON.stringify({success:ok,completed:at,targets:targets.length,frames:ticks,reason:message}));
      }
   }
}
