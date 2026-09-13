package
{
   import flash.display.Sprite;
   import flash.desktop.NativeApplication;
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
   import rr.RRGrowth;
   import rr.RRTestLand;
   import rr.RRTravelBtn;
   
   /**
    * RandomRooms v7: architectural rooms, fresh maps and connected growth.
    * The existing host loader calls static init(main). Runtime changes are
    * confined to room pools and the two mod-owned lands; host SWFs stay intact.
    * F1 enters a fresh themed adventure; F5 provides a four-theme showroom.
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
      
      // Complete generated pools, with distinct vertical and endpoint rooms.
      private static var synth:RRSynth;
      private static var growth:RRGrowth;
      private static const SYNTH_COUNT:int = 48;
      
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
      private static const SHOW_SYNTH_COUNT:int = 24;
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
         
         growth=new RRGrowth(synth,cook,diag);

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
         diag.log("[RR] RandomRoomsMod v8.0 loaded <generator=space-v8, growth=right+down> stage bound (KEY_DOWN capture)");
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
         // Rebuild requests (including native death/retry) must use the same
         // coordinated pipeline, rather than falling back to random pool picks.
         if (preflightDone && world["game"]!=null && world["game"]["crea"])
         {
            var pendingId:String=String(world["game"]["curLandId"]);
            if (pendingId==LAND_ID_RR || pendingId==LAND_ID_SHOW)
            {
               try { refreshArchitecturePool(world,pendingId); }
               catch (buildError:*) { diag.log("C-REBUILD-FAIL "+buildError); }
            }
         }
         // 无限模式：进入边缘房间时向该方向扩展网格
         if (preflightDone && !f8Issued)
         {
            if (growth != null) growth.update(world);
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
         if (!preflightDone) maybeFinalize();
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
      
      /** Test driver entry uses the exact public travel path, only in isolated apps. */
      public static function debugReady():Boolean { return preflightDone; }
      public static function debugTravel(landId:String):Boolean
      {
         if (NativeApplication.nativeApplication.applicationID.indexOf("pferr-style-") != 0) return false;
         if (!preflightDone || [LAND_ID_RR,LAND_ID_SHOW,"rbl"].indexOf(landId)<0) return false;
         targetLand=landId;
         triggerTravel(landId,"isolated-test");
         return true;
      }

      private static function refreshArchitecturePool(world:*, landId:String):void
      {
         var show:Boolean=landId==LAND_ID_SHOW;
         var act:*=world["game"]["lands"][landId];
         if (act==null) throw new Error("C map LandAct is missing: "+landId);
         var biome:String=randBiome();
         var st:int=int(act["landStage"]);
         act["conf"]=9;
         act["mLocX"]=show?SHOW_MX:5; act["mLocY"]=show?SHOW_MY:5;
         act["lastCpCode"]="";
         act["dif"]=show?0:BASE_DIF_RR+st*DIF_PER_STAGE;
         var built:*=growth.build(world,act,int(act["mLocX"]),int(act["mLocY"]),biome,show);
         act["land"]=built;
         // The complete map is ready before normal travel activates it.
         world["game"]["crea"]=false;
         diag.log("C-POOL "+landId+" total="+act["allroom"].room.length()+
            " theme="+(show?"all":biome)+" ports=coordinated");
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
         if (landId == LAND_ID_SHOW || landId == LAND_ID_RR)
         {
            refreshArchitecturePool(world, landId);
            return;
         }
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
         // roomsLoad=0 changes World.roomsLoadOk from a counted barrier into
         // "any callback means ready". Do not switch while vanilla LandLoaders
         // are pending, or Game can capture a null probation pool at startup.
         var world:*=WCls!=null?WCls["w"]:null;
         if (world==null || world["landData"]==null || !world["allLandsLoaded"]) return;
         for each (var hostLoader:* in world["landData"])
         {
            if (hostLoader!=null && (!hostLoader["loaded"] || hostLoader["allroom"]==null)) return;
         }
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
         
         // Mod-owned lands keep native random-land lifecycle semantics. Their
         // complete coordinated maps are prepared before normal travel.
         if (gd.land.(@id == LAND_ID_RR).length() == 0)
            gd.appendChild(<land id="random_rooms" tip="rnd" rnd="1" dif="8" biom="1" conf="9"
               file="rooms_random_rooms" mx="5" my="5" locx="0" locy="0" list="0">
               <options backwall="tBackWall" music="music_plant_1" fon="fonDarkClouds" xp="150"/></land>);
         if (gd.land.(@id == LAND_ID_SHOW).length() == 0)
            gd.appendChild(<land id="rr_showroom" tip="rnd" rnd="1" dif="0" biom="0" conf="9"
               file="rooms_showroom" mx={SHOW_MX} my={SHOW_MY} locx="0" locy="0" list="0">
               <options backwall="tBackWall" music="music_plant_1" fon="fonDarkClouds" xp="50"/></land>);
         // Only placeholders until the first travel; never snapshot generated
         // rooms then append another generation to that snapshot.
         for each (var ownFile:String in [POOL_FILE_RR,POOL_FILE_SHOW])
         {
            var emptyPool:XML=<all><land serial="1"/></all>;
            rooms["rooms"][ownFile]=emptyPool;
            origPools[ownFile]=emptyPool.copy();
         }
         diag.log("C maps registered: coordinated architecture on travel");

         // ---- P0：变异 tip=rnd 土地的池（会话级；进入级刷新见 refreshLandPool） ----
         var rndLands:XMLList = gd.land.(@tip == "rnd");
         var cookedTotal:int = 0;
         for each (var ld:XML in rndLands)
         {
            var f2:String = String(ld.@file);
            if (f2 == POOL_FILE_RR || f2 == POOL_FILE_SHOW) continue;
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
                  " | READY: F1 随机冒险，F5 展示馆，F2 回城");
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
