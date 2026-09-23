package rr
{
   /** Unequal architectural volumes and an undirected connection graph.
    * Edges are selected before their doors/stairs are built. There is no room
    * entrance/goal, universal floor, central shaft, or post-hoc tunnel repair. */
   public class RRArchitecture
   {
      public var grid:Array;
      public var regions:Array;
      public var ladders:Array;
      public var stairs:Array;
      public var doors:Array;
      public var hatches:Array;
      public var windows:Array;
      public var reserved:Object;
      public var wall:String;
      public var trim:String;
      public var backgrounds:Array;
      public var theme:String;
      public var archetype:String;
      public var ports:Array;
      public var links:Array;
      public var spawn:Object;
      public var scene:Object;
      public var sceneForm:String;
      public var pools:Array;
      public var partitionInfo:Object;
      public var masses:Array;
      public var merges:Array;
      private var rnd:Function;
      private var volumes:Array;
      private var tallBias:Number;

      public function RRArchitecture(random:Function) { rnd=random; }
      private function pick(lo:int,hi:int):int { return lo+int(rnd()*(hi-lo+1)); }
      private function shuffle(a:Array):void
      {
         for (var i:int=a.length-1;i>0;i--)
         { var j:int=pick(0,i); var v:*=a[i]; a[i]=a[j]; a[j]=v; }
      }
      public function build(biome:String,requested:String="", boundary:Array=null,context:Object=null):void
      {
         theme=biome;
         scene=RRScene.profile(theme);
         sceneForm=scene.forms[pick(0,scene.forms.length-1)];
         if(context && context.form && scene.forms.indexOf(String(context.form))>=0) sceneForm=String(context.form);
         if(theme=="mane" && context && context.city) sceneForm=String(context.city.form);
         wall=scene.wall; trim=scene.trim; backgrounds=scene.backgrounds;
         var kinds:Array=theme=="stable"?["atrium","offices","offices","service","warehouse"]:
            (theme=="sewer"?["service","service","workshop","damaged","warehouse"]:
             (theme=="plant"?["workshop","workshop","warehouse","service","atrium"]:
              ["damaged","damaged","offices","warehouse","atrium"]));
         archetype=kinds[pick(0,kinds.length-1)];
         if (requested=="hall") requested="atrium";
         if (requested=="corridor") requested="service";
         if (["atrium","offices","workshop","damaged","service","warehouse","connector"].indexOf(requested)>=0) archetype=requested;
         ports=boundary!=null?boundary.concat():RRPorts.sample(rnd);
         grid=[]; regions=[]; ladders=[]; stairs=[]; doors=[]; hatches=[]; windows=[]; pools=[];
         reserved={}; links=[]; partitionInfo=null; masses=[]; merges=[];
         for (var y:int=0;y<25;y++)
         {
            grid[y]=[];
            for (var x:int=0;x<48;x++) grid[y][x]=wall;
         }
         tallBias=scene.bias;
         volumes=[{x0:1,top:1,x1:46,floor:23}];
         if(context && context.partition=="rules")
         {
            var partition:RRPartitionPlan=new RRPartitionPlan(rnd);
            volumes=partition.build(theme,sceneForm,ports);
            partitionInfo=partition.info;
            masses=partition.masses;
         }
         else { seedScene(); refineSpaces(); }
         for (var i:int=0;i<volumes.length;i++)
         {
            var r:Object=volumes[i];
            r.id=i; r.role=r.role?r.role:purpose(r); r.bg=RRScene.background(theme,r.role,rnd);
            open(r.x0,r.top,r.x1,r.floor,r.bg);
            regions.push(r);
         }
         connectBoundary();
         connectVolumes();
         for each (r in volumes)
         {
            if (r.floor-r.top>=10 && r.x1-r.x0>=14 &&
                (r.role=="workshop" || r.role=="warehouse" || r.role=="hall" || r.role=="street" ||
                 (theme=="sewer" && r.role=="service"))) gallery(r);
            shapeCeiling(r);
         }
         addSceneFeatures();
         addHatches();
         addWindows();
         chooseSpawn();
         auditLadders();
         auditStairs();
         for each(var fixture:Object in doors)
            if(!support(fixture.x,fixture.y) || !solid(fixture.x,fixture.y-(fixture.id=="stdoor" || fixture.id=="door3"?3:2)))
               throw new Error("Unsupported door frame after circulation");
         auditBoundary();
         RRTraversal.check(this);
         if (pools.length) RRTraversal.check(this,true);
         for (y=1;y<25;y++) for (x=0;x<48;x++)
            if (solid(x,y) && !solid(x,y-1)) grid[y][x]=trim;
         dressMaterials();
      }
      private function purpose(r:Object):String
      {
         var roles:Array;
         if (theme=="sewer") roles=["service","service","service","control","store"];
         else if (theme=="plant") roles=["workshop","workshop","store","control","office"];
         else if (theme=="stable") roles=sceneForm=="quarters"?["living","living","kitchen","office"]:
            ["office","medical","service","control","store"];
         else roles=["living","living","kitchen","office","office","store"];
         return roles[pick(0,roles.length-1)];
      }
      private function divide(r:Object,vertical:Boolean,lo:int,hi:int):Array
      {
         var cuts:Array=[];
         for (var c:int=lo;c<=hi;c++) if (canSplit(r,vertical,c)) cuts.push(c);
         if (!cuts.length)
         {
            // Preserve the scene's relation and orientation when a preferred
            // cut intersects a real port; vary its dimensions instead.
            lo=vertical?r.x0+8:r.top+5; hi=vertical?r.x1-8:r.floor-5;
            for (c=lo;c<=hi;c++) if (canSplit(r,vertical,c)) cuts.push(c);
         }
         if (!cuts.length) throw new Error("Scene cannot meet shared ports");
         c=cuts[pick(0,cuts.length-1)];
         var a:Object={x0:r.x0,top:r.top,x1:vertical?c-1:r.x1,floor:vertical?r.floor:c-1};
         var b:Object={x0:vertical?c+1:r.x0,top:vertical?r.top:c+1,x1:r.x1,floor:r.floor};
         volumes.splice(volumes.indexOf(r),1); volumes.push(a,b);
         return [a,b];
      }
      // These are different construction sequences, not labels on a common
      // whole-room partition. The low-level cut only enforces shared sockets.
      private function splitWing(r:Object,roles:Array):void
      {
         var parts:Array=divide(r,false,r.top+6,r.floor-6);
         parts[0].role=roles[0]; parts[1].role=roles[1];
      }
      private function cells(r:Object,count:int,roles:Array):void
      {
         var todo:Array=[r];
         while(todo.length<count)
         {
            todo.sort(function(a:Object,b:Object):Number { return (b.x1-b.x0)-(a.x1-a.x0); });
            var major:Object=todo.shift();
            if(major.x1-major.x0<17) { todo.push(major); break; }
            var mid:int=int((major.x0+major.x1)/2);
            var pair:Array=divide(major,true,Math.max(major.x0+8,mid-3),Math.min(major.x1-8,mid+3));
            todo.push(pair[0],pair[1]);
         }
         for(var i:int=0;i<todo.length;i++) todo[i].role=roles[i%roles.length];
      }
      private function centralBay(role:String):Object
      {
         var left:Array=divide(volumes[0],true,12,16);
         var right:Array=divide(left[1],true,30,34);
         var center:Object=right[0]; center.role=role;
         splitWing(left[0],theme=="stable"?["office","living"]:["control","store"]);
         splitWing(right[1],theme=="stable"?["service","office"]:["office","service"]);
         return center;
      }
      private function seedScene():void
      {
         var parts:Array,major:Object,other:Array;
         if(theme=="plant")
         {
            if(sceneForm=="production") centralBay("workshop");
            else if(sceneForm=="storage_hall")
            {
               parts=divide(volumes[0],false,7,10);
               parts[1].role="warehouse";
               cells(parts[0],pick(2,3),["store","control","office"]);
            }
            else
            {
               parts=divide(volumes[0],true,17,23);
               parts[1].role="workshop";
               other=divide(parts[0],false,10,16);
               other[0].role="control";
               cells(other[1],2,["service","store"]);
            }
            return;
         }
         if(theme=="stable")
         {
            if(sceneForm=="atrium_ring") centralBay("hall");
            else if(sceneForm=="quarters")
            {
               parts=divide(volumes[0],false,6,9);
               other=divide(parts[1],false,12,15);
               other[0].role="corridor";
               cells(parts[0],pick(3,4),["living","living","office"]);
               cells(other[1],pick(2,3),["living","kitchen","medical"]);
            }
            else
            {
               parts=divide(volumes[0],true,12,18);
               splitWing(parts[0],["store","service"]);
               other=divide(parts[1],false,9,14);
               cells(other[0],2,["control","service"]);
               cells(other[1],2,["medical","office"]);
            }
            return;
         }
         if(theme=="sewer")
         {
            if(sceneForm=="cistern")
            {
               // Incoming upper sockets end in a service gallery, keeping
               // their descending ladders out of the main reservoir volume.
               parts=divide(volumes[0],false,6,8);
               cells(parts[0],2,["service","service"]);
               for each(var galleryRoom:Object in volumes) if(galleryRoom.floor<=8) galleryRoom.keep=true;
               other=divide(parts[1],true,11,14);
               other[0].role="control"; other[1].role="canal";
            }
            else if(sceneForm=="dry_tunnels")
            {
               parts=divide(volumes[0],true,19,28);
               splitWing(parts[0],["service","store"]);
               other=divide(parts[1],false,6,10);
               other[0].role="service";
               splitWing(other[1],["control","service"]);
            }
            else
            {
               parts=divide(volumes[0],false,sceneForm=="canal_gallery"?12:7,sceneForm=="canal_gallery"?14:11);
               cells(parts[0],2,["service","control"]);
               if(sceneForm=="pump_chain")
               {
                  other=divide(parts[1],true,21,28);
                  other[0].role="canal"; other[1].role="control";
               }
               else parts[1].role="canal";
            }
            return;
         }
         if(sceneForm=="rooftops")
         {
            parts=divide(volumes[0],false,6,9);
            major=parts[0]; major.keep=true; major.role="roof";
            parts[1].role="service";
         }
         else if(sceneForm=="street_links")
         {
            parts=divide(volumes[0],true,13,17);
            other=divide(parts[1],true,30,34);
            other[0].role="street"; other[0].keep=true;
            parts[0].role="store"; other[1].role="service";
         }
         else if(sceneForm=="offices")
         {
            parts=divide(volumes[0],true,9,12);
            parts[0].role="service"; parts[1].role="office";
         }
         else if(sceneForm=="commercial")
         {
            parts=divide(volumes[0],false,10,14);
            parts[0].role="office"; parts[1].role="store";
         }
         else if(sceneForm=="ruined")
         {
            parts=divide(volumes[0],true,18,25);
            parts[0].role="living"; parts[1].role="hall";
         }
         else volumes[0].role="living";
      }
      /** Subdivide oversize functional rooms before any circulation is built.
       * No furniture quota can make a 20-tile bedroom feel inhabited. Keep
       * purposeful reservoirs/outdoors, with only a few double-height halls. */
      private function refineSpaces():void
      {
         var limit:int=theme=="stable"?pick(11,15):(theme=="plant"?pick(8,11):
            (theme=="sewer"?pick(8,11):(sceneForm=="rooftops" || sceneForm=="street_links"?pick(7,10):pick(10,14))));
         for(var attempt:int=0;attempt<60 && volumes.length<limit;attempt++)
         {
            var candidates:Array=[];
            for each(var r:Object in volumes)
            {
               if(r.keep || r.role=="canal" || r.role=="corridor") continue;
               var w:int=r.x1-r.x0+1,h:int=r.floor-r.top+1;
               var hall:Boolean=r.role=="workshop" || r.role=="warehouse" || r.role=="hall";
               var maxArea:int=hall?210:(theme=="sewer"?110:95);
               var maxHeight:int=hall?12:8, maxWidth:int=hall?25:16;
               if(w*h<=maxArea && h<=maxHeight && w<=maxWidth) continue;
               var directions:Array=(h>maxHeight && h>=11)?[false,true]:[true,false];
               var cuts:Array=[];
               for each(var vertical:Boolean in directions)
               {
                  var lo:int=vertical?r.x0+7:r.top+5,hi:int=vertical?r.x1-7:r.floor-5;
                  for(var c:int=lo;c<=hi;c++) if(canSplit(r,vertical,c))
                     cuts.push({vertical:vertical,c:c,center:Math.abs(c-(lo+hi)/2)});
                  if(cuts.length) break;
               }
               if(cuts.length) candidates.push({r:r,cuts:cuts,score:w*h/maxArea});
            }
            if(!candidates.length) break;
            candidates.sortOn("score",Array.NUMERIC|Array.DESCENDING);
            var chosen:Object=candidates[0]; r=chosen.r;
            hall=r.role=="workshop" || r.role=="warehouse" || r.role=="hall";
            chosen.cuts.sortOn("center",Array.NUMERIC);
            var cut:Object=chosen.cuts[pick(0,Math.min(3,chosen.cuts.length-1))];
            var pair:Array=divide(r,cut.vertical,cut.c,cut.c);
            pair[0].role=r.role; pair[1].role=r.role;
            if(hall)
            {
               // The smaller room is a supporting use, not another huge hall.
               var small:Object=(pair[0].x1-pair[0].x0+1)*(pair[0].floor-pair[0].top+1)<
                  (pair[1].x1-pair[1].x0+1)*(pair[1].floor-pair[1].top+1)?pair[0]:pair[1];
               small.role=theme=="plant"?"control":(theme=="stable"?"office":"store");
            }
            else if(r.role=="living" && rnd()<0.4) pair[1].role=rnd()<0.5?"kitchen":"office";
            else if(r.role=="service" && rnd()<0.4) pair[1].role="store";
         }
      }
      private function canSplit(r:Object,vertical:Boolean,c:int):Boolean
      {
         for (var p:int=0;p<22;p++) if (ports[p]>=2)
         {
            var b:Object=RRPorts.rect(p,ports[p]);
            if (vertical && RRPorts.vertical(p) && ((p>=17 && r.top==1) || (p<11 && r.floor==23)) &&
                c>=b.x0-1 && c<=b.x1+1) return false;
            if (!vertical && !RRPorts.vertical(p) && ((p>=11 && r.x0==1) || (p<6 && r.x1==46)) &&
                c>=b.y0-1 && c<=b.y1) return false;
         }
         return true;
      }
      private function partition(target:int):void
      {
         for (var attempt:int=0;attempt<80 && volumes.length<target;attempt++)
         {
            var choices:Array=[];
            for (var i:int=0;i<volumes.length;i++)
            {
               var r:Object=volumes[i];
               if (!r.keep && (r.x1-r.x0>=17 || r.floor-r.top>=10))
                  choices.push({r:r,score:(r.x1-r.x0+1)*(r.floor-r.top+1)*(0.45+rnd())});
            }
            if (!choices.length) break;
            choices.sortOn("score",Array.NUMERIC|Array.DESCENDING);
            r=choices[0].r;
            var vertical:Boolean=rnd()<tallBias;
            if (r.x1-r.x0<17) vertical=false;
            if (r.floor-r.top<10) vertical=true;
            var cuts:Array=[];
            var lo:int=vertical?r.x0+8:r.top+5;
            var hi:int=vertical?r.x1-8:r.floor-5;
            for (var c:int=lo;c<=hi;c++) if (canSplit(r,vertical,c)) cuts.push(c);
            if (!cuts.length) continue;
            c=cuts[pick(0,cuts.length-1)];
            volumes.splice(volumes.indexOf(r),1);
            volumes.push({x0:r.x0,top:r.top,x1:vertical?c-1:r.x1,floor:vertical?r.floor:c-1});
            volumes.push({x0:vertical?c+1:r.x0,top:vertical?r.top:c+1,x1:r.x1,floor:r.floor});
         }
      }
      private function adjacent(a:Object,b:Object):Object
      {
         var lo:int,hi:int;
         var reach:int=partitionInfo?12:1;
         var left:Object=a.x0<b.x0?a:b,right:Object=left==a?b:a;
         var above:Object=a.top<b.top?a:b,below:Object=above==a?b:a;
         if (right.x0-left.x1>=2 && right.x0-left.x1<=reach+1)
         {
            lo=Math.max(a.top,b.top); hi=Math.min(a.floor,b.floor);
            if (hi-lo>=(partitionInfo?2:3) && emptyBridge(left.x1+1,hi-2,right.x0-1,hi,a,b))
               return {a:a,b:b,vertical:false,x:left.x1+1,x0:left.x1+1,x1:right.x0-1,lo:lo,hi:hi};
         }
         if (below.top-above.floor>=2 && below.top-above.floor<=reach+1)
         {
            lo=Math.max(a.x0,b.x0); hi=Math.min(a.x1,b.x1);
            if (hi-lo>=4 && emptyBridge(lo,above.floor+1,hi,below.top-1,a,b))
               return {a:a,b:b,vertical:true,y:above.floor+1,y1:below.top-1,lo:lo,hi:hi};
         }
         return null;
      }
      private function emptyBridge(x0:int,y0:int,x1:int,y1:int,a:Object,b:Object):Boolean
      {
         for each(var r:Object in volumes) if(r!=a && r!=b &&
            r.x0<=x1 && r.x1>=x0 && r.top<=y1 && r.floor>=y0) return false;
         return true;
      }
      private function mergeSide(e:Object,roomGroups:Array):Boolean
      {
         if(!partitionInfo || e.vertical || e.x0!=e.x1 || roomGroups[e.a.id]==roomGroups[e.b.id]) return false;
         var excluded:Array=["canal","roof","street","medical"];
         if(excluded.indexOf(e.a.role)>=0 || excluded.indexOf(e.b.role)>=0) return false;
         var size:int=0;
         for each(var g:int in roomGroups) if(g==roomGroups[e.a.id] || g==roomGroups[e.b.id]) size++;
         if(size>3) return false;
         var irregular:Boolean=e.a.top!=e.b.top || e.a.floor!=e.b.floor;
         if(rnd()>(irregular?0.6:0.22)) return false;
         // Keep previously built stairs and boundary landings. A broad opening
         // is a room merge; a small doorway remains a graph connection only.
         for(var y:int=e.lo;y<=e.hi;y++)
            if(reserved[y+","+e.x] || /[АВГ-]/.test(String(grid[y][e.x]))) return false;
         open(e.x,e.lo,e.x,e.hi,e.a.bg);
         reserve(e.x-1,e.lo,e.x+1,e.hi);
         merges.push({a:e.a.id,b:e.b.id,x0:e.x,top:e.lo,x1:e.x,floor:e.hi,axis:"side"});
         return true;
      }
      private function mergeStoreys(e:Object,roomGroups:Array):Boolean
      {
         if(!partitionInfo || e.y1!=e.y || e.hi-e.lo<9 || roomGroups[e.a.id]==roomGroups[e.b.id]) return false;
         var excluded:Array=["canal","roof","street","medical"];
         if(excluded.indexOf(e.a.role)>=0 || excluded.indexOf(e.b.role)>=0) return false;
         var size:int=0;
         for each(var g:int in roomGroups) if(g==roomGroups[e.a.id] || g==roomGroups[e.b.id]) size++;
         if(size>3 || rnd()>(theme=="stable"?0.10:0.20)) return false;
         // Open part of the slab after the return route exists. Keep every
         // authored landing, frame and stair reserve, and leave a balcony.
         var upper:Object=e.a.top<e.b.top?e.a:e.b;
         var runs:Array=[];
         // An interior cut can strand the floor on its far side. Start at an
         // actual end of the upper room instead, leaving one continuous ledge.
         for each(var direction:int in [-1,1])
         {
            var edge:int=direction>0?e.lo:e.hi;
            if(edge!=(direction>0?upper.x0:upper.x1)) continue;
            var length:int=0;
            for(var x:int=edge;x>=e.lo && x<=e.hi && length<9;x+=direction)
            {
               var ok:Boolean=solid(x,e.y);
               for(var y:int=e.y-2;y<=e.y+1;y++) if(reserved[y+","+x]) ok=false;
               if(!ok) break;
               length++;
            }
            if(length>=5) runs.push({x:direction>0?edge:edge-length+1,w:length});
         }
         if(!runs.length) return false;
         var cut:Object=runs[pick(0,runs.length-1)];
         open(cut.x,e.y,cut.x+cut.w-1,e.y,e.a.bg);
         reserve(cut.x,e.y-2,cut.x+cut.w-1,e.y+1);
         merges.push({a:e.a.id,b:e.b.id,x0:cut.x,top:e.y,x1:cut.x+cut.w-1,floor:e.y,axis:"floor"});
         return true;
      }
      private function connectVolumes():void
      {
         var edges:Array=[], groups:Array=[];
         for (var i:int=0;i<volumes.length;i++)
         {
            groups[i]=i;
            for (var j:int=0;j<i;j++)
            { var e:Object=adjacent(volumes[i],volumes[j]); if (e) edges.push(e); }
         }
         shuffle(edges);
         if(partitionInfo)
         {
            for each(var relation:Object in edges)
               relation.priority=-Math.log(Math.max(0.00001,rnd()))/RRSpaceRules.affinity(theme,relation.a.role,relation.b.role);
            edges.sortOn("priority",Array.NUMERIC);
         }
         var chosen:Array=[], extras:Array=[];
         for each (e in edges)
         {
            var ga:int=groups[e.a.id],gb:int=groups[e.b.id];
            if (ga==gb) { extras.push(e); continue; }
            chosen.push(e);
            for (i=0;i<groups.length;i++) if (groups[i]==gb) groups[i]=ga;
         }
         if (chosen.length!=volumes.length-1) throw new Error("Disconnected architectural partition");
         var density:Number=partitionInfo?Number(partitionInfo.extra):[0,0.45,0.75,1][pick(0,3)];
         for each (e in extras) if (rnd()<density) chosen.push(e);
         var roomGroups:Array=[];
         for(i=0;i<volumes.length;i++) roomGroups[i]=i;
         for each (e in chosen)
         {
            var merged:Boolean=false;
            if (e.vertical)
            {
               var lower:Object=e.a.top>e.b.top?e.a:e.b;
               var lx:int=ladderPosition(e.lo+1,e.hi-2,e.y,lower.floor,lower.role=="canal"?lower:null);
               ladderRoute(lx,e.y,lower.floor,lower);
               e.x=lx; e.kind="ladder";
               merged=mergeStoreys(e,roomGroups);
            }
            else
            {
               var f:int=e.hi;
               merged=mergeSide(e,roomGroups);
               if(!merged) open(e.x0,f-2,e.x1,f,e.a.bg);
               reserve(e.x0-2,f-3,e.x1+2,f);
               landingToFloor(e.a,e.x,f);
               landingToFloor(e.b,e.x1,f);
               var outdoors:Boolean=e.a.role=="street" || e.b.role=="street" || e.a.role=="roof" || e.b.role=="roof";
               var chance:Number=theme=="sewer"?0.28:(theme=="stable"?0.88:0.7);
               if(merged) e.kind="merge";
               else if (rnd()<chance && !outdoors && support(e.x,f)) { door(e.x,f,e.a.bg,e.a.role,e.b.role); e.kind="door"; }
               else e.kind="opening";
               e.y=f;
            }
            if(merged)
            {
               e.kind="merge"; ga=roomGroups[e.a.id]; gb=roomGroups[e.b.id];
               for(i=0;i<roomGroups.length;i++) if(roomGroups[i]==gb) roomGroups[i]=ga;
            }
            links.push({a:e.a.id,b:e.b.id,kind:e.kind,x:e.x,y:e.y});
         }
         if(partitionInfo)
         {
            var distinct:Object={},rooms:int=0;
            for(i=0;i<volumes.length;i++)
            {
               volumes[i].room=roomGroups[i];
               if(!distinct[roomGroups[i]]) { distinct[roomGroups[i]]=true; rooms++; }
            }
            partitionInfo.rooms=rooms; partitionInfo.merges=merges.length;
         }
      }
      private function volumeAt(x:int,y:int):Object
      {
         for each (var r:Object in volumes) if (x>=r.x0 && x<=r.x1 && y>=r.top && y<=r.floor) return r;
         throw new Error("No volume at port "+x+","+y);
      }
      private function connectBoundary():void
      {
         for (var p:int=0;p<22;p++) if (ports[p]>=2)
         {
            var b:Object=RRPorts.rect(p,ports[p]);
            var r:Object;
            if (RRPorts.vertical(p))
            {
               r=volumeAt(b.x0,p>=17?1:23);
               if (p>=17) ladderRoute(b.x0,0,r.floor,r);
               else ladder(b.x0,24,24,r.bg);
               reserve(b.x0-1,p>=17?0:21,b.x1+1,p>=17?3:24);
            }
            else
            {
               r=volumeAt(p>=11?1:46,b.y1);
               open(b.x0,b.y0,b.x1,b.y1,r.bg);
               for (var x:int=b.x0;x<=b.x1;x++) grid[b.y1+1][x]=trim;
               landingToFloor(r,p>=11?0:47,b.y1);
               reserve(p>=11?0:43,b.y0-1,p>=11?4:47,b.y1);
            }
         }
      }
      private function landingToFloor(r:Object,edgeX:int,f:int):void
      {
         if (r.floor==f) return;
         var left:Boolean=edgeX<=r.x0;
         var bank:Object=partitionInfo && r.role=="canal"?r:null;
         var lx:int=left?ladderPosition(r.x0,Math.min(r.x0+6,r.x1-1),f+1,r.floor,bank):
            ladderPosition(Math.max(r.x1-7,r.x0),r.x1-1,f+1,r.floor,bank);
         var x0:int=left?r.x0:Math.max(r.x0,lx-1), x1:int=left?Math.min(r.x1,lx+2):r.x1;
         platform(x0,x1,f+1,r.bg);
         ladderRoute(lx,f+1,r.floor,r);
         reserve(x0,f-2,x1,f);
      }
      private function gallery(r:Object):void
      {
         // A large hall should not lose its only mezzanine because the first
         // trial intersects one reserved doorway. Try complete valid placements.
         for(var attempt:int=0;attempt<10;attempt++)
         {
            var f:int=pick(r.top+4,r.floor-5);
            var wide:Boolean=r.role=="hall" || (r.role=="workshop" && rnd()<0.5);
            var width:int=wide?pick(int((r.x1-r.x0)/2),r.x1-r.x0-3):pick(6,Math.min(12,r.x1-r.x0-3));
            var left:Boolean=rnd()<0.5;
            var x0:int=left?r.x0:r.x1-width+1,x1:int=left?r.x0+width-1:r.x1;
            var clear:Boolean=true;
            for(var y:int=f-2;y<=f+1;y++) for(var x:int=x0;x<=x1;x++)
               if(reserved[y+","+x] || solid(x,y)) clear=false;
            if(!clear) continue;
            platform(x0,x1,f+1,r.bg);
            var lx:int=ladderPosition(x0+1,x1-2,f+1,r.floor);
            ladderRoute(lx,f+1,r.floor,r);
            regions.push({x0:x0,top:r.top,x1:x1,floor:f,bg:r.bg,
               role:r.role=="hall"?"corridor":(r.role=="workshop"?"control":(r.role=="warehouse"?"store":(r.role=="service"?"service":"roof")))});
            return;
         }
      }
      private function addSceneFeatures():void
      {
         if (theme=="sewer")
         {
            for each (var r:Object in volumes) if (r.role=="canal") addPool(r);
            if (sceneForm!="dry_tunnels" && !pools.length) throw new Error("No safe space for a canal and dry bank");
         }
         if (theme=="mane" && (sceneForm=="ruined" || sceneForm=="rooftops" || sceneForm=="street_links"))
         {
            // Short missing floor sections make visible ruptures. The directed
            // return audit below must still pass through the remaining routes.
            var changes:int=pick(1,3);
            for (var t:int=0;t<60 && changes>0;t++)
            {
               var x:int=pick(5,39),y:int=pick(6,19),width:int=pick(2,4),ok:Boolean=true;
               for (var xx:int=x-1;xx<=x+width;xx++)
               {
                  if (!solid(xx,y) || solid(xx,y-1) || solid(xx,y+1)) ok=false;
                  for (var yy:int=y-2;yy<=y+2;yy++) if (reserved[yy+","+xx]) ok=false;
               }
               if (!ok) continue;
               // Concrete has fallen away, leaving a traversable native beam.
               // The old clearance-only gap implied jumps the route audit did
               // not simulate. A residual beam keeps both approaches valid.
               for (xx=x;xx<x+width;xx++) grid[y][xx]=String(grid[y+1][xx])+"-";
               changes--;
            }
         }
      }
      private function addPool(r:Object):void
      {
         var f:int=r.floor;
         var depth:int=sceneForm=="cistern"?pick(5,8):pick(2,3);
         if(partitionInfo && sceneForm=="cistern") depth=Math.min(depth,r.floor-r.top-4);
         if (f-r.top<depth+4 || r.x1-r.x0<14) return;
         var candidates:Array=[];
         for (var lo:int=r.x0+4;lo<=r.x1-10;lo++)
         {
            var available:int=Math.min(sceneForm=="pump_chain"?12:26,r.x1-lo-4);
            var minimum:int=sceneForm=="cistern"?(partitionInfo?10:12):(sceneForm=="pump_chain"?6:10);
            if(available<minimum) continue;
            for(var width:int=available;width>=minimum;width--)
            {
               var hi:int=lo+width-1,ok:Boolean=true;
               for (var y:int=f-depth-3;y<=f;y++) for (var x:int=lo-3;x<=hi+3;x++)
                  if (solid(x,y) || reserved[y+","+x] || String(grid[y][x]).indexOf("-")>=0) ok=false;
               if (ok) { candidates.push({lo:lo,hi:hi,score:width+rnd()*3}); break; }
            }
         }
         if (!candidates.length) return;
         candidates.sortOn("score",Array.NUMERIC|Array.DESCENDING);
         var p:Object=candidates[0]; lo=p.lo; hi=p.hi;
         // A contained basin, a dry crossing above it, dry bank
         // ladders outside, and a separate ladder out of the optional basin.
         for (y=f-depth+1;y<=f;y++) { grid[y][lo-1]=wall; grid[y][hi+1]=wall; }
         platform(lo-2,hi+2,f-depth,r.bg);
         ladder(lo-3,f-depth,f,r.bg); ladder(hi+2,f-depth,f,r.bg);
         ladder(lo+1,f-depth,f,r.bg);
         for (y=f-depth+1;y<=f;y++) for (x=lo;x<=hi;x++) grid[y][x]+="*";
         pools.push({x0:lo,x1:hi,top:f-depth+1,bottom:f,deck:f-depth});
         reserve(lo-3,f-depth-3,hi+3,f);
         regions.push({x0:lo-2,x1:hi+2,top:r.top,floor:f-depth-1,bg:r.bg,role:"canal_walk"});
      }
      private function shapeCeiling(r:Object):void
      {
         if(theme=="mane" || r.role=="canal" || r.role=="hall" || r.role=="warehouse") return;
         var deep:int=theme=="sewer"?pick(2,5):(theme=="stable"?pick(1,3):pick(0,2));
         deep=Math.min(deep,r.floor-r.top-5);
         if(deep<1) return;
         var left:Boolean=rnd()<0.5, width:int=pick(3,Math.max(3,int((r.x1-r.x0+1)*0.65)));
         var lo:int=left?r.x0:r.x1-width+1,hi:int=lo+width-1;
         // A stepped equipment/structural bulkhead hangs from the ceiling.
         // Keep entire authored traffic reserves; never patch a route later.
         for(var y:int=r.top;y<r.top+deep;y++) for(var x:int=lo;x<=hi;x++)
            if(reserved[y+","+x] || String(grid[y][x]).indexOf("А")>=0 || String(grid[y][x]).indexOf("-")>=0) return;
         for(y=r.top;y<r.top+deep;y++) for(x=lo;x<=hi;x++) grid[y][x]=wall;
      }
      private function dressMaterials():void
      {
         for each(var r:Object in volumes)
         {
            for(var y:int=r.top;y<=r.floor;y++) for(var x:int=r.x0;x<=r.x1;x++)
            {
               var code:String=String(grid[y][x]);
               if(solid(x,y)) continue;
               var bg:String=r.bg;
               if(theme=="stable")
               {
                  if(y<=r.top+1) bg="R";
                  else if(y>=r.floor-1) bg="P";
                  else if(r.role=="control" && x>=r.x0+2 && x<=r.x1-2) bg="O";
               }
               else if(theme=="sewer" && (r.role=="canal" || r.role=="service"))
                  bg=y>=r.floor-3?"E":(x<r.x0+3 || x>r.x1-3?"S":r.bg);
               else if(theme=="plant" && (r.role=="workshop" || r.role=="warehouse"))
                  bg=y>=r.floor-3?"D":r.bg;
               // Replace only the background symbol. Water, stairs and shelves
               // retain exactly the geometry audited immediately above.
               var extra:String=code.substr(1);
               if(extra.length && RRSynth.WALL_CHARS.indexOf(extra.charAt(0))>=0) extra=extra.substr(1);
               grid[y][x]="_"+bg+extra;
            }
         }
         for(y=1;y<24;y++) for(x=1;x<47;x++) if(solid(x,y))
         {
            if(theme=="stable" && solid(x,y-1) && solid(x,y+1)) grid[y][x]=(x%9<2)?"K":"J";
            if(theme=="plant" && (x<4 || x>43 || y>20) && (int(x/7)+int(y/5))%3==0) grid[y][x]="D";
            if(theme=="sewer" && solid(x,y-1) && solid(x,y+1) && (x<5 || x>42)) grid[y][x]="I";
            if(theme=="mane" && (int(x/8)+int(y/6))%3==0) grid[y][x]="D";
         }
      }
      private function open(x0:int,top:int,x1:int,bottom:int,bg:String):void
      {
         for (var y:int=Math.max(0,top);y<=Math.min(24,bottom);y++)
            for (var x:int=Math.max(0,x0);x<=Math.min(47,x1);x++) grid[y][x]="_"+bg;
      }
      private function platform(x0:int,x1:int,y:int,bg:String):void
      {
         for (var x:int=Math.max(1,x0);x<=Math.min(46,x1);x++)
            if (!reserved[y+","+x]) grid[y][x]="_"+bg+"-";
      }
      private function ladder(x:int,top:int,bottom:int,bg:String):void
      {
         for (var yy:int=top;yy<=bottom;yy++) for(var xx:int=x;xx<=x+1;xx++)
            if(/[ВГ]/.test(String(grid[yy][xx]))) throw new Error("Later ladder cuts an existing stair flight");
         for (var y:int=top;y<=bottom;y++)
         { grid[y][x]="_"+bg; grid[y][x+1]="_"+bg+"А"; }
         ladders.push({x:x,top:top,bottom:bottom});
         reserve(x,Math.max(0,top-2),x+1,bottom);
         reserve(x-1,bottom-1,x+2,bottom);
      }
      private function ladderPosition(lo:int,hi:int,top:int,bottom:int,canal:Object=null):int
      {
         var choices:Array=[];
         for (var x:int=lo;x<=hi;x++)
         {
            var ok:Boolean=true;
            for each (var l:Object in ladders)
            {
               if (top<=l.bottom+1 && bottom>=l.top-1 && x!=l.x && Math.abs(x-l.x)<3) ok=false;
               // Do not turn an already staggered upper flight back into a
               // straight shaft when attaching a later doorway below it.
               if (archetype!="connector" && x==l.x && top<=l.bottom && bottom>l.bottom) ok=false;
            }
            // Fixed top sockets will later descend into their containing room.
            for (var p:int=17;p<22;p++) if (ports[p]>=2)
            {
               var px:int=5+9*(p-17);
               if (x!=px && Math.abs(x-px)<3) ok=false;
            }
            if (archetype!="connector" && bottom>=21)
               for (p=6;p<11;p++) if (ports[p]>=2 && Math.abs(x-(5+9*(p-6)))<3) ok=false;
            if (ok) choices.push(x);
         }
         if (!choices.length) throw new Error("No separate ladder landing "+lo+".."+hi);
         if(canal!=null)
         {
            choices.sort(function(a:*,b:*):Number {
               return Math.min(Math.abs(int(a)-canal.x0),Math.abs(int(a)-canal.x1+1))-
                  Math.min(Math.abs(int(b)-canal.x0),Math.abs(int(b)-canal.x1+1));
            });
            return choices[0];
         }
         return choices[pick(0,choices.length-1)];
      }
      private function ladderRoute(x:int,top:int,bottom:int,r:Object):void
      {
         // In a planned water volume, circulation belongs on its banks. A
         // diagonal/staggered flight here would consume the basin's footprint.
         if(partitionInfo && r.role=="canal") { ladder(x,top,bottom,r.bg); return; }
         if(top>=4 && bottom-top>=3 && bottom-top<=8 && rnd()<0.65 && stairRoute(x,top,bottom,r)) return;
         if (bottom-top>10 && archetype!="connector")
         {
            var mid:int=top+pick(5,8), choices:Array=[];
            for (var nx:int=r.x0;nx<=r.x1-1;nx++)
            {
               if (Math.abs(nx-x)<3 || Math.abs(nx-x)>9) continue;
               var a:int=Math.max(r.x0,Math.min(x,nx)-1), b:int=Math.min(r.x1,Math.max(x,nx)+2);
               var ok:Boolean=true;
               for (var yy:int=mid-2;yy<=mid;yy++) for (var xx:int=a;xx<=b;xx++)
                  if (solid(xx,yy) || reserved[yy+","+xx]) ok=false;
               for each (var l:Object in ladders)
                  if (mid<=l.bottom+1 && bottom>=l.top-1 && nx!=l.x && Math.abs(nx-l.x)<3) ok=false;
               if (bottom>=21)
                  for (var p:int=6;p<11;p++) if (ports[p]>=2 && Math.abs(nx-(5+9*(p-6)))<3) ok=false;
               if (ok) choices.push({x:nx,a:a,b:b});
            }
            if (choices.length)
            {
               var chosen:Object=choices[pick(0,choices.length-1)];
               platform(chosen.a,chosen.b,mid,r.bg);
               ladder(x,top,mid-1,r.bg);
               ladder(chosen.x,mid,bottom,r.bg);
               reserve(chosen.a,mid-2,chosen.b,mid-1);
               return;
            }
         }
         ladder(x,top,bottom,r.bg);
      }
      private function stairRoute(x:int,top:int,bottom:int,r:Object):Boolean
      {
         var directions:Array=rnd()<0.5?[1,-1]:[-1,1];
         for each(var dir:int in directions)
         {
            var start:int=dir>0?x:x+1, end:int=start+dir*(bottom-top);
            var apertureLo:int=Math.min(x,start+dir*4),apertureHi:int=Math.max(x+1,start+dir*4);
            if(Math.min(start,end)<r.x0+2 || Math.max(start,end)>r.x1-2) continue;
            if(!landing(dir>0?x-1:x+2,top)) continue;
            // A wide stair head in the middle of an intact upper floor can
            // divide it into one-way ledges. Use the narrow ladder fallback;
            // stairs remain available at a floor/platform end.
            if(partitionInfo && landing(apertureLo-1,top) && landing(apertureHi+1,top)) continue;
            var ok:Boolean=true;
            for(var y:int=top;y<=bottom;y++)
            {
               var sx:int=start+dir*(y-top);
               for(var yy:int=y-3;yy<=y;yy++) for(var xx:int=sx-1;xx<=sx+1;xx++)
               {
                  if(yy==top && xx==(dir>0?x-1:x+2)) continue;
                  if(yy==top && xx>=apertureLo && xx<=apertureHi)
                  { if(reserved[yy+","+xx]) ok=false; continue; }
                  if(solid(xx,yy) || reserved[yy+","+xx] || String(grid[yy][xx]).indexOf("-")>=0) ok=false;
               }
            }
            if(!ok) continue;
            open(apertureLo,top,apertureHi,top,r.bg);
            reserve(apertureLo,top-3,apertureHi,top);
            for(y=top;y<=bottom;y++)
            {
               sx=start+dir*(y-top);
               grid[y][sx]="_"+r.bg+(dir>0?"Г":"В");
               reserve(sx-1,y-3,sx+1,y);
            }
            stairs.push({x:start,top:top,bottom:bottom,dir:dir});
            return true;
         }
         return false;
      }
      private function door(x:int,floor:int,bg:String,a:String,b:String):void
      {
         var id:String=RRScene.door(theme,a,b,rnd);
         var h:int=id=="stdoor" || id=="door3"?3:2;
         grid[floor-h][x]=wall;
         open(x,floor-h+1,x,floor,bg);
         doors.push({id:id,x:x,y:floor});
         reserve(x-1,floor-h,x+1,floor);
      }
      private function landing(x:int,y:int):Boolean
      { return solid(x,y) || String(grid[y][x]).indexOf("-")>=0; }
      private function auditLadders():void
      {
         for (var y:int=0;y<25;y++) for (var x:int=1;x<48;x++)
         {
            if (String(grid[y][x]).indexOf("А")<0) continue;
            if (solid(x-1,y)) throw new Error("Narrow ladder "+x+","+y);
            if (y==0 || String(grid[y-1][x]).indexOf("А")>=0) continue;
            if (y<2 || solid(x,y-1) || solid(x-1,y-1) || solid(x,y-2) || solid(x-1,y-2))
               throw new Error("Ladder head "+x+","+y);
            if (!landing(x-2,y) && !landing(x+1,y)) throw new Error("Ladder landing "+x+","+y);
         }
      }
      private function auditStairs():void
      {
         for each(var flight:Object in stairs) for(var y:int=flight.top;y<=flight.bottom;y++)
         {
            var x:int=flight.x+flight.dir*(y-flight.top);
            if(String(grid[y][x]).indexOf(flight.dir>0?"Г":"В")<0)
               throw new Error("Interrupted stair flight "+x+","+y);
         }
      }
      private function auditBoundary():void
      {
         var expected:Object={};
         for (var p:int=0;p<22;p++) if (ports[p]>=2)
         {
            var b:Object=RRPorts.rect(p,ports[p]);
            for (var y:int=b.y0;y<=b.y1;y++) for (var x:int=b.x0;x<=b.x1;x++)
            {
               if (solid(x,y)) throw new Error("Blocked declared port "+p);
               expected[y+","+x]=true;
            }
         }
         for (y=0;y<25;y++) for (x=0;x<48;x++)
            if ((x==0 || x==47 || y==0 || y==24) && !solid(x,y) && !expected[y+","+x])
               throw new Error("Undeclared edge hole "+x+","+y);
      }
      private function addHatches():void
      {
         var candidates:Array=[];
         for each (var l:Object in ladders) for (var y:int=Math.max(4,l.top);y<=Math.min(20,l.bottom-2);y++)
         {
            var x:int=l.x;
            if (!landing(x-1,y) || !landing(x+2,y)) continue;
            var clear:Boolean=true;
            for (var yy:int=y-2;yy<=y+2;yy++) if (solid(x,yy) || solid(x+1,yy)) clear=false;
            if (clear) candidates.push({x:x,y:y});
         }
         shuffle(candidates);
         var target:int=pick(0,2);
         for each (var p:Object in candidates)
         {
            if (hatches.length>=target) break;
            var overlaps:Boolean=false;
            for each (var h:Object in hatches) if (Math.abs(p.x-h.x)<3 && Math.abs(p.y-h.y)<4) overlaps=true;
            if (overlaps) continue;
            p.id=scene.hatches[pick(0,scene.hatches.length-1)];
            hatches.push(p); reserve(p.x-1,p.y-2,p.x+2,p.y+2);
         }
      }
      private function addWindows():void
      {
         var candidates:Array=[];
         for (var x:int=4;x<=43;x++) for (var y:int=3;y<=21;y++)
         {
            if (!solid(x,y-2) || !solid(x,y-1) || !solid(x,y) || !solid(x,y+1)) continue;
            if (reserved[(y-1)+","+x] || reserved[y+","+x]) continue;
            if (solid(x-1,y-1) || solid(x-1,y) || solid(x+1,y-1) || solid(x+1,y)) continue;
            candidates.push({x:x,y:y});
         }
         shuffle(candidates);
         var target:int=pick(0,scene.windowMax);
         for each (var p:Object in candidates)
         {
            if (windows.length>=target) break;
            if (reserved[(p.y-1)+","+p.x] || reserved[p.y+","+p.x]) continue;
            p.id=scene.windows[pick(0,scene.windows.length-1)];
            open(p.x,p.y-1,p.x,p.y,backgrounds[0]);
            windows.push(p); reserve(p.x-1,p.y-2,p.x+1,p.y+1);
         }
      }
      private function chooseSpawn():void
      {
         var candidates:Array=[];
         for each (var r:Object in volumes) for (var x:int=r.x0+1;x<r.x1-1;x++)
         {
            var f:int=r.floor,ok:Boolean=true;
            for (var xx:int=x;xx<=x+1;xx++) for (var y:int=f-2;y<=f;y++)
               if (solid(xx,y) || reserved[y+","+xx]) ok=false;
            if (ok && support(x,f) && support(x+1,f)) candidates.push({x:x,y:f});
         }
         if (!candidates.length) throw new Error("No supported spawn in architecture");
         spawn=candidates[pick(0,candidates.length-1)];
         reserve(spawn.x-1,spawn.y-3,spawn.x+2,spawn.y);
      }
      public function reserve(x0:int,top:int,x1:int,bottom:int):void
      {
         for (var y:int=Math.max(0,top);y<=Math.min(24,bottom);y++)
            for (var x:int=Math.max(0,x0);x<=Math.min(47,x1);x++) reserved[y+","+x]=true;
      }
      public function solid(x:int,y:int):Boolean
      { return x<0 || x>=48 || y<0 || y>=25 || RRSynth.WALL_CHARS.indexOf(String(grid[y][x]).charAt(0))>=0; }
      public function support(x:int,y:int):Boolean
      { return x>=0 && x<48 && y>=0 && y+1<25 && (solid(x,y+1) || String(grid[y+1][x]).indexOf("-")>=0); }
   }
}
