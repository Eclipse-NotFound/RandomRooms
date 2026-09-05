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
   import rr.RRSynth;
   import rr.RRTestLand;
   import rr.RRTravelBtn;
   
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
      
      // P2：全新房间合成器（合成房混入池数量）
      private static var synth:RRSynth;
      private static const SYNTH_COUNT:int = 6;
      
      // P1 收尾：PipPage 旅行入口按钮
      private static var travelBtn:RRTravelBtn;
      private static var travelBtnShown:Boolean = false;
      
      // 深度循环状态
      private static var exitHintShown:Boolean = false;
      
      // 诊断：游戏错误对话框文本（showError 写入 World.verror.txt.text）
      private static var lastVerr:String = "";
      
      private static const F1_KEY:int = 112;  // F1 -> random_rooms（正式无限废墟）
      private static const F2_KEY:int = 113;  // F2 -> rbl
      private static const F3_KEY:int = 114;  // F3 -> rr_test（开发测试土地）
      private static const F4_KEY:int = 115;  // F4 -> 本层完成，进入下一层
      private static const F5_KEY:int = 116;  // F5 -> 合成房展示馆（每次进入重新合成）
      private static const F7_KEY:int = 118;  // F7 -> 当前层直传一个合成房
      private static const ENTRY_TIMEOUT_TICKS:int = 600; // ~10s @60fps
      
      /** P1 正式新土地 */
      public static const LAND_ID_RR:String = "random_rooms";
      public static const POOL_FILE_RR:String = "rooms_random_rooms";
      /** 深度循环：基础难度 + 每层增量（注入 LandAct.dif） */
      private static const BASE_DIF_RR:Number = 8;
      private static const DIF_PER_STAGE:Number = 2;
      /** 出口房 id（uniq，每层最多 1 个） */
      public static const EXIT_ROOM_ID:String = "rr_exit";
      /** 合成房展示馆（可视化测试通道） */
      public static const LAND_ID_SHOW:String = "rr_showroom";
      public static const POOL_FILE_SHOW:String = "rooms_showroom";
      private static const SHOW_SYNTH_COUNT:int = 8;
      private static const SHOW_MX:int = 4;
      private static const SHOW_MY:int = 3;
      
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
         
         // 全局未捕获异常落盘（诊断；游戏内 Land 构建异常会冒泡到这里）
         try
         {
            var uce:* = main.loaderInfo.uncaughtErrorEvents;
            if (uce != null)
            {
               uce.addEventListener("uncaughtError", onUncaught);
               diag.log("诊断: uncaughtError 监听已挂载");
            }
         }
         catch (e:*)
         {
            diag.log("诊断: uncaughtError 挂载失败 " + e);
         }
         
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
         
         // P2：合成器（独立 synth 种子序列）
         synth = new RRSynth();
         if (config.seedEnabled)
         {
            var synthGen:RRSeed = new RRSeed(config.seed).fork("synth");
            synth.rnd = function():Number { return synthGen.next(); };
            diag.log("合成器: synth PRNG 已注入（fork(synth)）");
         }
         else
         {
            synth.rnd = Math.random;
            diag.log("合成器: 使用 Math.random");
         }
         
         // 全局未捕获异常监听（诊断：游戏内 Land 构建等异常会冒泡到这里）
         try
         {
            var uce:* = main.loaderInfo.uncaughtErrorEvents;
            if (uce != null)
            {
               uce.addEventListener("uncaughtError", onUncaught);
               diag.log("诊断: uncaughtError 监听已挂载");
            }
         }
         catch (e:*)
         {
            diag.log("诊断: uncaughtError 挂载失败 " + e);
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
      
      /** 自动试驾（v6.5，仅测试实例）：applicationStorage 下存在 auto_enter.txt
       *  时自动 newGame + 进展示馆——供 agent 截图自检视觉，真实游戏无此文件
       *  永不触发。 */
      private static var autoState:int = -1;
      private static var autoTick:int = 0;
      private static var autoShotAt:int = -1;
      /** 合成按键事件发给 stage（模组 KEY_DOWN capture 可收；用于试驾关菜单） */
      private static function autoKey(code:int):void
      {
         try
         {
            var KECls:* = getDefinitionByName("flash.events.KeyboardEvent");
            main["stage"]["dispatchEvent"](new KECls("keyDown", true, false, code, code));
         }
         catch (e:*) {}
      }
      
      private static function autoShot(name:String):void
      {
         try
         {
            var BDcls:* = getDefinitionByName("flash.display.BitmapData");
            var bd:* = new BDcls(main["stage"]["stageWidth"], main["stage"]["stageHeight"]);
            bd["draw"](main["stage"]);
            var encCls:* = getDefinitionByName("flash.display.PNGEncoderOptions");
            var png:* = bd["encode"](bd["rect"], new encCls());
            var fo:* = getDefinitionByName("flash.filesystem.File")["applicationStorageDirectory"]["resolvePath"](name);
            var fs:* = new (getDefinitionByName("flash.filesystem.FileStream"))();
            fs["open"](fo, "write");
            fs["writeBytes"](png);
            fs["close"]();
            diag.log("AUTOPILOT: 截图 " + name);
         }
         catch (e:*)
         {
            diag.log("AUTOPILOT: 截图失败 " + name + " " + e);
         }
      }
      
      private static function autoPilot():void
      {
         if (autoState >= 12 || autoState == 0) return;
         autoTick++;
         var w:* = null;
         try { w = WCls["w"]; } catch (e:*) {}
         if (autoState == -1)
         {
            if (autoTick < 40) return;
            var f:* = null;
            try
            {
               var FCls:* = getDefinitionByName("flash.filesystem.File");
               f = FCls["applicationStorageDirectory"]["resolvePath"]("auto_enter.txt");
            }
            catch (e:*) {}
            autoState = (f != null && f.exists) ? 1 : 0;
            diag.log("AUTOPILOT: " + (autoState == 1 ? "标记存在，启动自动试驾" : "无标记，关闭"));
            return;
         }
         if (w == null) return;
         if (autoState == 1)
         {
            try
            {
               w["mm"]["active"] = false;
               w["newGame"](0, "LP", null);
               autoState = 2;
               diag.log("AUTOPILOT: newGame 已发出");
            }
            catch (e:*)
            {
               if (autoTick % 60 == 0) diag.log("AUTOPILOT: 等待可开档 " + e);
            }
            return;
         }
         if (autoState == 2)
         {
            var gg:* = null;
            try { gg = w["gg"]; } catch (e:*) {}
            if (gg != null)
            {
               autoState = 3;
               diag.log("AUTOPILOT: gg 就绪，发展示馆旅行");
            }
            else if (autoTick % 60 == 0) diag.log("AUTOPILOT: 等待 gg");
            return;
         }
         if (autoState == 3)
         {
            var landsOK:Boolean = false;
            try { landsOK = w["lands"] != null && w["lands"][LAND_ID_SHOW] == true; } catch (e:*) {}
            if (landsOK || autoTick % 120 == 0)
            {
               triggerTravel(LAND_ID_SHOW, "F5");
               autoState = 5;
               autoShotAt = -1;
               diag.log("AUTOPILOT: 旅行已发（landsOK=" + landsOK + "），切观察");
            }
            return;
         }
         if (autoState == 5)
         {
            // 进入后等 ~2.5s 土地渲染稳定，stage 截图落盘（不抢前台）
            if (autoShotAt < 0) autoShotAt = autoTick;
            if (autoTick - autoShotAt >= 150)
            {
               try
               {
                  var BDcls:* = getDefinitionByName("flash.display.BitmapData");
                  var bd:* = new BDcls(main["stage"]["stageWidth"], main["stage"]["stageHeight"]);
                  bd["draw"](main["stage"]);
                  var encCls:* = getDefinitionByName("flash.display.PNGEncoderOptions");
                  var png:* = bd["encode"](bd["rect"], new encCls());
                  var fo:* = getDefinitionByName("flash.filesystem.File")["applicationStorageDirectory"]["resolvePath"]("showroom_shot.png");
                  var fs:* = new (getDefinitionByName("flash.filesystem.FileStream"))();
                  fs["open"](fo, "write");
                  fs["writeBytes"](png);
                  fs["close"]();
                  diag.log("AUTOPILOT: 截图已存 showroom_shot.png");
               }
               catch (e:*)
               {
                  diag.log("AUTOPILOT: 截图失败 " + e);
               }
               autoState = 6;
            }
            return;
         }
         if (autoState == 6)
         {
            if (autoShotAt < 0) autoShotAt = autoTick;
            if (autoTick - autoShotAt >= 150)
            {
               autoKey(27);   // ESC 关可能弹出的菜单
               autoKey(9);    // TAB 关模组面板
               var px0:* = null, lx0:* = null;
               try { px0 = w["gg"]["X"]; lx0 = w["land"]["locX"]; } catch (e:*) {}
               diag.log("AUTOPILOT: 出发点 X=" + px0 + " locX=" + lx0);
               try { w["land"]["gotoXY"](0, 1); diag.log("AUTOPILOT: gotoXY(0,1) 切相邻合成房"); } catch (e:*) { diag.log("AUTOPILOT: gotoXY 异常 " + e); }
               autoShot("syn_view.png");
            }
            if (autoTick - autoShotAt >= 300)
            {
               autoKey(27);
               autoShot("syn_view2.png");
               var lx1:* = null;
               try { lx1 = w["land"]["locX"]; } catch (e:*) {}
               diag.log("AUTOPILOT: 合成房内 locX=" + lx1);
            }
            if (autoTick - autoShotAt >= 370)
            {
               autoKey(27);
               // 站位到 GY 行右缘内侧（GY 左右锚点洞+normalizeGaps 保证目标房同高开放）
               try
               {
                  var limX:* = w["land"]["loc"] != null ? null : null;
               } catch (e:*) {}
               try
               {
                  w["gg"]["X"] = 47 * 36 - 40;
                  w["gg"]["Y"] = 12 * 36 + 18;
                  diag.log("AUTOPILOT: 已站位 GY 行右缘 (X,Y 设置)");
               }
               catch (e:*) { diag.log("AUTOPILOT: 站位异常 " + e); }
               var res:* = "无";
               try { res = w["gg"]["outLoc"](2); } catch (e:*) { res = "异常" + e; }
               diag.log("AUTOPILOT: outLoc(2) 撞右边界 → " + (res == null ? "null=被弹回(通道不通)" : "Object=切格成功"));
               autoShot("cross_test.png");
            }
            if (autoTick - autoShotAt >= 440)
            {
               var lx2:* = null;
               try { lx2 = w["land"]["locX"]; } catch (e:*) {}
               diag.log("AUTOPILOT: 撞边测试后 locX=" + lx2 + "（0=锁原格失败，1=横向通行成功）");
               autoState = 9;
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
      
      private static function onUncaught(ev:*):void
      {
         try
         {
            var err:* = ev["error"];
            var msg:String = String(err);
            try { msg = String(err["getStackTrace"]()) + " || " + msg; } catch (e:*) {}
            diag.log("UNCAUGHT: " + msg);
         }
         catch (e:*)
         {
            diag.log("UNCAUGHT(解析失败): " + e);
         }
      }
      
      // ---------- 主循环 ----------
      
      private static function onFrame(ev:Event):void
      {
         autoPilot();
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
         // PipPage 旅行入口按钮管理（仅 in-game）
         if (!inMenu)
         {
            manageTravelBtn(world);
         }
         else if (travelBtnShown)
         {
            detachTravelBtn();
         }
         // 深度循环：出口房提示（进入 rr_exit 时提示 F4）
         if (preflightDone && !f8Issued)
         {
            var locRoomId:String = "";
            try { locRoomId = String(world["loc"]["room"]["id"]); } catch (e:*) {}
            if (locRoomId == EXIT_ROOM_ID)
            {
               if (!exitHintShown)
               {
                  exitHintShown = true;
                  mess(world, "RandomRooms: 找到出口！按 F4 进入下一层");
                  diag.log("rr_exit: 玩家已到达出口房");
               }
            }
            else
            {
               exitHintShown = false;
            }
         }
         // 无限模式：进入边缘房间时向该方向扩展网格
         if (preflightDone && !f8Issued)
         {
            maybeExpand(world);
         }
         // 诊断：游戏错误对话框文本（Land 构建异常被游戏 catch 后显示于此）
         var vtxt:String = "";
         try { vtxt = String(world["verror"]["txt"]["text"]); } catch (e:*) {}
         if (vtxt != null && vtxt.length > 0 && vtxt != lastVerr)
         {
            lastVerr = vtxt;
            diag.log("GAME_ERROR_DIALOG: " + vtxt);
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
      
      // ---------- PipPage 旅行入口 ----------
      
      private static function manageTravelBtn(world:*):void
      {
         try
         {
            var pip:* = world["pip"];
            if (pip == null) return;
            var page:* = pip["currentPage"];
            var cls:String = "";
            try { cls = flash.utils.getQualifiedClassName(page); } catch (e:*) {}
            var pipActive:Boolean = false;
            try { pipActive = Boolean(pip["active"]); } catch (e:*) {}
            if (cls == "fe.inter::PipPageInfo" && pipActive)
            {
               if (!travelBtnShown)
               {
                  attachTravelBtn(world);
               }
            }
            else if (travelBtnShown)
            {
               detachTravelBtn();
            }
         }
         catch (e:*)
         {
         }
      }
      
      private static function attachTravelBtn(world:*):void
      {
         try
         {
            var vpip:* = world["vpip"];
            if (vpip == null) return;
            if (travelBtn == null)
            {
               travelBtn = new RRTravelBtn(diag);
               travelBtn.travelFn = function():void { doTravelFromPip(world); };
            }
            if (travelBtn.parent == null)
            {
               vpip.addChild(travelBtn);
            }
            travelBtn.x = 360;
            travelBtn.y = 30;   // 横幅带（PipPageOpt 实测 y<100 空闲）
            travelBtnShown = true;
            diag.log("RRTravelBtn: PipPageInfo 旅行按钮已挂载");
         }
         catch (e:*)
         {
            diag.log("RRTravelBtn 挂载失败: " + e);
         }
      }
      
      private static function detachTravelBtn():void
      {
         if (!travelBtnShown) return;
         travelBtnShown = false;
         try
         {
            if (travelBtn != null && travelBtn.parent != null)
            {
               travelBtn.parent.removeChild(travelBtn);
            }
         }
         catch (e:*)
         {
         }
      }
      
      /** PipPage 按钮点击：校验 → 进入级刷新 → beginMission */
      private static function doTravelFromPip(world:*):void
      {
         try
         {
            var game:* = world["game"];
            if (game == null)
            {
               diag.log("doTravelFromPip: game 未创建");
               return;
            }
            var can:Boolean = false;
            try { can = Boolean(game["checkTravel"](LAND_ID_RR)); } catch (e:*) {}
            var loaded:Boolean = false;
            try { loaded = Boolean(game["lands"][LAND_ID_RR]["loaded"]); } catch (e:*) {}
            diag.log("doTravelFromPip: checkTravel=" + can + " lands.loaded=" + loaded);
            if (!can || !loaded)
            {
               diag.log("doTravelFromPip: 旅行校验未通过，忽略");
               return;
            }
            refreshLandPool(world, LAND_ID_RR);
            game["beginMission"](LAND_ID_RR);
            try
            {
               var pip:* = world["pip"];
               if (pip != null)
               {
                  pip["onoff"](-1);
               }
            }
            catch (e:*) {}
            diag.log("doTravelFromPip: beginMission(random_rooms) 已发起");
            // 进入后采样（复用 verifyEntry 通道）
            targetLand = LAND_ID_RR;
            f8Issued = true;
            f8Ticks = 0;
         }
         catch (e:*)
         {
            diag.log("doTravelFromPip 异常: " + e);
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
         else if (ev.keyCode == F4_KEY)
         {
            upstage();
         }
         else if (ev.keyCode == F5_KEY)
         {
            targetLand = LAND_ID_SHOW;
            triggerTravel(targetLand, "F5");
         }
         else if (ev.keyCode == F7_KEY)
         {
            jumpToSynth();
         }
      }
      
      /** 随机生物群系主题（种子确定性） */
      private static function randBiome():String
      {
         return RRSynth.BIOMES[int(synth.rnd() * RRSynth.BIOMES.length)];
      }
      
      // ---------- 合成房测试通道 ----------
      
      /** LocCls 缓存（构造预检用） */
      private static function getLocCls():*
      {
         try { return getDefinitionByName("fe.loc.Location"); } catch (e:*) {}
         return null;
      }
      
      /**
       * 合成房构造预检：new fe.loc.Location 复现 buildLoc；返回是否可构造。
       * 崩溃时可选触发格定位（逐格替换为 "_" 重试，找到首个触发格）。
       */
      private static function dumpSynthGrid(sroom:XML):void
      {
         try
         {
            var rows:XMLList = sroom.a;
            var wallCnt:int = 0;
            var total:int = 0;
            var sample:String = "";
            for (var j:int = 0; j < rows.length(); j++)
            {
               var cells:Array = String(rows[j]).split(".");
               for (var i:int = 0; i < cells.length; i++)
               {
                  total++;
                  if (RRSynth.WALL_CHARS.indexOf(String(cells[i]).charAt(0)) >= 0)
                  {
                     wallCnt++;
                  }
                  if (j == 12 && i < 30)
                  {
                     sample += String(cells[i]) + " ";
                  }
               }
            }
            diag.log("合成房网格: " + String(sroom.@name) + " 行=" + rows.length() +
                     " 墙占比=" + (total > 0 ? (wallCnt / total).toFixed(2) : "?") +
                     " [行12样本] " + sample);
            // 对照：独立 genGrid（固定参数、同 rnd 闭包）——若也全墙则 genGrid 本体 bug
            try
            {
               var rr2:RRSynth = new RRSynth(synth.rnd);
               var g2:Array = rr2.genGrid("stable", "corridor");
               var w2:int = 0;
               var t2:int = 0;
               var open2:int = 0;
               for (var a:int = 0; a < g2.length; a++)
               {
                  for (var b:int = 0; b < g2[a].length; b++)
                  {
                     t2++;
                     if (RRSynth.WALL_CHARS.indexOf(String(g2[a][b]).charAt(0)) >= 0) w2++;
                     else open2++;
                  }
               }
               diag.log("对照 genGrid(stable,corridor): 墙=" + w2 + " 开放=" + open2 + " 占比=" +
                        (t2 > 0 ? (w2 / t2).toFixed(2) : "?"));
               var stages:String = "";
               for (var si2:int = 0; si2 < rr2.debugStages.length; si2++)
               {
                  stages += String(rr2.debugStages[si2][0]) + "=" + String(rr2.debugStages[si2][1]) + " ";
               }
               diag.log("genGrid 分阶段: " + stages);
            }
            catch (e2:*)
            {
               diag.log("对照 genGrid 异常: " + e2);
            }
         }
         catch (e:*)
         {
            diag.log("dumpSynthGrid 异常: " + e);
         }
      }
      
      private static function precheckSynth(world:*, sroom:XML, locate:Boolean):Boolean
      {
         var LocCls:* = getLocCls();
         var curLandNow:* = null;
         try { curLandNow = world["land"]; } catch (e:*) {}
         if (LocCls == null || curLandNow == null)
         {
            diag.log("precheck: LocCls/land 不可用，跳过构造预检");
            return true;
         }
         dumpSynthGrid(sroom);
         try
         {
            new LocCls(curLandNow, sroom, false, {});
            return true;
         }
         catch (e:*)
         {
            if (locate)
            {
               var found:String = probeTriggerCell(curLandNow, LocCls, sroom);
               diag.log("合成房构造预检丢弃（触发格定位 " + found + "），异常: " + e);
            }
            else
            {
               diag.log("合成房构造预检丢弃（未定位），异常: " + e);
            }
            return false;
         }
         return false;   // 兜底（满足编译器返回分析）
      }
      
      /** 触发格定位：逐格替换为 "_" 重试构造，返回首个"替换后不崩"的格与代码 */
      private static function probeTriggerCell(land:*, LocCls:*, sroom:XML):String
      {
         var rows:XMLList = sroom.a;
         var h:int = rows.length();
         var grid:Array = [];
         var w:int = 0;
         for (var j:int = 0; j < h; j++)
         {
            grid[j] = String(rows[j]).split(".");
            if (w == 0) w = grid[j].length;
         }
         for (var jj:int = 0; jj < h; jj++)
         {
            for (var ii:int = 0; ii < w; ii++)
            {
               var orig:String = String(grid[jj][ii]);
               if (orig == "_") continue;
               var testRoom:XML = sroom.copy();
               var rows2:XMLList = testRoom.a;
               var rowArr:Array = String(rows2[jj]).split(".");
               rowArr[ii] = "_";
               rows2[jj] = <a>{rowArr.join(".")}</a>;
               try
               {
                  new LocCls(land, testRoom, false, {});
                  return "(" + jj + "," + ii + ") 原始码=" + orig;
               }
               catch (e2:*)
               {
               }
            }
         }
         return "扫描未定位（全格替换后仍崩）";
      }
      private static function jumpToSynth():void
      {
         var world:* = null;
         try { world = WCls["w"]; } catch (e:*) {}
         if (world == null || !preflightDone)
         {
            diag.log("F7: preflight 未完成，忽略");
            return;
         }
         var land:* = null;
         try { land = world["land"]; } catch (e:*) {}
         if (land == null) return;
         var actId:String = "";
         try { actId = String(land["act"]["id"]); } catch (e:*) {}
         if (actId != LAND_ID_RR && actId != LAND_ID_SHOW)
         {
            mess(world, "RandomRooms: F7 需在废墟（F1）或展示馆（F5）内使用");
            diag.log("F7: 不在合成房土地（" + actId + "），忽略");
            return;
         }
         try
         {
            var locs:* = land["locs"];
            var spots:Array = [];
            for (var x:int = 0; x < locs.length; x++)
            {
               var col:* = locs[x];
               if (col == null) continue;
               for (var y:int = 0; y < col.length; y++)
               {
                  var cell:* = col[y];
                  if (cell == null || cell[0] == null) continue;
                  var rid:String = "";
                  try { rid = String(cell[0]["room"]["id"]); } catch (e:*) {}
                  if (rid.indexOf("syn_") == 0)
                  {
                     spots.push([x, y]);
                  }
               }
            }
            if (spots.length == 0)
            {
               mess(world, "RandomRooms: 本层没有合成房（重新进入一层试试）");
               diag.log("F7: 未找到 syn_* 房间");
               return;
            }
            var pick:Array = spots[int(Math.random() * spots.length)];
            land["gotoXY"](pick[0], pick[1]);
            mess(world, "RandomRooms: 已传送到合成房 syn 房间（" + spots.length + " 个可选）");
            diag.log("F7: gotoXY(" + pick[0] + "," + pick[1] + ") 传送完成，合成房 " + spots.length + " 个");
         }
         catch (e:*)
         {
            diag.log("F7 异常: " + e);
         }
      }
      
      // ---------- 深度循环 ----------
      
      // 无限模式：边缘扩展状态
      private static var expandTick:int = 0;
      
      /**
       * 无限模式：玩家进入 random_rooms 边缘房间 → 向该方向扩展网格。
       * 用 Land.newRandomLoc（public）生成新列/行，缺口统一保证连通；
       * 右/下单向无限（左/上为固定起点侧，后续可做双向）。
       */
      private static function maybeExpand(world:*):void
      {
         var land:* = null;
         try { land = world["land"]; } catch (e:*) {}
         if (land == null) return;
         var actId:String = "";
         try { actId = String(land["act"]["id"]); } catch (e:*) {}
         if (actId != LAND_ID_RR) return;
         
         var maxX:int = 0;
         var maxY:int = 0;
         var lx:int = 0;
         var ly:int = 0;
         try
         {
            maxX = int(land["maxLocX"]);
            maxY = int(land["maxLocY"]);
            lx = int(land["locX"]);
            ly = int(land["locY"]);
         }
         catch (e:*) { return; }
         
         var needX:Boolean = lx >= maxX - 1;
         var needY:Boolean = ly >= maxY - 1;
         if (!needX && !needY)
         {
            expandTick = 0;
            return;
         }
         expandTick++;
         if (expandTick < 10) return;   // 防抖：进入边缘房间 10 帧后再扩展
         expandTick = 0;
         
         try
         {
            var stage:int = 0;
            try { stage = int(land["act"]["landStage"]); } catch (e:*) {}
            var opts:Object = {};
            
            if (needX)
            {
               var col:Array = [];
               var y:int = 0;
               while (y < maxY)
               {
                  var locX:* = land["newRandomLoc"](stage, maxX, y, opts, null);
                  col.push(locX != null ? [locX] : null);
                  y++;
               }
               land["locs"][maxX] = col;
               land["maxLocX"] = maxX + 1;
               diag.log("expand: 右扩一列 -> maxLocX=" + (maxX + 1) + "（层 " + stage + "）");
            }
            if (needY)
            {
               var newMaxX:int = int(land["maxLocX"]);
               var x2:int = 0;
               while (x2 < newMaxX)
               {
                  var col2:* = land["locs"][x2];
                  if (col2 == null)
                  {
                     x2++;
                     continue;
                  }
                  var locY:* = land["newRandomLoc"](stage, x2, maxY, opts, null);
                  col2[maxY] = locY != null ? [locY] : null;
                  x2++;
               }
               land["maxLocY"] = maxY + 1;
               diag.log("expand: 下扩一行 -> maxLocY=" + (maxY + 1) + "（层 " + stage + "）");
            }
            // 重建地图（尺寸随网格）
            try { land["createMap"](); } catch (e:*) {}
            diag.log("expand: 完成（locs 尺寸 " + land["maxLocX"] + "x" + land["maxLocY"] + "）");
         }
         catch (e:*)
         {
            diag.log("expand 异常: " + e);
         }
      }
      
      /** 消息提示（世界消息条） */
      private static function mess(world:*, text:String):void
      {
         try
         {
            world["gui"]["messText"]("", text, false, false, 150);
         }
         catch (e:*)
         {
         }
      }
      
      /**
       * F4：本层完成 → 层数+1 → 自动重进（新层新布局新难度）。
       * 走 gotoLand 通道（与 F1 相同），受 dopusk 门控保护。
       */
      private static function upstage():void
      {
         var world:* = null;
         try { world = WCls["w"]; } catch (e:*) {}
         if (world == null || !preflightDone)
         {
            diag.log("F4: preflight 未完成，忽略");
            return;
         }
         var game:* = world["game"];
         if (game == null)
         {
            diag.log("F4: game 未创建，忽略");
            return;
         }
         var cur:String = "";
         try { cur = String(game["curLandId"]); } catch (e:*) {}
         if (cur != LAND_ID_RR)
         {
            diag.log("F4: 当前不在 " + LAND_ID_RR + "（" + cur + "），忽略");
            return;
         }
         // dopusk 门控（gotoLand 同款检查，先探测给出友好提示）
         var pers:* = null;
         try { pers = world["pers"]; } catch (e:*) {}
         var dopusk:Boolean = false;
         try { dopusk = Boolean(pers["dopusk"]()); } catch (e:*) {}
         if (!dopusk)
         {
            mess(world, "RandomRooms: 伤势过重，无法深入下一层");
            diag.log("F4: dopusk 不通过（部件伤重），放弃升层");
            return;
         }
         try
         {
            game["upLandLevel"]();
            var act:* = game["lands"][LAND_ID_RR];
            var st:int = 0;
            try { st = int(act["landStage"]); } catch (e:*) {}
            mess(world, "RandomRooms 第 " + (st + 1) + " 层");
            diag.log("F4 upstage: landStage=" + st + "（下一层显示 " + (st + 1) + "）");
            // 自动重进新层（refreshLandPool 注入新难度+新变异）
            targetLand = LAND_ID_RR;
            f8Issued = true;
            f8Ticks = 0;
            refreshLandPool(world, LAND_ID_RR);
            game["gotoLand"](LAND_ID_RR);
         }
         catch (e:*)
         {
            diag.log("F4 upstage 异常: " + e);
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
            // 防重入：目标 == 当前土地（含传送过渡中 curLandId 已改）→ 忽略。
            // 重入当前土地会破坏退出流程（游戏已知危险操作）。
            if (landId == curLandId)
            {
               mess(world, "RandomRooms: 已在目标区域或传送中（先 F2 回城再试）");
               diag.log(tag + " 重入当前土地 " + landId + "，忽略");
               return;
            }
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
            if (file == POOL_FILE_SHOW)
            {
               // 展示馆：每次进入重新合成（beg0 模板 + 全新合成房），纯净无敌人
               var showFresh:XML = base.copy();
               var kept:int = 0;
               var dropped:int = 0;
               for (var si:int = 0; si < SHOW_SYNTH_COUNT; si++)
               {
                  var sroom:XML = synth.generate(100 + si, randBiome());
                  if (!RRSynth.validateRoom(sroom))
                  {
                     dropped++;
                     diag.log("合成房预检丢弃 syn_" + (100 + si) + "（字符非法，首行: " +
                              String(sroom.a[0]).substr(0, 50) + "）");
                     continue;
                  }
                  if (!precheckSynth(world, sroom, true))
                  {
                     dropped++;
                     continue;
                  }
                  showFresh.appendChild(sroom);
                  kept++;
               }
               if (dropped > 0)
               {
                  diag.log("展示馆: 合成房预检 保留=" + kept + " 丢弃=" + dropped);
               }
               // 降级：全部合成房被过滤时补作者 rnd 房，避免池无 rnd 房（#1010）
               if (kept == 0)
               {
                  var poolRooms:* = null;
                  try { poolRooms = world["rooms"]["rooms"]; } catch (e:*) {}
                  if (poolRooms != null)
                  {
                     var fbPool:XML = poolRooms["rooms_stable"] as XML;
                     if (fbPool != null)
                     {
                        for each (var fbr:XML in fbPool.room)
                        {
                           if (cook.isRndRoom(fbr) && RRSynth.validateRoom(fbr))
                           {
                              showFresh.appendChild(fbr.copy());
                              kept++;
                              diag.log("展示馆降级: 补作者 rnd 房 " + String(fbr.@name));
                              break;
                           }
                        }
                     }
                  }
               }
               cook.cookPool(showFresh, 1);   // 变异副本（展示更多变化）
               // 纯净：删除 en 类 obj + 禁敌（展示结构为主）
               for each (var r2:XML in showFresh.room)
               {
                  var keep2:Array = [];
                  for each (var o2:XML in r2.obj)
                  {
                     if (String(o2.@id).indexOf("en") != 0)
                     {
                        keep2.push(o2);
                     }
                  }
                  if (keep2.length != r2.obj.length())
                  {
                     delete r2.obj;
                     for each (var k2:XML in keep2)
                     {
                        r2.appendChild(k2);
                     }
                  }
                  if (r2.options.length() == 0)
                  {
                     r2.appendChild(<options/>);
                  }
                  r2.options.@entip = "0";
                  r2.options.@kolspawn = "0";
               }
               act["allroom"] = showFresh;
               act["land"] = null;
               diag.log("refreshLandPool: " + landId + " 展示馆已重合成（合成房 " + kept +
                        "，变异副本，无敌人）");
               // v6.5 完整 dump 首个合成房（网格+obj+back）——离线渲染定位悬空/门
               try
               {
                  var dpool:XMLList = act["allroom"].room;
                  for each (var dxm:XML in dpool)
                  {
                     if (String(dxm.@name).indexOf("syn_") != 0) continue;
                     diag.log("DUMP-BEGIN " + dxm.@name);
                     for each (var drow:XML in dxm.a) diag.log("DUMP-ROW " + drow.toString());
                     for each (var dobj:XML in dxm.obj) diag.log("DUMP-OBJ " + dobj.@id + " " + dobj.@x + " " + dobj.@y);
                     for each (var dback:XML in dxm.back) diag.log("DUMP-BACK " + dback.@id + " " + dback.@x + " " + dback.@y);
                     diag.log("DUMP-END");
                  }
               }
               catch (de:*)
               {
                  diag.log("DUMP 异常 " + de);
               }
               return;
            }
            var fresh:XML = base.copy();
            // P2：进入级注入合成房（仅 random_rooms；rr_test 等测试土地不混入）
            var keptRR:int = 0;
            for (var sri:int = 0; sri < SYNTH_COUNT && landId == LAND_ID_RR; sri++)
            {
               var sr:XML = synth.generate(sri, randBiome());
               if (RRSynth.validateRoom(sr) && precheckSynth(world, sr, true))
               {
                  fresh.appendChild(sr);
                  keptRR++;
               }
            }
            if (keptRR > 0)
            {
               diag.log("refreshLandPool: " + landId + " 注入合成房 " + keptRR + " 个");
            }
            var n:int = cook.cookPool(fresh, 1);
            // 深度循环：每层敌人表重掷（landStage 驱动分层）
            var st:int = 0;
            try { st = int(act["landStage"]); } catch (e:*) {}
            var en:int = cook.rollEnemies(fresh, st);
            act["allroom"] = fresh;                 // Land.prepareRooms 读此
            act["land"] = null;                     // 强制下次进入重建 Land
            // 深度循环：层数注入难度（LandAct.dif 每层 +DIF_PER_STAGE，
            // Land 构造时 landDifLevel 抬高 → setLocDif 全线难度提升）
            var newDif:Number = BASE_DIF_RR + st * DIF_PER_STAGE;
            act["dif"] = newDif;
            diag.log("refreshLandPool: " + landId + " 池已重 cook（+" + n + " 副本，变异变更格=" +
                     cook.lastChangedTotal + "，敌表重掷 " + en + " 房），并置 land=null 强制重建；dif=" +
                     newDif + "（层 " + st + "）");
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
         cook.normalizePool(poolXml);
         diag.log("inject: rr_test 池边界缺口已统一（门 bug 修复）");
         
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
         
         // 深度循环：出口房 rr_exit（uniq，每层最多 1 个；tip=uniq 不变异）
         var exitSrc:XMLList = (rooms["rooms"]["rooms_stable"] as XML).room.(options.@tip.length() == 0);
         if (exitSrc.length() > 0)
         {
            var exitRoom:XML = exitSrc[0].copy();
            exitRoom.@name = EXIT_ROOM_ID;
            if (exitRoom.options.length() == 0)
            {
               exitRoom.appendChild(<options/>);
            }
            exitRoom.options.@tip = "uniq";
            mix.appendChild(exitRoom);
            diag.log("inject: 出口房 " + EXIT_ROOM_ID + " 已加入混合池（池房间数=" + mix.room.length() + "）");
         }
         else
         {
            diag.log("inject: WARN 出口房源缺失（rooms_stable 无普通房）");
         }
         // P2 合成房：改为进入级（refreshLandPool）生成+预检注入
         // （finalize 在主菜单无 Land 无法构造预检）。混合池仅作者房。
         diag.log("inject: 合成房将在进入级刷新时生成并预检注入（本次不预混入池）");
         // 门 bug 修复：统一混合池边界缺口（在快照/cook 之前）
         var normalized:int = cook.normalizePool(mix);
         diag.log("inject: 混合池边界缺口已统一（" + normalized + " 房）");
         
         // ---- 合成房展示馆（可视化测试通道） ----
         var showLands:XMLList = gd.land.(@id == LAND_ID_SHOW);
         if (showLands.length() == 0)
         {
            gd.appendChild(<land id="rr_showroom" tip="rnd" rnd="1" dif="0" biom="0" conf="1"
                 file="rooms_showroom" mx="4" my="3" locx="0" locy="0" list="0">
                 <options backwall="tBackWall" music="music_plant_1" fon="fonDarkClouds" xp="50"/></land>);
            diag.log("inject: <land rr_showroom 4x3> 已追加");
         }
         var showPool:XML = <all><land serial="1"/></all>;
         var showBeg:XMLList = (rooms["rooms"]["rooms_stable"] as XML).room.(options.@tip == "beg0");
         if (showBeg.length() > 0)
         {
            showPool.appendChild(showBeg[0].copy());
         }
         for (var sn2:int = 0; sn2 < SHOW_SYNTH_COUNT; sn2++)
         {
            showPool.appendChild(synth.generate(sn2, randBiome()));
         }
         rooms["rooms"][POOL_FILE_SHOW] = showPool;
         cook.normalizePool(showPool);
         // 快照 = beg0-only（refresh 时重新合成，展示每次不同）
         var showBase:XML = <all><land serial="1"/></all>;
         if (showBeg.length() > 0)
         {
            showBase.appendChild(showBeg[0].copy());
         }
         origPools[POOL_FILE_SHOW] = showBase;
         diag.log("inject: 展示馆池构建完成（beg0 + " + SHOW_SYNTH_COUNT + " 合成房，缺口已统一）");
         
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
            cook.rollEnemies(pool, 0);   // 会话级兜底：层 0 敌人表
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
         diag.log("verifyEntry: 进入 " + targetLand + " 成功！网格=" + gridX + "x" + colLens.join(",") +
                  " 采集 " + n + " 个 loc，房间 id 集合(" + list.length + ")=" + list.join(","));
         diag.log("verifyEntry: 预期池房间(含P0变异副本前缀): " + test.pickedRooms().join(",") + " + *_rr* 副本");
         // 边界通行检查（v6.4）：读运行时 Location.space 的四边 phis，
         // 输出每边开放格数——对应 gotoLoc 的同高度碰撞判定
         try
         {
            var vloc:* = world.land.locs[0][0][0];
            var vsp:* = vloc.space;
            if (vsp == null) throw new Error("space 未构建");
            var openL:int = 0, openR:int = 0, openT:int = 0, openB:int = 0;
            var vi:int;
            // space[x][y]（Location 内部 space[i][j] i=x）
            for (vi = 0; vi < vloc.spaceY; vi++)
            {
               if (vsp[0][vi].phis <= 0) openL++;
               if (vsp[vloc.spaceX - 1][vi].phis <= 0) openR++;
            }
            for (vi = 0; vi < vloc.spaceX; vi++)
            {
               if (vsp[vi][0].phis <= 0) openT++;
               if (vsp[vi][vloc.spaceY - 1].phis <= 0) openB++;
            }
            diag.log("verifyEntry: 边界通行 L=" + openL + "/" + vloc.spaceY +
                     " R=" + openR + "/" + vloc.spaceY +
                     " T=" + openT + "/" + vloc.spaceX +
                     " B=" + openB + "/" + vloc.spaceX +
                     "（开放格数；gotoLoc 同高度进入，开放位=可通行）");
         }
         catch (e:*)
         {
            diag.log("verifyEntry: 边界检查异常 " + e);
         }
         f8Issued = false;
      }
   }
}