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
   public class ContentBatch extends Sprite
   {
      private var jobs:Array=[],index:int=0,clock:Timer;
      private var result:Object={maps:0,parity:0,independence:0,failures:[],cases:[],counts:{},zones:0,terminals:0,turrets:0};
      private var pool:XML=<contentBatch/>;
      private function write(name:String,value:String):void
      { var f:FileStream=new FileStream(); f.open(new File(File.applicationDirectory.nativePath).resolvePath(name),FileMode.WRITE); f.writeUTFBytes(value); f.close(); }
      private function require(ok:Boolean,message:String):void { if(!ok) throw new Error(message); }
      public function ContentBatch()
      {
         for each(var scene:String in ["plant","stable","sewer","mane"])
            for(var s:int=0;s<12;s++)
            {
               var run:RRExpedition=new RRExpedition("13",4345+s*7919,scene,s%3,false),map:RRMapPlan=run.planner();
               for each(var coordinate:Array in [[0,0],[1,0],[2,1],[3,3]]) jobs.push({run:run,map:map,x:coordinate[0],y:coordinate[1],independence:s<2});
            }
         clock=new Timer(1); clock.addEventListener(TimerEvent.TIMER,tick); clock.start();
      }
      private function major(room:XML):String
      {
         var out:Array=[];
         for each(var o:XML in room.obj) if(o.@rrContent=="enemy" || o.@rrContent=="security") out.push([String(o.@id),String(o.@x),String(o.@y),String(o.@rrMount)].join(":"));
         return out.join(";");
      }
      private function tick(event:TimerEvent):void
      {
         var job:Object=jobs[index],start:int=getTimer();
         try
         {
            var run:RRExpedition=job.run,map:RRMapPlan=job.map;
            var ports:Array=map.ports(job.x,job.y);
            var room:XML=run.generate(index,job.x,job.y,ports,map.city(job.x,job.y),8+2*run.depth);
            require(RRSynth.validateRoom(room),"invalid native grammar");
            var zones:Object={},totals:Object={};
            for each(var z:XML in room.rrPlan.zone)
            { zones[String(z.@id)]=z; result.zones++; require(Number(z.@pressure)<=Number(z.@limit)+0.011,"zone pressure overflow"); }
            for each(var space:XML in room.rrPlan.space)
            {
               z=zones[String(space.@zone)]; require(z!=null,"unassigned final room");
               require(space.@danger==z.@danger && space.@value==z.@value,"merged D/V mismatch");
            }
            for each(var point:XML in room.rrPlan.point)
            {
               var id:String=String(point.@id),key:String=String(point.@zone);
               totals[key]=Number(totals[key] || 0)+Number(point.@cost);
               result.counts[id]=int(result.counts[id])+1;
               if(id.indexOf("turret")>=0) require(point.@kind=="security","turret leaked from native main pool");
               if(id=="msp" || id=="spritebot" || id=="vortex" || id=="mine") require(point.@kind=="special","special threat escaped special placement");
               if(["term1","term2","term3","knop1","knop3","wallsafe","elpanel"].indexOf(id)>=0)
               {
                  require(point.@mount=="fixture" && int(point.@floorY)-int(point.@y)==1,"wall fixture height");
                  require(int(int(point.@operator)/48)==int(point.@floorY),"fixture operator is airborne");
               }
            }
            for(key in totals) require(Math.abs(totals[key]-Number(zones[key].@pressure))<0.011,"budget metadata differs");
            for each(var terminal:XML in room.rrPlan.control)
            {
               require(room.rrPlan.gun.length()>0 && String(terminal.@path).split(",").length>=6,"invalid terminal contract");
               var covered:Boolean=false;
               for each(var e:XML in terminal.entry) if(e.@state=="covered-route") covered=true;
               require(covered,"terminal has no modeled covered approach"); result.terminals++;
               var op:int=int(terminal.@operator),ox:int=op%48,oy:int=op/48;
               for(var yy:int=oy-1;yy<=oy;yy++) for(var xx:int=ox;xx<=ox+1;xx++)
                  require(String(room.a[yy]).split(".")[xx].indexOf("А")<0,"terminal operator is on a ladder snap line");
            }
            result.turrets+=room.rrPlan.gun.length();
            if(job.independence)
            {
               var ctx:Object={partition:"rules",seed:uint(room.@rrSeed),difficulty:8+2*run.depth,parity:job.x+job.y,city:map.city(job.x,job.y),contentVersion:"13",danger:45,value:0};
               var a:XML=new RRSynth().generate(index,run.theme,"",ports,run.depth,false,false,ctx);
               ctx.value=100;
               var b:XML=new RRSynth().generate(index,run.theme,"",ports,run.depth,false,false,ctx);
               require(a.a.toXMLString()==b.a.toXMLString(),"V changed terrain");
               require(major(a)==major(b),"V changed primary defenders");
               require(a.@rrDifficulty==b.@rrDifficulty && a.@rrEcology==b.@rrEcology,"V changed native strength/ecology"); result.independence++;
            }
            room.@batchSeed=run.seed; room.@batchX=job.x; room.@batchY=job.y; pool.appendChild(room);
            result.maps++; result.cases.push({index:index,scene:run.theme,seed:run.seed,x:job.x,y:job.y,milliseconds:getTimer()-start,d:int(room.@rrDanger),v:int(room.@rrValue),zones:room.rrPlan.zone.length(),turrets:room.rrPlan.gun.length(),terminal:room.rrPlan.control.length()});
         }
         catch(error:*) { result.failures.push({index:index,error:String(error),stack:error.getStackTrace()}); }
         index++; try { write("progress.txt",index+" / "+jobs.length+" failures="+result.failures.length); } catch(statusBusy:*) {}
         if(index>=jobs.length)
         {
            clock.stop(); write("rooms.xml",pool.toXMLString()); write("results.json",JSON.stringify(result,null,2));
            NativeApplication.nativeApplication.exit(result.failures.length?1:0);
         }
      }
   }
}
