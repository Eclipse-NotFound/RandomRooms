package rr
{
   /**
    * A room plan keeps geometry and its meaning together. Coordinates are tiles:
    * regions contain x0/top/x1/floor/bg/role; ladder and doorway cells are reserved
    * before furnishing. No connectivity repair is allowed to carve the final plan.
    */
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
      private var rnd:Function;

      public function RRArchitecture(random:Function) { rnd = random; }
      private function pick(lo:int, hi:int):int { return lo + int(rnd() * (hi - lo + 1)); }

      public function build(biome:String, requested:String = ""):void
      {
         theme = biome;
         var palettes:Object = {
            stable:["J","K",["R","P","F"]],
            sewer:["L","L",["","E","T"]],
            plant:["C","C",["","J","D"]],
            mane:["N","N",["","C","D"]]
         };
         if (palettes[theme] == null) theme = "stable";
         var palette:Array = palettes[theme];
         wall = palette[0]; trim = palette[1]; backgrounds = palette[2];
         grid = []; regions = []; ladders = []; doors = []; hatches = []; windows = []; reserved = {};
         var x:int, y:int;
         for (y = 0; y < 25; y++)
         {
            grid[y] = [];
            for (x = 0; x < 48; x++) grid[y][x] = wall;
         }
         var weights:Object = {
            stable:["atrium","offices","offices","service","workshop","warehouse"],
            sewer:["service","service","workshop","damaged","warehouse","atrium"],
            plant:["workshop","workshop","warehouse","service","atrium","offices"],
            mane:["damaged","damaged","offices","warehouse","workshop","atrium"]
         };
         var kinds:Array = weights[theme];
         archetype = kinds[int(rnd() * kinds.length)];
         if (requested == "hall") archetype = "atrium";
         else if (requested == "corridor") archetype = "service";
         else if (["atrium","offices","workshop","damaged","service","warehouse","connector"].indexOf(requested) >= 0) archetype = requested;
         if (archetype == "atrium") atrium();
         else if (archetype == "workshop") workshop();
         else if (archetype == "offices") offices();
         else if (archetype == "damaged") damaged();
         else if (archetype == "service") service();
         else if (archetype == "connector") connector();
         else warehouse();

         // All generated rooms share a safe ground-level horizontal entrance.
         // Top/bottom openings are not a horizontal-platformer entrance contract.
         for (x = 0; x < 48; x++) { grid[0][x] = wall; grid[24][x] = wall; }
         if (archetype == "connector") ladder(23,0,24,backgrounds[0]);
         for (y = 21; y <= 23; y++)
         {
            for (x = 0; x < 3; x++) grid[y][x] = "_" + backgrounds[0];
            for (x = 45; x < 48; x++) grid[y][x] = "_" + backgrounds[0];
         }
         reserve(0,20,3,23); reserve(44,20,47,23);
         addHatch();
         addWindows();
         // Match floor edges as continuous bands, not random material pixels.
         for (y = 1; y < 25; y++)
         {
            for (x = 0; x < 48; x++)
            {
               if (solid(x,y) && !solid(x,y-1)) grid[y][x] = trim;
            }
         }
      }

      private function open(x0:int, top:int, x1:int, bottom:int, bg:String):void
      {
         for (var y:int = Math.max(0,top); y <= Math.min(24,bottom); y++)
            for (var x:int = Math.max(0,x0); x <= Math.min(47,x1); x++)
               grid[y][x] = "_" + bg;
      }
      private function room(x0:int, top:int, x1:int, floor:int, bg:String, role:String):void
      {
         open(x0,top,x1,floor,bg);
         regions.push({x0:x0,top:top,x1:x1,floor:floor,bg:bg,role:role});
      }
      private function platform(x0:int, x1:int, y:int, bg:String, full:Boolean = false):void
      {
         for (var x:int = Math.max(0,x0); x <= Math.min(47,x1); x++)
            grid[y][x] = full ? trim : "_" + bg + "-";
      }
      private function ladder(x:int, top:int, bottom:int, bg:String):void
      {
         for (var y:int = top; y <= bottom; y++)
         {
            grid[y][x] = "_" + bg;
            grid[y][x+1] = "_" + bg + "А";
         }
         ladders.push({x:x,top:top,bottom:bottom});
         reserve(x,top,x+1,bottom);
         reserve(x-1,bottom-1,x+2,bottom);
      }
      private function door(x:int, floor:int, bg:String):void
      {
         var id:String=theme=="stable"?"stdoor":(theme=="plant"?"door2":(theme=="sewer"?"door1b":"door1"));
         var height:int=id=="stdoor"?3:2;
         for (var y:int = floor-3; y <= floor; y++) grid[y][x] = wall;
         open(x,floor-height+1,x,floor,bg);
         doors.push({id:id,x:x,y:floor});
         reserve(x-1,floor-3,x+1,floor);
      }

      private function landing(x:int,y:int):Boolean
      {
         return solid(x,y) || String(grid[y][x]).indexOf("-")>=0;
      }
      private function addHatch():void
      {
         // Native hatches occupy two tiles in a floor. Keep the ladder suffix:
         // Box.initDoor/setDoor changes collision without erasing Tile.stair.
         var candidates:Array=[];
         for each (var l:Object in ladders)
            for (var y:int=Math.max(4,l.top);y<=Math.min(20,l.bottom-2);y++)
            {
               var x:int=l.x;
               if (!landing(x-1,y) || !landing(x+2,y)) continue;
               var clear:Boolean=true;
               for (var yy:int=y-2;yy<=y+2;yy++)
                  if (solid(x,yy) || solid(x+1,yy)) clear=false;
               if (clear) candidates.push({x:x,y:y});
            }
         if (candidates.length==0) throw new Error("No framed hatch landing: "+archetype);
         var chosen:Object=candidates[int(rnd()*candidates.length)];
         chosen.id=(theme=="mane" || theme=="sewer")?"hatch1":"hatch2";
         hatches.push(chosen);
         reserve(chosen.x-1,chosen.y-2,chosen.x+2,chosen.y+2);
      }
      private function addWindows():void
      {
         // Real glass in an interior partition, with a solid lintel and sill.
         // It is never substituted for a doorway or an open ladder route.
         var candidates:Array=[];
         for (var x:int=6;x<=41;x++) for (var y:int=3;y<=20;y++)
         {
            if (!solid(x,y-2) || !solid(x,y-1) || !solid(x,y) || !solid(x,y+1)) continue;
            if (reserved[(y-1)+","+x] || reserved[y+","+x]) continue;
            if (solid(x-1,y-1) || solid(x-1,y) || solid(x+1,y-1) || solid(x+1,y)) continue;
            candidates.push({x:x,y:y});
         }
         var target:int=theme=="sewer"?1:2;
         while (candidates.length && windows.length<target)
         {
            var n:int=int(rnd()*candidates.length);
            var p:Object=candidates.splice(n,1)[0];
            if (reserved[(p.y-1)+","+p.x] || reserved[p.y+","+p.x]) continue;
            p.id=theme=="stable"?"window2":"window1";
            open(p.x,p.y-1,p.x,p.y,backgrounds[0]);
            windows.push(p);
            reserve(p.x-1,p.y-2,p.x+1,p.y+1);
         }
      }
      public function reserve(x0:int, top:int, x1:int, bottom:int):void
      {
         for (var y:int = Math.max(0,top); y <= Math.min(24,bottom); y++)
            for (var x:int = Math.max(0,x0); x <= Math.min(47,x1); x++) reserved[y+","+x] = true;
      }
      public function solid(x:int,y:int):Boolean
      {
         if (x < 0 || x >= 48 || y < 0 || y >= 25) return true;
         return RRSynth.WALL_CHARS.indexOf(String(grid[y][x]).charAt(0)) >= 0;
      }
      public function support(x:int,y:int):Boolean
      {
         if (x < 0 || x >= 48 || y < 0 || y+1 >= 25) return false;
         return solid(x,y+1) || String(grid[y+1][x]).indexOf("-") >= 0;
      }

      private function atrium():void
      {
         var l:int = pick(8,12), r:int = pick(34,38);
         var b0:String = backgrounds[0], b1:String = backgrounds[1], b2:String = backgrounds[2];
         room(l,pick(2,5),r,23,b0,"hall");
         var floors:Array = [7,15,23];
         for (var i:int = 0; i < floors.length; i++)
         {
            var f:int = floors[i];
            room(0,i*8+1,l-2,f,b1,i == 1 ? "office" : "store");
            open(l-1,f-2,l+1,f,b1);
         }
         room(r+2,3,47,11,b2,"service"); open(r-1,9,r+1,11,b2);
         room(r+2,13,47,23,b2,"office"); open(r-1,21,r+1,23,b2);
         platform(l,r-8,16,b0); platform(l+9,r,8,b0);
         platform(r-8,r+1,12,b0); platform(l,l+3,8,b0);
         ladder(l+2,8,23,b0); ladder(r-3,8,23,b0);
         door(l-1,15,b1); door(l-1,23,b1); door(r+1,23,b2);
      }

      private function workshop():void
      {
         var s:int = pick(21,27);
         var b0:String = backgrounds[0], b1:String = backgrounds[1], b2:String = backgrounds[2];
         room(0,6,s-1,23,b0,"workshop");
         room(s+1,2,47,15,b1,"office"); room(s+1,17,47,23,b2,"store");
         open(s,21,s,23,b2); door(s,23,b2); open(s,12,s,15,b1);
         platform(3,s-1,16,b0); platform(6,s-6,9,b0);
         ladder(4,9,23,b0); ladder(42,16,23,b1);
         for (var d:int = 0; d < 8; d++) grid[16+d][s-10+d] = "_" + b0 + "Г";
         reserve(s-11,14,s-2,23);
      }

      private function offices():void
      {
         var s:int = pick(19,25);
         var b0:String = backgrounds[0], b1:String = backgrounds[1], b2:String = backgrounds[2];
         room(s-3,1,s+3,23,b2,"shaft");
         for (var i:int = 0; i < 3; i++)
         {
            var f:int = 7+i*8;
            room(0,1+i*8,s-5,f,backgrounds[i%3],i == 1 ? "store" : "office");
            room(s+5,1+i*8,47,f,backgrounds[(i+1)%3],i == 1 ? "living" : "service");
            open(s-4,f-2,s-4,f,b2); open(s+4,f-2,s+4,f,b2);
            if (i != 1) door(s-4,f,b2);
            if (i != 0) door(s+4,f,b2);
            platform(s-3,s+3,f+1,b2,true);
         }
         ladder(s-1,8,23,b2);
         // Sometimes join two bays into a double-height room.
         if (rnd() < 0.65) { open(6,5,14,15,b0); platform(5,14,16,b0,true); }
      }

      private function damaged():void
      {
         var b0:String = backgrounds[0], b1:String = backgrounds[1];
         room(0,2,47,23,b0,"hall");
         var edge:int = pick(11,14), start:int = pick(31,34);
         platform(0,edge,8,b1,true); platform(start,47,8,b1,true);
         platform(0,edge,16,b1,true); platform(start,47,16,b1,true);
         room(0,1,edge-1,7,b1,"living"); room(start+1,1,47,7,b1,"office");
         for (var y:int = 1; y < 16; y++)
            if ([5,6,7,13,14,15].indexOf(y) < 0) { grid[y][edge] = wall; grid[y][start] = wall; }
         if (rnd()<0.7) platform(edge+1,pick(24,29),12,b0);
         platform(23,36,20,b0);
         ladder(7,8,23,b1); ladder(39,8,23,b1);
         platform(edge+1,17,16,b0);
         for (var d:int = 0; d < 5; d++) grid[16+d][18+d] = "_" + b0 + "Г";
         reserve(17,14,23,20);
         var rubble:int = pick(27,30);
         for (var x:int = rubble; x < rubble+5; x++)
         {
            var h:int = Math.max(1,4-Math.abs(x-rubble-2));
            for (y = 24-h; y < 24; y++) grid[y][x] = wall;
         }
         // Enclose the surviving ground-floor annex under its existing slab.
         for (y=17;y<=23;y++) grid[y][edge]=wall;
         door(edge,23,b1); door(start,7,b1);
      }

      private function service():void
      {
         var l:int = pick(10,13), r:int = pick(33,36);
         var b0:String = backgrounds[0], b1:String = backgrounds[1], b2:String = backgrounds[2];
         room(0,1,l-1,23,b0,"service");
         room(r+1,1,47,23,b0,"service");
         room(l+1,17,r-1,23,b1,"control");
         room(l+1,1,r-1,7,b2,"store");
         // A usable maintenance core instead of an eight-tile solid slab.
         room(l+3,10,r-3,15,b1,theme=="sewer"?"service":"workshop");
         open(l,13,l+2,15,b1); open(r-2,13,r,15,b1);
         open(l,5,l,7,b2); open(r,5,r,7,b2);
         open(l,21,l,23,b1); open(r,21,r,23,b1);
         door(l,23,b1); door(r,23,b1);
         platform(0,l-1,8,b0,true); platform(0,l-1,16,b0);
         platform(r+1,47,8,b0,true); platform(r+1,47,16,b0);
         ladder(4,8,23,b0); ladder(42,8,23,b0);
      }

      private function warehouse():void
      {
         var split:int = pick(19,24);
         var b0:String = backgrounds[0], b1:String = backgrounds[1], b2:String = backgrounds[2];
         room(0,2,47,23,b0,"warehouse");
         room(0,2,split-1,11,b1,"store");
         platform(0,split-1,12,b0,true);
         // A side office and loading mezzanine frame a tall central void.
         room(34,4,47,15,b2,"office");
         platform(33,47,16,b0,true);
         for (var y:int = 2; y <= 15; y++) grid[y][33] = wall;
         open(33,13,33,15,b2);
         door(33,15,b2);
         for (y=17;y<=23;y++) grid[y][33]=wall;
         door(33,23,b2);
         ladder(5,12,23,b1); ladder(41,16,23,b2);
         if (rnd() < 0.6) platform(split-1,30,12,b0);
      }

      private function connector():void
      {
         // Centered, mirror-safe shaft matches vertical port 8/19 at x23/24.
         var bg:String=backgrounds[0];
         open(21,0,26,24,bg);
         for (var i:int=0;i<3;i++)
         {
            var f:int=7+i*8;
            room(0,1+i*8,19,f,backgrounds[1],i==1?"control":"store");
            room(28,1+i*8,47,f,backgrounds[2],i==1?"service":"office");
            open(20,f-2,21,f,bg); open(26,f-2,27,f,bg);
            platform(20,27,f+1,bg,true);
         }
         reserve(21,0,26,24);
         door(20,23,bg); door(27,15,bg);
      }
   }
}
