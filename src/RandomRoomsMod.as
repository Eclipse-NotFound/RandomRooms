package
{
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.IOErrorEvent;
   import flash.events.KeyboardEvent;
   import flash.net.URLLoader;
   import flash.net.URLRequest;
   import rr.RRDiag;
   import rr.RRTestLand;
   
   /**
    * RandomRoomsMod —— M0 实验文档类（文件名 = 类名 = 默认包）。
    *
    * 加载契约（mod-loader-patch-structure）：loader 用 getDefinition("RandomRoomsMod")
    * 并调用 init(this)，this = MainFE 实例。
    *
    * M0 流程：
    *   1. init → 绑定 stage（ENTER_FRAME 晚于游戏 step；KEY_DOWN 早于游戏）；
    *   2. 等 World.w 就绪 → preflight：
    *      a. 预加载全部磁盘 Rooms/rooms_*.xml 到 World.w.rooms.rooms（保持原版内容）；
    *      b. 全部就绪后：GameData.d 追加 rr_test 土地 + rooms.rooms["rooms_rr_test"]
    *         注入测试池 + roomsLoad=0（LandLoader 将读取数组而非磁盘）；
    *   3. F8 → gotoLand("rr_test")；F9 → gotoLand("rbl")；
    *   4. 进入后采集 land.locs 的房间 id 集合写入日志（H3 判定）。
    *
    * 只读/写内存对象，不触碰游戏文件。
    */
   public class RandomRoomsMod extends Sprite
   {
      private var diag:RRDiag;
      private var test:RRTestLand;
      private var main:*;
      
      private var WCls:*;      // fe.World 类对象
      private var GDataCls:*;  // fe.GameData 类对象
      private var ad:*;        // applicationDomain
      
      private var stageBound:Boolean = false;
      private var preflightDone:Boolean = false;
      private var preflightStarted:Boolean = false;
      
      private var fileList:Array = [];
      private var fileLoaded:int = 0;
      private var fileFailed:int = 0;
      private var fileTotal:int = 0;
      
      private var f8Issued:Boolean = false;
      private var f8Ticks:int = 0;
      
      private static const F8_KEY:int = 119;
      private static const F9_KEY:int = 120;
      private static const ENTRY_TIMEOUT_TICKS:int = 600; // ~10s @60fps
      
      public function RandomRoomsMod()
      {
         diag = new RRDiag();
         test = new RRTestLand(diag);
         diag.log("ctor");
      }
      
      /** 加载器契约入口 */
      public function init(main:*):void
      {
         this.main = main;
         diag.log("init(main) called, main=" + main + " stage=" + (main ? main.stage : "n/a"));
         ad = this.loaderInfo.applicationDomain;
         
         // 确认关键游戏类可达（DLC 实玩构建验证）
         var probes:Array = ["fe.World", "fe.GameData", "fe.loc.Game", "fe.loc.Land"];
         for each (var n:String in probes)
         {
            var ok:Boolean = false;
            try { ok = ad.hasDefinition(n); } catch (e:*) { ok = false; }
            diag.log("class probe " + n + " => " + (ok ? "OK" : "MISSING"));
         }
         try { WCls = ad.getDefinition("fe.World"); } catch (e:*) {}
         try { GDataCls = ad.getDefinition("fe.GameData"); } catch (e:*) {}
         
         var st:* = null;
         try { st = main.stage; } catch (e:*) {}
         if (st)
         {
            bindStage(st);
         }
         else
         {
            diag.log("stage 暂不可用，进入轮询");
            addEventListener(Event.ENTER_FRAME, pollStage);
         }
      }
      
      private function pollStage(ev:Event):void
      {
         var st:* = null;
         try { st = main.stage; } catch (e:*) {}
         if (!st) return;
         removeEventListener(Event.ENTER_FRAME, pollStage);
         bindStage(st);
      }
      
      private function bindStage(st:*):void
      {
         stageBound = true;
         st.addEventListener(Event.ENTER_FRAME, onFrame);
         st.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
         diag.log("[RR] RandomRoomsMod M0 loaded <preflight=disk-reseed+rr_test-land> stage bound");
      }
      
      // ---------- 主循环 ----------
      
      private function onFrame(ev:Event):void
      {
         var world:* = null;
         try { world = WCls["w"]; } catch (e:*) {}
         if (world == null)
         {
            if (preflightStarted) return;
            return;
         }
         if (!preflightStarted)
         {
            preflightStarted = true;
            startPreflight(world);
            return;
         }
         if (preflightDone && f8Issued)
         {
            verifyEntry(world);
         }
      }
      
      private function onKeyDown(ev:KeyboardEvent):void
      {
         if (ev.keyCode == F8_KEY)
         {
            triggerTravel("rr_test", "F8");
         }
         else if (ev.keyCode == F9_KEY)
         {
            triggerTravel("rbl", "F9");
         }
      }
      
      private function triggerTravel(landId:String, tag:String):void
      {
         var world:* = null;
         try { world = WCls["w"]; } catch (e:*) {}
         if (world == null || !preflightDone)
         {
            diag.log(tag + " 被按，但 preflight 未完成（或 World 未就绪），忽略");
            return;
         }
         var game:* = world["game"];
         if (game == null)
         {
            diag.log(tag + " 被按，但 game 未创建（需先开始游戏），忽略");
            return;
         }
         try
         {
            var lands:* = game["lands"];
            var hasLand:Boolean = false;
            try { hasLand = lands[landId] != null; } catch (e:*) {}
            var curLandId:String = "";
            try { curLandId = String(game["curLandId"]); } catch (e:*) {}
            diag.log(tag + " -> gotoLand(" + landId + "), preflight=OK, lands[" + landId + "]=" + hasLand +
                     ", 当前土地=" + curLandId);
            game["gotoLand"](landId);
            if (landId == RRTestLand.LAND_ID)
            {
               f8Issued = true;
               f8Ticks = 0;
            }
         }
         catch (e:*)
         {
            diag.log(tag + " 调用 gotoLand 异常: " + e);
         }
      }
      
      // ---------- preflight ----------
      
      private function startPreflight(world:*):void
      {
         diag.log("preflight start: World.w 就绪");
         // 1) 收集磁盘房间文件清单
         try
         {
            var gd:XML = GDataCls["d"] as XML;
            var seen:Object = {};
            for each (var ld:XML in gd.land)
            {
               var f:String = String(ld.@file);
               if (f.length > 0 && seen[f] == null)
               {
                  seen[f] = 1;
                  fileList.push(f);
               }
            }
         }
         catch (e:*)
         {
            diag.log("preflight: 读取 GameData.d land 列表异常 " + e);
         }
         fileTotal = fileList.length;
         diag.log("preflight: 计划加载 " + fileTotal + " 个房间文件: " + fileList.join(","));
         
         // 2) 判定 rr_test 土地是否已注册（防重复注入）
         var already:Boolean = false;
         try
         {
            var gd2:XML = GDataCls["d"] as XML;
            already = gd2.land.(@id == RRTestLand.LAND_ID).length() > 0;
         }
         catch (e:*) {}
         diag.log("preflight: rr_test 已注册=" + already);
         
         // 3) 逐个加载磁盘文件
         for each (var file:String in fileList)
         {
            loadRoomFile(world, file);
         }
      }
      
      private function loadRoomFile(world:*, file:String):void
      {
         var rooms:* = world["rooms"];
         if (rooms == null)
         {
            diag.log("loadRoomFile: world.rooms 为空，跳过 " + file);
            fileFailed++;
            maybeFinalize();
            return;
         }
         var url:String = "Rooms/" + file + ".xml";
         var loader:URLLoader = new URLLoader();
         loader.addEventListener(Event.COMPLETE, function(ev:Event):void
         {
            try
            {
               var xml:XML = new XML(String(loader.data));
               rooms["rooms"][file] = xml;
               fileLoaded++;
               diag.log("房间文件已载入数组: " + file + "（房间数=" + xml.room.length() + "）");
            }
            catch (e:*)
            {
               fileFailed++;
               diag.log("房间文件解析失败: " + file + " : " + e);
            }
            maybeFinalize();
         });
         loader.addEventListener(IOErrorEvent.IO_ERROR, function(ev:IOErrorEvent):void
         {
            fileFailed++;
            diag.log("房间文件 IO 失败（保留内嵌副本）: " + file);
            maybeFinalize();
         });
         loader.addEventListener(flash.events.SecurityErrorEvent.SECURITY_ERROR, function(ev:*):void
         {
            fileFailed++;
            diag.log("房间文件安全错误: " + file);
            maybeFinalize();
         });
         try
         {
            loader.load(new URLRequest(url));
         }
         catch (e:*)
         {
            fileFailed++;
            diag.log("房间文件 load 调用异常: " + file + " : " + e);
            maybeFinalize();
         }
      }
      
      private function maybeFinalize():void
      {
         if (preflightDone) return;
         if (fileLoaded + fileFailed < fileTotal) return;
         finalizePreflight();
      }
      
      private function finalizePreflight():void
      {
         var world:* = null;
         try { world = WCls["w"]; } catch (e:*) {}
         diag.log("preflight finalize: 文件加载完成 成功=" + fileLoaded + " 失败=" + fileFailed +
                  " / 共" + fileTotal);
         if (world == null || GDataCls == null)
         {
            diag.log("preflight finalize: World/GameData 不可用，中止注入");
            return;
         }
         
         var rooms:* = world["rooms"];
         var gd:XML = GDataCls["d"] as XML;
         if (rooms == null || gd == null)
         {
            diag.log("preflight finalize: rooms 或 GameData.d 为空，中止注入");
            return;
         }
         
         // 注册测试土地（若已有则跳过——保单例）
         var already:Boolean = gd.land.(@id == RRTestLand.LAND_ID).length() > 0;
         if (!already)
         {
            gd.appendChild(test.makeLandXML());
            diag.log("inject: GameData.d 已追加 <land id=rr_test conf=1 3x3>");
         }
         else
         {
            diag.log("inject: <land rr_test> 已存在，跳过追加");
         }
         
         // 源池（预加载后的 rooms_stable 即磁盘真源）→ 构造测试池
         var srcPool:XML = rooms["rooms"][RRTestLand.SOURCE_LAND] as XML;
         if (srcPool == null)
         {
            diag.log("inject: 源池 " + RRTestLand.SOURCE_LAND + " 不存在，中止");
            return;
         }
         var poolXml:XML = test.makePoolXML(srcPool);
         rooms["rooms"][RRTestLand.POOL_FILE] = poolXml;
         
         // 切换加载路径：LandLoader 读数组
         world["roomsLoad"] = 0;
         preflightDone = true;
         diag.log("inject: roomsLoad=0，rr_test 池已就位（房间数=" + poolXml.room.length() + "）" +
                  " | READY: 开新游戏后按 F8 进入 rr_test，F9 回 rbl");
      }
      
      // ---------- 进入判定（H3） ----------
      
      private function verifyEntry(world:*):void
      {
         f8Ticks++;
         if (f8Ticks > ENTRY_TIMEOUT_TICKS)
         {
            diag.log("verifyEntry: 超时未进入 rr_test（" + ENTRY_TIMEOUT_TICKS + " 帧），停止等待");
            f8Issued = false;
            return;
         }
         var game:* = world["game"];
         if (game == null) return;
         var cur:String = "";
         try { cur = String(game["curLandId"]); } catch (e:*) {}
         if (cur != RRTestLand.LAND_ID) return;
         var land:* = world["land"];
         if (land == null) return;
         var locs:* = land["locs"];
         if (locs == null) return;
         
         // 采集 locs[x][y][0].room.id
         var ids:Object = {};
         var list:Array = [];
         var n:int = 0;
         for (var x:int = 0; x < locs.length; x++)
         {
            var col:* = locs[x];
            if (col == null) continue;
            for (var y:int = 0; y < col.length; y++)
            {
               var cell:* = col[y];
               if (cell == null || cell[0] == null) continue;
               n++;
               var room:* = cell[0]["room"];
               var rid:String = "";
               try { rid = String(room["id"]); } catch (e:*) {}
               if (ids[rid] == null)
               {
                  ids[rid] = 1;
                  list.push(rid);
               }
            }
         }
         list.sort();
         diag.log("verifyEntry: 进入 rr_test 成功！采集 " + n + " 个 loc，房间 id 集合(" + list.length + ")=" +
                  list.join(","));
         diag.log("verifyEntry: 预期池房间: " + test.pickedRooms().join(","));
         f8Issued = false;
      }
   }
}