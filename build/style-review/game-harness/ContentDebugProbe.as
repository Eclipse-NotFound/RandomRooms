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
      private static function fixtureLine(loc:*,ax:Number,ay:Number,bx:Number,by:Number,owner:*):Boolean
      {
         // Native Location.isLine reads World.w.loc, even when invoked on a
         // different Location. Sample the specified location without switching
         // the live world; separately call the native method in the active room.
         var steps:int=Math.ceil(Math.max(Math.abs(bx-ax),Math.abs(by-ay))/4);
         for(var i:int=1;i<steps;i++)
         {
            var x:Number=ax+(bx-ax)*i/steps,y:Number=ay+(by-ay)*i/steps,t:*=loc.getAbsTile(x,y);
            if(t.phis==1 && x>=t.phX1 && x<=t.phX2 && y>=t.phY1 && y<=t.phY2 && t.door!==owner) return false;
         }
         return true;
      }
      private static function save(directory:File,name:String):void
      { var f:FileStream=new FileStream(); f.open(directory.resolvePath("captures/"+name+"-content-debug.json"),FileMode.WRITE); f.writeUTFBytes(JSON.stringify(report,null,2)); f.close(); }
      public static function before(w:*,cls:*,directory:File,name:String):void
      {
         report={rooms:0,zones:0,points:0,ceilings:0,groundTurrets:0,terminals:0,specials:0,mirrored:0,wallFixtures:[],errors:[]};
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
               if(point.@mount=="fixture")
               {
                  var floorY:int=int(point.@floorY),node:int=int(point.@operator),col:int=node%48;
                  var opX:Number=(loc.mirror?48-col-1:col+1)*40,opY:Number=(int(node/48)+1)*40-1;
                  require(floorY-int(point.@y)==1 && int(node/48)==floorY,"fixture has no 40px lift");
                  require(Math.abs(obj.Y-(int(point.@y)+1)*40+1)<0.1,"native fixture moved vertically");
                  require((opX-obj.X)*(opX-obj.X)+(opY-obj.Y)*(opY-obj.Y)<=w.actionDist,"operator too far away");
                  require(fixtureLine(loc,opX,opY-30,obj.X,obj.Y-obj.scY/2,obj),"fixture interaction line blocked "+point.@uid);
                  if(loc===w.loc) require(loc.isLine(opX,opY-30,obj.X,obj.Y-obj.scY/2,obj),"native active-room interaction line blocked");
                  report.wallFixtures.push({id:String(point.@id),uid:String(point.@uid),room:String(xml.@name),mirror:loc.mirror,x:obj.X,y:obj.Y,operatorX:opX,operatorY:opY,lift:opY-obj.Y});
               }
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
         var beforeXML:String=oldLand.act.allroom.toXMLString();
         w.main.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,true,0,116,0,false,false,true));
         require(w.land===oldLand && w.game.curLandId==oldLand.act.id,"Shift F5 triggered travel");
         require(oldLand.act.allroom.toXMLString()==beforeXML,"export modified generation XML");
         var exported:File=directory.resolvePath("mods/RandomRooms/exports/review/latest.xml"),stream:FileStream=new FileStream();
         require(exported.exists,"Shift F5 did not export");
         stream.open(exported,FileMode.READ); var snapshot:XML=new XML(stream.readUTFBytes(stream.bytesAvailable));stream.close();
         require(snapshot.rrReview.@schema=="1" && snapshot.room.length()==report.rooms,"incomplete review snapshot");
         report.export={rooms:snapshot.room.length(),selectedX:int(snapshot.rrReview.@selectedX),selectedY:int(snapshot.rrReview.@selectedY),sourceCRC32:String(snapshot.rrReview.@sourceCRC32)};
         var original:XML=snapshot.copy();delete original.rrReview;
         require(original.toXMLString()==beforeXML,"review lost room metadata");
         exported.copyTo(directory.resolvePath("captures/"+name+"-review.xml"),true);
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
