package rr
{
   import flash.geom.Point;
   import flash.utils.getDefinitionByName;

   /** Grow a complete connected grid, one row/column ahead of the player.
    * Uses the same construction order as Land.buildRandomLand. A periodic
    * vertical spine preserves access between rows as the grid grows right. */
   public class RRGrowth
   {
      private var synth:RRSynth;
      private var cook:RRCook;
      private var diag:RRDiag;
      private var serial:int=100000;
      private var theme:String="stable";
      private var busy:Boolean=false;
      private var failedLand:*=null;

      public function RRGrowth(s:RRSynth,c:RRCook,d:RRDiag) { synth=s; cook=c; diag=d; }
      public function reset(biome:String):void { theme=biome; failedLand=null; }

      public function update(world:*):void
      {
         if (busy || world==null || world["land"]==null) return;
         var land:*=world["land"];
         if (String(land["act"]["id"])!="random_rooms" || land===failedLand ||
             world["loc"]!==land["loc"] || String(land["prob"])!="") return;
         var w:int=int(land["maxLocX"]),h:int=int(land["maxLocY"]);
         // Build before a fast fall/knockback can cross the old bottom edge.
         var right:Boolean=int(land["locX"])>=w-2;
         var down:Boolean=int(land["locY"])>=h-2;
         if (!right && !down) return;
         busy=true;
         try { extend(land,world,w,h,right,down); }
         catch (e:*)
         {
            failedLand=land;
            diag.log("C-GROW-FAIL "+e);
            // Report the actual failure once; do not mutate/retry each frame.
            try { world["gui"]["messText"]("","RandomRooms: 扩张失败，请保留日志并回城重进",false,false,240); } catch (ignored:*) {}
         }
         finally { busy=false; }
      }

      private function link(a:*,b:*,vertical:Boolean):void
      {
         var port:int=vertical?8:5;
         var amount:int=Math.min(int(a["doors"][port]),int(b["doors"][port+11]));
         a[vertical?"pass_d":"pass_r"]=[];
         if (amount<2) return;
         a[vertical?"pass_d":"pass_r"].push({n:port,fak:amount});
         restoreOpening(a,port);
         restoreOpening(b,port+11);
         a["setDoor"](port,amount);
         b["setDoor"](port+11,amount);
      }

      private function restoreOpening(loc:*,port:int):void
      {
         // mainFrame erased stair/visuals while this was the world edge. hole()
         // alone cannot restore them. Decode the original, mirrored interface.
         var xml:XML=loc["room"]["xml"];
         var mirror:Boolean=Boolean(loc["mirror"]);
         var x0:int=port==5?46:(port==16?0:23);
         var y0:int=port==8?23:(port==19?0:21);
         var x1:int=x0+1;
         var y1:int=(port==5 || port==16)?23:y0+1;
         for (var y:int=y0;y<=y1;y++)
         {
            var row:Array=String(xml.a[y]).split(".");
            for (var x:int=x0;x<=x1;x++)
            {
               var tile:*=loc["space"][x][y];
               // Tile.dec resets geometry but not the opaque wall flag left by
               // mainFrame. A reopened doorway must also transmit sight/light.
               tile["opac"]=0;
               tile["dec"](row[mirror?47-x:x],mirror);
            }
         }
      }

      private function extend(land:*,world:*,w:int,h:int,right:Boolean,down:Boolean):void
      {
         var nw:int=w+(right?1:0),nh:int=h+(down?1:0);
         var staged:Array=[];
         var RoomClass:*=getDefinitionByName("fe.loc.Room");
         var pool:XML=<all/>;
         var x:int,y:int;
         // Prepare all XML and Location instances before publishing new bounds.
         for (x=0;x<nw;x++) for (y=0;y<nh;y++)
         {
            if (x<w && y<h) continue;
            var shaft:Boolean=x%4==0;
            var xml:XML=synth.generate(serial++,theme,shaft?"connector":"");
            xml.@rrGrowth="1";
            if (!RRSynth.validateRoom(xml)) throw new Error("Invalid growth room "+xml.@name);
            pool.appendChild(xml);
            staged.push({x:x,y:y,xml:xml});
         }
         cook.rollEnemies(pool,int(land["act"]["landStage"]));
         for (var i:int=0;i<staged.length;i++)
         {
            var p:Object=staged[i];
            // Consume the copy in the pool after encounter settings are applied.
            p.xml=pool.room[i];
            var room:*=new RoomClass(p.xml);
            p.loc=land["newLoc"](room,p.x,p.y,0,{mirror:synth.rnd()<0.5,water:null,ramka:null,backform:0,transpFon:false});
            p.loc["pass_r"]=[]; p.loc["pass_d"]=[];
         }
         for each (p in staged)
         {
            if (land["locs"][p.x]==null) land["locs"][p.x]=[];
            land["locs"][p.x][p.y]=[p.loc];
         }
         land["maxLocX"]=nw; land["maxLocY"]=nh;
         land["act"]["mLocX"]=nw; land["act"]["mLocY"]=nh;
         var touched:Array=[];
         for each (p in staged)
         {
            if (p.x>0)
            {
               var left:*=land["locs"][p.x-1][p.y][0];
               link(left,p.loc,false);
               if (touched.indexOf(left)<0) touched.push(left);
            }
            if (p.y>0)
            {
               var above:*=land["locs"][p.x][p.y-1][0];
               link(above,p.loc,true);
               if (touched.indexOf(above)<0) touched.push(above);
            }
            if (touched.indexOf(p.loc)<0) touched.push(p.loc);
         }
         for each (var loc:* in touched) loc["mainFrame"]();
         // Objects and XP must exist before the location becomes enterable.
         for each (p in staged)
         {
            p.loc["setObjects"]();
            if (p.x%4==3 && p.y%2==0) p.loc["createCheck"](false);
            p.loc["preStep"]();
            p.loc["createXpBonuses"](5);
            land["allXp"]+=int(p.loc["summXp"]);
            land["act"]["allroom"].appendChild(p.xml);
         }
         var oldMap:*=land["map"];
         land["createMap"]();
         if (oldMap!=null)
         {
            land["map"]["copyPixels"](oldMap,oldMap["rect"],new Point());
            oldMap["dispose"]();
         }
         // The current border may already have been drawn before it was joined.
         if (touched.indexOf(world["loc"])>=0) world["redrawLoc"]();
         diag.log("C-GROW "+w+"x"+h+" -> "+nw+"x"+nh+" rooms="+staged.length+
            " player="+land["locX"]+","+land["locY"]+" objects=ready links=ready");
      }
   }
}
