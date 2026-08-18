package
{
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.IOErrorEvent;
   import flash.events.KeyboardEvent;
   import flash.net.URLLoader;
   import flash.net.URLRequest;
   import flash.utils.getDefinitionByName;
   import rr.RRConfig;
   import rr.RRDiag;
   import rr.RRCook;
   import rr.RRMenu;
   import rr.RRSeed;
   import rr.RRTestLand;
   
   /**
    * RandomRoomsMod —— M0 实验文档类。
    *
    * 加载契约（mod-loader-patch-structure）：loader 用 getDefinition("RandomRoomsMod")
    * 并调用 **RandomRoomsMod.init(this)**（静态方法；与其他模组一致）。
    *
    * 注意：Loader 加载时会自动实例化文档类一次（root），构造必须保持轻量；
    * 全部运行逻辑在 static init 中启动。
    *
    * M0 流程：
    *   1. init(main) → 绑定 stage（ENTER_FRAME 晚于游戏 step；KEY_DOWN 早于游戏）；
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
      private static var diag:RRDiag;
      private static var test:RRTestLand;
      private static var main:*;
      
      private static var WCls:*;       // fe.World 类对象
      private static var GDataCls:*;   // fe.GameData 类对象
      
      private static var stageBound:Boolean = false;
      private static var preflightDone:Boolean = false;
      private static var preflightStarted:Boolean = false;
      
      private static var fileList:Array = [];
      private static var fileLoaded:int = 0;
      private static var fileFailed:int = 0;
      private static var fileTotal:int = 0;
      
      private static var f8Issued:Boolean = false;
      private static var f8Ticks:int = 0;
      
      // P0：原始池快照（进入级刷新用，避免对已变异池二次变异）
      private static var origPools:Object = {};
      private static var cook:RRCook = new RRCook();
      
      // P1：配置 + 种子 + 主菜单 UI
      private static var config:RRConfig;
      private static var seedGen:RRSeed;   // cook 用种子序列（会话级）
      private static var menu:RRMenu;
      private static var menuShown:Boolean = false;
      private static var targetLand:String = LAND_ID_RR;   // F1 目标土地（verifyEntry 用）
      
      private static const F1_KEY:int = 112;  // F1 -> random_rooms（正式无限废墟）
      private static const F2_KEY:int = 113;  // F2 -> rbl
      private static const F3_KEY:int = 114;  // F3 -> rr_test（开发测试土地）
      private static const ENTRY_TIMEOUT_TICKS:int = 600; // ~10s @60fps
      
      /** P1 正式新土地 */
      public static const LAND_ID_RR:String = "random_rooms";
      public static const POOL_FILE_RR:String = "rooms_random_rooms";
      
      /** Loader 会自动实例化文档类；构造保持空，避免日志歧义。 */
      public function RandomRoomsMod()
      {
      }
      
      /** 加载器契约入口（静态，与现有模组一致） */
      public static function init(main:*):void
      {
         RandomRoomsMod.main = main;
         diag = RRDiag.inst;
         test = new RRTestLand(diag);
         diag.log("init(main) called (static), main=" + main + " stage=" + (main ? main.stage : "n/a"));
         
         // P1：配置 + 种子序列注入 cook
         config = RRConfig.loadFromDisk();
         diag.log("config: enabled=" + config.enabled + " seedEnabled=" + config.seedEnabled +
                  " seed=" + config.seed);
         if (config.seedEnabled)
         {
            seedGen = new RRSeed(config.seed).fork("cook");
            cook.rnd = function():Number { return seedGen.next(); };
            diag.log("种子模式: cook PRNG 已注入（seed=" + config.seed + "），preview=" +
                     seedGen.preview(5).join(","));
         }
         else
         {
            cook.rnd = Math.random;
            diag.log("随机模式: cook 使用 Math.random");
         }
         
         // 模组与游戏主 SWF 同 applicationDomain（LoaderContext(false)），
         // 顶层 getDefinitionByName 在当前域解析游戏类。
         var probes:Array = ["fe.World", "fe.GameData", "fe.loc.Game", "fe.loc.Land"];
         for each (var n:String in probes)
         {
            var ok:Boolean = false;
            try { ok = getDefinitionByName(n) != null; } catch (e:*) { ok = false; }
            diag.log("class probe " + n + " => " + (ok ? "OK" : "MISSING"));
         }
         try { WCls = getDefinitionByName("fe.World"); } catch (e:*) { diag.log("getDefinition fe.World 失败: " + e); }
         try { GDataCls = getDefinitionByName("fe.GameData"); } catch (e:*) { diag.log("getDefinition fe.GameData 失败: " + e); }
         
         var st:* = null;
         try { st = main.stage; } catch (e:*) {}
         if (st)
         {
            bindStage(st);
         }
         else
         {
            diag.log("stage 暂不可用，进入轮询");
            try { st = main["stage"]; if (st) bindStage(st); } catch (e:*) {}
            try
            {
               main.stage.addEventListener(Event.ENTER_FRAME, onFrame);
            }
            catch (e:*)
            {
               diag.log("绑定轮询失败: " + e);
            }
         }
      }
      
      private static function bindStage(st:*):void
      {
         stageBound = true;
         st.addEventListener(Event.ENTER_FRAME, onFrame);
         // capture 阶段监听：先于所有 bubble 阶段监听（其它模组的
         // stopImmediatePropagation 无法阻止已先执行的捕获监听）
         st.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown, true);
         diag.log("[RR] RandomRoomsMod M0 loaded <preflight=disk-reseed+rr_test-land> stage bound (KEY_DOWN capture)");
      }
      
      // ---------- 主循环 ----------
      
      private static function onFrame(ev:Event):void
      {
         var world:* = null;
         try { world = WCls["w"]; } catch (e:*) {}
         if (world == null)
         {
            return;
         }
         // 主菜单 UI 管理
         var inMenu:Boolean = RRMenu.isMenuTime(world);
         if (inMenu && !menuShown)
         {
            showMenu();
         }
         else if (!inMenu && menuShown)
         {
            hideMenu();
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
      
      private static function showMenu():void
      {
         menuShown = true;
         try
         {
            if (menu == null)
            {
               menu = new RRMenu(config, diag);
            }
            var st:* = main.stage;
            menu.x = st.stageWidth - 310;
            menu.y = st.stageHeight - 70;
            st.addChild(menu);
            diag.log("RRMenu: 主菜单配置条已显示");
         }
         catch (e:*)
         {
            diag.log("RRMenu 显示失败: " + e);
         }
      }
      
      private static function hideMenu():void
      {
         if (!menuShown) return;
         menuShown = false;
         try
         {
            if (menu != null && menu.parent != null)
            {
               menu.parent.removeChild(menu);
            }
         }
         catch (e:*)
         {
         }
      }
      
      private static function onKeyDown(ev:KeyboardEvent):void
      {
         if (ev.keyCode == F1_KEY)
         {
            targetLand = LAND_ID_RR;
            triggerTravel(targetLand, "F1");
         }
         else if (ev.keyCode == F2_KEY)
         {
            triggerTravel("rbl", "F2");
         }
         else if (ev.keyCode == F3_KEY)
         {
            targetLand = RRTestLand.LAND_ID;
            triggerTravel(targetLand, "F3");
         }
      }
      
      private static function triggerTravel(landId:String, tag:String):void
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
            // P0 进入级刷新：rnd 土地在进入前重 cook 并强制重建
            refreshLandPool(world, landId);
            game["gotoLand"](landId);
            if (landId == targetLand)
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
      
      /**
       * P0 进入级刷新：用原始池快照重新变异，覆写 LandAct.allroom，
       * 并置 land=null 强制下次进入重建（rnd 土地内容可再生，无损）。
       */
      private static function refreshLandPool(world:*, landId:String):void
      {
         try
         {
            var game:* = world["game"];
            var act:* = game["lands"][landId];
            if (act == null)
            {
               diag.log("refreshLandPool: lands[" + landId + "] 不存在，跳过");
               return;
            }
            var file:String = "";
            try { file = String(act["landFile"]); } catch (e:*) {}
            if (file.length == 0)
            {
               // 从 GameData.d 反查
               var gd:XML = GDataCls["d"] as XML;
               var ldXml:XMLList = gd.land.(@id == landId);
               if (ldXml.length() > 0)
               {
                  file = String(ldXml[0].@file);
               }
            }
            if (file.length == 0)
            {
               diag.log("refreshLandPool: 无法确定 " + landId + " 的房间文件，跳过");
               return;
            }
            var base:XML = origPools[file] as XML;
            if (base == null)
            {
               diag.log("refreshLandPool: " + file + " 无原始池快照（非 tip=rnd 土地？），跳过");
               return;
            }
            var fresh:XML = base.copy();
            var n:int = cook.cookPool(fresh, 1);
            act["allroom"] = fresh;                 // Land.prepareRooms 读此
            act["land"] = null;                     // 强制下次进入重建 Land
            diag.log("refreshLandPool: " + landId + " 池已重 cook（+" + n + " 副本，变异变更格=" +
                     cook.lastChangedTotal + "），并置 land=null 强制重建");
         }
         catch (e:*)
         {
            diag.log("refreshLandPool 异常: " + e);
         }
      }
      
      // ---------- preflight ----------
      
      /**
       * 确保 World.w.rooms 有实例。
       * 原版从未初始化该字段（LandLoader 的 roomsLoad==0 分支从不执行，
       * roomsLoad 默认 1）；我们的注入路径需要它，故反射实例化 fe.rooms.Rooms。
       */
      private static function ensureRooms(world:*):*
      {
         var rooms:* = null;
         try { rooms = world["rooms"]; } catch (e:*) {}
         if (rooms != null) return rooms;
         diag.log("ensureRooms: World.w.rooms 为 null，反射实例化 fe.rooms.Rooms");
         try
         {
            var RoomsCls:* = getDefinitionByName("fe.rooms.Rooms");
            rooms = new RoomsCls();
            world["rooms"] = rooms;
            diag.log("ensureRooms: 已创建并挂接 Rooms 实例（内部池项=" + rooms["rooms"].length + "）");
         }
         catch (e:*)
         {
            diag.log("ensureRooms 失败: " + e);
         }
         return rooms;
      }
      
      private static function startPreflight(world:*):void
      {
         diag.log("preflight start: World.w 就绪");
         ensureRooms(world);
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
         
         var already:Boolean = false;
         try
         {
            var gd2:XML = GDataCls["d"] as XML;
            already = gd2.land.(@id == RRTestLand.LAND_ID).length() > 0;
         }
         catch (e:*) {}
         diag.log("preflight: rr_test 已注册=" + already);
         
         for each (var file:String in fileList)
         {
            loadRoomFile(world, file);
         }
      }
      
      private static function loadRoomFile(world:*, file:String):void
      {
         var rooms:* = world["rooms"];
         if (rooms == null)
         {
            diag.log("loadRoomFile: world.rooms 为空，跳过 " + file);
            fileFailed++;
            maybeFinalize();
            return;
         }
         // 绝对 app:/ 路径：相对路径会基于 mod SWF 位置（release/ 目录）解析
         var url:String = "app:/Rooms/" + file + ".xml";
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
      
      private static function maybeFinalize():void
      {
         if (preflightDone) return;
         if (fileLoaded + fileFailed < fileTotal) return;
         finalizePreflight();
      }
      
      private static function finalizePreflight():void
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
         
         var srcPool:XML = rooms["rooms"][RRTestLand.SOURCE_LAND] as XML;
         if (srcPool == null)
         {
            diag.log("inject: 源池 " + RRTestLand.SOURCE_LAND + " 不存在，中止");
            return;
         }
         var poolXml:XML = test.makePoolXML(srcPool);
         rooms["rooms"][RRTestLand.POOL_FILE] = poolXml;
         
         // ---- P1：random_rooms 新土地注册 + 混合池（stable+sewer） ----
         var rrLands:XMLList = gd.land.(@id == LAND_ID_RR);
         if (rrLands.length() == 0)
         {
            gd.appendChild(<land id="random_rooms" tip="rnd" rnd="1" dif="8" biom="1" conf="1"
                 file="rooms_random_rooms" mx="5" my="5" locx="0" locy="0" list="0">
                 <options backwall="tBackWall" music="music_plant_1" fon="fonDarkClouds" xp="150"/></land>);
            diag.log("inject: GameData.d 已追加 <land random_rooms 5x5 conf=1 dif=8>");
         }
         else
         {
            diag.log("inject: <land random_rooms> 已存在，跳过追加");
         }
         var mix:XML = <all><land serial="1"/></all>;
         var begXml:XMLList = (rooms["rooms"]["rooms_stable"] as XML).room.(options.@tip == "beg0");
         if (begXml.length() > 0)
         {
            mix.appendChild(begXml[0].copy());
         }
         for each (var srcName:String in ["rooms_stable", "rooms_sewer"])
         {
            var srcPool2:XML = rooms["rooms"][srcName] as XML;
            if (srcPool2 == null)
            {
               diag.log("inject: 混合池源 " + srcName + " 缺失，跳过");
               continue;
            }
            var added:int = 0;
            for each (var srcRoom:XML in srcPool2.room)
            {
               if (cook.isRndRoom(srcRoom))
               {
                  mix.appendChild(srcRoom.copy());
                  added++;
               }
            }
            diag.log("inject: 混合池加入 " + srcName + " 的 " + added + " 个 rnd 房");
         }
         rooms["rooms"][POOL_FILE_RR] = mix;
         diag.log("inject: 混合池 " + POOL_FILE_RR + " 构建完成（房间数=" + mix.room.length() + "）");
         
         // ---- P0：变异 tip=rnd 土地的池（会话级；进入级刷新见 refreshLandPool） ----
         var rndLands:XMLList = gd.land.(@tip == "rnd");
         var cookedTotal:int = 0;
         for each (var ld:XML in rndLands)
         {
            var f2:String = String(ld.@file);
            var pool:XML = rooms["rooms"][f2] as XML;
            if (pool == null)
            {
               diag.log("P0 cook: " + f2 + " 池缺失，跳过");
               continue;
            }
            origPools[f2] = pool.copy();   // 原始池快照（进入级刷新基座）
            var n2:int = cook.cookPool(pool, 1);
            cookedTotal += n2;
            diag.log("P0 cook: " + f2 + " +" + n2 + " 个变异副本（池房间数=" + pool.room.length() + "）");
         }
         diag.log("P0 cook 完成: 共 " + cookedTotal + " 个变异副本（tip=rnd 土地）");
         
         world["roomsLoad"] = 0;
         preflightDone = true;
         diag.log("inject: roomsLoad=0，rr_test 池已就位（房间数=" + poolXml.room.length() + "）" +
                  " | READY: 开新游戏后按 F1 进入 rr_test，F2 回 rbl");
      }
      
      // ---------- 进入判定（H3） ----------
      
      private static function verifyEntry(world:*):void
      {
         f8Ticks++;
         if (f8Ticks > ENTRY_TIMEOUT_TICKS)
         {
            diag.log("verifyEntry: 超时未进入 " + targetLand + "（" + ENTRY_TIMEOUT_TICKS + " 帧），停止等待");
            f8Issued = false;
            return;
         }
         var game:* = world["game"];
         if (game == null) return;
         var cur:String = "";
         try { cur = String(game["curLandId"]); } catch (e:*) {}
         if (cur != targetLand) return;
         var land:* = world["land"];
         if (land == null) return;
         
         // 硬门控：确认 World.land 实际是目标土地的 Land（传送过渡期
         // curLandId 已改但 World.land 还是旧土地）
         var actId:String = "";
         try { actId = String(land["act"]["id"]); } catch (e:*) {}
         if (actId != targetLand)
         {
            if (f8Ticks % 30 == 0)
            {
               diag.log("verifyEntry: 等待 Land 切换, World.land.act.id=" + actId + " (tick=" + f8Ticks + ")");
            }
            return;
         }
         if (f8Ticks < 30)
         {
            // 稳定期：等退出流程与 ativateLand 完成
            return;
         }
         
         var locs:* = land["locs"];
         if (locs == null) return;
         
         // 富采样：网格尺寸 + 每格 Location.id / room.id / room.tip
         var ids:Object = {};
         var list:Array = [];
         var n:int = 0;
         var colLens:Array = [];
         var gridX:int = locs.length;
         for (var x:int = 0; x < gridX; x++)
         {
            var col:* = locs[x];
            if (col == null)
            {
               colLens.push(0);
               continue;
            }
            colLens.push(col.length);
            for (var y:int = 0; y < col.length; y++)
            {
               var cell:* = col[y];
               if (cell == null || cell[0] == null)
               {
                  diag.log("verifyEntry: locs[" + x + "][" + y + "] 为空");
                  continue;
               }
               n++;
               var locObj:* = cell[0];
               var room:* = locObj["room"];
               var rid:String = "";
               var rtip:String = "";
               var lid:String = "";
               try { lid = String(locObj["id"]); } catch (e:*) {}
               try { rid = String(room["id"]); } catch (e:*) {}
               try { rtip = String(room["tip"]); } catch (e:*) {}
               diag.log("verifyEntry: locs[" + x + "][" + y + "] loc=" + lid + " room=" + rid + " tip=" + rtip);
               if (ids[rid] == null)
               {
                  ids[rid] = 1;
                  list.push(rid);
               }
            }
         }
         list.sort();
         diag.log("verifyEntry: 进入 rr_test 成功！网格=" + gridX + "x" + colLens.join(",") +
                  " 采集 " + n + " 个 loc，房间 id 集合(" + list.length + ")=" + list.join(","));
         diag.log("verifyEntry: 预期池房间(含P0变异副本前缀): " + test.pickedRooms().join(",") + " + *_rr* 副本");
         f8Issued = false;
      }
   }
}