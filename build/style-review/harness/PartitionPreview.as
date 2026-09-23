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
   import rr.RRSeed;
   import rr.RRSynth;
   import rr.RRScene;
   import rr.RRPorts;

   /** Paired real-AS3 exports. No game world, native save, mod init or browser
    * reimplementation. Every requested case has a result or an explicit error. */
   public class PartitionPreview extends Sprite
   {
      private var output:String;
      private var samples:int;
      private var jobs:Array=[];
      private var index:int=0;
      private var timer:Timer;
      private var modern:XML=<baseline generator="partition-prototype-3"/>;
      private var legacy:XML=<baseline generator="v11.1-forced-form-control"/>;
      private var report:Object={cases:[],rejections:{},repeatChecks:0};
      private function write(name:String,s:String):void
      {
         var f:File=new File(File.applicationDirectory.nativePath).parent.resolvePath(name);
         var stream:FileStream=new FileStream(); stream.open(f,FileMode.WRITE); stream.writeUTFBytes(s); stream.close();
      }
      public function PartitionPreview()
      {
         var f:File=File.applicationDirectory.resolvePath("partition-settings.json"),s:FileStream=new FileStream();
         s.open(f,FileMode.READ); var settings:Object=JSON.parse(s.readUTFBytes(s.bytesAvailable)); s.close();
         output=String(settings.output); samples=int(settings.samples);
         if(!/^[a-zA-Z0-9-]+$/.test(output) || samples<1 || samples>16) throw new Error("Invalid preview settings");
         for each(var scene:String in RRScene.IDS) for each(var form:String in RRScene.profile(scene).forms)
            for(var port:int=0;port<4;port++) for(var sample:int=0;sample<samples;sample++)
               jobs.push({scene:scene,form:form,port:port,sample:sample,seed:uint(20260923+jobs.length*7919)});
         write(output+"-progress.txt","started 0/"+jobs.length);
         timer=new Timer(1); timer.addEventListener(TimerEvent.TIMER,tick); timer.start();
      }
      private function boundary(p:int):Array
      {
         var a:Array=RRPorts.empty();
         var selected:Array=[[14,3,18,8],[12,5,17,10],[16,2,20,6],[4,19,9]][p];
         for each(var slot:int in selected) a[slot]=RRPorts.vertical(slot)?2:3;
         return a;
      }
      private function generate(job:Object,rules:Boolean,serial:int,ambient:uint=0):XML
      {
         var rng:RRSeed=new RRSeed(job.seed+ambient).fork("synth");
         var synth:RRSynth=new RRSynth(function():Number { return rng.next(); });
         var context:Object={form:job.form,difficulty:14,parity:serial,seed:job.seed};
         if(rules) context.partition="rules";
         if(job.scene=="mane") context.city={form:job.form,block:0,roofRow:0};
         var room:XML;
         try { room=synth.generate(serial,job.scene,"",boundary(job.port),3,false,false,context); }
         finally
         {
            if(ambient==0) for(var key:String in synth.rejections)
               report.rejections[(rules?"new/":"old/")+key]=int(report.rejections[(rules?"new/":"old/")+key])+int(synth.rejections[key]);
         }
         room.@harnessBiome=job.scene; room.@harnessSeed=job.seed; room.@harnessCase=serial;
         room.@harnessPortSet=job.port; room.@harnessSample=job.sample; room.@harnessValid=RRSynth.validateRoom(room);
         if(String(room.@harnessValid)!="true") throw new Error("Export validation failed");
         return room;
      }
      private function tick(e:TimerEvent):void
      {
         try
         {
            var job:Object=jobs[index],entry:Object={index:index,scene:job.scene,form:job.form,port:job.port,sample:job.sample,seed:job.seed};
            for each(var mode:String in ["new","old"])
            {
               var start:int=getTimer();
               try
               {
                  var room:XML=generate(job,mode=="new",index);
                  entry[mode]={ok:true,ms:getTimer()-start,attempts:int(room.@rrAttempts)};
                  if(mode=="new")
                  {
                     if(job.port==0 && job.sample==0)
                     {
                        var repeat:XML=generate(job,true,index,123456);
                        if(repeat.toXMLString()!=room.toXMLString()) throw new Error("Independent seed replay differs");
                        report.repeatChecks++;
                     }
                     modern.appendChild(room);
                  }
                  else legacy.appendChild(room);
               }
               catch(error:Error) { entry[mode]={ok:false,ms:getTimer()-start,error:error.toString()}; }
            }
            report.cases.push(entry); index++;
            write(output+"-progress.txt",index+"/"+jobs.length+" "+job.scene+"/"+job.form);
            if(index==jobs.length)
            {
               timer.stop(); report.requested=jobs.length;
               write(output+"-new.xml",modern.toXMLString()+"\n"); write(output+"-old.xml",legacy.toXMLString()+"\n");
               write(output+"-results.json",JSON.stringify(report));
               NativeApplication.nativeApplication.exit(0);
            }
         }
         catch(fatal:Error)
         { timer.stop(); write(output+"-error.txt",fatal.toString()+"\n"+fatal.getStackTrace()); NativeApplication.nativeApplication.exit(1); }
      }
   }
}
