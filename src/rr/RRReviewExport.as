package rr
{
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.ByteArray;
   /** Copies complete generation records. Never writes saves or live rooms. */
   public class RRReviewExport
   {
      public static const REVISION:String="13.1-editor";
      public static function capture(w:*):XML
      {
         if(!w || !w.land || !w.loc || w.loc!==w.land.loc ||
            ["random_rooms","rr_showroom"].indexOf(String(w.land.act.id))<0)
            throw new Error("请先进入随机探索或合成房展示馆");
         if(w.game.curLandId!=w.land.act.id || w.t_exit>0) throw new Error("区域切换中，请稍后再导出");
         var source:XML=w.land.act.allroom;
         if(!source || !source.room.length()) throw new Error("当前地图没有完整生成记录");
         var output:XML=source.copy();
         var review:XML=<rrReview schema="1" revision={REVISION} captured={new Date().toUTCString()}
            mode="generation-not-live-state" selectedX={w.land.locX} selectedY={w.land.locY}
            landId={w.land.act.id} depth={w.land.act.landStage} width={w.land.maxLocX} height={w.land.maxLocY}
            sourceCRC32={crc(source.toXMLString())}/>;
         for(var x:int=0;x<w.land.maxLocX;x++) for(var y:int=0;y<w.land.maxLocY;y++)
         {
            var loc:*=w.land.locs[x][y][0];
            var row:XML=<location x={x} y={y} name={loc.room.id} mirror={loc.mirror?1:0}
               difficulty={loc.locDifLevel} ecology={loc.tipEnemy}/>;
            for each(var spec:Array in [["left",-1,0],["right",1,0],["up",0,-1],["down",0,1]])
            {
               var nx:int=x+spec[1],ny:int=y+spec[2];
               var exists:Boolean=nx>=0 && ny>=0 && nx<w.land.maxLocX && ny<w.land.maxLocY;
               row.appendChild(<neighbour direction={spec[0]} x={nx} y={ny} present={exists?1:0}/>);
            }
            review.appendChild(row);
         }
         output.appendChild(review); return output;
      }
      public static function crc(text:String):String
      {
         var bytes:ByteArray=new ByteArray(); bytes.writeUTFBytes(text);
         var value:uint=0xFFFFFFFF;
         for(var i:int=0;i<bytes.length;i++)
         {
            value^=bytes[i];
            for(var bit:int=0;bit<8;bit++) value=(value>>>1)^((value&1)?0xEDB88320:0);
         }
         var result:String=uint(value^0xFFFFFFFF).toString(16);
         while(result.length<8) result="0"+result;
         return result;
      }
      public static function save(w:*):Object
      {
         var xml:XML=capture(w),text:String=xml.toXMLString();
         var dir:File=new File(File.applicationDirectory.resolvePath("mods/RandomRooms/exports/review").nativePath);
         dir.createDirectory();
         var stamp:String=String(new Date().time),name:String="review-"+xml.@rrSeed+"-"+stamp+".xml";
         write(dir.resolvePath(name),text);
         var temp:File=dir.resolvePath("latest-"+stamp+".tmp"); write(temp,text);
         temp.moveTo(dir.resolvePath("latest.xml"),true);
         return {path:dir.resolvePath(name).nativePath,rooms:xml.room.length(),crc32:String(xml.rrReview.@sourceCRC32),revision:REVISION};
      }
      private static function write(file:File,text:String):void
      {
         var stream:FileStream=new FileStream();
         try { stream.open(file,FileMode.WRITE); stream.writeUTFBytes(text); }
         finally { stream.close(); }
      }
   }
}
