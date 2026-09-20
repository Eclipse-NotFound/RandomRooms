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
      private static var growing:Boolean;
      private static var milestones:Array;
      private static var milestone:int;
      private static var settlingGoal:Boolean;
      private static var originals:Object;
      private static var scene:String;
      private static var dry:Boolean;
      private static var wetFrames:int;
      private static var optionalWater:Boolean;
      private static var originBlueprint:String;
      private static var activeWorld:*;
      private static var contentBefore:Object;
      private static var consumedCache:*;
      private static var persistentCount:int;

      public static function begin(w:*,directory:File,caseName:String,log:Function,doorAction:Function,screen:Function,growth:Boolean=false,waterProbe:Boolean=false):void
      {
         root=directory; name=caseName; logger=log; action=doorAction; capture=screen;
         done=success=false; reason=""; ticks=legTicks=at=stuck=0;
         local=null; records=[]; targets=[]; route=[];
         originX=w.land.locX; originY=w.land.locY;
         originBlueprint=w.loc.room.xml.toXMLString();
         activeWorld=w; contentBefore={}; consumedCache=null; persistentCount=0;
         for each(var oldRoom:XML in w.land.act.allroom.room) for each(var content:XML in oldRoom.obj)
            if(String(content.@rrContent).length)
            {
               var uid:String=String(content.@uid),runtime:*=w.land.uidObjs[uid];
               if(runtime==null) throw new Error("Missing content before navigation "+uid);
               contentBefore[uid]=runtime;
            }
         for each(content in w.loc.room.xml.obj) if(content.@rrContent=="loot")
         {
            consumedCache=w.land.uidObjs[String(content.@uid)];
            consumedCache.inter.command("unlock"); consumedCache.inter.actOsn();
            if(consumedCache.inter.cont!="empty") throw new Error("Cache was not consumed before navigation");
            break;
         }
         growing=growth; milestone=0; settlingGoal=false; originals={};
         scene=String(w.loc.room.xml.@rrTheme); dry=scene=="sewer"; wetFrames=0;
         optionalWater=waterProbe;
         if (optionalWater)
         {
            if (scene!="sewer" || !w.loc.room.xml.rrPlan.water.length()) throw new Error("No optional sewer basin");
            dry=false;
            var pool:XML=w.loc.room.xml.rrPlan.water[0];
            var lo:int=int(pool.@x0),hi:int=int(pool.@x1);
            if (w.loc.mirror) { var oldLo:int=lo; lo=47-hi; hi=47-oldLo; }
            targets=[{kind:"space",x:originX,y:originY,x0:lo,x1:hi,floor:int(pool.@bottom),entry:"optional-water",space:0},
               {kind:"space",x:originX,y:originY,x0:lo-2,x1:hi+2,floor:int(pool.@deck)-1,entry:"return-dry",space:1}];
            w.gg.invulner=true;
            logger("WATER-PROBE enter native basin then return to its dry deck; normal controls");
            return;
         }
         if (growing)
         {
            var iw:int=w.land.maxLocX,ih:int=w.land.maxLocY;
            milestones=[{x:iw,y:0,label:"new-column"},{x:iw-1,y:0,label:"return-column"},
               {x:iw-1,y:ih,label:"new-row"},{x:iw-1,y:ih-1,label:"return-row"}];
            for (var ox:int=0;ox<iw;ox++) for (var oy:int=0;oy<ih;oy++)
               originals[ox+","+oy]={xml:w.land.locs[ox][oy][0].room.xml.toXMLString(),mirror:Boolean(w.land.locs[ox][oy][0].mirror)};
            w.gg.invulner=true;
            logger("NAV-GROWTH natural spawn, initial="+iw+"x"+ih+"; targets="+JSON.stringify(milestones));
            return;
         }
         var open:Array=[];
         for (var p:int=0;p<22;p++)
         {
            if (int(w.loc.doors[p])<2) continue;
            var cells:Array=StyleDriver.portCells(p,int(w.loc.doors[p]));
            var valid:Boolean=true;
            for each (var c:Object in cells) if (w.loc.space[c.x][c.y].phis!=0) valid=false;
            if (valid) open.push(p);
         }
         // Walk an interior circuit, then each actual port both ways back to
         // the same anchor. The unchanged room composes these actual paths.
         addSpaces(w,"initial");
         var first:Object=targets[0];
         targets.push({kind:"space",x:originX,y:originY,x0:first.x0,x1:first.x1,floor:first.floor,entry:"interior-return",space:0});
         for each (p in open)
         {
            var nx:int=originX+(p<6?1:(p>=11 && p<17?-1:0));
            var ny:int=originY+(p>=17?-1:(p>=6 && p<=10?1:0));
            targets.push({kind:"cross",x:originX,y:originY,port:p,toX:nx,toY:ny});
            targets.push({kind:"cross",x:nx,y:ny,port:p<11?p+11:p-11,toX:originX,toY:originY});
            targets.push({kind:"space",x:originX,y:originY,x0:first.x0,x1:first.x1,floor:first.floor,entry:"entry-"+p,space:0});
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
            if (dry && (local.space[x][y].water>0 || local.space[x+1][y].water>0 ||
                local.space[x][y-1].water>0 || local.space[x+1][y-1].water>0 ||
                y<24 && (local.space[x][y+1].water>0 || local.space[x+1][y+1].water>0))) clear[i]=false;
            // A pose just below a one-way dry deck is geometrically empty,
            // but reaching its foot height touches the water surface. Route
            // along the actual deck above it instead of pressing down through.
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
            // A native one-way beam immediately over the solid floor raises
            // the actual standing surface by one tile, within this same space.
            if (target!=null && (y<target.floor-1 || y>target.floor || x<target.x0 || x+1>target.x1 || !support[i])) continue;
            if (target!=null && furnitureAt(w,(x+1)*40,(y+1)*40-1)) continue;
            var cost:Number=target==null?Math.abs((x+1)*40-w.gg.X)+Math.abs((y+1)*40-1-w.gg.Y)*2:
               Math.abs(x-(target.x0+target.x1-1)/2);
            if (cost<score) { score=cost; best=i; }
         }
         return best;
      }
      private static function furnitureAt(w:*,x:Number,y:Number):Boolean
      {
         var obj:*=w.loc.firstObj;
         while (obj!=null)
         {
            if ("wall" in obj && obj.wall==0 && obj.phis>0 && !obj.dead &&
                x+w.gg.scX/2>obj.X1 && x-w.gg.scX/2<obj.X2 && y>obj.Y1 && y-w.gg.scY<obj.Y2) return true;
            obj=obj.nobj;
         }
         return false;
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
         for (k=0;k<full.length;k++)
         {
            var before:int=k==0?start:full[k-1];
            var after:int=k==full.length-1?full[k]:full[k+1];
            var edgeLanding:Boolean=support[full[k]] && Math.abs(full[k]-before)==1 && Math.abs(after-full[k])==1 &&
               (!support[before] || !support[after]);
            // Land on each side of a broken floor before starting the next
            // jump. Combining a ladder-exit jump and a second gap into one
            // horizontal run can overshoot the intervening short platform.
            if (k==full.length-1 || after-full[k]!=full[k]-before || edgeLanding) out.push(full[k]);
         }
         return out;
      }
      private static function goalFor(t:Object):int
      {
         var p:int=t.port,cells:Array=StyleDriver.portCells(p,2),pt:Object=cells[0];
         if (p>=17) return 48+pt.x;
         if (p>=6 && p<=10) return 24*48+pt.x;
         return cells[cells.length-1].y*48+(p>=11?0:46);
      }
      private static function growTargets(w:*):Boolean
      {
         targets=[]; at=0; route=[]; legTicks=0;
         if (milestone>=milestones.length)
         {
            for (var key:String in originals)
            {
               var xy:Array=key.split(","),old:Object=originals[key];
               var loc:*=w.land.locs[int(xy[0])][int(xy[1])][0];
               if (old.xml!=loc.room.xml.toXMLString() || old.mirror!=Boolean(loc.mirror)) throw new Error("Explored room was regenerated "+key);
            }
            finish(true,"Normal movement entered and returned from both new column and new row; original XML and mirrors unchanged");
            return false;
         }
         var m:Object=milestones[milestone];
         if (w.land.locX==m.x && w.land.locY==m.y)
         {
            if (!settlingGoal)
            {
               var r:XML=w.loc.room.xml.rrPlan.space[0];
               var a:int=int(r.@x0),b:int=int(r.@x1);
               if (w.loc.mirror) { var swap:int=a; a=47-b; b=47-swap; }
               targets.push({kind:"space",entry:m.label,space:0,x:m.x,y:m.y,x0:a,x1:b,floor:int(r.@floor)});
               settlingGoal=true; return true;
            }
            records.push({kind:"milestone",label:m.label,x:m.x,y:m.y,width:w.land.maxLocX,height:w.land.maxLocY,success:true});
            logger("NAV-MILESTONE "+JSON.stringify(records[records.length-1]));
            capture(w,name+"-"+m.label,true);
            milestone++; settlingGoal=false; return false;
         }
         var goal:String=Math.min(m.x,w.land.maxLocX-1)+","+Math.min(m.y,w.land.maxLocY-1);
         var start:String=w.land.locX+","+w.land.locY;
         if (start==goal) return false; // The production frame prepares the next frontier.
         var q:Array=[start],prev:Object={},via:Object={}; prev[start]="";
         for (var i:int=0;i<q.length;i++)
         {
            key=q[i]; if (key==goal) break;
            xy=key.split(","); var x:int=int(xy[0]),y:int=int(xy[1]);
            loc=w.land.locs[x][y][0];
            for (var p:int=0;p<22;p++) if (int(loc.doors[p])>=2)
            {
               var nx:int=x+(p<6?1:(p>=11 && p<17?-1:0));
               var ny:int=y+(p>=17?-1:(p>=6 && p<=10?1:0));
               if (nx<0 || ny<0 || nx>=w.land.maxLocX || ny>=w.land.maxLocY) continue;
               var next:String=nx+","+ny; if (prev[next]!==undefined) continue;
               var open:Boolean=true;
               for each (var c:Object in StyleDriver.portCells(p,int(loc.doors[p]))) if (loc.space[c.x][c.y].phis!=0) open=false;
               if (!open) continue;
               prev[next]=key; via[next]={kind:"cross",x:x,y:y,port:p,toX:nx,toY:ny}; q.push(next);
            }
         }
         if (prev[goal]===undefined) throw new Error("No native map route "+start+" -> "+goal);
         for (key=goal;key!=start;key=prev[key]) targets.unshift(via[key]);
         logger("NAV-GROW-ROUTE "+start+" -> "+goal+" edges="+targets.length);
         return true;
      }
      public static function step(w:*):void
      {
         if (done) return;
         try
         {
            ticks++; legTicks++; w.ctr.clearAll(); w.ctr.keyAction=false;
            // Native controlOn clears invulnerability after a room transition.
            // Keep combat protection throughout this geometry-only probe.
            w.gg.invulner=true;
            if (String(w.loc.room.xml.@rrTheme)!=scene) throw new Error("Scene changed during traversal/growth");
            if (w.gg.inWater) { wetFrames++; if (dry) throw new Error("Mandatory dry route entered native water"); }
            if (at>=targets.length)
            {
               if (!growing)
               {
                  if (optionalWater && (wetFrames==0 || w.gg.inWater)) throw new Error("Optional water visit/return not observed");
                  finish(true,optionalWater?"Native water entered and dry deck regained":"Interior circuit and each actual port left/re-entered to the same anchor"); return;
               }
               if (!growTargets(w)) return;
            }
            var t:Object=targets[at];
            if (!growing && w.land.locX==originX && w.land.locY==originY && w.loc.room.xml.toXMLString()!=originBlueprint)
               throw new Error("Room blueprint changed after entry");
            if (t.kind=="cross" && w.land.locX==t.toX && w.land.locY==t.toY)
            {
               records.push({kind:"cross",from:t.x+","+t.y,to:t.toX+","+t.toY,port:t.port,success:true,x:w.gg.X,y:w.gg.Y,frames:legTicks});
               logger("NAV-CROSS "+JSON.stringify(records[records.length-1]));
               at++; route=[]; legTicks=0; local=null; return;
            }
            if (w.land.locX!=t.x || w.land.locY!=t.y) throw new Error("Unexpected room while aiming for "+JSON.stringify(t));
            if (local!==w.loc) { rebuild(w); w.pers.healAll(); }
            if (legTicks==1 && t.kind=="space" && !optionalWater && !growing)
            {
               // Visit the interior spaces in the nearest walkable order.
               // XML order used to add long, irrelevant repeated laps.
               var from:int=nearest(w),dist:Object={},queue:Array=[from]; dist[from]=0;
               for (var qi:int=0;qi<queue.length;qi++) for each (var next:int in graph[queue[qi]])
                  if (dist[next]===undefined) { dist[next]=int(dist[queue[qi]])+1; queue.push(next); }
               var best:int=at,bestDistance:int=100000;
               for (var ti:int=at;ti<targets.length && targets[ti].kind=="space" && targets[ti].entry==t.entry;ti++)
               {
                  var destination:int=nearest(w,targets[ti]);
                  if (destination>=0 && dist[destination]!==undefined && int(dist[destination])<bestDistance)
                  { best=ti; bestDistance=int(dist[destination]); }
               }
               targets[at]=targets[best]; targets[best]=t; t=targets[at];
            }
            if (t.crossing)
            {
               w.ctr.keyRight=t.port<6;
               w.ctr.keyLeft=t.port>=11 && t.port<17;
               w.ctr.keyBeUp=t.port>=17;
               w.ctr.keySit=t.port>=6 && t.port<=10;
               if (legTicks>1500) throw new Error("Boundary crossing timed out "+t.port);
               return;
            }
            if (ticks%60==1) logger("NAV-SAMPLE "+JSON.stringify({target:at,task:t,x:w.gg.X,y:w.gg.Y,ladder:w.gg.isLaz,stay:w.gg.stay,route:route,frame:legTicks}));
            if (legTicks>1500) throw new Error("Movement timed out at "+JSON.stringify(t));
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
                   (!support[later] || w.gg.stay || w.gg.isLaz && w.gg.Y<=(int(later/48)+1)*40))
               { route=route.slice(ahead); break; }
            }
            var step:int=route[0],tx:Number=(step%48+1)*40,ty:Number=(int(step/48)+1)*40-1;
            var transferUp:Boolean=climb[step] && route.length>1 && int(route[1]/48)<int(step/48);
            var leaveSide:Boolean=climb[step] && route.length>1 && int(route[1]/48)==int(step/48) && route[1]!=step;
            if (climb[step] || Math.abs(ty-w.gg.Y)>10)
            {
               var column:int=step%48;
               // checkStairs samples floor(X/40), then snaps to the rung's
               // side using the pony's actual width. A tile-boundary centre
               // is outside a mirrored ladder and can never engage it.
               var scanTop:int=Math.max(0,Math.min(int((w.gg.Y-1)/40),int(step/48)));
               var scanBottom:int=Math.min(24,Math.max(int((w.gg.Y-1)/40),int(step/48))+1);
               // While dropping from a shelf, align with the clear two-tile
               // opening here. A distant lower rung's edge may leave a hoof
               // on the upper solid wall and prevent the initial drop.
               if (ty-w.gg.Y>80 && !w.gg.isLaz) scanBottom=Math.min(scanBottom,scanTop+1);
               for (var sy:int=scanTop;sy<=scanBottom;sy++)
               {
                  if (local.space[column][sy].stair<0) { tx=column*40+w.gg.scX/2; break; }
                  if (local.space[column+1][sy].stair>0) { tx=(column+2)*40-w.gg.scX/2; break; }
               }
            }
            var dx:Number=tx-w.gg.X,dy:Number=ty-w.gg.Y;
            if (Math.abs(dx)<(w.gg.isLaz?32:19) && (leaveSide?w.gg.Y<=ty-12 && w.gg.Y>=ty-40:(transferUp?w.gg.Y<=ty+20:Math.abs(dy)<(support[step]?6:20))) &&
                (!support[step] || w.gg.stay || w.gg.isLaz && w.gg.Y<=ty+1) && (!transferUp || w.gg.isLaz))
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
            // A lateral ladder exit needs the hooves above the receiving
            // ledge. Use that same height for the input controller; otherwise
            // its down command fights the waypoint's higher arrival condition.
            if (leaveSide) dy-=16;
            if (action(w,dx<0?-1:1)) return;
            if (Math.abs(w.gg.X-lastX)<0.5 && Math.abs(w.gg.Y-lastY)<0.5) stuck++; else stuck=0;
            lastX=w.gg.X; lastY=w.gg.Y;
            w.ctr.keyLeft=dx<-12; w.ctr.keyRight=dx>12;
            if (!w.gg.stay && !w.gg.isLaz && support[step] && Math.abs(dy)<160)
            {
               // Releasing a direction in mid-air preserves native inertia.
               // Brake before a short landing rather than only steering back
               // after the pony has already drifted beyond the floor edge.
               var brakingDx:Number=dx-Number(w.gg.dx)*8;
               w.ctr.keyLeft=brakingDx<-8; w.ctr.keyRight=brakingDx>8;
            }
            if (dy>45 && w.gg.stay && Math.abs(dx)<30)
            {
               // A loose 12 px ladder alignment can leave the pony's rear
               // hoof over an adjacent solid wall. Native double-down then
               // correctly refuses to drop through that wall (stayPhis != 2).
               // Walk fully onto the shelf before asking to drop through it.
               w.ctr.keyLeft=dx<-4; w.ctr.keyRight=dx>4;
            }
            if (stuck==60) logger("NAV-STUCK "+JSON.stringify({x:w.gg.X,y:w.gg.Y,tx:tx,ty:ty,stayPhis:w.gg.stayPhis,dx:dx,dy:dy}));
            if (Math.abs(dx)<24)
            {
               w.ctr.keyBeUp=dy<(w.gg.isLaz?-0.5:-5) || transferUp || (leaveSide && w.gg.Y>ty-12);
               // A free fall needs no down key. Down during a jump makes the
               // pony pass through the very platform it is trying to land on.
               w.ctr.keySit=dy>5 && (w.gg.isLaz || w.gg.stay);
               if (dy>20 && stuck>15 && w.gg.stay) w.ctr.keyDubSit=true;
            }
            // Native jumping releases a ladder onto its adjacent landing and
            // steps over movable furniture. Never move or delete the obstacle.
            if (Math.abs(dx)>18 && Math.abs(dy)<50 && w.gg.isLaz || stuck>24 && w.gg.stay && dy<20 && dy>-50)
            { w.ctr.keyJump=true; w.ctr.keySit=false; w.ctr.keyBeUp=false; stuck=0; }
            if (!climb[step] && !transferUp && w.gg.stay && Math.abs(dx)>25 && dy<=5 && dy>-45)
            {
               var aheadX:int=int((w.gg.X+(dx<0?-70:70))/40);
               var belowY:int=int((w.gg.Y+2)/40);
               if (aheadX>=0 && aheadX<48 && belowY<25)
               {
                  var aheadTile:*=w.loc.space[aheadX][belowY];
                  if (aheadTile.phis==0 && !aheadTile.shelf)
                  { w.ctr.keyJump=true; w.ctr.keySit=false; w.ctr.keyBeUp=false; }
               }
            }
            // If an ordinary fall missed a ledge, navigate from the observed
            // landing again. This changes only the test's intended route.
            if (legTicks%240==0 && w.gg.stay && !w.gg.isLaz && Math.abs(dy)>80)
               route=path(w,t.kind=="space"?nearest(w,t):goalFor(t));
            if (w.gg.isLaz && Math.abs(dx)<64 && (Math.abs(dy)>50 || dy>8))
            {
               // First reach the landing height on the ladder already held;
               // a mirrored rung and the adjacent two-tile floor pose can be
               // 55 px apart. Horizontal input alone cannot release a ladder.
               w.ctr.keyLeft=w.ctr.keyRight=false;
               w.ctr.keyBeUp=dy<0; w.ctr.keySit=dy>0; w.ctr.keyJump=false;
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
         if(ok)
         {
            for(var uid:String in contentBefore)
            {
               if(activeWorld.land.uidObjs[uid]!==contentBefore[uid]) { ok=false; message="Old content replaced "+uid; break; }
               persistentCount++;
            }
            if(consumedCache && consumedCache.inter.cont!="empty") { ok=false; message="Loot respawned after travel/growth"; }
            for each(var room:XML in activeWorld.land.act.allroom.room) for each(var xml:XML in room.obj)
               if(String(xml.@rrContent).length && activeWorld.land.uidObjs[String(xml.@uid)]==null)
               { ok=false; message="Missing generated content after travel/growth "+xml.@uid; }
         }
         done=true; success=ok; reason=message;
         var result:Object={success:ok,reason:message,caseId:name,scene:scene,dryRequired:dry,optionalWater:optionalWater,wetFrames:wetFrames,targets:targets.length,completed:at,frames:ticks,records:records,growth:growing,milestones:growing?milestone:0,persistentObjects:persistentCount,cacheStayedEmpty:consumedCache!=null && consumedCache.inter.cont=="empty"};
         var stream:FileStream=new FileStream();
         stream.open(root.resolvePath("captures/"+name+"-navigation.json"),FileMode.WRITE);
         stream.writeUTFBytes(JSON.stringify(result)); stream.close();
         logger("NAV-END "+JSON.stringify({success:ok,completed:at,targets:targets.length,frames:ticks,reason:message}));
      }
   }
}
