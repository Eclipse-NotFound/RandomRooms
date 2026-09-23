package rr.v122
{
   import rr.RREcology;
   import rr.RRPorts;
   import rr.RRScene;
   import rr.RRSeed;

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
      public static const GENERATOR:String="space-v11";
      public var rnd:Function;
      public var debugStages:Array=[];
      public var rejections:Object={};
      private var plan:RRArchitecture;
      private var furnishing:RRFurnish;
      private var population:RRPopulation;
      private var attempts:int;
      private var prototypeSeed:RRSeed;
      private static function source(seed:RRSeed):Function
      { return function():Number { return seed.next(); }; }

      public function RRSynth(random:Function=null) { rnd=random!=null?random:Math.random; }

      public function genGrid(biome:String, rtype:String="", ports:Array=null,n:int=0,depth:int=0,peaceful:Boolean=false,safe:Boolean=false,context:Object=null):Array
      {
         if (ports==null) ports=RRPorts.sample(rnd);
         if(context && context.partition=="rules" && !context.hasOwnProperty("seed")) throw new Error("Partition prototype requires an explicit room seed");
         prototypeSeed=context && context.partition=="rules"?new RRSeed(uint(context.seed)):null;
         var lastError:*=null;
         var errors:Object={}; rejections={};
         for (attempts=1;attempts<=48;attempts++)
         {
            try
            {
               plan=new RRArchitecture(prototypeSeed?source(prototypeSeed.fork("geometry:"+attempts)):rnd);
               plan.build(biome,rtype,ports,context);
               lastError=null; break;
            }
            catch (error:*)
            {
               lastError=error; var reason:String=String(error); errors[reason]=int(errors[reason])+1;
               var key:String=biome+"/"+plan.sceneForm+": "+reason;
               rejections[key]=int(rejections[key])+1;
            }
         }
         if (lastError!=null) throw new Error("Architecture cannot fit "+biome+" ports="+ports.join(".")+": "+JSON.stringify(errors));
         population=new RRPopulation(plan,prototypeSeed?source(prototypeSeed.fork("population")):rnd,n,depth,peaceful,safe,context);
         population.build();
         furnishing=new RRFurnish(plan,prototypeSeed?source(prototypeSeed.fork("furnishing")):rnd);
         furnishing.build();
         debugStages=[[plan.archetype,plan.regions.length]];
         return plan.grid;
      }

      public function generate(n:int, biome:String="stable", rtype:String="", boundary:Array=null,depth:int=0,peaceful:Boolean=false,safe:Boolean=false,context:Object=null):XML
      {
         var grid:Array=genGrid(biome,rtype,boundary,n,depth,peaceful,safe,context);
         var room:XML=<room name={"syn_"+n} rrGen={GENERATOR} rrRevision="11.1" rrTheme={plan.theme} rrKind={plan.archetype} rrForm={plan.sceneForm} rrAttempts={attempts} rrPopulation={population.mood} rrDepth={population.stage} rrEcology={population.ecology.type} rrDifficulty={population.ecology.difficulty}/>;
         if(plan.partitionInfo)
         {
            room.@rrRevision="12-prototype-2";
            room.@rrPartition="rules"; room.@rrSeed=prototypeSeed.seed;
            for(var field:String in plan.partitionInfo) room.@["rrP_"+field]=plan.partitionInfo[field];
         }
         if(biome=="mane")
         {
            room.@rrDistrict=plan.sceneForm=="street_links"?"street":(plan.sceneForm=="rooftops"?"roof":"building");
            if(context && context.city) { room.@rrBlock=context.city.block; room.@rrRoofRow=context.city.roofRow; }
         }
         // All three native beams have identical shelf collision; the plan
         // uses '-' internally and the scene chooses the exported material.
         var beam:String=biome=="stable"?"Е":(biome=="mane"?"К":"-");
         var up:String=biome=="stable"?"И":(biome=="mane"?"Л":"В");
         var down:String=biome=="stable"?"Й":(biome=="mane"?"М":"Г");
         for (var y:int=0;y<GRID_H;y++) room.appendChild(<a>{grid[y].join(".").split("-").join(beam).split("В").join(up).split("Г").join(down)}</a>);
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
         for each(var content:XML in population.objects)
         {
            content.@code="syn_"+n+"_p"+String(room.obj.length());
            room.appendChild(content);
         }
         for each (var b:Array in furnishing.backs) room.appendChild(<back id={b[0]} x={b[1]} y={b[2]}/>);
         room.appendChild(<doors>{plan.ports.join(".")}</doors>);
         room.appendChild(RRScene.options(plan.theme,plan.sceneForm));
         room.options.@entip=population.ecology.type;
         // Evidence and in-game test targets. Native Room ignores this node.
         var meta:XML=<rrPlan/>;
         if(plan.partitionInfo) for each(var coverage:Object in furnishing.coverage)
            meta.appendChild(<furnish region={coverage.region} role={coverage.role} groups={coverage.groups} target={coverage.target}/>);
         for each (var r:Object in plan.regions)
            meta.appendChild(<space kind={r.hasOwnProperty("id")?"volume":"gallery"} x0={r.x0} top={r.top} x1={r.x1} floor={r.floor} role={r.role}/>);
         for each (var e:Object in plan.links)
            meta.appendChild(<link a={e.a} b={e.b} kind={e.kind} x={e.x} y={e.y}/>);
         for each (var l:Object in plan.ladders)
            meta.appendChild(<ladder x={l.x} top={l.top} bottom={l.bottom}/>);
         for each (l in plan.stairs)
            meta.appendChild(<stairs x={l.x} top={l.top} bottom={l.bottom} dir={l.dir}/>);
         for each (var p:Object in plan.pools)
            meta.appendChild(<water x0={p.x0} x1={p.x1} top={p.top} bottom={p.bottom} deck={p.deck}/>);
         room.appendChild(meta);
         return room;
      }

      public static function isGenerated(room:XML):Boolean
      { return String(room.@rrGen)==GENERATOR || String(room.@rrGen)=="space-v10" || String(room.@rrGen)=="space-v9" || String(room.@rrGen)=="space-v8" || String(room.@rrGen)=="space-v7"; }

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
