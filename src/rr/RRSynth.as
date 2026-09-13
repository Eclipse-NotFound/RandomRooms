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
      public static const GENERATOR:String="space-v8";
      public var rnd:Function;
      public var debugStages:Array=[];
      private var plan:RRArchitecture;
      private var furnishing:RRFurnish;
      private var attempts:int;

      public function RRSynth(random:Function=null) { rnd=random!=null?random:Math.random; }

      public function genGrid(biome:String, rtype:String="", ports:Array=null):Array
      {
         if (ports==null) ports=RRPorts.sample(rnd);
         var lastError:*=null;
         for (attempts=1;attempts<=48;attempts++)
         {
            try
            {
               plan=new RRArchitecture(rnd);
               plan.build(biome,rtype,ports);
               lastError=null; break;
            }
            catch (error:*) { lastError=error; }
         }
         if (lastError!=null) throw new Error("Architecture cannot fit shared ports: "+lastError);
         furnishing=new RRFurnish(plan,rnd);
         furnishing.build();
         debugStages=[[plan.archetype,plan.regions.length]];
         return plan.grid;
      }

      public function generate(n:int, biome:String="stable", rtype:String="", boundary:Array=null):XML
      {
         var grid:Array=genGrid(biome,rtype,boundary);
         var room:XML=<room name={"syn_"+n} rrGen={GENERATOR} rrRevision="8.0" rrTheme={plan.theme} rrKind={plan.archetype} rrAttempts={attempts}/>;
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
         room.appendChild(<doors>{plan.ports.join(".")}</doors>);
         room.appendChild(<options/>);
         // Evidence and in-game test targets. Native Room ignores this node.
         var meta:XML=<rrPlan/>;
         for each (var r:Object in plan.regions)
            meta.appendChild(<space kind={r.hasOwnProperty("id")?"volume":"gallery"} x0={r.x0} top={r.top} x1={r.x1} floor={r.floor} role={r.role}/>);
         for each (var e:Object in plan.links)
            meta.appendChild(<link a={e.a} b={e.b} kind={e.kind} x={e.x} y={e.y}/>);
         for each (var l:Object in plan.ladders)
            meta.appendChild(<ladder x={l.x} top={l.top} bottom={l.bottom}/>);
         room.appendChild(meta);
         return room;
      }

      public static function isGenerated(room:XML):Boolean
      { return String(room.@rrGen)==GENERATOR || String(room.@rrGen)=="space-v7"; }

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
