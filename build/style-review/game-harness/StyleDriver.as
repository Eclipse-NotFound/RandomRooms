package
{
   import flash.desktop.NativeApplication;
   import flash.display.BitmapData;
   import flash.display.PNGEncoderOptions;
   import flash.display.Sprite;
   import flash.display.Loader;
   import flash.display.LoaderInfo;
   import flash.events.Event;
   import flash.events.IOErrorEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.geom.Matrix;
   import flash.media.SoundMixer;
   import flash.media.SoundTransform;
   import flash.net.URLRequest;
   import flash.system.ApplicationDomain;
   import flash.system.LoaderContext;
   import flash.utils.getTimer;

   /** Build-only driver loaded through the unmodified game's existing RR loader. */
   public class StyleDriver extends Sprite
   {
      private static var main:*;
      private static var W:*;
      private static var Act:*;
      private static var rootDir:File;
      private static var cases:XMLList;
      private static var state:int = 0;
      private static var index:int = 0;
      private static var started:int;
      private static var settled:int = -1;
      private static var lastBeat:int = -1;
      private static var movementEnabled:Boolean = false;
      private static var movePhase:String = "";
      private static var moveFrame:int = 0;
      private static var moveStartX:Number;
      private static var moveStartY:Number;
      private static var ladderX:Number;
      private static var exitX:Number;
      private static var exitY:Number;
      private static var movements:Array = [];
      private static var developmentMode:Boolean = false;
      private static var developmentClass:*;
      private static var developmentLoader:Loader;
      private static var crossingEnabled:Boolean = false;
      private static var crossingLastX:Number = 0;
      private static var crossingStuck:int = 0;
      private static var crossingJump:int = 0;
      private static var shaftEnabled:Boolean = false;
      private static var growthEnabled:Boolean = false;
      private static var fixtureEnabled:Boolean = false;
      private static var fixtureCyclesOnly:Boolean = false;
      private static var navigationEnabled:Boolean = false;
      private static var probeRoom:String = "";
      private static var initialWidth:int = 5;
      private static var initialHeight:int = 5;
      private static var doorTarget:*;
      private static var startupDelayEnabled:Boolean = false;
      private static var delayedHost:*;
      private static var delayStarted:int = -1;
      private static var delayFinished:Boolean = false;
      private static var delayChecks:int = 0;

      public function StyleDriver() {}

      public static function init(host:*):void
      {
         if (NativeApplication.nativeApplication.applicationID.indexOf("pferr-style-") != 0) return;
         main = host;
         rootDir = new File(File.applicationDirectory.nativePath);
         rootDir.resolvePath("captures").createDirectory();
         started = getTimer();
         try
         {
            var hostDomain:ApplicationDomain = ApplicationDomain.currentDomain;
            W = hostDomain.getDefinition("fe.World");
            Act = hostDomain.getDefinition("fe.loc.LandAct");
            var stream:FileStream = new FileStream();
            stream.open(rootDir.resolvePath("captures/runner.log"), FileMode.WRITE);
            stream.writeUTFBytes("appId=" + NativeApplication.nativeApplication.applicationID + "\n");
            stream.close();
            stream.open(rootDir.resolvePath("cases.xml"), FileMode.READ);
            var input:XML = new XML(stream.readUTFBytes(stream.bytesAvailable));
            cases = input.child("case");
            movementEnabled = String(input.@movement) == "true";
            developmentMode = String(input.@development) == "true";
            crossingEnabled = String(input.@crossing) == "true";
            shaftEnabled = String(input.@shaft) == "true";
            growthEnabled = String(input.@growth) == "true";
            fixtureEnabled = String(input.@fixtures) == "true";
            fixtureCyclesOnly = String(input.@fixtureCyclesOnly) == "true";
            navigationEnabled = String(input.@navigation) == "true";
            startupDelayEnabled = String(input.@startupDelay) == "true";
            stream.close();
            SoundMixer.soundTransform = new SoundTransform(0);
            main.stage.addEventListener(Event.ENTER_FRAME, tick);
            log("ready cases=" + cases.length());
            if (developmentMode)
            {
               var storage:File = File.applicationStorageDirectory;
               log("STORAGE path=" + storage.nativePath + " existsBefore=" + storage.exists);
               try { storage.createDirectory(); log("STORAGE existsAfter=" + storage.exists); }
               catch (storageError:Error) { log("STORAGE preparation failed " + storageError.toString()); }
               loadDevelopmentMod();
            }
         }
         catch (error:Error) { fail(error.toString() + "\n" + error.getStackTrace()); }
      }

      private static function log(value:String):void
      {
         trace("[RR-style] " + value);
         var stream:FileStream = new FileStream();
         stream.open(rootDir.resolvePath("captures/runner.log"), FileMode.APPEND);
         stream.writeUTFBytes(getTimer() + " " + value + "\n");
         stream.close();
      }

      private static function fail(value:String):void
      {
         state = 4;
         try { if (W != null && W.w != null && W.w.ctr != null) W.w.ctr.clearAll(); } catch (ignored:Error) {}
         try { log("FAIL " + value); } catch (ignore:Error) { trace(value); }
         NativeApplication.nativeApplication.exit(1);
      }

      private static function screenshot(w:*, name:String, fullRoom:Boolean):void
      {
         var width:int = fullRoom ? int(w.loc.limX) : int(main.stage.stageWidth);
         var height:int = fullRoom ? int(w.loc.limY) : int(main.stage.stageHeight);
         var bitmap:BitmapData = new BitmapData(width, height, false, 0x171717);
         var lightWasVisible:Boolean = w.grafon.visLight.visible;
         // Diagnostic full-room comparison: same exposure, no player visibility overlay.
         // The stage image always retains normal game lighting.
         if (fullRoom) w.grafon.visLight.visible = false;
         bitmap.draw(fullRoom ? w.visual : main.stage, new Matrix());
         w.grafon.visLight.visible = lightWasVisible;
         var bytes:* = bitmap.encode(bitmap.rect, new PNGEncoderOptions());
         var stream:FileStream = new FileStream();
         stream.open(rootDir.resolvePath("captures/" + name + ".png"), FileMode.WRITE);
         stream.writeBytes(bytes);
         stream.close();
         bitmap.dispose();
         log("capture " + name + " " + width + "x" + height + " room=" + w.loc.room.id + " lightOverlay=" + !fullRoom);
      }

      private static function tick(event:Event):void
      {
         try
         {
            if (state == 4) return;
            if (getTimer() - started > (navigationEnabled ? 900000 : developmentMode || fixtureEnabled || crossingEnabled && cases.length()>4 ? 345000 : movementEnabled || crossingEnabled || shaftEnabled ? 225000 : 105000)) { fail("driver timeout"); return; }
            var w:* = W.w;
            if (w == null) return;
            if (w.verror != null && w.verror.visible) { fail("game error: " + w.verror.txt.text); return; }
            var beat:int = int((getTimer() - started) / 10000);
            if (beat != lastBeat)
            {
               lastBeat = beat;
               log("heartbeat state=" + state + " case=" + index + " allLands=" + w.allLandsLoaded + " text=" + w.textLoaded + " resources=" + w.grafon.resIsLoad + " rrCurrent=" + ApplicationDomain.currentDomain.hasDefinition("RandomRoomsMod") + " rrHost=" + main.loaderInfo.applicationDomain.hasDefinition("RandomRoomsMod"));
            }
            if (state == 0)
            {
               if (startupDelayEnabled && !stepStartupDelay(w)) return;
               if (w.landData == null || !w.allLandsLoaded || !w.textLoaded || !w.grafon.resIsLoad) return;
               if (developmentMode)
               {
                  if (developmentClass == null)
                  {
                     return;
                  }
                  if (!developmentClass.debugReady()) return;
                  var readyLoaders:Array=[];
                  for (var loaderId:String in w.landData)
                  {
                     var hostLoader:*=w.landData[loaderId];
                     if (hostLoader==null) continue;
                     var hostPool:XML=hostLoader.allroom as XML;
                     readyLoaders.push({id:loaderId,loaded:Boolean(hostLoader.loaded),hasPool:hostPool!=null,rooms:hostPool==null?0:hostPool.room.length()});
                     if (!hostLoader.loaded || hostPool==null || hostPool.room.length()==0) { fail("debugReady preceded host pool readiness: "+loaderId); return; }
                  }
                  var readyStream:FileStream=new FileStream();
                  readyStream.open(rootDir.resolvePath("captures/startup-readiness.json"),FileMode.WRITE);
                  readyStream.writeUTFBytes(JSON.stringify({debugReady:true,allLandsLoaded:w.allLandsLoaded,hostLoaders:readyLoaders}));
                  readyStream.close();
                  log("STARTUP-READY all "+readyLoaders.length+" host loaders loaded with nonempty pools");
               }
               w.mm.mainMenuOff();
               w.newGame(-1, "LP", {propusk:true});
               state = 1;
               log("newGame(-1) issued, intro skipped");
               return;
            }
            if (state == 1)
            {
               if (w.gg == null || w.land == null || w.loc == null || w.allStat != 1) return;
               w.onPause = false;
               w.pip.onoff(-1);
               state = 2;
               log("initial world ready land=" + w.game.curLandId);
               return;
            }
            if (state == 2)
            {
               if (index >= cases.length())
               {
                  if (developmentMode) exportDevelopmentLog();
                  log("DONE " + index + " cases");
                  state = 4;
                  NativeApplication.nativeApplication.exit(0);
                  return;
               }
               var item:XML = cases[index];
               var id:String = String(item.@id);
               if (developmentMode)
               {
                  var target:String = String(item.@landId);
                  w.pers.healAll();
                  w.onPause = false;
                  if (w.game.curLandId == target)
                  {
                     if (!developmentClass.debugTravel("rbl")) { fail("debugTravel rejected return to base"); return; }
                     state = 7; settled = -1;
                     log("return to base before refreshing " + target);
                     return;
                  }
                  if (!developmentClass.debugTravel(target)) { fail("debugTravel rejected " + target); return; }
                  if (navigationEnabled && !growthEnabled)
                  {
                     var testLand:*=w.game.lands[target].land;
                     var chosenX:int=1,chosenY:int=1,bestPorts:int=-1;
                     for (var nx:int=1;nx<testLand.maxLocX-1;nx++) for (var ny:int=1;ny<testLand.maxLocY-1;ny++)
                     {
                        var nloc:*=testLand.locs[nx][ny][0],count:int=0;
                        for each (var amount:int in nloc.doors) if (amount>=2) count++;
                        if (count>bestPorts) { bestPorts=count; chosenX=nx; chosenY=ny; }
                     }
                     // Native travel coordinates select a test room before
                     // spawning. All subsequent movement is normal controls.
                     w.game.curCoord=chosenX+":"+chosenY;
                     log("NAV-SETUP native travel spawn room="+w.game.curCoord+" declaredPorts="+bestPorts);
                  }
                  settled = -1;
                  state = 3;
                  log("development debugTravel " + target + " case=" + id);
                  return;
               }
               var definition:XML = <land id={id} tip="rnd" rnd="1" conf="1" dif="0" biom="0" mx="1" my="1" locx="0" locy="0">
                  <options backwall="tBackWall" music="music_plant_1" fon="fonDarkClouds" xp="100"/>
               </land>;
               var act:* = new Act(definition);
               act.allroom = <all/>;
               act.allroom.appendChild(item.room[0].copy());
               if (crossingEnabled || shaftEnabled)
               {
                  if (shaftEnabled) act.mLocY = 2;
                  else act.mLocX = 2;
                  act.allroom.appendChild(item.neighbor.room[0].copy());
               }
               act.loaded = true;
               w.game.lands[id] = act;
               w.pers.healAll();
               w.onPause = false;
               w.game.beginMission(id);
               settled = -1;
               state = 3;
               log("beginMission " + id);
               return;
            }
            if (state == 3)
            {
               var wanted:String = developmentMode ? String(cases[index].@landId) : String(cases[index].@id);
               if (w.game.curLandId != wanted || w.land == null || w.land.act.id != wanted || w.loc == null) return;
               if (settled < 0) { settled = getTimer(); log("arrived " + wanted + " room=" + w.loc.room.id); }
               if (getTimer() - settled < 2500) return;
               var captureName:String = String(cases[index].@id);
               screenshot(w, captureName + "-stage", false);
               screenshot(w, captureName + "-room", true);
               if (developmentMode) dumpRuntimePool(w, captureName);
               if (navigationEnabled)
               {
                  NavigationProbe.begin(w,rootDir,captureName,log,useNearbyDoor,screenshot,growthEnabled);
                  state=11; moveFrame=0; return;
               }
               if (fixtureEnabled)
               {
                  FixtureProbe.begin(w,rootDir,captureName,!fixtureCyclesOnly);
                  if (fixtureCyclesOnly) { index++; state=2; return; }
                  moveStartX=w.gg.X; moveStartY=w.gg.Y; moveFrame=0;
                  crossingLastX=w.gg.X; crossingStuck=crossingJump=0;
                  movePhase="approach-hatch"; state=10;
                  log("FIXTURE-PLAN hatch="+FixtureProbe.hatch.id+" x="+FixtureProbe.hatch.X+" y="+FixtureProbe.hatch.Y);
                  return;
               }
               if (growthEnabled)
               {
                  initialWidth=w.land.maxLocX; initialHeight=w.land.maxLocY;
                  moveStartX=w.gg.X; moveStartY=w.gg.Y; moveFrame=0;
                  movePhase="grow-right"; state=9; probeRoom="";
                  crossingLastX=w.gg.X; crossingStuck=crossingJump=0;
                  w.gg.invulner=true;
                  log("GROWTH-PLAN normal spawn, initial="+initialWidth+"x"+initialHeight+"; invulner=true and healAll on each room entry for geometry isolation; no godMode");
                  return;
               }
               if (shaftEnabled)
               {
                  w.ctr.clearAll();
                  moveStartX = w.gg.X; moveStartY = w.gg.Y;
                  moveFrame = 0; movePhase = "approach-shaft";
                  state = 8;
                  log("SHAFT-PLAN natural spawn=" + moveStartX + "," + moveStartY + " room=" + w.loc.room.id);
                  return;
               }
               if (crossingEnabled)
               {
                  w.ctr.clearAll();
                  moveStartX = crossingLastX = w.gg.X;
                  moveStartY = w.gg.Y;
                  moveFrame = crossingStuck = crossingJump = 0;
                  movePhase = "cross-adjacent-room";
                  state = 6;
                  log("CROSS-PLAN from=" + w.loc.room.id + " target=" + cases[index].neighbor.room[0].@name);
                  return;
               }
               if (movementEnabled && String(cases[index].@move) == "true")
               {
                  beginMovement(w);
                  return;
               }
               index++;
               state = 2;
            }
            if (state == 5) stepMovement(w);
            if (state == 6) stepCrossing(w);
            if (state == 8) stepShaft(w);
            if (state == 9) stepGrowth(w);
            if (state == 10) stepFixture(w);
            if (state == 11)
            {
               moveFrame++;
               NavigationProbe.step(w);
               if (NavigationProbe.done)
               {
                  if (!NavigationProbe.success) { exportDevelopmentLog(); fail(NavigationProbe.reason); return; }
                  if (growthEnabled) dumpRuntimePool(w,String(cases[index].@id)+"-after-growth");
                  index++; state=2;
               }
            }
            if (state == 7)
            {
               if (w.game.curLandId != "rbl" || w.land == null || w.land.act.id != "rbl") return;
               if (settled < 0) settled = getTimer();
               if (getTimer() - settled > 1500) { state = 2; settled = -1; log("returned to base"); }
            }
         }
         catch (error:Error) { fail(error.toString() + "\n" + error.getStackTrace()); }
      }

      private static function stepCrossing(w:*):void
      {
         moveFrame++;
         w.ctr.clearAll();
         w.ctr.keyAction = false;
         if (w.land.locX == 1)
         {
            finishSegment(w, true, "entered adjacent room through normal movement");
            return;
         }
         if (moveFrame % 15 == 1) log("CROSS-SAMPLE " + JSON.stringify({frame:moveFrame, x:w.gg.X, y:w.gg.Y, stay:w.gg.stay, locX:w.land.locX, room:String(w.loc.room.id)}));
         if (moveFrame > 900) { finishSegment(w,false,"crossing timeout, including door interaction"); return; }
         if (Math.abs(w.gg.X - crossingLastX) < 0.5) crossingStuck++;
         else crossingStuck = 0;
         crossingLastX = w.gg.X;
         if (crossingStuck >= 20 && w.gg.stay && crossingJump == 0)
         {
            crossingJump = 8;
            crossingStuck = 0;
            log("CROSS-JUMP obstacle at x=" + w.gg.X + " y=" + w.gg.Y);
         }
         if (useNearbyDoor(w,1)) return;
         w.ctr.keyRight = true;
         w.ctr.keyJump = crossingJump > 0;
         if (crossingJump > 0) crossingJump--;
         if (moveFrame > 600)
         {
            finishSegment(w, false, w.gg.X < w.loc.limX - 100 ? "blocked before right boundary" : "reached boundary but did not enter neighbor");
         }
      }

      private static function useNearbyDoor(w:*,direction:int):Boolean
      {
         var obj:* = w.loc.firstObj;
         while (obj != null)
         {
            if ("door" in obj && obj.door > 0 && obj.inter != null && !obj.inter.open && obj.inter.active &&
                ((obj.X-w.gg.X)*direction>=-10 || Math.abs(obj.X-w.gg.X)<(obj.scX+w.gg.scX)/2) &&
                Math.abs(obj.X-w.gg.X)<100 && Math.abs(obj.Y-w.gg.Y)<100)
            {
               if (obj !== doorTarget) { doorTarget=obj; log("DOOR target="+obj.id+" x="+obj.X+" lock="+obj.inter.lock+" mine="+obj.inter.mine); }
               aimObject(w,obj);
               if (w.loc.celObj === obj && obj.onCursor>0) w.ctr.keyAction=true;
               else
               {
                  // Turn and approach normally before waiting for selection.
                  // Freezing as soon as a door enters the 100 px search range
                  // can leave it behind the pony's field of view indefinitely.
                  w.ctr.keyLeft=obj.X<w.gg.X-15;
                  w.ctr.keyRight=obj.X>w.gg.X+15;
               }
               if (moveFrame%30==1) log("DOOR-SAMPLE "+JSON.stringify({cursor:obj.onCursor,selected:w.loc.celObj===obj,
                  selectedId:w.loc.celObj==null?null:String(w.loc.celObj.id),action:w.ctr.keyAction,remaining:w.gg.t_action,
                  open:obj.inter.open,cx:w.celX,cy:w.celY,visi:w.loc.getTile(Math.round(w.celX/40),Math.round(w.celY/40)).visi,
                  x1:obj.X1,x2:obj.X2,y1:obj.Y1,y2:obj.Y2,face:w.gg.storona}));
               return true;
            }
            obj=obj.nobj;
         }
         return false;
      }

      private static function aimObject(w:*,obj:*):void
      {
         var px:Number=obj.X,py:Number=obj.Y-obj.scY/2;
         var best:Number=-1;
         // Location.getDist discards targets on dark tiles. Aim at the visible
         // edge of a hatch, just as a player does from below an opaque floor.
         for each (var xx:Number in [obj.X,obj.X1+3,obj.X2-3])
            for each (var yy:Number in [obj.Y-obj.scY/2,obj.Y1+3,obj.Y2-3])
            {
               // Camera cursor fields are integers. Evaluate the world point
               // after that screen-pixel rounding, otherwise the centre of a
               // one-tile door can round onto its unseen neighbour forever.
               var actualX:Number=(int(xx*w.cam.scaleV+w.cam.vx)-w.cam.vx)/w.cam.scaleV;
               var actualY:Number=(int(yy*w.cam.scaleV+w.cam.vy)-w.cam.vy)/w.cam.scaleV;
               if (actualX<=obj.X1 || actualX>=obj.X2 || actualY<=obj.Y1 || actualY>=obj.Y2) continue;
               var visibility:Number=w.loc.getTile(Math.round(actualX/40),Math.round(actualY/40)).visi;
               if (visibility>best) { best=visibility; px=xx; py=yy; }
            }
         w.cam.celX=px*w.cam.scaleV+w.cam.vx;
         w.cam.celY=py*w.cam.scaleV+w.cam.vy;
      }

      private static function stepFixture(w:*):void
      {
         moveFrame++; w.ctr.clearAll(); w.ctr.keyAction=false;
         var hatch:*=FixtureProbe.hatch;
         if (moveFrame%30==1) log("FIXTURE-SAMPLE "+JSON.stringify({phase:movePhase,x:w.gg.X,y:w.gg.Y,isLaz:w.gg.isLaz,open:hatch.inter.open,frame:moveFrame}));
         if (moveFrame>1500) { finishSegment(w,false,"hatch approach/open/climb timeout"); return; }
         if (movePhase=="approach-hatch")
         {
            if (Math.abs(w.gg.X-hatch.X)<12) { movePhase="open-and-climb-hatch"; return; }
            driveHorizontal(w,w.gg.X<hatch.X?1:-1);
            return;
         }
         if (hatch.inter.open) FixtureProbe.openedByInput=true;
         // hatch2 artwork is 48 px tall, but its collision occupies one 40 px tile.
         // Judge arrival at the supporting floor, not the protruding sprite lip.
         if (FixtureProbe.openedByInput && w.gg.Y<=Math.floor(hatch.Y/40)*40+4)
         {
            screenshot(w,String(cases[index].@id)+"-hatch-open-stage",false);
            finishSegment(w,true,"native fixture cycles and glass breakage checked; naturally approached, opened hatch with action key and climbed above it");
            return;
         }
         var distance:Number=(hatch.Y-w.gg.Y)*(hatch.Y-w.gg.Y)+(hatch.X-w.gg.X)*(hatch.X-w.gg.X);
         if (!hatch.inter.open && distance<=w.actionDist)
         {
            aimObject(w,hatch);
            if (w.loc.celObj===hatch && hatch.onCursor>0) w.ctr.keyAction=true;
            else w.ctr.keyBeUp=true;
            if (moveFrame%30==1) log("HATCH-ACTION selected="+(w.loc.celObj===hatch)+" cursor="+hatch.onCursor+" distance="+distance+" limit="+w.actionDist+" action="+w.ctr.keyAction);
            return;
         }
         w.ctr.keyBeUp=true;
      }

      private static function driveHorizontal(w:*,direction:int):void
      {
         if (useNearbyDoor(w,direction)) return;
         if (String(w.loc.room.xml.@rrKind)=="connector" && w.gg.Y>900 && w.gg.stay && crossingJump==0 &&
             (direction>0 && w.gg.X>840 && w.gg.X<925 || direction<0 && w.gg.X>995 && w.gg.X<1080))
         {
            crossingJump=8;
            log("SHAFT-JUMP across central floor opening x="+w.gg.X+" direction="+direction);
         }
         if (Math.abs(w.gg.X-crossingLastX)<0.5) crossingStuck++; else crossingStuck=0;
         crossingLastX=w.gg.X;
         if (crossingStuck>=20 && w.gg.stay && crossingJump==0) { crossingJump=8; crossingStuck=0; }
         w.ctr.keyRight=direction>0; w.ctr.keyLeft=direction<0;
         w.ctr.keyJump=crossingJump>0;
         if (crossingJump>0) crossingJump--;
      }

      private static function stepGrowth(w:*):void
      {
         moveFrame++; w.ctr.clearAll(); w.ctr.keyAction=false;
         w.gg.invulner=true;
         var locationKey:String=w.land.locX+","+w.land.locY;
         if (probeRoom!=locationKey) { probeRoom=locationKey; w.pers.healAll(); doorTarget=null; log("GROWTH enter "+locationKey+" room="+w.loc.room.id+" healAll"); }
         if (moveFrame%30==1)
         {
            log("GROWTH-SAMPLE "+JSON.stringify({phase:movePhase,frame:moveFrame,x:w.gg.X,y:w.gg.Y,locX:w.land.locX,locY:w.land.locY,width:w.land.maxLocX,height:w.land.maxLocY,isLaz:w.gg.isLaz,hp:w.gg.hp,sost:w.gg.sost}));
            if (w.gg.X>w.loc.limX-80 && w.land.locs[w.land.locX+1]!=null)
            {
               var target:*=w.land.locs[w.land.locX+1][w.land.locY][0];
               var boundaryTiles:Array=[];
               for (var yy:int=21;yy<=23;yy++) for (var xx:int=0;xx<=2;xx++) boundaryTiles.push({x:xx,y:yy,phis:target.space[xx][yy].phis,stair:target.space[xx][yy].stair,shelf:target.space[xx][yy].shelf,door:target.space[xx][yy].door!=null ? String(target.space[xx][yy].door.id) : ""});
               log("BOUNDARY target="+target.room.id+" collision="+target.collisionUnit(w.gg.scX/2+9,w.gg.Y-1,w.gg.scX-4,w.gg.scY)+" tiles="+JSON.stringify(boundaryTiles));
            }
         }
         if (moveFrame>5400) { finishSegment(w,false,"growth route timeout"); return; }
         if (movePhase=="grow-right")
         {
            if (w.land.locX>=initialWidth && w.land.maxLocX>initialWidth)
            {
               movements.push({phase:movePhase,success:true,locX:w.land.locX,locY:w.land.locY,width:w.land.maxLocX,height:w.land.maxLocY,room:String(w.loc.room.id)});
               settled=getTimer(); movePhase="pause-right";
               log("GROWTH right success, settle capture then return to column 4");
            }
            else driveHorizontal(w,1);
         }
         else if (movePhase=="pause-right")
         {
            if (getTimer()-settled<1000) return;
            screenshot(w,String(cases[index].@id)+"-right-stage",false);
            screenshot(w,String(cases[index].@id)+"-right-room",true);
            movePhase="return-to-spine";
         }
         else if (movePhase=="return-to-spine")
         {
            if (w.land.locX==4 && Math.abs(w.gg.X-960)<15) { movePhase="grow-down"; log("GROWTH begin descent column4"); }
            else driveHorizontal(w,w.land.locX>4 || w.gg.X>960 ? -1 : 1);
         }
         else if (movePhase=="grow-down")
         {
            if (useNearbyDoor(w,0)) return;
            if (w.land.locY>=initialHeight && w.land.maxLocY>initialHeight)
            {
               movements.push({phase:movePhase,success:true,locX:w.land.locX,locY:w.land.locY,width:w.land.maxLocX,height:w.land.maxLocY,room:String(w.loc.room.id)});
               settled=getTimer(); movePhase="pause-bottom";
            }
            else
            {
               if (!w.gg.isLaz && Math.abs(w.gg.X-960)>12)
               {
                  w.ctr.keyRight=w.gg.X<960; w.ctr.keyLeft=w.gg.X>960;
               }
               w.ctr.keySit=true;
            }
         }
         else if (movePhase=="pause-bottom")
         {
            if (getTimer()-settled<700) return;
            screenshot(w,String(cases[index].@id)+"-down-stage",false);
            screenshot(w,String(cases[index].@id)+"-down-room",true);
            dumpRuntimePool(w,String(cases[index].@id)+"-expanded");
            movePhase="climb-expanded-join";
         }
         else
         {
            if (useNearbyDoor(w,0)) return;
            if (w.land.locY<initialHeight && w.gg.isLaz)
            {
               finishSegment(w,true,"entered expanded right column and bottom row, then climbed back across restored join");
               return;
            }
            w.ctr.keyBeUp=true;
         }
      }

      private static function stepShaft(w:*):void
      {
         moveFrame++;
         w.ctr.clearAll();
         w.ctr.keyAction=false;
         if (moveFrame % 15 == 1) log("SHAFT-SAMPLE " + JSON.stringify({phase:movePhase,frame:moveFrame,x:w.gg.X,y:w.gg.Y,locX:w.land.locX,locY:w.land.locY,isLaz:w.gg.isLaz,stay:w.gg.stay}));
         if (movePhase == "approach-shaft")
         {
            if (w.land.locY == 1 || Math.abs(w.gg.X - 960) < 15)
            {
               movePhase = "descend-shaft"; moveFrame = 0;
               log("SHAFT approached center at " + w.gg.X + "," + w.gg.Y);
               return;
            }
            w.ctr.keyRight = w.gg.X < 960;
            w.ctr.keyLeft = w.gg.X > 960;
            if (moveFrame > 300) finishSegment(w,false,"shaft approach timeout");
         }
         else if (movePhase == "descend-shaft")
         {
            if (useNearbyDoor(w,0)) return;
            if (w.land.locY == 1 && w.gg.Y > 180)
            {
               movements.push({caseId:String(cases[index].@id),phase:movePhase,success:true,room:String(w.loc.room.id),locX:w.land.locX,locY:w.land.locY,x:w.gg.X,y:w.gg.Y,frames:moveFrame});
               log("SHAFT descended into actual locY=1");
               screenshot(w,String(cases[index].@id)+"-lower-stage",false);
               movePhase = "ascend-shaft"; moveFrame = 0;
               return;
            }
            w.ctr.keySit = true;
            if (moveFrame > 210) finishSegment(w,false,"did not descend into next room");
         }
         else
         {
            if (useNearbyDoor(w,0)) return;
            if (w.land.locY == 0)
            {
               finishSegment(w,true,"descended to locY1 then climbed back to locY0 through actual shaft");
               return;
            }
            w.ctr.keyBeUp = true;
            if (moveFrame > 210) finishSegment(w,false,"did not climb back into previous room");
         }
      }

      private static function loadDevelopmentMod():void
      {
         var gameDomain:ApplicationDomain = ApplicationDomain.currentDomain;
         if (!gameDomain.hasDefinition("fe.World")) throw new Error("Cannot identify game's inherited domain");
         var childDomain:ApplicationDomain = new ApplicationDomain(gameDomain);
         developmentLoader = new Loader();
         developmentLoader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, function(event:IOErrorEvent):void { fail("development load: " + event.text); });
         developmentLoader.contentLoaderInfo.addEventListener(Event.COMPLETE, function(event:Event):void
         {
            try
            {
               var info:LoaderInfo = event.currentTarget as LoaderInfo;
               var cls:* = info.applicationDomain.getDefinition("RandomRoomsMod");
               if (cls === StyleDriver) throw new Error("Development class resolved to test driver");
               log("development class loaded from unchanged SWF in driver's child domain; init caller is harness");
               developmentClass = cls;
               if (!startupDelayEnabled) { cls.init(main); log("development init returned"); }
               else log("development init deferred until prob loader is held");
            }
            catch (error:Error) { fail(error.toString() + "\n" + error.getStackTrace()); }
         });
         developmentLoader.load(new URLRequest("app:/development/RandomRoomsMod.swf"), new LoaderContext(false, childDomain));
      }

      private static function exportDevelopmentLog():void
      {
         // Only this isolated app's own log; no real profile or other module access.
         var data:Object = {applicationId:NativeApplication.nativeApplication.applicationID};
         try
         {
            var diag:* = developmentLoader.contentLoaderInfo.applicationDomain.getDefinition("rr.RRDiag");
            data.runtimeTag = String(diag.TAG);
            diag.inst.close();
            var source:File = File.applicationStorageDirectory.resolvePath("RandomRooms_diag.log");
            data.storageDirectory = File.applicationStorageDirectory.nativePath;
            data.logExists = source.exists;
            if (source.exists) source.copyTo(rootDir.resolvePath("captures/production-diag.log"), true);
            log("DEVELOPMENT-VERSION runtimeTag=" + data.runtimeTag + " copiedOriginalLog=" + data.logExists);
         }
         catch (error:Error) { data.error = error.toString(); log("DEVELOPMENT-VERSION export error " + error.toString()); }
         var stream:FileStream = new FileStream();
         stream.open(rootDir.resolvePath("captures/production-version.json"), FileMode.WRITE);
         stream.writeUTFBytes(JSON.stringify(data));
         stream.close();
      }

      private static function stepStartupDelay(w:*):Boolean
      {
         if (delayFinished) return true;
         if (developmentClass==null || w.landData==null) return false;
         if (delayStarted<0)
         {
            var candidate:*=w.landData["prob"];
            if (candidate==null || !candidate.loaded || candidate.allroom==null) return false;
            delayedHost=candidate;
            delayedHost.loaded=false;
            delayStarted=getTimer();
            developmentClass.init(main);
            log("STARTUP-DELAY prob loaded=false; existing pool preserved; development init returned");
         }
         delayChecks++;
         if (developmentClass.debugReady()) { fail("debugReady became true while prob.loaded was held false"); return false; }
         if (delayedHost.loaded) { fail("prob.loaded changed unexpectedly during controlled hold"); return false; }
         if (getTimer()-delayStarted<1500) return false;
         var elapsed:int=getTimer()-delayStarted;
         delayedHost.loaded=true;
         delayFinished=true;
         var stream:FileStream=new FileStream();
         stream.open(rootDir.resolvePath("captures/startup-delay.json"),FileMode.WRITE);
         stream.writeUTFBytes(JSON.stringify({loader:"prob",heldMilliseconds:elapsed,checks:delayChecks,readyThroughoutHold:false,loadedRestored:true,poolUnchanged:true}));
         stream.close();
         log("STARTUP-DELAY restored prob after "+elapsed+"ms; debugReady false in "+delayChecks+" checks");
         return true;
      }

      private static function dumpRuntimePool(w:*, name:String):void
      {
         var pool:XML = w.game.lands[String(cases[index].@landId)].allroom as XML;
         var generated:int = 0;
         var themeCounts:Object = {}, kindCounts:Object = {}, tips:Object = {};
         for each (var room:XML in pool.room)
         {
            if (String(room.@rrGen).length == 0) continue;
            generated++;
            var theme:String = String(room.@rrTheme), kind:String = String(room.@rrKind), tip:String = String(room.options.@tip);
            if (tip.length == 0) tip = "ordinary";
            themeCounts[theme] = int(themeCounts[theme]) + 1;
            kindCounts[kind] = int(kindCounts[kind]) + 1;
            tips[tip] = int(tips[tip]) + 1;
         }
         var layout:XML = <layout land={w.land.act.id} poolRooms={pool.room.length()} generatedPoolRooms={generated}/>;
         var nodes:Array=[],links:Array=[],issues:Array=[],nodeByXY:Object={};
         for (var x:int=w.land.minLocX;x<w.land.maxLocX;x++) for (var y:int=w.land.minLocY;y<w.land.maxLocY;y++)
         {
            var loc:*=w.land.locs[x][y][0];
            var source:XML=loc.room.xml;
            var node:Object={x:x,y:y,room:String(loc.room.id),mirror:Boolean(loc.mirror),generator:String(source.@rrGen),
               theme:String(source.@rrTheme),kind:String(source.@rrKind),doors:loc.doors.concat(),openPorts:[]};
            nodes.push(node); nodeByXY[x+","+y]=node;
            if (loc.doors.length!=22) issues.push("doors count "+x+","+y);
            for (var p:int=0;p<22;p++) if (loc.doors[p]>=2)
            {
               var points:Array=portCells(p,int(loc.doors[p]));
               var isOpen:Boolean=true;
               for each (var point:Object in points) if (loc.space[point.x][point.y].phis!=0) isOpen=false;
               if (isOpen)
               {
                  node.openPorts.push(p);
                  for each (point in points)
                  {
                     var tile:*=loc.space[point.x][point.y];
                     if (tile.opac!=0) issues.push("opaque port "+x+","+y+":"+p);
                  }
                  if (p>=17 || p>=6 && p<=10)
                  {
                     var rightTile:*=loc.space[points[points.length-1].x][points[points.length-1].y];
                     var leftTile:*=loc.space[points[0].x][points[points.length-1].y];
                     if (!rightTile.stair && !leftTile.stair) issues.push("vertical port lacks ladder "+x+","+y+":"+p);
                  }
               }
            }
            layout.appendChild(<loc x={x} y={y} room={loc.room.id} mirror={loc.mirror} rrGen={node.generator} rrTheme={node.theme} rrKind={node.kind} openPorts={node.openPorts.join(",")}/>);
         }
         var neighbors:Object={};
         for each (node in nodes)
         {
            var key:String=node.x+","+node.y; neighbors[key]=[];
            for (p=0;p<11;p++)
            {
               var nextKey:String=p<6?(node.x+1)+","+node.y:node.x+","+(node.y+1);
               var neighbor:Object=nodeByXY[nextKey];
               if (neighbor==null)
               {
                  if (node.openPorts.indexOf(p)>=0) issues.push("unbuilt boundary open "+key+":"+p);
                  continue;
               }
               if (node.doors[p]!=neighbor.doors[p+11]) issues.push("mismatched port contract "+key+":"+p);
               var expected:Boolean=node.doors[p]>=2;
               var actual:Boolean=node.openPorts.indexOf(p)>=0 && neighbor.openPorts.indexOf(p+11)>=0;
               if (expected!=actual) issues.push("closed/misaligned shared edge "+key+":"+p);
               if (actual) links.push({from:key,to:nextKey,port:p,axis:p<6?"x":"y",open:true});
            }
         }
         for each (var edge:Object in links) { neighbors[edge.from].push(edge.to); neighbors[edge.to].push(edge.from); }
         var queue:Array=["0,0"],seen:Object={"0,0":true};
         for (var qi:int=0;qi<queue.length;qi++) for each (nextKey in neighbors[queue[qi]])
            if (!seen[nextKey]) { seen[nextKey]=true; queue.push(nextKey); }
         if (queue.length!=nodes.length) issues.push("disconnected map "+queue.length+"/"+nodes.length);
         var stream:FileStream = new FileStream();
         stream.open(rootDir.resolvePath("captures/" + name + "-pool.xml"), FileMode.WRITE);
         stream.writeUTFBytes(pool.toXMLString());
         stream.close();
         stream.open(rootDir.resolvePath("captures/" + name + "-layout.xml"), FileMode.WRITE);
         stream.writeUTFBytes(layout.toXMLString());
         stream.close();
         stream.open(rootDir.resolvePath("captures/" + name + "-topology.json"), FileMode.WRITE);
         stream.writeUTFBytes(JSON.stringify({land:String(w.land.act.id),conf:w.land.act.conf,poolRooms:pool.room.length(),generatedPoolRooms:generated,themeCounts:themeCounts,kindCounts:kindCounts,tipCounts:tips,mbaseVisited:w.game.triggers["mbase_visited"],nodes:nodes,links:links,issues:issues,boundary:"Tile port checks only; interior reachability needs movement probes"}));
         stream.close();
         log("development pool " + name + " total=" + pool.room.length() + " generated=" + generated + " assembled=" + layout.loc.length() + " issues=" + issues.length + " themes=" + JSON.stringify(themeCounts));
      }

      public static function portCells(p:int,n:int):Array
      {
         var out:Array=[],x0:int,x1:int,y0:int,y1:int;
         if (p>=17 || p>=6 && p<=10)
         {
            x0=5+9*(p>=17?p-17:p-6); x1=x0+1;
            if (n>2) { x0--; x1++; }
            y0=p>=17?0:23; y1=y0+1;
         }
         else { x0=p>=11?0:46; x1=x0+1; y1=3+4*(p>=11?p-11:p); y0=y1-(n>2?2:1); }
         for (var y:int=y0;y<=y1;y++) for (var x:int=x0;x<=x1;x++) out.push({x:x,y:y});
         return out;
      }

      private static function sideOpen(loc:*, right:Boolean):Boolean
      {
         for (var y:int = 21; y <= 23; y++)
            for (var offset:int = 0; offset <= 1; offset++)
               if (loc.space[right ? loc.spaceX - 1 - offset : offset][y].phis != 0) return false;
         return true;
      }

      private static function centerOpen(loc:*, bottom:Boolean):Boolean
      {
         for (var x:int = 23; x <= 24; x++)
            for (var offset:int = 0; offset <= 1; offset++)
               if (loc.space[x][bottom ? loc.spaceY - 1 - offset : offset].phis != 0) return false;
         return true;
      }

      private static function beginMovement(w:*):void
      {
         var tx:int, ty:int;
         var cellW:Number = w.loc.limX / w.loc.spaceX;
         var cellH:Number = w.loc.limY / w.loc.spaceY;
         var footRow:int = Math.min(w.loc.spaceY - 1, int((w.gg.Y - 1) / cellH));
         var best:int = -1;
         var distance:Number = Number.MAX_VALUE;
         for (tx = 0; tx < w.loc.spaceX; tx++)
         {
            if (!w.loc.space[tx][footRow].stair) continue;
            var delta:Number = Math.abs((tx + 0.5) * cellW - w.gg.X);
            if (delta < distance) { best = tx; distance = delta; }
         }
         w.ctr.clearAll();
         moveStartX = w.gg.X;
         moveStartY = w.gg.Y;
         movePhase = "walk-to-ladder";
         moveFrame = 0;
         state = 5;
         if (best < 0) { finishSegment(w, false, "no ladder intersects current foot row"); return; }
         ty = footRow;
         while (ty > 0 && w.loc.space[best][ty - 1].stair) ty--;
         ladderX = (best + 0.5) * cellW;
         exitX = NaN;
         exitY = NaN;
         for (var offset:int = 1; offset <= 4 && isNaN(exitX); offset++)
         {
            for each (var direction:int in [-1, 1])
            {
               tx = best + direction * offset;
               if (tx < 1 || tx >= w.loc.spaceX - 1 || ty < 2) continue;
               var floor:* = w.loc.space[tx][ty];
               if ((floor.phis > 0 || floor.shelf) && w.loc.space[tx][ty - 1].phis == 0 && w.loc.space[tx][ty - 2].phis == 0)
               {
                  exitX = (tx + 0.5) * cellW;
                  exitY = floor.phY1;
                  break;
               }
            }
         }
         if (isNaN(exitX)) { finishSegment(w, false, "no nearby supported exit at ladder top"); return; }
         log("MOVE-PLAN " + JSON.stringify({caseId:String(cases[index].@id), room:String(w.loc.room.id), fromX:w.gg.X, fromY:w.gg.Y, ladderColumn:best, ladderTopRow:ty, ladderX:ladderX, exitX:exitX, exitY:exitY}));
      }

      private static function finishSegment(w:*, success:Boolean, reason:String):void
      {
         w.ctr.clearAll();
         var result:Object = {caseId:String(cases[index].@id), room:String(w.loc.room.id), locX:w.land.locX, locY:w.land.locY, phase:movePhase, success:success, reason:reason, frames:moveFrame, fromX:moveStartX, fromY:moveStartY, toX:w.gg.X, toY:w.gg.Y, isLaz:w.gg.isLaz, stay:w.gg.stay};
         movements.push(result);
         log("MOVE-RESULT " + JSON.stringify(result));
         var stream:FileStream = new FileStream();
         stream.open(rootDir.resolvePath("captures/movement.json"), FileMode.WRITE);
         stream.writeUTFBytes(JSON.stringify(movements));
         stream.close();
         if (!success || movePhase == "exit-ladder" || movePhase == "cross-adjacent-room" || state == 8 || state == 9 || state == 10)
         {
            index++;
            state = 2;
            return;
         }
         movePhase = movePhase == "walk-to-ladder" ? "climb-ladder" : "exit-ladder";
         moveFrame = 0;
         moveStartX = w.gg.X;
         moveStartY = w.gg.Y;
      }

      private static function stepMovement(w:*):void
      {
         if (w.game.curLandId != String(cases[index].@id) || w.land.act.id != String(cases[index].@id))
         {
            finishSegment(w, false, "room changed during probe");
            return;
         }
         moveFrame++;
         w.ctr.clearAll();
         if (moveFrame % 15 == 1) log("MOVE-SAMPLE " + JSON.stringify({caseId:String(cases[index].@id), phase:movePhase, frame:moveFrame, x:w.gg.X, y:w.gg.Y, isLaz:w.gg.isLaz, stay:w.gg.stay}));
         if (movePhase == "walk-to-ladder")
         {
            var dx:Number = ladderX - w.gg.X;
            if (Math.abs(dx) < 9 || w.gg.isLaz != 0) { finishSegment(w, true, "reached ladder column from spawn"); return; }
            w.ctr.keyRight = dx > 0;
            w.ctr.keyLeft = dx < 0;
            w.ctr.keyBeUp = Math.abs(dx) < 30;
            if (moveFrame > 240) finishSegment(w, false, "walk timeout");
         }
         else if (movePhase == "climb-ladder")
         {
            if (w.gg.Y <= exitY + 4) { finishSegment(w, true, "climbed to supported exit height"); return; }
            w.ctr.keyBeUp = true;
            if (moveFrame > 450) finishSegment(w, false, "climb timeout");
         }
         else
         {
            var remaining:Number = exitX - w.gg.X;
            if (Math.abs(remaining) < 12 && w.gg.stay && Math.abs(w.gg.Y - exitY) < 8)
            {
               finishSegment(w, true, "landed on adjacent platform after normal jump");
               return;
            }
            w.ctr.keyRight = remaining > 8;
            w.ctr.keyLeft = remaining < -8;
            w.ctr.keyJump = moveFrame <= 8;
            if (moveFrame > 180) finishSegment(w, false, "exit timeout");
         }
      }
   }
}
