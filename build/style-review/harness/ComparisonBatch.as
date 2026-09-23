package
{
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.TimerEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rr.RRExpedition;
   import rr.RRMapPlan;
   import rr.RRPorts;
   import rr.RRSynth;
   import rr.v122.RRSynth;

   /** Replay the frozen HTML evidence and exercise actual runtime map inputs. */
   public class ComparisonBatch extends Sprite
   {
      private var jobs:Array=[];
      private var index:int=0;
      private var clock:Timer;
      private var result:Object={parity:0,maps:0,failures:[],cases:[]};
      private var pool:XML=<baseline/>;
      private var folder:File=new File(File.applicationDirectory.nativePath);
      private function write(name:String,value:String):void
      { var s:FileStream=new FileStream(); s.open(folder.resolvePath(name),FileMode.WRITE); s.writeUTFBytes(value); s.close(); }
      private function canonical(xml:XML):String
      {
         if(xml.nodeKind()!="element") return String(xml);
         var attrs:Array=[];
         for each(var a:XML in xml.attributes()) attrs.push(String(a.name())+"="+JSON.stringify(String(a)));
         attrs.sort();
         var value:String="<"+xml.name()+" "+attrs.join(" ")+">";
         for each(var child:XML in xml.children()) value+=canonical(child);
         return value+"</"+xml.name()+">";
      }
      public function ComparisonBatch()
      {
         for each(var version:String in ["12.2","12.3"])
         {
            var stream:FileStream=new FileStream(); stream.open(folder.resolvePath("baseline-"+version+".xml"),FileMode.READ);
            var xml:XML=new XML(stream.readUTFBytes(stream.bytesAvailable)); stream.close();
            for each(var room:XML in xml.room) jobs.push({version:version,original:room});
            for each(var theme:String in ["plant","stable","sewer","mane"])
            {
               var run:RRExpedition=new RRExpedition(version,20260818,theme,0,false),map:RRMapPlan=run.planner();
               for(var x:int=0;x<8;x++) for(var y:int=0;y<8;y++) jobs.push({version:version,run:run,map:map,x:x,y:y});
            }
         }
         clock=new Timer(1); clock.addEventListener(TimerEvent.TIMER,tick); clock.start();
      }
      private function tick(e:TimerEvent):void
      {
         var job:Object=jobs[index],start:int=getTimer(),record:Object={index:index,version:job.version};
         try
         {
            var room:XML;
            if(job.original)
            {
               var old:XML=job.original,ports:Array=RRPorts.empty();
               var selected:Array=[[14,3,18,8],[12,5,17,10],[16,2,20,6],[4,19,9]][int(old.@harnessPortSet)];
               for each(var p:int in selected) ports[p]=RRPorts.vertical(p)?2:3;
               var scene:String=String(old.@harnessBiome),context:Object={partition:"rules",form:String(old.@rrForm),difficulty:14,parity:int(old.@harnessCase),seed:uint(old.@harnessSeed)};
               if(scene=="mane") context.city={form:context.form,block:0,roofRow:0};
               var synth:Object=job.version=="12.2"?new rr.v122.RRSynth():new rr.RRSynth();
               room=synth.generate(int(old.@harnessCase),scene,"",ports,3,false,false,context);
               for each(var attr:XML in old.attributes()) if(String(attr.name()).indexOf("harness")==0) room.@[String(attr.name())]=String(attr);
               if(canonical(room)!=canonical(old))
               {
                  if(!result.failures.length) { write("first-expected.xml",old.toXMLString()); write("first-actual.xml",room.toXMLString()); }
                  throw new Error("Frozen preview replay differs: "+old.@harnessCase);
               }
               result.parity++;
            }
            else
            {
               var run:RRExpedition=job.run,map:RRMapPlan=job.map;
               ports=map.ports(job.x,job.y); var mirrored:Boolean=run.mirror(job.x,job.y);
               room=run.generate(job.x*8+job.y,job.x,job.y,mirrored?RRPorts.mirror(ports):ports,run.theme=="mane"?map.city(job.x,job.y):null,8);
               room.@x=job.x; room.@y=job.y; room.@rrMirror=mirrored?"1":"0";
               if(!rr.RRSynth.validateRoom(room)) throw new Error("Invalid runtime XML");
               pool.appendChild(room); result.maps++;
               record.scene=run.theme; record.x=job.x; record.y=job.y;
               record.attempts=int(room.@rrAttempts);
            }
            record.ok=true;
         }
         catch(error:*) { record.ok=false; record.error=String(error); result.failures.push(record); }
         record.ms=getTimer()-start; result.cases.push(record); index++;
         // A status reader can briefly hold this optional file on Windows.
         // Never let that stop the evidence-producing batch.
         try { write("progress.txt",index+"/"+jobs.length+" failures="+result.failures.length); } catch(statusBusy:*) {}
         if(index==jobs.length)
         {
            clock.stop(); write("results.json",JSON.stringify(result)); write("runtime.xml",pool.toXMLString());
            NativeApplication.nativeApplication.exit(result.failures.length?1:0);
         }
      }
   }
}
