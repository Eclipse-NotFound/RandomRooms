package
{
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.getQualifiedClassName;

   /** Native lifecycle/interaction checks; direct successful-action calls test
    * effects, not player approach, hacking probability or disarm skill checks. */
   public class PopulationProbe
   {
      private static function require(ok:Boolean,message:String):void
      { if(!ok) throw new Error("POPULATION "+message); }
      private static function lootCount(loc:*):int
      {
         var n:int=0,o:*=loc.firstObj;
         while(o!=null) { if(getQualifiedClassName(o)=="fe.loc::Loot") n++; o=o.nobj; }
         return n;
      }
      public static function begin(w:*,directory:File,caseId:String):void
      {
         var records:Array=[],objects:Array=[],circuits:Array=[],counts:Object={},checks:Object={loot:0,lootCreated:0,terminalRobot:0,terminalLock:0,disarm:0,switches:0,stations:0,npc:0,circuitsActivated:0};
         var blueprint:String=w.land.act.allroom.toXMLString();
         for(var x:int=0;x<w.land.maxLocX;x++) for(var y:int=0;y<w.land.maxLocY;y++)
         {
            var loc:*=w.land.locs[x][y][0];
            for each(var xml:XML in loc.room.xml.obj)
            {
               if(!String(xml.@rrContent).length) continue;
               var obj:*=w.land.uidObjs[String(xml.@uid)];
               require(obj!=null,"missing "+xml.@uid+" "+xml.@id+" at "+x+","+y);
               require(obj.loc===loc,"wrong owning room "+xml.@uid);
               var id:String=String(xml.@id),kind:String=String(xml.@rrContent);
               counts[id]=int(counts[id])+1;
               objects.push({obj:obj,xml:xml,loc:loc});
               records.push({id:id,uid:String(xml.@uid),kind:kind,className:getQualifiedClassName(obj),room:loc.room.id,x:obj.X,y:obj.Y});
               if(kind=="enemy") require(getQualifiedClassName(obj).indexOf("fe.unit::")==0,"enemy class "+id);
               if(kind=="loot" || kind=="reward") require(obj.inter!=null && String(obj.inter.cont)!="", "container "+id);
               if(kind=="trigger")
               {
                  var paired:Boolean=false;
                  for each(var other:XML in loc.room.xml.obj)
                     if(other.@rrContent=="damager" && other.@allid==xml.@allid && w.land.uidObjs[String(other.@uid)]!=null) paired=true;
                  require(paired,"missing circuit partner "+xml.@uid);
                  circuits.push({obj:obj,xml:xml,loc:loc});
               }
            }
         }
         require(objects.length>0,"no generated contents");
         // Test terminals before disarming their targets or emptying rewards.
         for each(var entry:Object in objects)
         {
            obj=entry.obj; xml=entry.xml; loc=entry.loc; id=String(xml.@id);
            if(id=="term1")
            {
               var targets:Array=[];
               for each(var u:* in loc.units)
                  if(getQualifiedClassName(u)=="fe.unit::UnitTurret") targets.push(u);
               require(targets.length>0,"term1 has no turret");
               obj.inter.command("unlock"); obj.inter.actOsn();
               for each(u in targets)
               { var save:Object=u.save(); require(save.off || save.reprog,"term1 did not control turret"); }
               checks.terminalRobot++;
            }
            else if(id=="term2")
            {
               var caches:Array=[];
               for each(var box:* in loc.objs) if(box.id=="wallsafe" && box.inter) caches.push(box);
               require(caches.length>0,"term2 has no optional cache");
               obj.inter.command("unlock"); obj.inter.actOsn();
               for each(box in caches) require(box.inter.lock==0 && box.inter.mine==0,"term2 did not unlock cache");
               checks.terminalLock++;
            }
            else if(String(xml.@rrContent)=="switch")
            {
               obj.inter.command("unlock"); obj.inter.actOsn();
               var target:*=w.land.uidObjs[String(xml.scr.@targ)];
               require(target!=null && target.inter.lock==0,"button target remained locked"); checks.switches++;
            }
         }
         for each(entry in objects)
         {
            obj=entry.obj; xml=entry.xml; loc=entry.loc; id=String(xml.@id); kind=String(xml.@rrContent);
            if(kind=="loot" || kind=="reward" || id=="term3")
            {
               var before:int=lootCount(loc);
               obj.inter.command("unlock"); obj.inter.actOsn();
               require(obj.inter.cont=="empty" && obj.inter.saveLoot==1,"container not consumed "+id);
               var after:int=lootCount(loc); checks.lootCreated+=Math.max(0,after-before);
               obj.inter.actOsn(); require(lootCount(loc)==after,"container duplicated loot "+id); checks.loot++;
            }
            else if(id=="mine" || id=="trap" || id=="trcans")
            {
               var oldAction:String=String(obj.inter.userAction);
               if(id=="mine") { obj.inter.unlock=100; obj.inter.act(); }
               else obj.inter.actOsn();
               if(id=="trap") require(String(obj.inter.userAction)!=oldAction,"bear trap failed to change state");
               else require(obj.sost>=3 || !obj.inter.active,"disarm failed "+id);
               checks.disarm++;
            }
            else if(id=="work" || id=="himlab" || id=="stove")
            {
               obj.inter.actOsn();
               require(w.pip.workTip==(id=="himlab"?"lab":id),"station did not choose native page "+id);
               w.pip.onoff(-1); checks.stations++;
            }
            else if(id=="vendor" || id=="doctor")
            {
               require(obj.inter!=null && obj.inter.actFun!=null,"service NPC interaction missing");
               obj.inter.actOsn(); w.pip.onoff(-1); checks.npc++;
            }
            else if(id=="elpanel") require(obj.inter.open && loc.electroDam==0,"electricity enabled at arrival");
         }
         // Exercise the real collision gate after reward/service checks: an
         // isolated native actor overlaps each trigger. No damage is applied
         // to the trigger itself, and this is not a navigation assertion.
         for each(entry in circuits)
         {
            obj=entry.obj; xml=entry.xml; loc=entry.loc;
            var weapon:*=null;
            for each(var part:Object in objects)
               if(part.loc===loc && part.xml.@rrContent=="damager" && part.xml.@allid==xml.@allid) weapon=part.obj;
            require(weapon!=null,"circuit weapon missing");
            var actor:*=loc.createUnit("raider",obj.X,obj.Y,true,<obj/>);
            require(actor!=null,"could not create collision fixture");
            actor.fraction=0; actor.invulner=true; actor.stay=true; actor.activateTrap=2;
            actor.disabled=false; actor.trigDis=false; actor.massa=1;
            require(obj.areaTest(actor),"actor did not overlap trigger");
            for(var step:int=0;step<5;step++) obj.control();
            require(obj.save().status==1,"native collision did not activate trigger "+xml.@id);
            require(weapon.isVis || weapon.sost>=3,"trigger did not activate paired weapon");
            obj.inter.actOsn(); require(!obj.inter.active,"trigger disarm failed");
            if(weapon.sost<3) weapon.inter.actOsn();
            require(weapon.sost>=3 || !weapon.inter.active,"weapon disarm failed");
            actor.sost=4; loc.remObj(actor);
            checks.circuitsActivated++; checks.disarm+=2;
         }
         require(checks.loot>0 && checks.lootCreated>0,"native loot never produced items");
         require(w.land.act.allroom.toXMLString()==blueprint,"interaction rewrote blueprint");
         var stream:FileStream=new FileStream();
         stream.open(directory.resolvePath("captures/"+caseId+"-population.json"),FileMode.WRITE);
         stream.writeUTFBytes(JSON.stringify({caseId:caseId,passed:true,rooms:w.land.maxLocX*w.land.maxLocY,counts:counts,checks:checks,records:records,
            scope:"Native construction, successful interactions, and real trigger collision using an injected native actor; no assertion about hacking probability or walking to every object"}));
         stream.close();
      }
   }
}
