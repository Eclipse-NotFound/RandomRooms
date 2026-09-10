package rr
{
   /** Furnish a completed space by purpose. Whole groups fit or are omitted;
    * background facilities can overlap furniture, but cannot cut walls/shafts. */
   public class RRFurnish
   {
      public var objects:Array = [];
      public var backs:Array = [];
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
         cup:[2,2,0],ccup:[1,1,0],tap:[1,2,0],fridge:[1,2,0],trash:[1,1,0]
      };
      private static const BACKS:Object = {
         stwindow:[4,2],bwindow:[4,2],stlight3:[2,1],stlight4:[2,1],
         light2:[2,1],light3:[2,1],light4:[2,1],wires1:[1,2],wires2:[1,2],
         pult:[2,1],monitor:[2,1],zavod2:[3,2],pipe3:[2,1],pipe4:[1,2],
         potek:[10,2],vent:[1,1],bvent:[4,2],depot:[2,3],storage:[4,3],
         electro:[3,4],clock:[1,1],poster:[2,2],stillage:[3,3]
      };

      public function RRFurnish(p:RRArchitecture, random:Function) { plan=p; rnd=random; }
      private function choose(a:Array):* { return a[int(rnd()*a.length)]; }
      private function group(w:int, h:int, obj:Array, back:Array):Object
      { return {w:w,h:h,obj:obj,back:back}; }

      // These are semantic relationships learned from the corpus, not terrain
      // chunks. Counts, spacing, position and the containing space are generated.
      private function kit(role:String):Object
      {
         var industrial:Boolean = plan.theme == "plant" || plan.theme == "sewer";
         if (role == "office")
         {
            if (rnd() < 0.5)
               return group(7,4,[["table2",1,0],["filecab",4,0],["filecab",5,0]],
                  [[plan.theme=="stable"?"stwindow":"bwindow",0,-3],["clock",5,-3],["light4",2,-4]]);
            return group(7,4,[["bookcase",0,0],["table",3,0],["trash",6,0]],
               [["poster",3,-3],["light3",4,-4]]);
         }
         if (role == "living")
         {
            if (rnd() < 0.55)
               return group(8,3,[["couch",0,0],["table1",3,0],["cup",6,0]],
                  [["poster",0,-3],["light2",4,-3]]);
            return group(6,4,[["table1",0,0],["ccup",2,0],["tap",3,0],["fridge",5,0],
                  ["wcup",2,-3],["wcup",3,-3]],[["light2",0,-4]]);
         }
         if (role == "workshop" || role == "control")
         {
            if (rnd() < 0.65)
               return group(8,4,[["bigbox",0,0]],[["electro",0,-3],["pult",3,-1],
                  ["monitor",3,-2],["monitor",3,-3],["electro",5,-3],["light3",3,-4]]);
            return group(7,4,[["table1",0,0],["instr1",4,0]],
               [["vent",1,-3],["pipe4",6,-3],["pipe4",6,-1],["light3",2,-4]]);
         }
         if (role == "service")
         {
            if (plan.theme == "sewer")
            {
               var pb:Array = [];
               var pipes:int=2+int(rnd()*3);
               for (var k:int=0;k<pipes;k++) { pb.push(["pipe3",k*2,-1]); pb.push(["pipe3",k*2,-2]); }
               pb.push(["light3",pipes-1,-4]);
               return group(pipes*2,4,[],pb);
            }
            return group(7,4,[["table",0,0],["bigmed",4,0],["medbox",2,-2]],
               [["vent",0,-3],["pipe4",6,-3],["pipe4",6,-1],["light3",2,-4]]);
         }
         if (role == "hall") return kit(industrial ? "workshop" : choose(["living","office","control"]));
         // Storage bays use back-layer shelves for density, leaving front space.
         var count:int = 2 + int(rnd()*2);
         var o:Array=[], b:Array=[];
         for (var i:int=0;i<count;i++)
         {
            o.push([plan.theme=="stable"?"mcrate1":"box",i*3,0]);
            b.push([industrial?"depot":(plan.theme=="stable"?"zavod2":"stillage"),i*3,plan.theme=="stable"?-1:-2]);
         }
         b.push([plan.theme=="stable"?"stlight3":"light3",1,-4]);
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
               if (plan.solid(xx,yy) || plan.reserved[yy+","+xx]) return false;
         return true;
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
         for each (a in g.back) if (!fitsBack(a[0],x+a[1],f+a[2])) return false;
         // Do not stack two scenery groups in the same strip. Overlap within a
         // coherent group (display over machine, shelf behind crate) is intended.
         for (var ix:int=x;ix<x+g.w;ix++) if (backUsed[f+","+ix]) return false;
         for (ix=x;ix<x+g.w;ix++) backUsed[f+","+ix]=true;
         for each (a in g.obj)
         {
            objects.push([a[0],x+a[1],f+a[2]]);
            mark(a[0],x+a[1],f+a[2],occupied);
         }
         for each (a in g.back) backs.push([a[0],x+a[1],f+a[2]]);
         return true;
      }

      public function build():void
      {
         objects.push(["player",1,23]);
         for each (var d:Object in plan.doors) objects.push(["stdoor",d.x,d.y]);
         for each (var r:Object in plan.regions)
         {
            if (r.role=="shaft") continue;
            var width:int=r.x1-r.x0+1;
            var groups:int=width>26 ? 2 : 1;
            for (var n:int=0;n<groups;n++)
            {
               var placed:Boolean=false;
               for (var trial:int=0;trial<12 && !placed;trial++)
               {
                  var g:Object=kit(r.role);
                  if (g.w>width || g.h>r.floor-r.top) continue;
                  var x:int=r.x0+int(rnd()*(width-g.w+1));
                  placed=place(g,x,r.floor);
               }
               // Small utility nook: choose a complete smaller relationship.
               if (!placed && width>=4)
               {
                  if (r.role=="service" && plan.theme=="sewer")
                     g=group(4,3,[],[["pipe4",0,-3],["pipe4",0,-1],["vent",2,-2]]);
                  else g=group(4,3,[[choose(["table","table1","couch"]),0,0]],
                     [[plan.theme=="stable"?"stlight3":"light3",1,-3]]);
                  for (trial=0;trial<8 && !placed;trial++)
                     placed=place(g,r.x0+int(rnd()*(width-3)),r.floor);
               }
            }
         }
         // Spawn markers use open, supported positions after furnishing. They
         // are gameplay markers, not members of the furniture density budget.
         var targets:int=4+int(rnd()*4), made:int=0;
         var rates:Array=RRSynth.EN_RATE[RRSynth.BIOMES.indexOf(plan.theme)];
         for (var t:int=0;t<180 && made<targets;t++)
         {
            x=6+int(rnd()*36);
            var y:int=3+int(rnd()*21);
            var key:String=y+","+x;
            if (!plan.support(x,y) || plan.solid(x,y) || plan.solid(x,y-1) ||
                plan.reserved[key] || occupied[key] || occupied[(y-1)+","+x]) continue;
            var roll:Number=rnd()*100;
            var id:String=roll<rates[0]?"enl1":(roll<rates[0]+rates[1]?"enl2":"enf1");
            objects.push([id,x,y]); occupied[key]=true; made++;
         }
      }
   }
}
