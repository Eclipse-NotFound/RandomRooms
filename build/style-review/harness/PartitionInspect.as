package
{
   import flash.display.Sprite;
   import flash.desktop.NativeApplication;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import rr.RRArchitecture;
   import rr.RRPorts;
   import rr.RRSeed;
   /** Inspect the 48 candidates for the seed rejected by mass-dev3 case 76.
    * To replay that historical failure, use its frozen rr source snapshot. */
   public class PartitionInspect extends Sprite
   {
      public function PartitionInspect()
      {
         var results:Array=[],seed:RRSeed=new RRSeed(20862767),ports:Array=RRPorts.empty();
         for each(var p:int in [12,5,17,10]) ports[p]=RRPorts.vertical(p)?2:3;
         for(var i:int=1;i<=48;i++)
         {
            var random:RRSeed=seed.fork("geometry:"+i);
            var plan:RRArchitecture=new RRArchitecture(function():Number{return random.next();});
            var error:String="";
            try { plan.build("plant","",ports,{partition:"rules",form:"service_wing",seed:20862767}); }
            catch(e:*) { error=String(e); }
            results.push({attempt:i,error:error,grid:plan.grid,regions:plan.regions,links:plan.links,
               masses:plan.masses,merges:plan.merges,spawn:plan.spawn,info:plan.partitionInfo,
               windows:plan.windows,stairs:plan.stairs,ladders:plan.ladders,doors:plan.doors});
         }
         var file:File=new File(File.applicationDirectory.nativePath).parent.resolvePath("partition-inspect-current.json");
         if(file.exists)
         { trace("Refusing to overwrite an earlier inspection"); NativeApplication.nativeApplication.exit(1); return; }
         var stream:FileStream=new FileStream();stream.open(file,FileMode.WRITE);stream.writeUTFBytes(JSON.stringify(results));stream.close();
         NativeApplication.nativeApplication.exit(0);
      }
   }
}
