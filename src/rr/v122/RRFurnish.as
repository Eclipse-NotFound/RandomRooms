package rr.v122
{
   import rr.RREcology;
   import rr.RRPorts;
   import rr.RRScene;
   import rr.RRSeed;

   /** Furnish a completed space by purpose. Collision groups fit as a whole;
    * background facilities can overlap furniture, but cannot cut walls/shafts. */
   public class RRFurnish
   {
      public var objects:Array = [];
      public var backs:Array = [];
      public var coverage:Array = [];
      private var plan:RRArchitecture;
      private var rnd:Function;
      private var occupied:Object = {};
      private var backUsed:Object = {};
      // size, conservative height, hanging fixture (AllData 1.02).
      public static const OBJECTS:Object = {
         table:[2,1,0],table1:[2,1,0],table2:[2,1,0],filecab:[1,2,0],
         bookcase:[2,3,0],locker:[2,3,0],couch:[2,1,0],bed:[4,1,0],
         mcrate1:[2,2,0],box:[2,2,0],bigbox:[3,2,0],instr1:[2,2,0],
         bigmed:[2,3,0],medbox:[1,1,1],wcup:[1,1,1],wallcab:[1,1,1],
         cup:[2,2,0],ccup:[1,1,0],tap:[1,2,0],fridge:[1,2,0],trash:[1,1,0],
         woodbox:[2,2,0],mcrate2:[2,2,0],tumba1:[1,1,0],tumba2:[1,1,0]
      };
      private static const BACKS:Object = {
         stwindow:[4,2],bwindow:[4,2],stlight3:[2,1],stlight4:[2,1],
         light2:[2,1],light3:[2,1],light4:[2,1],wires1:[1,2],wires2:[1,2],
         pult:[2,1],monitor:[2,1],zavod2:[3,2],pipe3:[2,1],pipe4:[1,2],
         potek:[10,2],vent:[1,1],bvent:[4,2],depot:[2,3],storage:[4,3],
         electro:[3,4],clock:[1,1],poster:[2,2],stillage:[3,3],
         fwindow:[6,6],stabledoor:[3,3],stlight1:[1,1],light1:[1,1],
         konstr:[1,4],vkonstr:[2,3],hkonstr:[6,2],railing:[4,1],
         pipe1:[10,2],pipe2:[12,3],pipes:[3,3],stok:[3,3],stok2:[2,2],
         plesen:[10,2],moss:[10,2],zavod1:[4,3],fuse:[4,3],
         heap1:[6,3],heap2:[6,2],heap3:[3,1],swindow:[2,1],hole:[10,10]
      };

      public function RRFurnish(p:RRArchitecture, random:Function) { plan=p; rnd=random; }
      private function choose(a:Array):* { return a[int(rnd()*a.length)]; }
      private function group(w:int, h:int, obj:Array, back:Array):Object
      { return {w:w,h:h,obj:obj,back:back}; }

      // These are semantic relationships learned from the corpus, not terrain
      // chunks. Counts, spacing, position and the containing space are generated.
      private function kit(role:String,compact:Boolean=false):Object
      {
         var theme:String=plan.theme,light:String=plan.scene.light;
         if (role=="street" || role=="roof")
            return compact?group(3,2,[],[["heap3",0,0]]):group(7,3,[],[["heap3",0,0],["railing",3,0]]);
         if (theme=="sewer")
         {
            if (role=="canal" || role=="canal_walk")
               return group(3,3,[],[["light1",0,-3],["pipe4",2,-2]]);
            if (compact)
               return role=="store"?group(2,3,[["locker",0,0]],[]):
                  group(2,2,[["instr1",0,0]],[["vent",0,-2]]);
            if (role=="control")
               return group(7,4,[["instr1",0,0],["table1",3,0]],[["pult",3,-2],["pipe4",6,-3],["pipe4",6,-1],["light1",2,-4]]);
            if (role=="store")
               return group(6,4,[["locker",0,0],["mcrate2",4,0]],[["storage",2,-2],["light1",3,-4]]);
            return group(6,4,[["table1",0,0],["instr1",4,0]],[["pipe4",3,-3],["pipe4",3,-1],["vent",0,-3],["light1",5,-4]]);
         }
         if (compact)
         {
            if(role=="living") return theme=="stable" && rnd()<0.7?
               group(4,1,[["bed",0,0]],[]):group(3,1,[["couch",0,0],[theme=="stable"?"tumba2":"tumba1",2,0]],[]);
            if(role=="office") return group(3,2,[[theme=="stable"?"table2":"table",0,0],["filecab",2,0]],[["clock",0,-2]]);
            if(role=="kitchen") return group(3,2,[["ccup",0,0],["tap",1,0],["fridge",2,0]],[["vent",1,-2]]);
            if(role=="medical") return group(2,3,[["bigmed",0,0]],[]);
            if(role=="control") return group(2,2,[["table1",0,0]],[["monitor",0,-2],["pult",0,-1]]);
            if(role=="hall" || role=="corridor") return group(2,1,[["couch",0,0]],[]);
            var small:String=role=="service" || role=="workshop"?"instr1":
               (theme=="stable"?"mcrate1":(theme=="plant"?"woodbox":"mcrate2"));
            return group(2,2,[[small,0,0]],[]);
         }
         if (role == "office")
         {
            if (theme=="stable")
               return group(7,4,[["table2",1,0],["filecab",4,0],["filecab",5,0]],
                  [["stwindow",0,-3],["wires1",6,-3],["wires1",6,-1],["stlight4",1,-4]]);
            if (rnd() < 0.5)
               return group(7,4,[["table",1,0],["filecab",4,0],["filecab",5,0]],
                  [["bwindow",0,-3],["clock",5,-3],[light,2,-4]]);
            return group(7,4,[["bookcase",0,0],["table",3,0],["trash",6,0]],
               [["poster",3,-3],[light,4,-4]]);
         }
         if (role == "living")
         {
            if (theme=="stable")
               return rnd()<0.65?group(7,4,[["bed",0,0],["tumba2",4,0],["cup",5,0]],[["stwindow",1,-3],["stlight3",4,-4]]):
                  group(7,4,[["couch",0,0],["table2",3,0],["tumba2",6,0]],[["stwindow",0,-3],["stlight3",4,-4]]);
            if (rnd() < 0.55)
               return group(8,3,[["couch",0,0],["table1",3,0],["cup",6,0]],
                  [["poster",0,-3],[light,4,-3]]);
            return group(6,4,[["table1",0,0],["ccup",2,0],["tap",3,0],["fridge",5,0],
                  ["wcup",2,-3],["wcup",3,-3]],[[light,0,-4]]);
         }
         if (role=="kitchen")
            return group(7,4,[[theme=="stable"?"table2":"table1",0,0],["ccup",3,0],["tap",4,0],["fridge",6,0],
               ["wcup",3,-3],["wcup",4,-3]],[[light,0,-4]]);
         if (role == "workshop" || role == "control" || role=="service")
         {
            if (theme=="plant" && role=="workshop")
               return group(9,5,[["instr1",5,0],["box",7,0]],[["zavod1",0,-2],["pult",5,-2],["light4",3,-5],["konstr",8,-4]]);
            if (role=="control")
               return group(8,4,[["bigbox",0,0]],[["electro",0,-3],["pult",3,-1],
                  ["monitor",3,-2],["monitor",3,-3],["electro",5,-3],[light,3,-4]]);
            return group(7,4,[["table1",0,0],["instr1",4,0]],
               [["vent",1,-3],["pipe4",6,-3],["pipe4",6,-1],[light,2,-4]]);
         }
         if (role == "medical")
         {
            return group(7,4,[["table",0,0],["bigmed",4,0],["medbox",2,-2]],
               [["vent",0,-3],["pipe4",6,-3],["pipe4",6,-1],[light,2,-4]]);
         }
         if (role=="hall" || role=="corridor")
            return theme=="stable"?group(6,4,[["couch",0,0],["tumba2",4,0]],[["stwindow",0,-3],[light,3,-4]]):
               group(5,3,[["trash",3,0]],[[light,1,-3]]);
         // Storage bays use back-layer shelves for density, leaving front space.
         var count:int = 2 + int(rnd()*2);
         var o:Array=[], b:Array=[];
         for (var i:int=0;i<count;i++)
         {
            o.push([theme=="stable"?"mcrate1":(theme=="plant"?"woodbox":"mcrate2"),i*3,0]);
            b.push([theme=="mane"?"stillage":"depot",i*3,-2]);
         }
         b.push([light,1,-4]);
         return group(count*3,4,o,b);
      }

      private function fitsObject(id:String,x:int,y:int, extra:Object=null):Boolean
      {
         var d:Array=OBJECTS[id];
         if (!d) return false;
         for (var yy:int=y-int(d[1])+1;yy<=y;yy++)
            for (var xx:int=x;xx<x+int(d[0]);xx++)
            {
               var key:String=yy+","+xx;
               if (plan.solid(xx,yy) || plan.reserved[key] || occupied[key] || (extra && extra[key])) return false;
               var code:String=String(plan.grid[yy][xx]);
               if (code.indexOf("-")>=0 || code.indexOf("А")>=0 || code.indexOf("Г")>=0) return false;
            }
         if (int(d[2])==0)
            for (xx=x;xx<x+int(d[0]);xx++) if (!plan.support(xx,y)) return false;
         return true;
      }
      private function mark(id:String,x:int,y:int, dst:Object):void
      {
         var d:Array=OBJECTS[id];
         for (var yy:int=y-int(d[1])+1;yy<=y;yy++)
            for (var xx:int=x;xx<x+int(d[0]);xx++) dst[yy+","+xx]=true;
      }
      private function fitsBack(id:String,x:int,y:int):Boolean
      {
         var d:Array=BACKS[id];
         if (!d) return false;
         for (var yy:int=y;yy<y+int(d[1]);yy++)
            for (var xx:int=x;xx<x+int(d[0]);xx++)
               if (plan.solid(xx,yy)) return false;
         return true;
      }
      private function facility(id:String,x:int,y:int,r:Object):Boolean
      {
         var d:Array=BACKS[id];
         if (!d || x<r.x0 || y<r.top || x+d[0]-1>r.x1 || y+d[1]-1>r.floor) return false;
         for (var yy:int=y;yy<y+d[1];yy++) for (var xx:int=x;xx<x+d[0];xx++)
            if (plan.solid(xx,yy)) return false;
         // Background installations can continue behind dry catwalks and
         // ladders. They do not consume collision space or cancel path reserves.
         backs.push([id,x,y]); return true;
      }
      private function facilities():void
      {
         for each (var r:Object in plan.regions)
         {
            if (!r.hasOwnProperty("id")) continue;
            var h:int=r.floor-r.top+1,w:int=r.x1-r.x0+1,x:int,y:int;
            if (plan.theme=="sewer")
            {
               if (r.role=="canal" || r.role=="service")
               {
                  for (x=r.x0;x<r.x1;x+=2)
                  {
                     facility("pipe3",x,r.top+1,r);
                     if (h>=8) facility("pipe3",x,r.top+2,r);
                  }
                  for (y=r.top+3;y<r.floor;y+=2) facility("pipe4",r.x0+1,y,r);
                  for (x=r.x0;x+9<=r.x1;x+=10) facility(rnd()<0.5?"potek":"plesen",x,r.floor-3,r);
                  if (w>=12 && h>=9)
                     for(x=r.x0+1;x+9<=r.x1;x+=10) facility("pipe1",x,r.top+4,r);
                  // The masonry cuts away to moss at an actual drainage band;
                  // pipes terminate at the basin rather than floating above it.
                  if(r.role=="canal") for each(var basin:Object in plan.pools)
                  {
                     if(basin.x0<r.x0 || basin.x1>r.x1 || basin.bottom!=r.floor) continue;
                     facility("stok",basin.x0,basin.top-2,r);
                     if(basin.x1-basin.x0>13) facility("stok2",basin.x1-2,basin.top-1,r);
                     for(x=basin.x0;x+3<=basin.x1;x+=4) facility("railing",x,basin.deck-1,r);
                     for(x=r.x0;x+9<=r.x1;x+=10) facility("moss",x,basin.top-1,r);
                  }
               }
               facility("light1",r.x0+int(w/2),r.top,r);
            }
            else if (plan.theme=="plant")
            {
               if (r.role=="workshop" || r.role=="warehouse")
               {
                  if (h>=9) for (x=r.x0+2;x+5<=r.x1;x+=9) facility("fwindow",x,r.top+1,r);
                  for (x=r.x0;x<=r.x1;x+=Math.max(12,w-1))
                     for (y=r.top;y+3<=r.floor;y+=4) facility("konstr",x,y,r);
                  for (x=r.x0;x+5<=r.x1;x+=6) facility("hkonstr",x,r.top,r);
                  // Fixed equipment belongs behind the accessible work floor;
                  // traffic clearance must not erase the whole machine line.
                  for (x=r.x0+2;x+3<=r.x1;x+=7)
                     facility(r.role=="warehouse"?"storage":"zavod1",x,r.floor-2,r);
               }
               facility("light4",r.x0+int(w/2)-1,r.top,r);
            }
            else if (plan.theme=="stable")
            {
               for (y=r.top;y+3<=r.floor;y+=4) facility("konstr",r.x0,y,r);
               if (h>=5 && w>=7 && r.role!="control") facility("stabledoor",r.x1-3,r.floor-2,r);
               if (r.role=="hall")
               {
                  for (x=r.x0+2;x+3<=r.x1;x+=7) facility("stwindow",x,r.top+2,r);
                  for (x=r.x0+2;x+2<=r.x1;x+=8) facility("stabledoor",x,r.floor-2,r);
               }
               facility("stlight4",r.x0+int(w/2)-1,r.top,r);
            }
            else
            {
               if (r.role=="street" || r.role=="roof")
               {
                  for (x=r.x0+1;x+3<=r.x1;x+=7) facility("railing",x,r.floor,r);
                  if (w>=8) facility("heap2",r.x0+1,r.floor-1,r);
               }
               else
               {
                  for (x=r.x0+2;x+1<=r.x1;x+=5) facility("swindow",x,r.top+2,r);
                  if (w>=10 && h>=10) facility("hole",r.x0,r.top,r);
                  facility("heap3",r.x1-2,r.floor,r);
                  facility("light3",r.x0+int(w/2)-1,r.top,r);
               }
            }
         }
      }
      private function place(g:Object,x:int,f:int):Boolean
      {
         var extra:Object={};
         var a:Array;
         for each (a in g.obj)
         {
            if (!fitsObject(a[0],x+a[1],f+a[2],extra)) return false;
            mark(a[0],x+a[1],f+a[2],extra);
         }
         // A ceiling bulkhead may hide a window or light without invalidating
         // the bed/desk underneath. Back art never changes collision space.
         // Do not stack two scenery groups in the same strip. Overlap within a
         // coherent group (display over machine, shelf behind crate) is intended.
         for (var ix:int=x;ix<x+g.w;ix++) if (backUsed[f+","+ix]) return false;
         for (ix=x;ix<x+g.w;ix++) backUsed[f+","+ix]=true;
         for each (a in g.obj)
         {
            objects.push([a[0],x+a[1],f+a[2]]);
            mark(a[0],x+a[1],f+a[2],occupied);
         }
         for each (a in g.back) if(fitsBack(a[0],x+a[1],f+a[2])) backs.push([a[0],x+a[1],f+a[2]]);
         return true;
      }

      public function build():void
      {
         objects.push(["player",plan.spawn.x,plan.spawn.y]);
         for each (var d:Object in plan.doors) objects.push([d.id,d.x,d.y,"door"]);
         for each (d in plan.hatches) objects.push([d.id,d.x,d.y,"hatch"]);
         for each (d in plan.windows) objects.push([d.id,d.x,d.y,"window"]);
         for each (var r:Object in plan.regions)
         {
            if (r.role=="shaft") continue;
            var width:int=r.x1-r.x0+1;
            var groups:int=width>26 ? 3 : (width>11?2:1);
            var placedGroups:int=0;
            for (var n:int=0;n<groups;n++)
            {
               var placed:Boolean=false;
               for (var trial:int=0;trial<24 && !placed;trial++)
               {
                  var g:Object=kit(r.role);
                  if (g.w>width || g.h>r.floor-r.top) continue;
                  var x:int=r.x0+int(rnd()*(width-g.w+1));
                  placed=place(g,x,r.floor);
               }
               // The smaller alternative belongs to the same scene and role.
               if (!placed && width>=3)
               {
                  // Try each available offset, not eight repeated random
                  // guesses that can miss the only usable corner in a cell.
                  for(var variant:int=0;variant<2 && !placed;variant++)
                  {
                     g=kit(r.role,true);
                     if(g.w>width || g.h>r.floor-r.top) continue;
                     var slots:int=width-g.w+1,start:int=int(rnd()*slots);
                     for (trial=0;trial<slots && !placed;trial++)
                        placed=place(g,r.x0+(start+trial)%slots,r.floor);
                  }
               }
               if(placed) placedGroups++;
            }
            if(r.hasOwnProperty("id")) coverage.push({region:r.id,role:r.role,groups:placedGroups,target:groups});
         }
         facilities();
      }
   }
}
