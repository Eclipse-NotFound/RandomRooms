package
{
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import rr.RRSeed;
   import rr.RRSynth;
   import rr.RRCook;

   /** Executes the real generator, without game classes, saves, or mod init. */
   public class SynthBaseline extends Sprite
   {
      private var outputName:String = "generated-current.xml";
      private var outputStem:String = "generated-current";
      public function SynthBaseline()
      {
         run();
      }

      private function writeText(name:String, value:String):void
      {
         if (name.indexOf("/") >= 0 || name.indexOf("\\") >= 0) throw new Error("Output must be a workspace leaf filename");
         // applicationDirectory is an app:/ root; its parent is null.
         // Convert to a native file URL before walking to the workspace output folder.
         var output:File = new File(File.applicationDirectory.nativePath).parent.resolvePath(name);
         var stream:FileStream = new FileStream();
         stream.open(output, FileMode.WRITE);
         stream.writeUTFBytes(value);
         stream.close();
      }

      private function run():void
      {
         try
         {
            var settings:Object = {outputName:"generated-current.xml", versionTag:"RRSynth-current", samplesPerBiome:8, baseSeed:20260910, cookCopies:0};
            var configFile:File = new File(File.applicationDirectory.nativePath).resolvePath("harness-settings.json");
            if (configFile.exists)
            {
               var configStream:FileStream = new FileStream();
               configStream.open(configFile, FileMode.READ);
               settings = JSON.parse(configStream.readUTFBytes(configStream.bytesAvailable));
               configStream.close();
            }
            outputName = String(settings.outputName);
            outputStem = outputName.replace(/\.xml$/i, "");
            var sampleCount:int = int(settings.samplesPerBiome);
            var baseSeed:uint = uint(settings.baseSeed);
            if (sampleCount < 1 || sampleCount > 256) throw new Error("samplesPerBiome must be 1..256");
            writeText(outputStem + "-progress.txt", "started\n");
            XML.prettyPrinting = true;
            var result:XML = <baseline generator={String(settings.versionTag)} baseSeed={baseSeed} samplesPerBiome={sampleCount}/>;
            var biomes:Array = ["stable", "sewer", "plant", "mane"];
            var count:int = 0;
            for (var b:int = 0; b < biomes.length; b++)
            {
               for (var n:int = 0; n < sampleCount; n++)
               {
                  var seed:uint = uint(baseSeed + b * 1000 + n);
                  var rng:RRSeed = new RRSeed(seed).fork("synth");
                  var synth:RRSynth = new RRSynth(function():Number { return rng.next(); });
                  var room:XML = synth.generate(count, String(biomes[b]),settings.roomKind==null?"":String(settings.roomKind));
                  room.@harnessBiome = String(biomes[b]);
                  room.@harnessSeed = seed;
                  room.@harnessValid = RRSynth.validateRoom(room);
                  result.appendChild(room);
                  count++;
                  writeText(outputStem + "-progress.txt", "generated=" + count + "\n");
               }
            }
            result.@count = count;
            writeText(outputName, result.toXMLString() + "\n");
            if (int(settings.cookCopies) > 0)
            {
               var pool:XML = <all generator={String(settings.versionTag)} phase="post-cook" originalCount={count}/>;
               for each (var original:XML in result.room) pool.appendChild(original.copy());
               var cookSeed:RRSeed = new RRSeed(baseSeed).fork("cook");
               var cook:RRCook = new RRCook(function():Number { return cookSeed.next(); });
               pool.@copiesAdded = cook.cookPool(pool, int(settings.cookCopies));
               pool.@count = pool.room.length();
               pool.@changedTotal = cook.lastChangedTotal;
               for each (var cooked:XML in pool.room) cooked.@harnessValid = RRSynth.validateRoom(cooked);
               writeText(outputStem + "-cooked.xml", pool.toXMLString() + "\n");
            }
            NativeApplication.nativeApplication.exit(0);
         }
         catch (error:Error)
         {
            trace(error.toString() + "\n" + error.getStackTrace());
            try { writeText(outputStem + "-error.txt", error.toString() + "\n" + error.getStackTrace()); }
            catch (writeError:Error) { trace("Error log unavailable: " + writeError); }
            NativeApplication.nativeApplication.exit(1);
         }
      }
   }
}
