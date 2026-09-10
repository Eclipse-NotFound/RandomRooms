package rr
{
   /** C / v7: generate an architectural plan, then furnish functional spaces.
    * Terrain comes from scratch. RRCook must not carve or mutate the final plan. */
   public class RRSynth
   {
      public static const GRID_W:int=48;
      public static const GRID_H:int=25;
      public static const FCHARS:String="ABCDEFGHIJKLMNOPQRST_";
      public static const OCHARS:String="ABCDEFGHIJKLMNOPQRSTUVWXYZАБВГДЕЖЗИЙКЛМОПСТ-ДЕКНР*,;:";
      public static const WALL_CHARS:String="ABCDEFGHIJKLMNOPQRST";
      public static const BIOMES:Array=["stable","sewer","plant","mane"];
      public static const EN_RATE:Array=[[28,49,23],[21,36,43],[35,50,15],[31,52,17]];
      public static const EN_IDS:Array=["enl1","enl2","enf1"];
      public static const GENERATOR:String="space-v7";
      public var rnd:Function;
      public var debugStages:Array=[];
      private var plan:RRArchitecture;
      private var furnishing:RRFurnish;

      public function RRSynth(random:Function=null) { rnd=random!=null?random:Math.random; }

      public function genGrid(biome:String, rtype:String=""):Array
      {
         plan=new RRArchitecture(rnd);
         plan.build(biome,rtype);
         furnishing=new RRFurnish(plan,rnd);
         furnishing.build();
         debugStages=[[plan.archetype,plan.regions.length]];
         return plan.grid;
      }

      public function generate(n:int, biome:String="stable", rtype:String=""):XML
      {
         var grid:Array=genGrid(biome,rtype);
         var room:XML=<room name={"syn_"+n} rrGen={GENERATOR} rrRevision="7.1" rrTheme={plan.theme} rrKind={plan.archetype}/>;
         for (var y:int=0;y<GRID_H;y++) room.appendChild(<a>{grid[y].join(".")}</a>);
         for (var i:int=0;i<furnishing.objects.length;i++)
         {
            var o:Array=furnishing.objects[i];
            var objectXML:XML=<obj id={o[0]} code={"syn_"+n+"_o"+i} x={o[1]} y={o[2]}/>;
            // These doors divide a route, so they must not inherit the asset's
            // random locks/mines. They remain normal operable, closed doors.
            if (o.length>3) objectXML.@rrFixture=o[3];
            if (o[3]=="door" || o[3]=="hatch") { objectXML.@lock="0"; objectXML.@mine="0"; }
            room.appendChild(objectXML);
         }
         for each (var b:Array in furnishing.backs) room.appendChild(<back id={b[0]} x={b[1]} y={b[2]}/>);
         // Empty <doors/> parses as [""]. Declare actual three-cell openings.
         var ports:Array=[];
         for (i=0;i<22;i++) ports[i]=0;
         ports[5]=3; ports[16]=3;
         if (plan.archetype=="connector") { ports[8]=2; ports[19]=2; }
         room.appendChild(<doors>{ports.join(".")}</doors>);
         room.appendChild(plan.archetype=="connector" ? <options tip="vert" nornd="1" level="0"/> : <options/>);
         return room;
      }

      public static function isGenerated(room:XML):Boolean { return String(room.@rrGen)==GENERATOR; }

      /** Generic Tile.dec check also accepts authored fallbacks. */
      public static function validateRoom(room:XML):Boolean
      {
         try
         {
            if (room.a.length()!=GRID_H || room.options.length()==0) return false;
            for (var y:int=0;y<GRID_H;y++)
            {
               var row:Array=String(room.a[y]).split(".");
               if (row.length!=GRID_W) return false;
               for (var x:int=0;x<GRID_W;x++)
               {
                  var c:String=String(row[x]);
                  if (c.length==0 || FCHARS.indexOf(c.charAt(0))<0) return false;
                  for (var j:int=1;j<c.length;j++) if (OCHARS.indexOf(c.charAt(j))<0) return false;
                  if (isGenerated(room) && (y==0 || y==24) && c.charAt(0)=="_" &&
                     !(String(room.@rrKind)=="connector" && (x==23 || x==24))) return false;
               }
            }
            if (isGenerated(room))
            {
               if (String(room.doors).split(".").length!=22) return false;
               var codes:Object={}, players:int=0;
               for each (var obj:XML in room.obj)
               {
                  var code:String=String(obj.@code);
                  if (code.length==0 || codes[code]) return false;
                  codes[code]=true;
                  if (String(obj.@id)=="player") players++;
               }
               if (players!=1) return false;
            }
            return true;
         }
         catch (e:*) { return false; }
         return false;
      }
   }
}
