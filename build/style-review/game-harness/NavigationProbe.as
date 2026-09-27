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
      private static var slope:Array;
      private static var slopeDirection:Array;
      private static var at:int;
      private static var ticks:int;
      private static var legTicks:int;
      private static var stuck:int;
      private static var jumpHold:int;
      private static var flightFoot:int=-1;
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
      private static var terminalOnly:Boolean;

      public static function begin(w:*,directory:File,caseName:String,log:Function,doorAction:Function,screen:Function,growth:Boolean=false,waterProbe:Boolean=false,terminalApproach:Boolean=false):void
      {
         root=directory; name=caseName; logger=log; action=doorAction; capture=screen;
         terminalOnly=terminalApproach;
         done=success=false; reason=""; ticks=legTicks=at=stuck=jumpHold=0;
         flightFoot=-1;
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
         if(terminalOnly)
         {
            addSpaces(w,"initial");
            targets=targets.filter(function(t:Object,...rest):Boolean { return Boolean(t.terminal); });
            if(!targets.length) throw new Error("No security terminal selected for approach probe");
            w.gg.invulner=true;
            logger("NAV-TERMINAL normal movement to modeled operator position; combat protection only, AI and collision unchanged"); return;
         }
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
         for each(var stairs:XML in w.loc.room.xml.rrPlan.stairs)
         {
            var dir:int=int(stairs.@dir),start:int=int(stairs.@x),bottom:int=int(stairs.@bottom),top:int=int(stairs.@top);
            if(w.loc.mirror) { start=47-start; dir=-dir; }
            var end:int=start+dir*(bottom-top);
            var head:int=start-dir*2,foot:int=end+dir*2;
            var label:String="stairs-"+i;
            var headLo:int=head-3,headHi:int=head+3;
            for each(var landing:XML in w.loc.room.xml.rrPlan.space)
            {
               var lx:int=int(landing.@x0),rx:int=int(landing.@x1);
               if(w.loc.mirror) { var before:int=lx; lx=47-rx; rx=47-before; }
               if(int(landing.@floor)==top-1 && head>=lx && head<=rx)
               { headLo=lx; headHi=rx; break; }
            }
            // Reach a free position on each landing, not one arbitrary point
            // that may legally contain a cabinet or intersect another ladder.
            targets.push({kind:"space",x:originX,y:originY,x0:foot-3,x1:foot+3,floor:bottom,entry:label+"-bottom",space:i++});
            targets.push({kind:"space",x:originX,y:originY,x0:headLo,x1:headHi,floor:top-1,entry:label+"-top",space:i++});
            targets.push({kind:"space",x:originX,y:originY,x0:foot-3,x1:foot+3,floor:bottom,entry:label+"-return",space:i++});
         }
         for each(var control:XML in w.loc.room.xml.rrPlan.control)
         {
            var node:int=int(control.@operator),column:int=node%48;
            if(w.loc.mirror) column=46-column;
            targets.push({kind:"space",x:originX,y:originY,x0:column,x1:column+1,floor:int(node/48),entry:"terminal-operator",space:i++,terminal:String(control.@uid)});
         }
      }
      private static function tileSolid(t:*):Boolean
      {
         // Operable doors are obstacles handled through the normal action key.
         return t.phis!=0 && !(t.door!=null && t.door.inter!=null && t.door.inter.active);
      }
      private static function rebuild(w:*,avoidFurniture:Boolean=false):void
      {
         local=w.loc; graph=[]; clear=[]; support=[]; climb=[]; slope=[]; slopeDirection=[];
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
            slope[i]=false;
            // A solid floor below the flight remains a distinct ground route.
            // Giving that pose the ramp's higher surface forces an unnecessary
            // ascent instead of allowing native walking underneath the stair.
            if(!(y<24 && (solid[i+48] || solid[i+49])))
               for(var sy:int=y;sy<=Math.min(24,y+1);sy++) for(var sx:int=x;sx<=x+1;sx++)
                  if(local.space[sx][sy].diagon!=0) { slope[i]=true; slopeDirection[i]=-local.space[sx][sy].diagon; }
            if(slope[i]) support[i]=true;
         }
         if(avoidFurniture)
            for(i=0;i<clear.length;i++) if(clear[i] && furnitureAt(w,(i%48+1)*40,poseY(i))) clear[i]=false;
         for (y=1;y<25;y++) for (x=0;x<47;x++)
         {
            i=y*48+x; if (!clear[i]) continue;
            for each (var dx:int in [-1,1])
            {
               var n:int=i+dx;
               if (x+dx>=0 && x+dx<47 && clear[n] && Math.abs(poseY(i)-poseY(n))<=45 &&
                   (support[i] || support[n] || climb[i] || climb[n])) graph[i].push(n);
               for each(var dy:int in [-1,1])
               {
                  var diagonal:int=n+dy*48;
                  if(x+dx>=0 && x+dx<47 && clear[diagonal] && (slope[i] || slope[diagonal]) &&
                     Math.abs(poseY(i)-poseY(diagonal))<=45 &&
                     dy==dx*(slope[i]?slopeDirection[i]:slopeDirection[diagonal]) &&
                     (clear[n] || clear[i+dy*48])) graph[i].push(diagonal);
               }
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
            // A furniture-pruned graph must not place the start in free air
            // above the pony. That silently skips the jump needed to get
            // there and can make the first waypoint a ramp several tiles up.
            if(target==null && w.gg.stay && Math.abs(poseY(i)-w.gg.Y)>30) continue;
            // A native one-way beam immediately over the solid floor raises
            // the actual standing surface by one tile, within this same space.
            if (target!=null && (y<target.floor-1 || y>target.floor || x<target.x0 || x+1>target.x1 || !support[i] || slope[i])) continue;
            // A floor pose directly under a one-way stair is not a stable
            // arrival from above. Pick a visible landing beside that flight.
            if(target!=null && underStair(i)) continue;
            if (target!=null && furnitureAt(w,(x+1)*40,(y+1)*40-1)) continue;
            var cost:Number=target==null?Math.abs((x+1)*40-w.gg.X)+Math.abs(poseY(i)-w.gg.Y)*2:
               Math.abs(x-(target.x0+target.x1-1)/2);
            if (cost<score) { score=cost; best=i; }
         }
         return best;
      }
      private static function underStair(i:int):Boolean
      {
         var x:int=i%48,y:int=int(i/48);
         for(var yy:int=y;yy>=Math.max(0,y-7);yy--)
         {
            if(local.space[x][yy].phis!=0 || local.space[x+1][yy].phis!=0) break;
            if(local.space[x][yy].diagon!=0 || local.space[x+1][yy].diagon!=0) return true;
         }
         return false;
      }
      private static function poseY(i:int):Number
      {
         if(!slope[i]) return (int(i/48)+1)*40-1;
         var x:int=i%48,y:int=int(i/48),surface:Number=Number.POSITIVE_INFINITY;
         for(var sy:int=y;sy<=Math.min(24,y+1);sy++) for(var sx:int=x;sx<=x+1;sx++)
            if(local.space[sx][sy].diagon!=0) surface=Math.min(surface,local.space[sx][sy].getMaxY((x+1)*40));
         return isFinite(surface)?surface-1:(y+1)*40-1;
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
      private static function standingOnSlope(w:*):Boolean
      {
         var x:int=int(w.gg.X/40),y:int=int((w.gg.Y-1)/40);
         if(x<0 || x>=48) return false;
         if(y>=0 && y<24 && tileSolid(local.space[x][y+1]) && Math.abs((y+1)*40-w.gg.Y)<2) return false;
         for(var row:int=Math.max(0,y-1);row<=Math.min(24,y+1);row++)
         {
            var tile:*=local.space[x][row];
            if(tile.diagon!=0 && Math.abs(tile.getMaxY(w.gg.X)-w.gg.Y)<8) return true;
         }
         return false;
      }
      private static function path(w:*,goal:int,refreshed:Boolean=false):Array
      {
         var start:int=nearest(w),prev:Object={},cost:Object={},q:Array=[{id:start,cost:0}];
         prev[start]=-1; cost[start]=0;
         // Prefer a continuous ground route over an equally short detour
         // onto a flight and straight through its one-way surface again.
         // All transitions still come from the actual native tile graph.
         while(q.length)
         {
            q.sortOn("cost",Array.NUMERIC);
            var item:Object=q.shift(),i:int=item.id;
            if(item.cost!=cost[i]) continue;
            if (i==goal) break;
            for each (var n:int in graph[i])
            {
               var nextCost:Number=Number(cost[i])+1+(poseY(n)<poseY(i)-10?3:0)+(slope[n]?1:0);
               if(cost[n]===undefined || nextCost<cost[n])
               { cost[n]=nextCost; prev[n]=i; q.push({id:n,cost:nextCost}); }
            }
         }
         if (prev[goal]===undefined)
         {
            // A movable box may have changed support since the optional
            // furniture detour was built. Restore the live terrain graph;
            // jumping over the box remains an ordinary control action.
            if(!refreshed) { rebuild(w); return path(w,goal,true); }
            throw new Error("No native tile route "+start+" -> "+goal);
         }
         var full:Array=[];
         for (i=goal;i!=start;i=int(prev[i])) full.unshift(i);
         // Keep turns; combine straight runs so animation does not have to stop
         // at every tile, especially while falling or stepping off a ladder.
         var out:Array=[];
         for (var k:int=0;k<full.length;k++)
         {
            var before:int=k==0?start:full[k-1];
            var after:int=k==full.length-1?full[k]:full[k+1];
            var edgeLanding:Boolean=support[full[k]] && Math.abs(full[k]-before)==1 && Math.abs(after-full[k])==1 &&
               (!support[before] || !support[after]);
            var stairEntry:Boolean=Boolean(slope[full[k]])!=Boolean(slope[before]) ||
               Boolean(slope[full[k]])!=Boolean(slope[after]);
            // Land on each side of a broken floor before starting the next
            // jump. Combining a ladder-exit jump and a second gap into one
            // horizontal run can overshoot the intervening short platform.
            if (k==full.length-1 || after-full[k]!=full[k]-before || edgeLanding || stairEntry) out.push(full[k]);
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
            if(w.gui.guiPause) w.ctr.active=true;
            // Native jump height depends on holding the key. A one-frame
            // pulse is a short hop and cannot clear an ordinary 40 px crate.
            if(jumpHold>0) { jumpHold--; w.ctr.keyJump=true; }
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
                  finish(true,terminalOnly?"Native terminal operator reached and interaction line verified":(optionalWater?"Native water entered and dry deck regained":"Interior circuit and each actual port left/re-entered to the same anchor")); return;
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
               at++; route=[]; flightFoot=-1; legTicks=0; local=null; return;
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
               if((t.port<6 || t.port>=11 && t.port<17) && w.gg.isLaz) w.ctr.keyJump=true;
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
            if(w.gg.stay && !w.gg.isLaz)
            {
               // Follow the real slope while standing on it. Re-planning a
               // vertical fall from the middle of a one-way flight oscillates
               // between the slope surface and the tile centre underneath.
               var actualX:int=int(w.gg.X/40),actualY:int=int((w.gg.Y-1)/40);
               // A route may climb first even when its eventual destination
               // is downstairs in another compartment. Follow the next leg.
               var finalY:Number=poseY(int(route[0]));
               var onFlatFloor:Boolean=actualX>=0 && actualX<48 && actualY<24 &&
                  tileSolid(local.space[actualX][actualY+1]) &&
                  Math.abs((actualY+1)*40-w.gg.Y)<2;
               if(actualX>=0 && actualX<48 && !onFlatFloor && Math.abs(finalY-w.gg.Y)>45)
                  for(var stairY:int=Math.max(0,actualY-1);stairY<=Math.min(24,actualY+1);stairY++)
                  {
                     var standingTile:*=local.space[actualX][stairY];
                     var slopeBelow:Number=standingTile.getMaxY(w.gg.X)-w.gg.Y;
                     if(standingTile.diagon!=0 && (Math.abs(slopeBelow)<8 ||
                        finalY>w.gg.Y && slopeBelow>=0 && slopeBelow<=40))
                     {
                        var uphill:Boolean=finalY<w.gg.Y;
                        if(!uphill && !slope[int(route[0])] && flightFoot<0)
                        {
                           // A fall node underneath a one-way stair cannot
                           // be approached vertically from its surface. Aim
                           // at the actual foot first, including while in air,
                           // then plan the rest from the observed landing.
                           var down:int=standingTile.diagon>0?-1:1;
                           var footX:int=actualX,footY:int=stairY;
                           while(footX+down>=0 && footX+down<48 && footY<24 &&
                              local.space[footX+down][footY+1].diagon==standingTile.diagon)
                           { footX+=down; footY++; }
                           var footCentre:Number=(down<0?footX:footX+1)*40+down*(w.gg.scX/2+18);
                           var footScore:Number=1e10;
                           for(var footPose:int=0;footPose<clear.length;footPose++)
                              if(clear[footPose] && support[footPose] && !slope[footPose] &&
                                 Math.abs(poseY(footPose)-(footY+1)*40)<3 &&
                                 ((footPose%48+1)*40-footCentre)*down>=-15 &&
                                 !furnitureAt(w,(footPose%48+1)*40,poseY(footPose)))
                              {
                                 var footDistance:Number=Math.abs((footPose%48+1)*40-footCentre);
                                 if(footDistance<120 && footDistance<footScore)
                                 { flightFoot=footPose; footScore=footDistance; }
                              }
                           if(flightFoot>=0)
                           {
                              route=[flightFoot];
                              logger("NAV-FLIGHT-FOOT "+JSON.stringify({pose:flightFoot,x:(flightFoot%48+1)*40,y:poseY(flightFoot)}));
                           }
                           else
                           {
                              // If the foot is occupied, choose a farther free
                              // point on its landing. Reversing toward a graph
                              // node under the flight would climb it again.
                              for(footPose=0;footPose<clear.length;footPose++)
                                 if(clear[footPose] && support[footPose] && !slope[footPose] &&
                                    Math.abs(poseY(footPose)-(footY+1)*40)<3 &&
                                    ((footPose%48+1)*40-footCentre)*down>=-15 &&
                                    !furnitureAt(w,(footPose%48+1)*40,poseY(footPose)))
                                 {
                                    footDistance=Math.abs((footPose%48+1)*40-footCentre);
                                    if(footDistance<480 && footDistance<footScore) { flightFoot=footPose; footScore=footDistance; }
                                 }
                              if(flightFoot>=0) { route=[flightFoot]; logger("NAV-FLIGHT-LANDING farther clear foot "+flightFoot); }
                           }
                        }
                        if(ticks%120==1) logger("NAV-SLOPE "+JSON.stringify({step:route[0],finalY:finalY,diagon:standingTile.diagon,x:w.gg.X,y:w.gg.Y,stuck:stuck,uphill:uphill}));
                        w.ctr.keyRight=uphill?standingTile.diagon>0:standingTile.diagon<0;
                        w.ctr.keyLeft=!w.ctr.keyRight; w.ctr.keyBeUp=uphill;
                        if (Math.abs(w.gg.X-lastX)<0.5 && Math.abs(w.gg.Y-lastY)<0.5) stuck++; else stuck=0;
                        lastX=w.gg.X; lastY=w.gg.Y;
                        if(action(w,w.ctr.keyRight?1:-1)) return;
                        // The native pony can meet a solid landing's edge
                        // before its centre reaches the end of the ramp.
                        // A normal jump clears that lip; holding up alone
                        // cannot override the horizontal collision.
                        if(stuck>24) { jumpHold=5; w.ctr.keyJump=true; w.ctr.keyBeUp=false; stuck=0; }
                        // Keep this flight's waypoint while moving on it;
                        // re-snapping to the grid halfway up can select the
                        // separate floor underneath and drop off the ramp.
                        return;
                     }
                  }
            }
            if(legTicks>=240 && legTicks%240==0 && w.gg.stay && !t.furnitureRerouted && flightFoot<0)
            {
               // Furniture can block the tile graph's preferred floor run.
               // Search an actual alternative through the existing room;
               // never move, destroy or ignore the object to satisfy a test.
               var saved:Object={graph:graph,clear:clear,support:support,climb:climb,slope:slope,dir:slopeDirection};
               t.furnitureRerouted=true;
               try
               {
                  rebuild(w,true);
                  var alternate:int=t.kind=="space"?nearest(w,t):goalFor(t);
                  if(alternate<0) throw new Error("No furniture-free target");
                  route=path(w,alternate);
                  logger("NAV-AVOID-FURNITURE alternate native tile route");
               }
               catch(avoidError:*)
               {
                  graph=saved.graph;clear=saved.clear;support=saved.support;climb=saved.climb;
                  slope=saved.slope;slopeDirection=saved.dir;
               }
            }
            if(!route.length) route=[t.kind=="space"?nearest(w,t):goalFor(t)];
            // A normal fall can reach the next landing before the controller
            // samples the preceding edge of a ledge. Accept the observed later
            // waypoint instead of trying to walk back up into empty air.
            for (var ahead:int=route.length-1;ahead>0;ahead--)
            {
               var later:int=route[ahead];
               if (Math.abs((later%48+1)*40-w.gg.X)<22 && Math.abs(poseY(later)-w.gg.Y)<(slope[later]?22:(support[later]?6:22)) &&
                   (!support[later] || w.gg.stay || w.gg.isLaz && w.gg.Y<=(int(later/48)+1)*40+2))
               { route=route.slice(ahead); break; }
            }
            var step:int=route[0],tx:Number=(step%48+1)*40,ty:Number=poseY(step);
            var transferUp:Boolean=climb[step] && route.length>1 && int(route[1]/48)<int(step/48);
            var leaveSide:Boolean=climb[step] && route.length>1 && int(route[1]/48)==int(step/48) &&
               route[1]!=step && support[int(route[1])];
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
            if(ticks%120==1) logger("NAV-CONTROL "+JSON.stringify({step:step,tx:tx,ty:ty,dx:dx,dy:dy,climb:climb[step],support:support[step],leaveSide:leaveSide,transferUp:transferUp,ladder:w.gg.isLaz}));
            if(leaveSide && w.gg.isLaz && Math.abs(dx)<64 && dy>=-30 && dy<=1)
            {
               // Some native ladders end at the deck itself. They cannot lift
               // the hooves above it; jump off towards the receiving platform.
               var nextX:Number=(int(route[1])%48+1)*40;
               w.ctr.keyLeft=nextX<w.gg.X; w.ctr.keyRight=nextX>w.gg.X;
               w.ctr.keyJump=true; route.shift(); stuck=0; return;
            }
            // A movable cabinet can support the pony above an intermediate
            // floor waypoint. Continue from its actual top rather than trying
            // to press down through the cabinet to the empty-tile graph.
            if(route.length>1 && support[step] && !slope[step] && w.gg.stay &&
               Math.abs(dx)<35 && dy>10 && dy<100 && furnitureAt(w,tx,ty))
            {
               logger("NAV-FURNITURE-LANDING "+JSON.stringify({x:w.gg.X,y:w.gg.Y,waypoint:step}));
               route.shift(); return;
            }
            if (Math.abs(dx)<(w.gg.isLaz?32:19) && (leaveSide?w.gg.Y<=ty-12 && w.gg.Y>=ty-40:(transferUp?w.gg.Y<=ty+20:Math.abs(dy)<(slope[step]?42:(support[step]?6:20)))) &&
                // A rung can hold the pony 0.25 px below its nominal ledge.
                // Accept the observed rung pose, then actually jump/walk the
                // next edge; insisting on exact equality jumps the wrong way.
                (!support[step] || w.gg.stay || w.gg.isLaz && w.gg.Y<=ty+3 ||
                 optionalWater && t.entry=="optional-water" && w.gg.inWater) && (!transferUp || w.gg.isLaz))
            {
               if(step==flightFoot)
               {
                  flightFoot=-1; route=[]; stuck=0; return;
               }
               route.shift();
               if (route.length) return;
               if (t.kind=="space")
               {
                  if(t.terminal)
                  {
                     var terminal:*=w.land.uidObjs[t.terminal];
                     if(!terminal || Math.abs(w.gg.X-terminal.X)>125 || Math.abs(w.gg.Y-terminal.Y)>60 ||
                        !w.loc.isLine(w.gg.X,w.gg.Y-w.gg.scY/2,terminal.X,terminal.Y-terminal.scY/2,terminal))
                        throw new Error("Terminal operator pose cannot interact with native terminal "+t.terminal);
                     logger("NAV-TERMINAL operator reached by normal movement; native interaction line clear uid="+t.terminal);
                     for each(var gun:XML in w.loc.room.xml.rrPlan.gun)
                     {
                        var turret:*=w.land.uidObjs[String(gun.@uid)];
                        if(!turret || turret.sost>=3 || turret.save().off) continue;
                        for each(var bx:Number in [-0.45,0,0.45]) for each(var by:Number in [0.1,0.5,0.9])
                        {
                           var px:Number=w.gg.X+bx*w.gg.scX,py:Number=w.gg.Y-by*w.gg.scY;
                           var angle:Number=Math.atan2(py-turret.weaponY,px-turret.weaponX)*180/Math.PI;
                           var fix:int=turret.currentWeapon.fixRot;
                           if(fix==1 && angle>-150 && angle<-30 || fix==2 && Math.abs(angle)>30 || fix==3 && Math.abs(angle)<150) continue;
                           if(w.loc.isLine(turret.weaponX,turret.weaponY,px,py))
                           {
                              logger("NAV-TERMINAL-EXPOSURE "+JSON.stringify({uid:String(gun.@uid),gunX:turret.weaponX,gunY:turret.weaponY,fix:fix,px:px,py:py,angle:angle,playerX:w.gg.X,playerY:w.gg.Y,width:w.gg.scX,height:w.gg.scY,ladder:w.gg.isLaz}));
                              throw new Error("Native turret sweep exposes terminal operator "+gun.@uid);
                           }
                        }
                     }
                     logger("NAV-TERMINAL all active turret mechanical sweeps blocked at actual operator body");
                  }
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
            if (Math.abs(w.gg.X-lastX)<0.5 && Math.abs(w.gg.Y-lastY)<0.5) stuck++; else stuck=0;
            lastX=w.gg.X; lastY=w.gg.Y;
            if(stuck==24 || stuck==31) logger("NAV-POSE "+JSON.stringify({x:w.gg.X,y:w.gg.Y,dx:dx,dy:dy,
               stay:w.gg.stay,stayPhis:w.gg.stayPhis,ladder:w.gg.isLaz,step:step,leaveSide:leaveSide,stuck:stuck}));
            // Step down beside a low door before aiming at its interaction
            // point. Otherwise the door helper can wait forever above it.
            if(stuck>30 && w.gg.stay && !w.gg.isLaz && w.gg.stayPhis==2 && dy>20 && dy<65 && !standingOnSlope(w))
            {
               w.ctr.keyDubSit=true; return;
            }
            if (action(w,dx<0?-1:1)) return;
            w.ctr.keyLeft=dx<-12; w.ctr.keyRight=dx>12;
            // Native Unit.checkDiagon only enters an ascending stair from a
            // solid floor while the player holds up (isUp), or is airborne.
            // Walking alone deliberately passes underneath this one-way stair.
            if(dy<-10 && Math.abs(dx)>12 && !w.gg.isLaz)
            {
               var rampX:int=int((w.gg.X+(dx>0?60:-60))/40),rampY:int=int((w.gg.Y-2)/40);
               var hoofX:int=int(w.gg.X/40);
               if(hoofX>=0 && hoofX<48 && rampY>=0 && rampY<25 && local.space[hoofX][rampY].diagon!=0) w.ctr.keyBeUp=true;
               if(rampX>=0 && rampX<48)
                  for(var ry:int=Math.max(0,rampY-1);ry<=Math.min(24,rampY+1);ry++)
                     if(local.space[rampX][ry].diagon==(dx>0?1:-1)) w.ctr.keyBeUp=true;
            }
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
            // Keep walking to the foot of a flight when the requested pose
            // belongs to the floor under it. A 20 px threshold alternates
            // uphill/downhill every frame near the bottom of the same stair.
            if(dy>=-2 && w.gg.stay && !w.gg.isLaz && !slope[step] && standingOnSlope(w))
            {
               var sx:int=int(w.gg.X/40),syFeet:int=int((w.gg.Y-1)/40);
               if(sx>=0 && sx<48 && syFeet>=0 && syFeet<25)
               {
                  var incline:int=local.space[sx][syFeet].diagon;
                  if(incline!=0)
                  {
                     // Native down does not drop vertically through a slope.
                     // Walk down its end, then approach the floor waypoint.
                     w.ctr.keyLeft=incline>0; w.ctr.keyRight=incline<0;
                     w.ctr.keySit=false; w.ctr.keyDubSit=false; w.ctr.keyBeUp=false;
                  }
               }
            }
            // Native jumping releases a ladder onto its adjacent landing and
            // steps over movable furniture. Never move or delete the obstacle.
            if (Math.abs(dx)>18 && Math.abs(dy)<50 && w.gg.isLaz ||
                stuck>30 && w.gg.isLaz && Math.abs(dx)>64 || stuck>24 && w.gg.stay && dy<20 && dy>-160)
            {
               if(w.gg.stay && !w.gg.isLaz) jumpHold=5;
               w.ctr.keyJump=true; w.ctr.keySit=false; w.ctr.keyBeUp=false; stuck=0;
            }
            var nextIsDrop:Boolean=route.length>1 && poseY(int(route[1]))>ty+40;
            if (w.gg.stay && Math.abs(dx)>25 && dy<=5 && dy>-45 && !nextIsDrop)
            {
               var aheadX:int=int((w.gg.X+(dx<0?-70:70))/40);
               var belowY:int=int((w.gg.Y+2)/40);
               if (aheadX>=0 && aheadX<48 && belowY<25)
               {
                  var aheadTile:*=w.loc.space[aheadX][belowY];
                  if (aheadTile.phis==0 && !aheadTile.shelf && aheadTile.diagon==0)
                  {
                     // Approach a planned downward edge without auto-jumping
                     // away from it. A short hanging ladder across a gap must be caught
                     // while jumping. Walking off drops below its last rung
                     // before the horizontal alignment can engage it.
                     w.ctr.keyJump=true; w.ctr.keySit=false; w.ctr.keyBeUp=transferUp || climb[step];
                  }
               }
            }
            // If an ordinary fall missed a ledge, navigate from the observed
            // landing again. This changes only the test's intended route.
            if (legTicks%240==0 && w.gg.stay && !w.gg.isLaz && Math.abs(dy)>80 && flightFoot<0)
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
         if(!ok && activeWorld!=null && activeWorld.loc!=null)
         {
            var failure:XML=<failure roomX={activeWorld.land.locX} roomY={activeWorld.land.locY} mirror={activeWorld.loc.mirror}/>;
            failure.appendChild(activeWorld.loc.room.xml.copy());
            stream.open(root.resolvePath("captures/"+name+"-failure-room.xml"),FileMode.WRITE);
            stream.writeUTFBytes(failure.toXMLString()); stream.close();
         }
         logger("NAV-END "+JSON.stringify({success:ok,completed:at,targets:targets.length,frames:ticks,reason:message}));
      }
   }
}
