package rr
{
   import flash.geom.Point;
   import flash.utils.getDefinitionByName;

   /** Initial construction and expansion share one native Location pipeline.
    * No random pool matching: paired edges are negotiated before architecture.
    * An explored room keeps its geometry, mirror and future border sockets. */
   public class RRGrowth
   {
      private var synth:RRSynth;
      private var cook:RRCook;
      private var diag:RRDiag;
      private var serial:int=0;
      private var theme:String="stable";
      private var mapPlan:RRMapPlan;
      private var busy:Boolean=false;
      private var failedLand:*=null;
      private var expedition:RRExpedition;

      public function RRGrowth(s:RRSynth,c:RRCook,d:RRDiag) { synth=s; cook=c; diag=d; }

      public function build(world:*,act:*,width:int,height:int,biome:String,show:Boolean,choice:Object):*
      {
         var run:RRExpedition=new RRExpedition(choice.version,uint(choice.seed),biome,int(act["landStage"]),show);
         var planner:RRMapPlan=run.planner();
         // Bootstrap an empty native Land, without constructing or discarding
         // any live rooms. Restore the LandAct synchronously, even on failure.
         var LandClass:*=getDefinitionByName("fe.loc.Land");
         var oldPool:XML=act["allroom"], wasRandom:Boolean=Boolean(act["rnd"]);
         var land:*;
         try
         {
            act["allroom"]=<all/>; act["rnd"]=false;
            land=new LandClass(world["gg"],act,Math.max(0,int(world["pers"]["level"])-1));
         }
         finally { act["allroom"]=oldPool; act["rnd"]=wasRandom; }
         land["rnd"]=true;
         land["landDifLevel"]=Math.max(Number(act["dif"]),show?0:int(world["pers"]["level"])-1);
         land["locs"]=[];
         land["maxLocX"]=0; land["maxLocY"]=0;
         act["allroom"]=<all rrVersion={run.version} rrSeed={run.seed}><land serial="1"/></all>;
         var previousSerial:int=serial;
         serial=0;
         try { append(land,world,0,0,width,height,planner,biome,show,run); }
         catch(error:*) { act["allroom"]=oldPool; serial=previousSerial; throw error; }
         if (!show) { mapPlan=planner; theme=biome; expedition=run; failedLand=null; }
         diag.log("C-BUILD "+act["id"]+" grid="+width+"x"+height+" coordinated=1 version="+run.version+" seed="+run.seed);
         return land;
      }

      public function update(world:*):void
      {
         if (busy || world==null || world["land"]==null || mapPlan==null) return;
         var land:*=world["land"];
         if (String(land["act"]["id"])!="random_rooms" || land===failedLand ||
             world["loc"]!==land["loc"] || String(land["prob"])!="") return;
         var w:int=int(land["maxLocX"]),h:int=int(land["maxLocY"]);
         var right:Boolean=int(land["locX"])>=w-2;
         var down:Boolean=int(land["locY"])>=h-2;
         if (!right && !down) return;
         busy=true;
         try { append(land,world,w,h,w+(right?1:0),h+(down?1:0),mapPlan,theme,false,expedition); }
         catch (e:*)
         {
            failedLand=land; diag.log("C-GROW-FAIL "+e);
            try { world["gui"]["messText"]("","RandomRooms: 扩张失败，请保留日志并回城重进",false,false,240); } catch (ignored:*) {}
         }
         finally { busy=false; }
      }
      private function link(a:*,b:*,vertical:Boolean):void
      {
         var field:String=vertical?"pass_d":"pass_r";
         a[field]=[];
         for (var p:int=vertical?6:0;p<=(vertical?10:5);p++)
         {
            var amount:int=Math.min(int(a["doors"][p]),int(b["doors"][p+11]));
            if (amount<2) continue;
            a[field].push({n:p,fak:amount});
            // Opening before decode retains the engine's signposts and spawn
            // exclusion. Decode restores ladders erased at the former border.
            a["setDoor"](p,amount); b["setDoor"](p+11,amount);
            restoreOpening(a,p,amount); restoreOpening(b,p+11,amount);
         }
      }
      private function restoreOpening(loc:*,port:int,amount:int):void
      {
         var xml:XML=loc["room"]["xml"];
         var mirror:Boolean=Boolean(loc["mirror"]);
         var b:Object=RRPorts.rect(port,amount);
         for (var y:int=b.y0;y<=b.y1;y++)
         {
            var row:Array=String(xml.a[y]).split(".");
            for (var x:int=b.x0;x<=b.x1;x++)
            {
               var tile:*=loc["space"][x][y];
               tile["opac"]=0;
               tile["dec"](row[mirror?47-x:x],mirror);
            }
         }
         // Location.buildLoc adds a shelf at the first tile of every ladder.
         // Tile.dec alone does not repeat that step after a framed border was
         // reopened. In particular a bottom socket starts its ladder at row 24.
         for (y=b.y0;y<=b.y1;y++) for (x=b.x0;x<=b.x1;x++)
         {
            tile=loc["space"][x][y];
            if (y>0 && tile["stair"]!=0 && tile["phis"]==0 && !tile["shelf"] &&
                tile["stair"]!=loc["space"][x][y-1]["stair"])
            { tile["shelf"]=true; tile["vid"]++; }
         }
      }
      private function append(land:*,world:*,w:int,h:int,nw:int,nh:int,planner:RRMapPlan,biome:String,show:Boolean,run:RRExpedition):void
      {
         var staged:Array=[],pool:XML=<all/>;
         var RoomClass:*=getDefinitionByName("fe.loc.Room");
         var x:int,y:int;
         for (x=0;x<nw;x++) for (y=0;y<nh;y++)
         {
            if (x<w && y<h) continue;
            var ports:Array=planner.ports(x,y);
            // A mirror transforms both terrain and the port contract. Native
            // Location then mirrors them back into the agreed world positions.
            var mirror:Boolean=run.mirror(x,y);
            var xml:XML=run.generate(serial++,x,y,mirror?RRPorts.mirror(ports):ports,
               biome=="mane"?planner.city(x,y):null,land["landDifLevel"]);
            xml.@x=x; xml.@y=y; xml.@rrMirror=mirror?"1":"0";
            if (w>0 || h>0) xml.@rrGrowth="1";
            if (x==0 && y==0) xml.@name="rr_begin";
            if (w==0 && h==0 && x==nw-1 && y==nh-1) xml.@name=show?"rr_show_end":"rr_exit";
            if (!RRSynth.validateRoom(xml)) throw new Error("Invalid architecture "+xml.@name);
            pool.appendChild(xml);
            staged.push({x:x,y:y,mirror:mirror});
         }
         // Explicit scene populations own counts. Native placeholder waves
         // must not silently add off-scene enemies or repopulate old rooms.
         for each (xml in pool.room) xml.options.@kolspawn="0";
         for (var i:int=0;i<staged.length;i++)
         {
            var cell:Object=staged[i];
            cell.xml=pool.room[i];
            cell.loc=land["newLoc"](new RoomClass(cell.xml),cell.x,cell.y,0,
               {mirror:cell.mirror,water:null,ramka:null,backform:0,transpFon:biome=="mane"});
            // Land.setLocDif rerolls entip even when XML explicitly specifies
            // one. Restore the planned ecology before native contents decode,
            // including alarm/reinforcement and robot-cell follow-up spawns.
            cell.loc["tipEnemy"]=int(cell.xml.@rrEcology);
            cell.loc["pass_r"]=[]; cell.loc["pass_d"]=[];
         }
         // Publish only after every XML and Location was constructed.
         for each (cell in staged)
         {
            if (land["locs"][cell.x]==null) land["locs"][cell.x]=[];
            land["locs"][cell.x][cell.y]=[cell.loc];
         }
         land["maxLocX"]=nw; land["maxLocY"]=nh;
         land["act"]["mLocX"]=nw; land["act"]["mLocY"]=nh;
         var touched:Array=[];
         for each (cell in staged)
         {
            if (cell.x>0)
            {
               var left:*=land["locs"][cell.x-1][cell.y][0];
               link(left,cell.loc,false);
               if (touched.indexOf(left)<0) touched.push(left);
            }
            if (cell.y>0)
            {
               var above:*=land["locs"][cell.x][cell.y-1][0];
               link(above,cell.loc,true);
               if (touched.indexOf(above)<0) touched.push(above);
            }
            if (touched.indexOf(cell.loc)<0) touched.push(cell.loc);
         }
         for each (var loc:* in touched) loc["mainFrame"]();
         for each (cell in staged)
         {
            cell.loc["setObjects"]();
            if ((cell.x==0 && cell.y==0) || (!show && run.checkpoint(cell.x,cell.y)))
               cell.loc["createCheck"](cell.x==0 && cell.y==0);
            cell.loc["preStep"]();
            cell.loc["createXpBonuses"](5);
            land["allXp"]+=int(cell.loc["summXp"]);
            land["act"]["allroom"].appendChild(cell.xml);
         }
         var oldMap:*=land["map"];
         land["createMap"]();
         if (oldMap!=null)
         {
            land["map"]["copyPixels"](oldMap,oldMap["rect"],new Point()); oldMap["dispose"]();
         }
         if (w>0 && h>0)
         {
            if (touched.indexOf(world["loc"])>=0) world["redrawLoc"]();
            diag.log("C-GROW "+w+"x"+h+" -> "+nw+"x"+nh+" rooms="+staged.length+
               " player="+land["locX"]+","+land["locY"]+" objects=ready links=ready");
         }
      }
   }
}
