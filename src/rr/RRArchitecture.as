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
      public function build(biome:String,requested:String="", boundary:Array=null):void
      {
         theme=biome;
         scene=RRScene.profile(theme);
         sceneForm=scene.forms[pick(0,scene.forms.length-1)];
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
         grid=[]; regions=[]; ladders=[]; doors=[]; hatches=[]; windows=[]; pools=[];
         reserved={}; links=[];
         for (var y:int=0;y<25;y++)
         {
            grid[y]=[];
            for (var x:int=0;x<48;x++) grid[y][x]=wall;
         }
         // Styles influence proportions and purpose, never fixed coordinates.
         tallBias=scene.bias;
         var target:int=pick(scene.min,scene.max);
         if (archetype=="connector") { target=pick(3,5); tallBias=0.9; }
         volumes=[{x0:1,top:1,x1:46,floor:23}];
         seedScene();
         partition(target);
         for (var i:int=0;i<volumes.length;i++)
         {
            var r:Object=volumes[i];
            r.id=i; r.role=r.role?r.role:purpose(r); r.bg=RRScene.background(theme,r.role,rnd);
            open(r.x0,r.top,r.x1,r.floor,r.bg);
            regions.push(r);
         }
         connectBoundary();
         connectVolumes();
         for each (r in volumes) if (r.floor-r.top>=10 && r.x1-r.x0>=14 && rnd()<0.6) gallery(r);
         addSceneFeatures();
         addHatches();
         addWindows();
         chooseSpawn();
         auditLadders();
         auditBoundary();
         RRTraversal.check(this);
         if (pools.length) RRTraversal.check(this,true);
         for (y=1;y<25;y++) for (x=0;x<48;x++)
            if (solid(x,y) && !solid(x,y-1)) grid[y][x]=trim;
      }
      private function purpose(r:Object):String
      {
         var roles:Array;
         if (theme=="sewer") roles=["service","service","service","control","store"];
         else if (theme=="plant") roles=["workshop","workshop","store","control","office"];
         else if (theme=="stable") roles=sceneForm=="quarters"?["living","living","office","store"]:
            ["office","living","service","control","store"];
         else roles=["living","living","office","office","store"];
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
      private function seedScene():void
      {
         var parts:Array,major:Object;
         if (theme=="plant")
         {
            // One generous working bay beside (or above) supporting rooms.
            var vertical:Boolean=sceneForm=="production" || (sceneForm=="storage_hall" && rnd()<0.5);
            parts=divide(volumes[0],vertical,vertical?16:8,vertical?31:14);
            major=parts[rnd()<0.5?0:1]; major.keep=true;
            major.role=sceneForm=="storage_hall"?"warehouse":"workshop";
         }
         else if (theme=="sewer")
         {
            if (sceneForm=="cistern")
            {
               parts=divide(volumes[0],true,17,30);
               major=parts[rnd()<0.5?0:1];
            }
            else { parts=divide(volumes[0],false,6,15); major=parts[1]; }
            major.keep=true; major.role="canal";
            if (sceneForm=="pump_chain")
            {
               major.keep=false;
               parts=divide(major,true,18,30);
               parts[0].keep=true; parts[0].role="canal";
               parts[1].keep=true; parts[1].role="control";
            }
         }
         else if (theme=="mane")
         {
            // A facade and outdoor volume; roof passage instead separates
            // the sky band above a building. Floors remain locally varied.
            if (sceneForm=="roof_passage")
            {
               parts=divide(volumes[0],false,7,12);
               major=parts[0]; major.keep=true; major.role="roof";
            }
            else
            {
               parts=divide(volumes[0],true,16,29);
               major=parts[rnd()<0.5?0:1];
               if (sceneForm=="courtyard" && major.x1-major.x0>=22)
               {
                  parts=divide(major,true,major.x0+9,major.x1-9);
                  major=parts[major.x0==1?1:0];
               }
               major.keep=true; major.role="street";
            }
         }
         else if (sceneForm=="atrium_ring")
         {
            parts=divide(volumes[0],true,17,29);
            major=parts[rnd()<0.5?0:1]; major.keep=true; major.role="hall";
         }
         else if (sceneForm=="quarters") divide(volumes[0],false,8,14);
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
         if (a.x1+2==b.x0 || b.x1+2==a.x0)
         {
            lo=Math.max(a.top,b.top); hi=Math.min(a.floor,b.floor);
            if (hi-lo>=3) return {a:a,b:b,vertical:false,x:a.x1<b.x0?a.x1+1:b.x1+1,lo:lo,hi:hi};
         }
         if (a.floor+2==b.top || b.floor+2==a.top)
         {
            lo=Math.max(a.x0,b.x0); hi=Math.min(a.x1,b.x1);
            if (hi-lo>=4) return {a:a,b:b,vertical:true,y:a.floor<b.top?a.floor+1:b.floor+1,lo:lo,hi:hi};
         }
         return null;
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
         var chosen:Array=[], extras:Array=[];
         for each (e in edges)
         {
            var ga:int=groups[e.a.id],gb:int=groups[e.b.id];
            if (ga==gb) { extras.push(e); continue; }
            chosen.push(e);
            for (i=0;i<groups.length;i++) if (groups[i]==gb) groups[i]=ga;
         }
         if (chosen.length!=volumes.length-1) throw new Error("Disconnected architectural partition");
         var density:Number=[0,0.45,0.75,1][pick(0,3)];
         for each (e in extras) if (rnd()<density) chosen.push(e);
         for each (e in chosen)
         {
            if (e.vertical)
            {
               var lower:Object=e.a.top>e.b.top?e.a:e.b;
               var lx:int=ladderPosition(e.lo+1,e.hi-2,e.y,lower.floor);
               ladderRoute(lx,e.y,lower.floor,lower);
               e.x=lx; e.kind="ladder";
            }
            else
            {
               var f:int=e.hi;
               open(e.x,f-2,e.x,f,e.a.bg);
               reserve(e.x-2,f-3,e.x+2,f);
               landingToFloor(e.a,e.x,f);
               landingToFloor(e.b,e.x,f);
               var outdoors:Boolean=e.a.role=="street" || e.b.role=="street" || e.a.role=="roof" || e.b.role=="roof";
               var chance:Number=theme=="sewer"?0.28:(theme=="stable"?0.88:0.7);
               if (rnd()<chance && !outdoors) { door(e.x,f,e.a.bg,e.a.role,e.b.role); e.kind="door"; }
               else e.kind="opening";
               e.y=f;
            }
            links.push({a:e.a.id,b:e.b.id,kind:e.kind,x:e.x,y:e.y});
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
         var lx:int=left?ladderPosition(r.x0,Math.min(r.x0+6,r.x1-1),f+1,r.floor):
            ladderPosition(Math.max(r.x1-7,r.x0),r.x1-1,f+1,r.floor);
         var x0:int=left?r.x0:Math.max(r.x0,lx-1), x1:int=left?Math.min(r.x1,lx+2):r.x1;
         platform(x0,x1,f+1,r.bg);
         ladderRoute(lx,f+1,r.floor,r);
         reserve(x0,f-2,x1,f);
      }
      private function gallery(r:Object):void
      {
         var f:int=pick(r.top+4,r.floor-5);
         var width:int=pick(6,Math.min(12,r.x1-r.x0-3));
         var left:Boolean=rnd()<0.5;
         var x0:int=left?r.x0:r.x1-width+1, x1:int=left?r.x0+width-1:r.x1;
         for (var y:int=f-2;y<=f+1;y++) for (var x:int=x0;x<=x1;x++)
            if (reserved[y+","+x]) return;
         platform(x0,x1,f+1,r.bg);
         var lx:int=ladderPosition(x0+1,x1-2,f+1,r.floor);
         ladderRoute(lx,f+1,r.floor,r);
         regions.push({x0:x0,top:r.top,x1:x1,floor:f,bg:r.bg,
            role:(r.role=="street" || r.role=="roof")?"roof":purpose(r)});
      }
      private function addSceneFeatures():void
      {
         if (theme=="sewer")
         {
            for each (var r:Object in volumes) if (r.role=="canal") addPool(r);
            if (!pools.length) throw new Error("No safe space for a canal and dry bank");
         }
         if (theme=="mane")
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
               for (xx=x;xx<x+width;xx++) grid[y][xx]=String(grid[y+1][xx]);
               changes--;
            }
         }
      }
      private function addPool(r:Object):void
      {
         var f:int=r.floor;
         if (f-r.top<7 || r.x1-r.x0<14) return;
         var candidates:Array=[];
         for (var lo:int=r.x0+4;lo<=r.x1-10;lo++)
         {
            var width:int=pick(6,Math.min(14,r.x1-lo-4)),hi:int=lo+width-1,ok:Boolean=true;
            for (var y:int=f-5;y<=f;y++) for (var x:int=lo-3;x<=hi+3;x++)
               if (solid(x,y) || reserved[y+","+x] || String(grid[y][x]).indexOf("-")>=0) ok=false;
            if (ok) candidates.push({lo:lo,hi:hi});
         }
         if (!candidates.length) return;
         var p:Object=candidates[pick(0,candidates.length-1)]; lo=p.lo; hi=p.hi;
         // Two-cell-deep contained water, a dry crossing above it, dry bank
         // ladders outside, and a separate ladder out of the optional basin.
         for (y=f-1;y<=f;y++) { grid[y][lo-1]=wall; grid[y][hi+1]=wall; }
         platform(lo-2,hi+2,f-2,r.bg);
         ladder(lo-3,f-2,f,r.bg); ladder(hi+2,f-2,f,r.bg);
         ladder(lo+1,f-2,f,r.bg);
         for (y=f-1;y<=f;y++) for (x=lo;x<=hi;x++) grid[y][x]+="*";
         pools.push({x0:lo,x1:hi,top:f-1,bottom:f,deck:f-2});
         reserve(lo-3,f-5,hi+3,f);
         regions.push({x0:lo-2,x1:hi+2,top:r.top,floor:f-3,bg:r.bg,role:"canal_walk"});
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
         for (var y:int=top;y<=bottom;y++)
         { grid[y][x]="_"+bg; grid[y][x+1]="_"+bg+"А"; }
         ladders.push({x:x,top:top,bottom:bottom});
         reserve(x,Math.max(0,top-2),x+1,bottom);
         reserve(x-1,bottom-1,x+2,bottom);
      }
      private function ladderPosition(lo:int,hi:int,top:int,bottom:int):int
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
         return choices[pick(0,choices.length-1)];
      }
      private function ladderRoute(x:int,top:int,bottom:int,r:Object):void
      {
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
      private function door(x:int,floor:int,bg:String,a:String,b:String):void
      {
         var id:String=RRScene.door(theme,a,b,rnd);
         var h:int=id=="stdoor"?3:2;
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
