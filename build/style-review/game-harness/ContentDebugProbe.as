package
{
   import flash.events.KeyboardEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.getQualifiedClassName;
   /** Runs against the unchanged candidate loaded by StyleDriver. */
   public class ContentDebugProbe
   {
      private static var report:Object;
      private static function require(ok:Boolean,message:String):void { if(!ok) throw new Error("CONTENT-DEBUG "+message); }
      private static function save(directory:File,name:String):void
      { var f:FileStream=new FileStream(); f.open(directory.resolvePath("captures/"+name+"-content-debug.json"),FileMode.WRITE); f.writeUTFBytes(JSON.stringify(report,null,2)); f.close(); }
      public static function before(w:*,cls:*,directory:File,name:String):void
      {
         report={rooms:0,zones:0,points:0,ceilings:0,groundTurrets:0,terminals:0,specials:0,mirrored:0,errors:[]};
         for(var x:int=0;x<w.land.maxLocX;x++) for(var y:int=0;y<w.land.maxLocY;y++)
         {
            var loc:*=w.land.locs[x][y][0],xml:XML=loc.room.xml;
            require(xml.@rrVersion=="13" && xml.@rrContentModel=="danger-value-1","wrong content version"); report.rooms++;
            if(loc.mirror) report.mirrored++;
            var zones:Object={};
            for each(var z:XML in xml.rrPlan.zone)
            {
               require(Number(z.@danger)>=0 && Number(z.@danger)<=100 && Number(z.@value)>=0 && Number(z.@value)<=100,"D/V out of range");
               require(Number(z.@pressure)<=Number(z.@limit)+0.011,"pressure overflow");
               zones[String(z.@id)]=z; report.zones++;
            }
            for each(var space:XML in xml.rrPlan.space)
            {
               z=zones[String(space.@zone)]; require(z!=null,"space has no final zone");
               require(space.@danger==z.@danger && space.@value==z.@value,"merged zone D/V mismatch");
            }
            for each(var point:XML in xml.rrPlan.point)
            {
               var obj:*=w.land.uidObjs[String(point.@uid)]; require(obj && obj.loc===loc,"spawn missing: "+point.@uid); report.points++;
               if(point.@kind=="special") report.specials++;
               if(point.@kind=="security")
               {
                  require(getQualifiedClassName(obj)=="fe.unit::UnitTurret","non-native turret");
                  if(point.@mount=="ceiling") { report.ceilings++; require(obj.currentWeapon.fixRot==1,"ceiling mount not native"); }
                  else report.groundTurrets++;
               }
            }
            for each(var control:XML in xml.rrPlan.control)
            {
               require(xml.rrPlan.gun.length()>0 && control.@scope=="location","unpaired security terminal");
               require(String(control.@path).split(",").length>=6,"terminal approach too short"); report.terminals++;
            }
         }
         var oldLand:*=w.land;
         cls.debugOverlay(false);
         w.main.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,true,0,114,0,false,false,true));
         require(w.land===oldLand && w.game.curLandId==oldLand.act.id,"Shift F3 triggered travel");
         var state:Object=cls.debugOverlay(true);
         require(state.enabled && state.version=="13" && state.errors.length==0,"overlay failed: "+JSON.stringify(state.errors));
         require(state.spaces.length==w.loc.room.xml.rrPlan.space.length(),"overlay room metadata mismatch");
         require(state.spawns.length==w.loc.room.xml.rrPlan.point.length(),"overlay spawn metadata mismatch");
         for each(var roomLabel:Object in state.spaces) if(roomLabel.labelLines)
            require(roomLabel.labelLines>=2 && roomLabel.labelHeight<=68,"D/V label is visually clipped");
         for each(var marker:Object in state.spawns)
         {
            var source:XML=null;
            for each(var candidate:XML in w.loc.room.xml.obj) if(String(candidate.@uid)==marker.uid) { source=candidate; break; }
            require(source!=null,"marker has no source XML");
            var actual:*=w.land.uidObjs[marker.uid];
            // Native units' width can differ from the conservative planner box;
            // object center is compared only for immobile one-tile fixtures.
            if(String(source.@id)=="term1") require(Math.abs(marker.x-actual.X)<=22,"mirrored terminal marker drift");
         }
         report.before=state; save(directory,name);
      }
      public static function after(w:*,cls:*,directory:File,name:String):void
      {
         var state:Object=cls.debugOverlay(true);
         require(state.errors.length==0,"post-interaction overlay error");
         if(w.loc.room.xml.rrPlan.control.length())
            for each(var ray:Object in state.rays) require(!ray.turret,"sleeping turret still has a live ray");
         report.after=state; report.success=true; save(directory,name);
      }
   }
}
