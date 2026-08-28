package rr
{
   /**
    * RRSynth v2 —— 全新房间合成器（道路模板 × 生物群系分组）。
    *
    * 解决 v1 两缺陷：
    *   1. 材质混搭 → 整房只用单一 biome 组块/装饰（材料一致）；
    *   2. 无道路 → vcorr(纵向走廊)/hall(大厅) 道路模板：先画贯穿开放带，
    *      块只贴道路两侧分区，沿廊装饰带界定道路边界。
    *
    * 算法与 build/synth-proto2.py 同构（离线 200 房不变式已验证）。
    * 硬性约束：25 行 x 48 列（World.cellsY=25，作者房同维度）；
    * 缺口统一（左右=行12，上下=列23/24）；BFS 可达性（孤岛回填墙）。
    * rnd 可注入（种子确定性）。
    */
   public class RRSynth
   {
      public static const GRID_W:int = 48;
      public static const GRID_H:int = 25;   // 作者房均为 25 行（World.cellsY）；24 行致 buildLoc 越界 #1009
      
      public static const FCHARS:String = "ABCDEFGHIJKLMNOPQRST_";
      public static const OCHARS:String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
         "АБВГДЕЖЗИЙКЛМОПСТ-ДЕКНР" + "*,;:";
      /** 实体墙首字符（不含 _ 空地）——判墙必须用此集；FCHARS 含 _ 会误判 */
      public static const WALL_CHARS:String = "ABCDEFGHIJKLMNOPQRST";
      
      public static const BIOMES:Array = ["stable", "sewer", "plant", "mane"];

      /** 敌人出生标记配比 [enl1,enl2,enf1]，BIOMES 序（原版语料 rooms_*.xml
       *  实测: stable=28/49/23、sewer=21/36/43、plant=35/50/15、mane=31/52/17）。
       *  按名额分层分配（随机舍入），放置失败的名额不作桶间转移。 */
      public static const EN_RATE:Array = [[28,49,23],[21,36,43],[35,50,15],[31,52,17]];
      public static const EN_IDS:Array = ["enl1", "enl2", "enf1"];

      /** v5.7 墙面叙事：back 分组（结构/设施/照明），每房抽主导组 */
      public static const BACK_GROUPS:Array = [
         ["konstr", "vkonstr", "hkonstr"],
         ["vents", "pipe4"],
         ["stlight1"],
      ];
      /** v5.7 视觉锚池（卡2 MVP）：[id, 数量]——同 id 大件群横排 */
      public static const ANCHOR_POOL:Array = [["mcrate2", 4], ["table", 2], ["woodbox", 2]];

      /** v6.1 层界 profile 库：原版 658 房行剖面提取的真实层界组合（频次≥4，
       *  23 条覆盖 320 房）。[层1顶,层1底],[层2顶,层2底],... 层间 gap 即墙带。
       *  含通高大堂(1,23)、浮中层(8,19)、蜂窝(1,3)(5,7)... 全谱形态 */
      public static const LAYER_PROFILES:Array = [
         [[[1, 23]], 43], [[[1, 7], [9, 15], [17, 23]], 42], [[[1, 21]], 31],
         [[[1, 15], [17, 23]], 25], [[[1, 11], [13, 23]], 24], [[[1, 19]], 17],
         [[[1, 22]], 15], [[[1, 7], [9, 23]], 14], [[[1, 19], [21, 23]], 12],
         [[[1, 15]], 10], [[[1, 20]], 10], [[[8, 19]], 9], [[[8, 15]], 8],
         [[[9, 15]], 8], [[[1, 3], [5, 7], [9, 15], [17, 19], [21, 23]], 6],
         [[[1, 9], [11, 23]], 5], [[[1, 10], [12, 15], [17, 23]], 5],
         [[[1, 7], [9, 11], [13, 23]], 5], [[[1, 3], [5, 7], [9, 15], [17, 23]], 5],
         [[[1, 11], [13, 15], [17, 23]], 5], [[[1, 4], [8, 11], [16, 19]], 4],
         [[[4, 7], [12, 15], [20, 23]], 4], [[[1, 3], [5, 19], [21, 23]], 4],
      ];

      /** v6.0 物件脚下实证（原版 20198 obj）：全部拉丁 `_X` 都可站立（各字符
       *  200-800 个 obj），仅 `_-` 横梁（5 个）与 `_*` 水（139，特例）基本不放。
       *  isOpenCell 据此放宽；装饰排同样放宽到拉丁（原版地面纹理全系使用）。 */
      public static const SAFE_FLOOR:String = "BCFHLMNQTW";

      /** v5.9 物件谱系补充（AllData 实证占地）：hatch2 活板门 2×1、
       *  wallcab 墙柜 1×1、medbox 药箱 1×1、trash 垃圾 1×1、bed 床 4×1 */

      /** 房间个性向量（v5Skeleton 每房抽取，placeRoomObjects 消费） */
      private var emptyRoom:Boolean = false;
      private var density:Number = 1.0;

      
      private static const BLOCK_W:int = 6;
      private static const BLOCK_H:int = 4;
      private static const GY:int = 12;
      private static const GX1:int = 23;
      private static const GX2:int = 24;
      
      public var rnd:Function;
      /** 分阶段诊断：genGrid 每步墙数（定位全墙 bug） */
      public var debugStages:Array = [];
      /** v3.2 连通细胞表：主廊/纵连/腔室连廊落盘格（供腔室就近连廊） */
      private var pathCells:Array = [];
      /** v5.1 物件表：generate() 输出 <obj>/<back> 元素 */
      public var lastObjs:Array = [];
      public var lastBacks:Array = [];
      /** v5.6 竖隔断门口位（[x, yTop]）：门物件放置候选 */
      public var lastDoorSpots:Array = [];
      /** v6.0 层间主洞位（[x, bandTopRow]）：hatch2 活板门放置候选 */
      public var lastHatchSpots:Array = [];
      
      public function RRSynth(rndFn:Function = null)
      {
         rnd = rndFn != null ? rndFn : Math.random;
      }
      
      /** 生成一个合成房；biome 指定材质主题，rtype: "vcorr"/"hall"/""随机 */
      public function generate(n:int, biome:String = "stable", rtype:String = ""):XML
      {
         var grid:Array = genGrid(biome, rtype);
         var room:XML = <room name={"syn_" + n}/>;
         for (var j:int = 0; j < GRID_H; j++)
         {
            room.appendChild(<a>{grid[j].join(".")}</a>);
         }
         // v5.1 物件：门/箱子/家具/出生点/敌人标记
         if (lastObjs != null)
         {
            for (var k:int = 0; k < lastObjs.length; k++)
            {
               var o:Array = lastObjs[k] as Array;
               room.appendChild(<obj id={o[0]} code={o[1]} x={o[2]} y={o[3]}/>);
            }
         }
         if (lastBacks != null)
         {
            for (k = 0; k < lastBacks.length; k++)
            {
               var b:Array = lastBacks[k] as Array;
               room.appendChild(<back id={b[0]} x={b[1]} y={b[2]}/>);
            }
         }
         room.appendChild(<doors/>);
         room.appendChild(<options/>);
         return room;
      }
      
      /** 核心生成：场驱动（v3） */
      public function genGrid(biome:String, rtype:String):Array
      {
         var bIdx:int = RRGrammar.BIOME_ORDER.indexOf(biome);
         if (bIdx < 0) bIdx = 0;
         var wallTbl:Array = RRGrammar.BIOME_WALLS[bIdx] as Array;
         var decor:Array = RRGrammar.BIOME_DECORS[bIdx] as Array;
         if (rtype == null || rtype.length == 0)
         {
            var rt:int = int(rnd() * 4);
            rtype = rt == 0 ? "corridor" : (rt == 1 ? "hall" : (rt == 2 ? "l" : "split"));
         }
         
         var grid:Array = [];
         var j:int;
         var i:int;
         for (j = 0; j < GRID_H; j++)
         {
            grid[j] = [];
            for (i = 0; i < GRID_W; i++)
            {
               grid[j][i] = "_";
            }
         }
         debugStages = [];
         debugStages.push(["init", wallCount(grid)]);
         
         var f:Array = null;
         if (rtype == "corridor" || rtype == "hall" || rtype == "l" || rtype == "split")
         {
            // v5 房间-走廊骨架生成：显式房间 + 2 宽走廊网络 + 干净边界 +
            // 安全装饰（排除水/网格/横梁/台阶）+ 成片水池 + 连通修复
            v5Skeleton(grid, Math.min(bIdx, 3), rtype, wallTbl, decor);
            debugStages.push(["skeleton", wallCount(grid)]);
            finishStripRoom(grid);
            debugStages.push(["final", wallCount(grid)]);
            return grid;
         }
         else if (rtype == "quad")
         {
            f = quadField();
            var th:Number = threshWall(f, 0.22);
            for (j = 0; j < GRID_H; j++)
            {
               for (i = 0; i < GRID_W; i++)
               {
                  if (f[j][i] >= th)
                  {
                     grid[j][i] = wallChar(wallTbl);
                  }
               }
            }
            carveRooms(grid, rtype, wallTbl);
            materialBands(grid, wallTbl);
            applyBoundaryAndDecor(grid, decor, wallTbl, rtype);
            return grid;
         }
         else
         {
            // bunker：SDF 环带（掩体岛），独立画墙
            var ncen:int = 2 + int(rnd() * 2);
            var cx:Array = [];
            var cy:Array = [];
            for (var kc:int = 0; kc < ncen; kc++)
            {
               cx.push(8 + int(rnd() * (GRID_W - 17)));
               cy.push(5 + int(rnd() * (GRID_H - 11)));
            }
            for (j = 0; j < GRID_H; j++)
            {
               for (i = 0; i < GRID_W; i++)
               {
                  var d:Number = 1e9;
                  for (var kd:int = 0; kd < ncen; kd++)
                  {
                     var dd:Number = Math.sqrt((i - cx[kd]) * (i - cx[kd]) + (j - cy[kd]) * (j - cy[kd]));
                     if (dd < d) d = dd;
                  }
                  d += (rnd() - 0.5) * 1.2;
                  if (d >= 3.4 && d <= 5.6)
                  {
                     grid[j][i] = wallChar(wallTbl);
                  }
               }
            }
            applyBoundaryAndDecor(grid, decor, wallTbl, rtype);
            return grid;
         }
      }
      
      /** v5 房间-走廊骨架生成：
       * 1) 整图填墙（biome 材质）→ 2) 干净矩形房间(间距约束) 挖空
       * 3) 2 宽 L 形走廊网络：每房间连入生成树 + 6 缺口连入 → 房间-通道分明
       * 4) 边界 0/24 行 0/47 列整墙 + 6 缺口（干净边框）
       * 5) 材质带(2x4 区 90% 主字符) → 墙体区域统一不拼贴
       * 6) 装饰排仅安全地板纹理（排除 *水/K网格/-横梁/台阶/楼梯）
       * 7) 水池成片(sewer/plant)；连通修复由 finishStripRoom 完成 */
      private function v5Skeleton(grid:Array, bIdx:int, rtype:String, wallTbl:Array, decor:Array):void
      {
         var j:int, i:int, y:int, x:int, k:int, tries:int;
         // 1) 填墙
         lastDoorSpots = [];
         for (j = 0; j < GRID_H; j++)
         {
            for (i = 0; i < GRID_W; i++)
            {
               grid[j][i] = wallChar(wallTbl);
            }
         }
         // 2) 分层大厅 v6.0（原版取经）：层数按语料分布（658 房实证 1 层 31%/
         //    2 层 26%/3 层 26%/4 层 10%/5 层 3%）、层界非均分随机；40% 概率
         //    左右双列区各自独立分层（同一合成房内分层变化）；区界通高墙+门口
         var roomRects:Array = [];
         // 房间个性向量（DEC-0004 反均匀；语料校准：10/658 房全空 → 空房率 ~5%）
         emptyRoom = rnd() < 0.06;
         density = emptyRoom ? 0.0 : (0.5 + rnd() * 0.9);
         // 2a) 列区划分：单区=整宽统一分层；双区=左右各自分层（区界通高墙）
         var zones:Array = [];   // 每区 {x0,x1,layers,bands,walls}
         var nZone:int = rnd() < 0.4 ? 2 : 1;
         var zx:int = 10 + int(rnd() * 27);   // 10..36：双区宽度可悬殊
         var zw:int = rnd() < 0.3 ? 2 : 1;
         var zoneBounds:Array = nZone == 2 ? [[1, zx - 1], [zx + zw, GRID_W - 2]] : [[1, GRID_W - 2]];
         var zoneWalls:Array = nZone == 2 ? [[zx, zw]] : [];
         var zi:int;
         var li:int, y2:int, x2:int, r2:int, l3:int, b3:int;
         for (zi = 0; zi < zoneBounds.length; zi++)
         {
            var zx0:int = zoneBounds[zi][0];
            var zx1:int = zoneBounds[zi][1];
            var zw2:int = zx1 - zx0 + 1;
            // v6.1 层界 profile 库：加权抽一条原版真实组合（含通高/浮中层/
            // 蜂窝全谱形态）；带厚 = 层间 gap（天然来自 profile）
            var totalW:int = 0;
            for (b3 = 0; b3 < LAYER_PROFILES.length; b3++) totalW += LAYER_PROFILES[b3][1];
            var pv:Number = rnd() * totalW;
            var pi:int = 0;
            for (b3 = 0; b3 < LAYER_PROFILES.length; b3++)
            {
               pv -= int(LAYER_PROFILES[b3][1]);
               if (pv < 0)
               {
                  pi = b3;
                  break;
               }
            }
            var prof:Array = LAYER_PROFILES[pi][0];
            var zLayers:Array = [];
            var zBands:Array = [];
            for (l3 = 0; l3 < prof.length; l3++)
            {
               var pt:int = int(prof[l3][0]);
               var pb:int = int(prof[l3][1]);
               if (l3 > 0)
               {
                  var prevB:int = int(prof[l3 - 1][1]);
                  var gapRows:int = pt - prevB - 1;
                  if (gapRows >= 1) zBands.push([prevB + 1, gapRows]);
               }
               zLayers.push([pt, pb]);
            }
            zones.push({x0: zx0, x1: zx1, layers: zLayers, bands: zBands, walls: []});
         }
         // 2a') 挖开放层
         for (zi = 0; zi < zones.length; zi++)
         {
            var zl0:Array = zones[zi].layers;
            for (li = 0; li < zl0.length; li++)
            {
               for (y2 = zl0[li][0]; y2 <= zl0[li][1]; y2++)
               {
                  for (x2 = zones[zi].x0; x2 <= zones[zi].x1; x2++) grid[y2][x2] = "_";
               }
            }
         }
         // 2b) 层间墙带 + 主次洞 + hatch2 结构化（主洞 40% 出活板门——
         //     洞即层间通道口，活板门=其盖口，原版语义 0.40/房）
         var bandTop:int, bandRows:int, holeK:int, holeX:int, holeW:int, holeLast:int, gx:int;
         lastHatchSpots = [];
         for (zi = 0; zi < zones.length; zi++)
         {
            var zb0:Array = zones[zi].bands;
            for (li = 0; li < zb0.length; li++)
            {
               bandTop = int(zb0[li][0]);
               bandRows = int(zb0[li][1]);
               for (r2 = 0; r2 < bandRows; r2++)
               {
                  for (x2 = zones[zi].x0; x2 <= zones[zi].x1; x2++) grid[bandTop + r2][x2] = wallChar(wallTbl);
               }
               holeLast = zones[zi].x0;
               for (holeK = 0; holeK < 2 + int(rnd() * 2); holeK++)
               {
                  holeW = holeK == 0 ? 4 + int(rnd() * 2) : 3;
                  holeX = holeLast + 4 + int(rnd() * Math.max(1, zones[zi].x1 - 6 - holeLast));
                  if (holeX > zones[zi].x1 - holeW + 1) holeX = zones[zi].x1 - holeW + 1;
                  for (x2 = holeX; x2 < holeX + holeW && x2 <= zones[zi].x1; x2++)
                  {
                     for (r2 = 0; r2 < bandRows; r2++) grid[bandTop + r2][x2] = "_";
                  }
                  if (holeK == 0 && rnd() < 0.4)
                  {
                     lastHatchSpots.push([holeX, bandTop]);
                  }
                  holeLast = holeX + holeW;
               }
               // 十字动线：GX1/GX2 列对齐洞（若落在区内）
               if (rnd() < 0.6)
               {
                  gx = rnd() < 0.5 ? GX1 - 1 : GX2 - 1;
                  if (gx >= zones[zi].x0 && gx + 3 <= zones[zi].x1 + 1)
                  {
                     for (x2 = gx; x2 < gx + 3; x2++)
                     {
                        for (r2 = 0; r2 < bandRows; r2++) grid[bandTop + r2][x2] = "_";
                     }
                  }
               }
            }
         }
         // 2c) 区界墙（双区）：通高 1-2 格厚 + 2-3 个 3 宽×3 高门口
         var wallW:int, w2:int, doorK:int, doorY:int;
         for (zi = 0; zi < zoneWalls.length; zi++)
         {
            var zwx:int = zoneWalls[zi][0];
            var zww:int = zoneWalls[zi][1];
            for (y2 = 1; y2 <= GRID_H - 2; y2++)
            {
               for (w2 = 0; w2 < zww; w2++) grid[y2][zwx + w2] = wallChar(wallTbl);
            }
            for (doorK = 0; doorK < 2 + int(rnd() * 2); doorK++)
            {
               doorY = 2 + int(rnd() * (GRID_H - 7));
               for (var dz:int = 0; dz < 3; dz++)
               {
                  for (w2 = 0; w2 < zww; w2++) grid[doorY + dz][zwx + w2] = "_";
               }
               lastDoorSpots.push([zwx, doorY]);
            }
         }
         // 2d) 层内竖隔断（层型三档：大厅 0 隔断 / 普通 1-2 / 蜂窝 3-4，每层
         //     独立抽）；隔断厚 1-2 格；主门口宽 3、次门口宽 2，高 3
         var segIdx:int, wallX:int, dOK:Boolean;
         for (zi = 0; zi < zones.length; zi++)
         {
            var zl:Array = zones[zi].layers;
            var zx0b:int = zones[zi].x0;
            var zx1b:int = zones[zi].x1;
            for (li = 0; li < zl.length; li++)
            {
               var ltop:int = zl[li][0];
               var lbot:int = zl[li][1];
               var styleRoll:Number = rnd();
               var segs:int = styleRoll < 0.25 ? 0 : (styleRoll < 0.75 ? 1 + int(rnd() * 2) : 3 + int(rnd() * 2));
               var availW:int = zx1b - zx0b + 1;
               if (availW < 10) segs = Math.min(segs, 1);
               for (segIdx = 0; segIdx < segs; segIdx++)
               {
                  var placedW:Boolean = false;
                  for (tries = 0; tries < 20 && !placedW; tries++)
                  {
                     wallX = zx0b + 4 + int(rnd() * Math.max(1, availW - 8));
                     wallW = rnd() < 0.3 ? 2 : 1;
                     dOK = true;
                     for (k = 0; k < (zones[zi].walls as Array).length; k++)
                     {
                        if (Math.abs(int((zones[zi].walls[k] as Array)[0]) - wallX) < 6)
                        {
                           dOK = false;
                           break;
                        }
                     }
                     if (!dOK) continue;
                     for (y2 = ltop; y2 <= lbot; y2++)
                     {
                        for (w2 = 0; w2 < wallW; w2++) grid[y2][wallX + w2] = wallChar(wallTbl);
                     }
                     var nDoor:int = 1 + int(rnd() * 2);
                     for (doorK = 0; doorK < nDoor; doorK++)
                     {
                        doorY = ltop + 1 + int(rnd() * Math.max(1, lbot - ltop - 3));
                        var doorW:int = doorK == 0 ? 3 : 2;
                        for (var dz:int = 0; dz < 3 && doorY + dz <= lbot; dz++)
                        {
                           for (w2 = 0; w2 < Math.min(doorW, wallW); w2++) grid[doorY + dz][wallX + w2] = "_";
                        }
                        lastDoorSpots.push([wallX, doorY]);
                     }
                     (zones[zi].walls as Array).push([wallX, wallW, ltop, lbot]);
                     placedW = true;
                  }
               }
            }
         }
         // 2e) roomRects：每区每层，按隔断切段（段宽 ≥4 才算房间）
         for (zi = 0; zi < zones.length; zi++)
         {
            var zl2:Array = zones[zi].layers;
            var zwalls:Array = zones[zi].walls;
            for (li = 0; li < zl2.length; li++)
            {
               var ltop2:int = zl2[li][0];
               var lbot2:int = zl2[li][1];
               var xs:Array = [];
               for (k = 0; k < zwalls.length; k++)
               {
                  var wrec:Array = zwalls[k] as Array;
                  if (int(wrec[2]) <= lbot2 && int(wrec[3]) >= ltop2) xs.push(int(wrec[0]));
               }
               xs.sort(Array.NUMERIC);
               var x0:int = zones[zi].x0;
               for (k = 0; k <= xs.length; k++)
               {
                  var x1:int = k < xs.length ? int(xs[k]) : zones[zi].x1 + 1;
                  if (x1 - x0 >= 4) roomRects.push([x0, ltop2, x1 - x0, lbot2 - ltop2 + 1]);
                  x0 = x1 + 1;
                  if (k < xs.length)
                  {
                     for (var wk:int = 0; wk < zwalls.length; wk++)
                     {
                        if (int((zwalls[wk] as Array)[0]) == x1)
                        {
                           x0 += int((zwalls[wk] as Array)[1]) - 1;
                           break;
                        }
                     }
                  }
               }
            }
         }
         // 4) 材质带（90% 主字符；v5.7 按层分区 + 对比补丁区）
         materialBands(grid, wallTbl, zones);
         // 5) 边界：0/24 行 0/47 列整墙 + 6 缺口
         for (i = 0; i < GRID_W; i++)
         {
            grid[0][i] = wallChar(wallTbl);
            grid[GRID_H - 1][i] = wallChar(wallTbl);
         }
         for (j = 0; j < GRID_H; j++)
         {
            grid[j][0] = wallChar(wallTbl);
            grid[j][GRID_W - 1] = wallChar(wallTbl);
         }
         grid[GY][0] = "_";
         grid[GY][GRID_W - 1] = "_";
         grid[0][GX1] = "_";
         grid[0][GX2] = "_";
         grid[GRID_H - 1][GX1] = "_";
         grid[GRID_H - 1][GX2] = "_";
         // 6) 装饰排：仅安全地板纹理后缀；密度联动房间个性，60% 用主导纹理
         //    （墙面叙事——纹理也讲分区，不再每格均匀抽）
         var safeDec:Array = safeDecor(decor);
         if (safeDec.length > 0 && !emptyRoom)
         {
            var den:Number = (bIdx == 0 ? 0.40 : (bIdx == 1 ? 0.30 : (bIdx == 2 ? 0.28 : 0.34))) * density;
            var mainDec:String = pickWeighted(safeDec);
            for (y = 1; y < GRID_H - 1; y++)
            {
               x = 1;
               while (x < GRID_W - 1)
               {
                  if (grid[y][x] == "_" && rnd() < den)
                  {
                     var L:int = 2 + int(rnd() * 5);
                     for (k = 0; k < L; k++)
                     {
                        var dx2:int = x + k;
                        if (dx2 < GRID_W - 1 && grid[y][dx2] == "_")
                        {
                           grid[y][dx2] = "_" + (rnd() < 0.6 ? mainDec : pickWeighted(safeDec));
                        }
                     }
                     x += L;
                  }
                  else
                  {
                     x++;
                  }
               }
            }
         }
         // 7) 水池成片（sewer/plant；v5.5：只放房间矩形内部且区域完整——
         //    v5.4 全图随机放置会被墙切成碎条、还可能横压走廊/门口）
         var pools:int = bIdx == 1 ? (1 + int(rnd() * 3)) : (bIdx == 2 ? (1 + int(rnd() * 2)) : 0);
         for (k = 0; k < pools && roomRects.length > 0; k++)
         {
            var pw:int = 4 + int(rnd() * 5);
            var ph2:int = 2 + int(rnd() * 3);
            var wr:Array = roomRects[int(rnd() * roomRects.length)] as Array;
            // rect 内部留 1 圈墙皮/通行边，区域完整才放（不成碎片）
            if (wr[2] < pw + 2 || wr[3] < ph2 + 2) continue;
            var px:int = wr[0] + 1 + int(rnd() * (wr[2] - pw - 1));
            var py:int = wr[1] + 1 + int(rnd() * (wr[3] - ph2 - 1));
            var full:Boolean = true;
            for (y = py; y < py + ph2 && full; y++)
            {
               for (x = px; x < px + pw; x++)
               {
                  if (grid[y][x] != "_")
                  {
                     full = false;
                     break;
                  }
               }
            }
            if (!full) continue;
            for (y = py; y < py + ph2; y++)
            {
               for (x = px; x < px + pw; x++)
               {
                  grid[y][x] = "_*";
               }
            }
         }
         // 8) 房间物件：门(竖隔断门口)/贴墙箱子/室内家具/书架/出生点/背景装饰
         lastObjs = [];
         lastBacks = [];
         placeRoomObjects(grid, bIdx, roomRects);
      }

      /** 房间物件放置：每房间 门+锚+箱子+家具/床+出生点；贴墙背景装饰。
       * 全部按占地格(size×wid)校验开放 → 无悬空/穿墙 */
      private function placeRoomObjects(grid:Array, bIdx:int, rects:Array):void
      {
         var doorId:String = bIdx == 2 ? "door1" : "stdoor";
         var crates:Array = bIdx == 0 ? ["ammobox", "explbox", "case", "mcrate2", "chest", "locker", "wallcab", "medbox", "trash"] :
                           (bIdx == 1 ? ["case", "ammobox", "explbox", "box", "woodbox", "chest", "locker", "radbarrel", "wallcab", "trash", "bookcase", "checkpoint"] :
                           (bIdx == 2 ? ["ammobox", "case", "box", "explbox", "chest", "radbarrel", "woodbox", "medbox", "bookcase", "hatch2", "checkpoint"] :
                                        ["case", "ammobox", "explbox", "mcrate2", "filecab", "locker", "wallcab", "medbox", "trash", "bookcase"]));
         var sofas:Array = bIdx == 0 ? ["couch", "lov"] : ["lov"];
         var tableId:String = bIdx == 0 ? "table2" : "table";
         var backs:Array = ["konstr", "vkonstr", "hkonstr", "stlight1", "vents", "pipe4"];
         var r:int, k:int, tries:int, placed:int;
         var usedGlobal:Object = {};  // 全局占用（门/活板门等跨 rect 结构物）
         var rectUsed:Array = [];    // 各 rect 的占用表（平行 rects；player/敌标记房间级放置用）
         var playerPos:Array = null; // 房间级唯一出生点（原版 0.99 player/房）
         // 门与活板门（v6.1 全局放置修复：门口/洞位在隔断列与墙带行上，
         // 不属于任何 rect——旧 per-rect 过滤把它们全部跳过，导致门/活板门
         // 自 v5.6 起从未实际生成）
         var dFoot2:Array = objFoot(doorId);
         for (k = 0; k < lastDoorSpots.length; k++)
         {
            var dsp:Array = lastDoorSpots[k] as Array;
            var dsx:int = int(dsp[0]);
            var dsy:int = int(dsp[1]);
            if (usedGlobal[dsy + "," + dsx] == true) continue;
            if (rnd() >= 0.7) continue;
            if (!footOk(grid, dsx, dsy, dFoot2[0], dFoot2[1])) continue;
            lastObjs.push([doorId, genCode(), dsx, dsy]);
            for (var dfy:int = 0; dfy < dFoot2[1]; dfy++) usedGlobal[(dsy + dfy) + "," + dsx] = true;
         }
         for (k = 0; k < lastHatchSpots.length; k++)
         {
            var hsp:Array = lastHatchSpots[k] as Array;
            var hfx:int = int(hsp[0]);
            var hfy:int = int(hsp[1]);
            if (usedGlobal[hfy + "," + hfx] == true || usedGlobal[hfy + "," + (hfx + 1)] == true) continue;
            if (rnd() >= 0.85) continue;
            if (!footOk(grid, hfx, hfy, 2, 1)) continue;
            lastObjs.push(["hatch2", genCode(), hfx, hfy]);
            usedGlobal[hfy + "," + hfx] = true;
            usedGlobal[hfy + "," + (hfx + 1)] = true;
         }
         // 房间个性（DEC-0004）：空房只留出生点与结构；密度系数缩放物件量
         var mainBacks:Array = BACK_GROUPS[int(rnd() * BACK_GROUPS.length)] as Array;
         for (r = 0; r < rects.length; r++)
         {
            var rect:Array = rects[r] as Array;
            var cwx:int = rect[0];
            var cwy:int = rect[1];
            var cw:int = rect[2];
            var ch2:int = rect[3];
            var used:Object = {};
            if (emptyRoom) 
            {
               rectUsed.push(used);
               continue;
            }
            // 视觉锚（卡2 MVP）：50% 房间，锚池大件群横排放 rect 中带，
            // 先占位——后续物件围绕退让（主角先行）
            if (cw >= 8 && ch2 >= 5 && rnd() < 0.5)
            {
               var apool:Array = ANCHOR_POOL[int(rnd() * ANCHOR_POOL.length)] as Array;
               var aid:String = String(apool[0]);
               var acount:int = int(apool[1]);
               var afoot:Array = objFoot(aid);
               var aw:int = acount * afoot[0];
               if (cw >= aw + 2 && ch2 >= afoot[1] + 2)
               {
                  var ax0:int = cwx + 2 + int(rnd() * Math.max(1, cw - aw - 3));
                  var ay0:int = cwy + 2 + int(rnd() * Math.max(1, ch2 - afoot[1] - 3));
                  var allOK:Boolean = true;
                  for (var ai:int = 0; ai < acount; ai++)
                  {
                     if (!footOk(grid, ax0 + ai * afoot[0], ay0, afoot[0], afoot[1]))
                     {
                        allOK = false;
                        break;
                     }
                  }
                  if (allOK)
                  {
                     for (ai = 0; ai < acount; ai++)
                     {
                        lastObjs.push([aid, genCode(), ax0 + ai * afoot[0], ay0]);
                        for (var ady:int = 0; ady < afoot[1]; ady++)
                        {
                           for (var adx:int = 0; adx < afoot[0]; adx++)
                           {
                              used[(ay0 + ady) + "," + (ax0 + ai * afoot[0] + adx)] = true;
                           }
                        }
                     }
                  }
               }
            }
            // 箱子（贴墙，占地校验；数量随房间个性密度缩放；全格占用防叠放）
            var nCrate:int = int((2 + int(rnd() * 3)) * density + 0.5);
            tries = 0;
            placed = 0;
            while (placed < nCrate && tries < 60)
            {
               tries++;
               var cid:String = crates[int(rnd() * crates.length)];
               var c:Array = wallSpot(grid, cwx, cwy, cw, ch2, used, cid);
               if (c == null) break;
               lastObjs.push([cid, genCode(), c[0], c[1]]);
               markUsed(used, c[0], c[1], cid);
               placed++;
            }
            // 沙发/桌子/书架/床（室内，占地校验；出现概率随密度缩放）
            var sofaId:String = sofas[int(rnd() * sofas.length)];
            var in1:Array = interiorSpot(grid, cwx, cwy, cw, ch2, used, sofaId);
            if (in1 != null && rnd() < 0.7 * density)
            {
               lastObjs.push([sofaId, genCode(), in1[0], in1[1]]);
               markUsed(used, in1[0], in1[1], sofaId);
            }
            var in2:Array = interiorSpot(grid, cwx, cwy, cw, ch2, used, tableId);
            if (in2 != null && rnd() < 0.6 * density)
            {
               lastObjs.push([tableId, genCode(), in2[0], in2[1]]);
               markUsed(used, in2[0], in2[1], tableId);
            }
            var in3:Array = interiorSpot(grid, cwx, cwy, cw, ch2, used, "bookcase");
            if (in3 != null && rnd() < 0.5 * density)
            {
               lastObjs.push(["bookcase", genCode(), in3[0], in3[1]]);
               markUsed(used, in3[0], in3[1], "bookcase");
            }
            var in5:Array = interiorSpot(grid, cwx, cwy, cw, ch2, used, "bed");
            if (in5 != null && rnd() < 0.3 * density)
            {
               lastObjs.push(["bed", genCode(), in5[0], in5[1]]);
               markUsed(used, in5[0], in5[1], "bed");
            }
            // 背景装饰（v5.9 贴墙采样：原版 84% back 距墙≤3 格——撒在大厅中央
            // 的灯/管道视觉上悬空）；数量随密度，60% 出主导组
            var nBack:int = int((3 + int(rnd() * 4)) * density + 0.5);
            var backSpots:Array = [];
            var yy2:int, xx2:int, dd:int, dHit:Boolean;
            for (yy2 = cwy; yy2 < cwy + ch2; yy2++)
            {
               for (xx2 = cwx; xx2 < cwx + cw; xx2++)
               {
                  if (yy2 < 0 || yy2 >= GRID_H || xx2 < 0 || xx2 >= GRID_W) continue;
                  if (!isOpenCell(grid[yy2][xx2])) continue;
                  dHit = false;
                  for (dd = 1; dd <= 2 && !dHit; dd++)
                  {
                     if ((yy2 - dd >= 0 && WALL_CHARS.indexOf(grid[yy2 - dd][xx2].charAt(0)) >= 0) ||
                         (yy2 + dd < GRID_H && WALL_CHARS.indexOf(grid[yy2 + dd][xx2].charAt(0)) >= 0) ||
                         (xx2 - dd >= 0 && WALL_CHARS.indexOf(grid[yy2][xx2 - dd].charAt(0)) >= 0) ||
                         (xx2 + dd < GRID_W && WALL_CHARS.indexOf(grid[yy2][xx2 + dd].charAt(0)) >= 0))
                     {
                        dHit = true;
                     }
                  }
                  if (dHit) backSpots.push([xx2, yy2]);
               }
            }
            tries = 0;
            placed = 0;
            while (placed < nBack && tries < 40 && backSpots.length > 0)
            {
               tries++;
               var bsi:int = int(rnd() * backSpots.length);
               var bspot:Array = backSpots.splice(bsi, 1)[0] as Array;
               var bid:String = (rnd() < 0.6)
                  ? String(mainBacks[int(rnd() * mainBacks.length)])
                  : String(backs[int(rnd() * backs.length)]);
               lastBacks.push([bid, int(bspot[0]), int(bspot[1])]);
               placed++;
            }
            rectUsed.push(used);
         }

         // ---- 房间级放置（v5.4 修正：原版 0.99 player/房、3.48 敌标记/房，
         //      均为每房一份，不随 rect 重复） ----
         // player 出生点：随机挑一个 rect
         if (rects.length > 0)
         {
            var pr:int = int(rnd() * rects.length);
            var prect:Array = rects[pr] as Array;
            var pspot:Array = interiorSpot(grid, prect[0], prect[1], prect[2], prect[3],
                                           rectUsed[pr], "player");
            if (pspot != null)
            {
               lastObjs.push(["player", genCode(), pspot[0], pspot[1]]);
               rectUsed[pr][pspot[1] + "," + pspot[0]] = true;
               playerPos = pspot;
            }
         }
         // 敌人出生标记：enl1/enl2/enf1 走原版 ups 桶（AllData tip=up, tipn=1/2/3），
         // 实际生成数量由 Location.kolEn、敌人类型由 Land.tipEnemy（land biom）决定；
         // 按语料配比分层名额（随机舍入），距 player >=3 格防开局即战
         // 3-4 基准随个性密度缩放（空房 0 个——原版 204/658 房无敌标记，
         // 安静房也是设计）；quota 随机舍入后实际 2-5
         var nEn:int = emptyRoom ? 0 : int((3 + int(rnd() * 2)) * density + 0.5);
         var enR:Array = EN_RATE[Math.min(bIdx, 3)] as Array;
         var enTot:int = 0;
         for (k = 0; k < 3; k++) enTot += int(enR[k]);
         var q1:int = int(nEn * enR[0] / enTot + rnd());
         var q2:int = int(nEn * enR[1] / enTot + rnd());
         var q3:int = nEn - q1 - q2;
         if (q3 < 0) q3 = 0;
         var enQuota:Array = [q1, q2, q3];
         for (k = 0; k < 3; k++)
         {
            var enId:String = EN_IDS[k];
            tries = 0;
            placed = 0;
            while (placed < int(enQuota[k]) && tries < 40 && rects.length > 0)
            {
               tries++;
               var er:int = int(rnd() * rects.length);
               var erect:Array = rects[er] as Array;
               var ef:Array = objFoot(enId);
               var ep:Array = null;
               for (var et:int = 0; et < 30 && ep == null; et++)
               {
                  var ex:int = erect[0] + 2 + int(rnd() * Math.max(1, erect[2] - 4 - ef[0]));
                  var ey:int = erect[1] + 2 + int(rnd() * Math.max(1, erect[3] - 4 - ef[1]));
                  if (ex < 0 || ey < 0 || ex >= GRID_W || ey >= GRID_H) continue;
                  var eused:Object = rectUsed[er];
                  var clash:Boolean = false;
                  for (var edy:int = 0; edy < ef[1]; edy++)
                  {
                     for (var edx:int = 0; edx < ef[0]; edx++)
                     {
                        if (ey + edy >= GRID_H || ex + edx >= GRID_W ||
                            !isOpenCell(grid[ey + edy][ex + edx]) || eused[(ey + edy) + "," + (ex + edx)] == true)
                        {
                           clash = true;
                           break;
                        }
                     }
                     if (clash) break;
                  }
                  if (clash) continue;
                  if (playerPos != null && Math.abs(ex - playerPos[0]) + Math.abs(ey - playerPos[1]) < 3) continue;
                  ep = [ex, ey];
               }
               if (ep == null) continue;
               lastObjs.push([enId, genCode(), ep[0], ep[1]]);
               for (edy = 0; edy < ef[1]; edy++)
               {
                  for (edx = 0; edx < ef[0]; edx++)
                  {
                     rectUsed[er][(ep[1] + edy) + "," + (ep[0] + edx)] = true;
                  }
               }
               placed++;
            }
         }
      }

      /** 物件占地格 [size(宽), wid(高)]（AllData 实测） */
      private static function objFoot(id:String):Array
      {
         switch (id)
         {
            case "case": case "ammobox": case "explbox": case "lov": case "enl1": case "enf1":
            case "wallcab": case "medbox": case "trash": return [1, 1];
            case "checkpoint": return [2, 3];
            case "couch": case "table2": case "table": case "chest": return [2, 1];
            case "hatch2": return [2, 1];
            case "bed": return [4, 1];
            case "mcrate2": case "box": case "woodbox": case "player": case "enl2": return [2, 2];
            case "radbarrel": case "filecab": case "door1": return [1, 2];
            case "locker": case "bookcase": return [2, 3];
            case "stdoor": return [1, 3];
            default: return [1, 1];
         }
      }

      /** 开放格判定（v6.0 原版行为实证）：首字符 '_' 即开放；`_X` 拉丁后缀全部
       *  可站立（原版 20198 obj 各字符 200-800 个）；排除水 `_*`、横梁 `_-`、
       *  Z 层 `,;:`、西里尔（原版 obj 不站） */
      private static function isOpenCell(cell:String):Boolean
      {
         if (cell == null || cell.charAt(0) != "_") return false;
         if (cell.length > 1)
         {
            var c2:String = cell.charAt(1);
            if (c2 == "*" || c2 == "-" || c2 == "," || c2 == ";" || c2 == ":") return false;
            if (c2 < "A" || c2 > "Z") return false;
         }
         return true;
      }

      /** 全格占用标记（v5.9：防 1×1 物件叠上多格物件的覆盖格——视觉穿模） */
      private static function markUsed(used:Object, x:int, y:int, id:String):void
      {
         var foot:Array = objFoot(id);
         for (var dy:int = 0; dy < foot[1]; dy++)
         {
            for (var dx:int = 0; dx < foot[0]; dx++)
            {
               used[(y + dy) + "," + (x + dx)] = true;
            }
         }
      }

      /** 占地格全开放校验（防悬空/穿墙） */
      private function footOk(grid:Array, x:int, y:int, size:int, wid:int):Boolean
      {
         for (var dy:int = 0; dy < wid; dy++)
         {
            for (var dx:int = 0; dx < size; dx++)
            {
               var xx:int = x + dx;
               var yy:int = y + dy;
               if (xx < 0 || yy < 0 || xx >= GRID_W || yy >= GRID_H) return false;
               if (!isOpenCell(grid[yy][xx])) return false;
            }
         }
         return true;
      }

      /** 找房间边界上与走廊相邻的开放格（门洞位） */
      private function findJunction(grid:Array, cwx:int, cwy:int, cw:int, ch2:int):Array
      {
         var y:int, x:int;
         // 上/下边
         for (x = cwx; x < cwx + cw; x++)
         {
            if (cellJunction(grid, cwy, x, cwx, cwy, cw, ch2)) return [x, cwy];
            if (cellJunction(grid, cwy + ch2 - 1, x, cwx, cwy, cw, ch2)) return [x, cwy + ch2 - 1];
         }
         // 左/右边
         for (y = cwy; y < cwy + ch2; y++)
         {
            if (cellJunction(grid, y, cwx, cwx, cwy, cw, ch2)) return [cwx, y];
            if (cellJunction(grid, y, cwx + cw - 1, cwx, cwy, cw, ch2)) return [cwx + cw - 1, y];
         }
         return null;
      }

      private function cellJunction(grid:Array, y:int, x:int, cwx:int, cwy:int, cw:int, ch2:int):Boolean
      {
         if (y < 1 || y >= GRID_H - 1 || x < 1 || x >= GRID_W - 1) return false;
         if (!isOpenCell(grid[y][x])) return false;
         var inside:Boolean = (y > cwy && y < cwy + ch2 - 1 && x > cwx && x < cwx + cw - 1);
         if (inside) return false;
         // 邻格在房间外且开放 → 门洞
         var nb:Array = [[y - 1, x], [y + 1, x], [y, x - 1], [y, x + 1]];
         for (var k:int = 0; k < 4; k++)
         {
            var ny:int = nb[k][0];
            var nx:int = nb[k][1];
            if (ny < 0 || ny >= GRID_H || nx < 0 || nx >= GRID_W) continue;
            var out:Boolean = !(ny >= cwy && ny < cwy + ch2 && nx >= cwx && nx < cwx + cw);
            if (out && isOpenCell(grid[ny][nx])) return true;
         }
         return false;
      }

      /** 贴墙位：房间边内 1 格、占地格全开放、未占用 */
      private function wallSpot(grid:Array, cwx:int, cwy:int, cw:int, ch2:int, used:Object, id:String):Array
      {
         var foot:Array = objFoot(id);
         var fs:int = foot[0];
         var fw:int = foot[1];
         for (var t:int = 0; t < 25; t++)
         {
            var side:int = int(rnd() * 4);
            var x:int, y:int;
            if (side == 0) { y = cwy + 1; x = cwx + 1 + int(rnd() * Math.max(1, cw - 2 - fs)); }
            else if (side == 1) { y = cwy + ch2 - 2; x = cwx + 1 + int(rnd() * Math.max(1, cw - 2 - fs)); }
            else if (side == 2) { x = cwx + 1; y = cwy + 1 + int(rnd() * Math.max(1, ch2 - 2 - fw)); }
            else { x = cwx + cw - 2; y = cwy + 1 + int(rnd() * Math.max(1, ch2 - 2 - fw)); }
            if (x < 0 || y < 0 || x >= GRID_W || y >= GRID_H) continue;
            if (isOpenCell(grid[y][x]) && used[y + "," + x] != true && footOk(grid, x, y, fs, fw)) return [x, y];
         }
         return null;
      }

      /** 室内位：离房间边 >=2、占地格全开放、未占用 */
      private function interiorSpot(grid:Array, cwx:int, cwy:int, cw:int, ch2:int, used:Object, id:String):Array
      {
         var foot:Array = objFoot(id);
         var fs:int = foot[0];
         var fw:int = foot[1];
         for (var t:int = 0; t < 40; t++)
         {
            var x:int = cwx + 2 + int(rnd() * Math.max(1, cw - 4 - fs));
            var y:int = cwy + 2 + int(rnd() * Math.max(1, ch2 - 4 - fw));
            if (x < 0 || y < 0 || x >= GRID_W || y >= GRID_H) continue;
            if (isOpenCell(grid[y][x]) && used[y + "," + x] != true && footOk(grid, x, y, fs, fw)) return [x, y];
         }
         return null;
      }

      /** 随机 16 位物件码（同原版 code 格式） */
      private function genCode():String
      {
         var chars:String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
         var s:String = "";
         for (var i:int = 0; i < 16; i++)
         {
            s += chars.charAt(int(rnd() * chars.length));
         }
         return s;
      }

      /** 2 宽 L 形走廊：最近开放格（排除 ex 矩形）-> (tx,ty)（目标=房间中心/缺口）
       * 排除自身矩形是必须的：否则最近格=目标自身，走廊不挖 → 房间孤立 */
      private function linkL2(grid:Array, pat:Object, patArr:Array, tx:int, ty:int, exX0:int, exY0:int, exX1:int, exY1:int):void
      {
         if (patArr.length == 0) return;
         var bi:int = 0;
         var bd:Number = 1e9;
         for (var k:int = 0; k < patArr.length; k++)
         {
            var cy0:int = patArr[k][0];
            var cx0:int = patArr[k][1];
            if (cx0 >= exX0 && cx0 <= exX1 && cy0 >= exY0 && cy0 <= exY1) continue;
            var dy:Number = cy0 - ty;
            var dx:Number = cx0 - tx;
            var d:Number = dy * dy + dx * dx;
            if (d < bd) { bd = d; bi = k; }
         }
         var y:int = patArr[bi][0];
         var x:int = patArr[bi][1];
         var st:int = 0;
         while ((y != ty || x != tx) && st < 120)
         {
            st++;
            for (var k2:int = 0; k2 < 2; k2++)
            {
               if (x + k2 < GRID_W)
               {
                  if (WALL_CHARS.indexOf(grid[y][x + k2].charAt(0)) >= 0) grid[y][x + k2] = "_";
                  if (pat[y + "," + (x + k2)] != true)
                  {
                     pat[y + "," + (x + k2)] = true;
                     patArr.push([y, x + k2]);
                  }
               }
            }
            var dx2:int = tx - x;
            var dy2:int = ty - y;
            if (Math.abs(dx2) >= Math.abs(dy2)) x += dx2 > 0 ? 1 : -1;
            else y += dy2 > 0 ? 1 : -1;
            y = Math.max(1, Math.min(GRID_H - 2, y));
            x = Math.max(1, Math.min(GRID_W - 2, x));
         }
         for (k2 = 0; k2 < 2; k2++)
         {
            if (x + k2 < GRID_W)
            {
               if (WALL_CHARS.indexOf(grid[y][x + k2].charAt(0)) >= 0) grid[y][x + k2] = "_";
               if (pat[y + "," + (x + k2)] != true)
               {
                  pat[y + "," + (x + k2)] = true;
                  patArr.push([y, x + k2]);
               }
            }
         }
      }

      /** 装饰表过滤：仅保留安全地板纹理（排除 *水 / K网格(框架地板) /
       *  -横梁 / 西里尔台阶楼梯横梁） */
      private function safeDecor(decor:Array):Array
      {
         // v6.0 白名单放宽到拉丁 A-Z（原版 obj 脚下实证全系可站）；仍排除
         // 水/横梁/西里尔/Z 层
         var out:Array = [];
         if (decor == null) return out;
         for (var k:int = 0; k < decor.length; k++)
         {
            var ch:String = String(decor[k][0]);
            if (ch >= "A" && ch <= "Z") out.push(decor[k]);
         }
         return out;
      }

      private function finishStripRoom(grid:Array):void
      {
         grid[GY][0] = "_";
         grid[GY][GRID_W - 1] = "_";
         grid[0][GX1] = "_";
         grid[0][GX2] = "_";
         grid[GRID_H - 1][GX1] = "_";
         grid[GRID_H - 1][GX2] = "_";
         repairConnectivity(grid);
      }

      /** 连通修复：从 6 缺口 BFS；未连通开放组件 <16 格填墙，否则挖 2 宽 L 连廊 */
      private function repairConnectivity(grid:Array):void
      {
         var j:int;
         var i:int;
         var seen:Array = [];
         for (j = 0; j < GRID_H; j++)
         {
            seen[j] = [];
            for (i = 0; i < GRID_W; i++) seen[j][i] = false;
         }
         var mainOpen:Array = [];
         var qy:Array = [];
         var qx:Array = [];
         var starts:Array = [[GY, 0], [GY, GRID_W - 1], [0, GX1], [0, GX2], [GRID_H - 1, GX1], [GRID_H - 1, GX2]];
         for (var s:int = 0; s < starts.length; s++)
         {
            var sy:int = starts[s][0];
            var sx:int = starts[s][1];
            if (!seen[sy][sx] && WALL_CHARS.indexOf(grid[sy][sx].charAt(0)) < 0)
            {
               seen[sy][sx] = true;
               qy.push(sy);
               qx.push(sx);
               mainOpen.push([sy, sx]);
            }
         }
         var head:int = 0;
         while (head < qx.length)
         {
            var cy:int = qy[head];
            var cx:int = qx[head];
            head++;
            if (cy > 0 && !seen[cy - 1][cx] && WALL_CHARS.indexOf(grid[cy - 1][cx].charAt(0)) < 0)
            {
               seen[cy - 1][cx] = true; qy.push(cy - 1); qx.push(cx); mainOpen.push([cy - 1, cx]);
            }
            if (cy < GRID_H - 1 && !seen[cy + 1][cx] && WALL_CHARS.indexOf(grid[cy + 1][cx].charAt(0)) < 0)
            {
               seen[cy + 1][cx] = true; qy.push(cy + 1); qx.push(cx); mainOpen.push([cy + 1, cx]);
            }
            if (cx > 0 && !seen[cy][cx - 1] && WALL_CHARS.indexOf(grid[cy][cx - 1].charAt(0)) < 0)
            {
               seen[cy][cx - 1] = true; qy.push(cy); qx.push(cx - 1); mainOpen.push([cy, cx - 1]);
            }
            if (cx < GRID_W - 1 && !seen[cy][cx + 1] && WALL_CHARS.indexOf(grid[cy][cx + 1].charAt(0)) < 0)
            {
               seen[cy][cx + 1] = true; qy.push(cy); qx.push(cx + 1); mainOpen.push([cy, cx + 1]);
            }
         }
         // 扫描未连通开放组件
         for (j = 0; j < GRID_H; j++)
         {
            for (i = 0; i < GRID_W; i++)
            {
               if (seen[j][i] || WALL_CHARS.indexOf(grid[j][i].charAt(0)) >= 0) continue;
               var comp:Array = [];
               var cqy:Array = [j];
               var cqx:Array = [i];
               seen[j][i] = true;
               var ch:int = 0;
               while (ch < cqx.length)
               {
                  var cy2:int = cqy[ch];
                  var cx2:int = cqx[ch];
                  ch++;
                  comp.push([cy2, cx2]);
                  if (cy2 > 0 && !seen[cy2 - 1][cx2] && WALL_CHARS.indexOf(grid[cy2 - 1][cx2].charAt(0)) < 0)
                  {
                     seen[cy2 - 1][cx2] = true; cqy.push(cy2 - 1); cqx.push(cx2);
                  }
                  if (cy2 < GRID_H - 1 && !seen[cy2 + 1][cx2] && WALL_CHARS.indexOf(grid[cy2 + 1][cx2].charAt(0)) < 0)
                  {
                     seen[cy2 + 1][cx2] = true; cqy.push(cy2 + 1); cqx.push(cx2);
                  }
                  if (cx2 > 0 && !seen[cy2][cx2 - 1] && WALL_CHARS.indexOf(grid[cy2][cx2 - 1].charAt(0)) < 0)
                  {
                     seen[cy2][cx2 - 1] = true; cqy.push(cy2); cqx.push(cx2 - 1);
                  }
                  if (cx2 < GRID_W - 1 && !seen[cy2][cx2 + 1] && WALL_CHARS.indexOf(grid[cy2][cx2 + 1].charAt(0)) < 0)
                  {
                     seen[cy2][cx2 + 1] = true; cqy.push(cy2); cqx.push(cx2 + 1);
                  }
               }
               // v5.5：阈值 16→6。小口袋多为通道残段/房间墙角，一律填墙会
               // 封死可看可用的通道（实机"通道被阻塞"观感来源之一）
               if (comp.length < 6)
               {
                  for (var ck:int = 0; ck < comp.length; ck++)
                  {
                     grid[comp[ck][0]][comp[ck][1]] = "C";
                  }
               }
               else
               {
                  carveConnector(grid, seen, comp, mainOpen);
               }
            }
         }
      }

      /** 组件最近格 -> 主网最近开放格：L 形 2 宽连廊 */
      private function carveConnector(grid:Array, seen:Array, comp:Array, mainOpen:Array):void
      {
         var bi:int = 0;
         var bm:int = 0;
         var bd:Number = 1e9;
         for (var a:int = 0; a < comp.length; a++)
         {
            for (var b:int = 0; b < mainOpen.length; b++)
            {
               var dy:Number = comp[a][0] - mainOpen[b][0];
               var dx:Number = comp[a][1] - mainOpen[b][1];
               var d:Number = dy * dy + dx * dx;
               if (d < bd) { bd = d; bi = a; bm = b; }
            }
         }
         var y0:int = comp[bi][0];
         var x0:int = comp[bi][1];
         var y1:int = mainOpen[bm][0];
         var x1:int = mainOpen[bm][1];
         // L 形：横段 + 竖段（2 宽），挖出的格标记 seen 防重复处理
         if (rnd() < 0.5)
         {
            carveH(grid, seen, x0, x1, y0, 2);
            carveV(grid, seen, y0, y1, x1, 2);
         }
         else
         {
            carveV(grid, seen, y0, y1, x0, 2);
            carveH(grid, seen, x0, x1, y1, 2);
         }
      }

      /** 横扫 w 宽（挖开放 + 标记 seen） */
      private function carveH(grid:Array, seen:Array, xa:int, xb:int, y:int, w:int):void
      {
         var lo:int = Math.min(xa, xb);
         var hi:int = Math.max(xa, xb);
         for (var x:int = lo; x <= hi; x++)
         {
            for (var dy:int = 0; dy < w; dy++)
            {
               var yy:int = y + dy;
               if (yy >= 0 && yy < GRID_H)
               {
                  grid[yy][x] = "_";
                  if (seen[yy] != null) seen[yy][x] = true;
               }
            }
         }
      }

      /** 竖扫 w 宽（挖开放 + 标记 seen） */
      private function carveV(grid:Array, seen:Array, ya:int, yb:int, x:int, w:int):void
      {
         var lo:int = Math.min(ya, yb);
         var hi:int = Math.max(ya, yb);
         for (var y:int = lo; y <= hi; y++)
         {
            for (var dx:int = 0; dx < w; dx++)
            {
               var xx:int = x + dx;
               if (xx >= 0 && xx < GRID_W)
               {
                  grid[y][xx] = "_";
                  if (seen[y] != null) seen[y][xx] = true;
               }
            }
         }
      }

      /** Voronoi 四区场（近区心低->开放，区界高->墙） */
      private function quadField():Array
      {
         var centers:Array = [[7, 7], [41, 7], [7, 18], [41, 18]];
         var f:Array = [];
         for (var y:int = 0; y < GRID_H; y++)
         {
            f[y] = [];
            for (var x:int = 0; x < GRID_W; x++)
            {
               var ds:Array = [];
               for (var k:int = 0; k < centers.length; k++)
               {
                  ds.push(Math.sqrt((x - centers[k][0]) * (x - centers[k][0]) + (y - centers[k][1]) * (y - centers[k][1])));
               }
               ds.sort(Array.NUMERIC);
               f[y][x] = ds[0] + 0.7 * ds[1];
            }
         }
         return f;
      }
      
      /** 二分阈值：f>=th 占 ratio（对聚集分布鲁棒，免排序） */
      private function threshWall(f:Array, ratio:Number):Number
      {
         var lo:Number = 1e9;
         var hi:Number = -1e9;
         var count:int = 0;
         for (var j:int = 0; j < GRID_H; j++)
         {
            for (var i:int = 0; i < GRID_W; i++)
            {
               if (f[j][i] < 0) continue;
               count++;
               if (f[j][i] < lo) lo = f[j][i];
               if (f[j][i] > hi) hi = f[j][i];
            }
         }
         if (count == 0) return 0.5;
         for (var it:int = 0; it < 14; it++)
         {
            var mid:Number = (lo + hi) / 2;
            var c3:int = 0;
            for (j = 0; j < GRID_H; j++)
            {
               for (i = 0; i < GRID_W; i++)
               {
                  if (f[j][i] >= 0 && f[j][i] >= mid) c3++;
               }
            }
            if (c3 / count > ratio) lo = mid;
            else hi = mid;
         }
         return (lo + hi) / 2;
      }
      
      private function pickWeighted(tbl:Array):String
      {
         var tot:int = 0;
         for (var k:int = 0; k < tbl.length; k++)
         {
            tot += int(tbl[k][1]);
         }
         var r:int = int(rnd() * tot);
         var acc:int = 0;
         for (k = 0; k < tbl.length; k++)
         {
            acc += int(tbl[k][1]);
            if (r < acc) return String(tbl[k][0]);
         }
         return String(tbl[0][0]);
      }
      
      /** 统计墙格数 */
      public function wallCount(grid:Array):int
      {
         var n:int = 0;
         for (var j:int = 0; j < grid.length; j++)
         {
            for (var i:int = 0; i < grid[j].length; i++)
            {
               if (WALL_CHARS.indexOf(String(grid[j][i]).charAt(0)) >= 0) n++;
            }
         }
         return n;
      }
      
      private function wallChar(wallTbl:Array):String
      {
         return pickWeighted(wallTbl);
      }
      
      /** 边界/缺口 + 装饰掩体层 + BFS */
      private function applyBoundaryAndDecor(grid:Array, decor:Array, wallTbl:Array, rtype:String = null):void
      {
         for (var i:int = 0; i < GRID_W; i++)
         {
            grid[0][i] = "A";
            grid[GRID_H - 1][i] = "A";
         }
         for (var j:int = 0; j < GRID_H; j++)
         {
            grid[j][0] = "A";
            grid[j][GRID_W - 1] = "A";
         }
         grid[GY][0] = "_";
         grid[GY][GRID_W - 1] = "_";
         grid[0][GX1] = "_";
         grid[0][GX2] = "_";
         grid[GRID_H - 1][GX1] = "_";
         grid[GRID_H - 1][GX2] = "_";
         if (decor != null && decor.length > 0)
         {
            for (j = 1; j < GRID_H - 1; j++)
            {
               for (i = 1; i < GRID_W - 1; i++)
               {
                  if (grid[j][i] == "_" && rnd() < 0.16)
                  {
                     grid[j][i] = "_" + pickWeighted(decor);
                  }
               }
            }
         }
         for (var m:int = 0; m < 6; m++)
         {
            j = 2 + int(rnd() * (GRID_H - 4));
            i = 2 + int(rnd() * (GRID_W - 4));
            if (grid[j][i] == "_")
            {
               grid[j][i] = "_-";
            }
         }
         if (rtype == "quad")
         {
            quadGates(grid);
         }
         gapGuard(grid);
         bfsFill(grid);
      }
      
      /** v3.5 原版分区墙（语料实证：原版墙占比 0.15-0.36，墙=1-2 格厚的
       * 部分宽度横/竖分区带，带缺口；开放为底 + 边缘墙条 + 高密度装饰）。
       * 分区带锚定层高 {4,12,20} / 列 {8,24,40}（原版块层结构），
       * 缺口+两端边道保证区块连通 → 出口不会被堵。 */
      private function carveRooms(grid:Array, rtype:String, wallTbl:Array):void
      {
         var k:int, g:int, xx:int, yy:int, x:int, y:int;
         var nH:int = rtype == "hall" ? 2 : (rtype == "split" ? 5 : 3);
         var levels:Array = [4, 12, 20];
         for (k = 0; k < nH; k++)
         {
            y = int(levels[int(rnd() * 3)]) + int(rnd() * 3) - 1;
            y = Math.max(2, Math.min(GRID_H - 3, y));
            var wseg:int = 24 + int(rnd() * 21);          // 24-44
            var x0:int = 2 + int(rnd() * (GRID_W - wseg - 2));
            var thick:int = rnd() < 0.7 ? 1 : 2;
            var ng:int = 2 + int(rnd() * 3);              // 2-4 缺口
            var gaps:Object = {};
            for (g = 0; g < ng; g++) gaps[x0 + int(rnd() * wseg)] = true;
            for (xx = x0 + 2; xx < x0 + wseg - 2; xx++)   // 两端留 2 格边道
            {
               if (gaps[xx] != null) continue;
               for (yy = y; yy < Math.min(y + thick, GRID_H - 1); yy++)
               {
                  if (grid[yy][xx] == "_") grid[yy][xx] = wallChar(wallTbl);
               }
            }
         }
         var nV:int = rtype == "hall" ? 0 : (rtype == "split" ? 3 : (rtype == "l" ? 2 : 1));
         var cols:Array = [8, 24, 40];
         for (k = 0; k < nV; k++)
         {
            x = int(cols[int(rnd() * 3)]) + int(rnd() * 3) - 1;
            x = Math.max(2, Math.min(GRID_W - 3, x));
            var hseg:int = 6 + int(rnd() * 13);           // 6-18
            var y0:int = 2 + int(rnd() * (GRID_H - hseg - 2));
            var thick2:int = rnd() < 0.8 ? 1 : 2;
            var ng2:int = 1 + int(rnd() * 2);             // 1-2 缺口
            var gaps2:Object = {};
            for (g = 0; g < ng2; g++) gaps2[y0 + int(rnd() * hseg)] = true;
            for (yy = y0 + 1; yy < y0 + hseg - 1; yy++)   // 两端留 1 格通道
            {
               if (gaps2[yy] != null) continue;
               for (xx = x; xx < Math.min(x + thick2, GRID_W - 1); xx++)
               {
                  if (grid[yy][xx] == "_") grid[yy][xx] = wallChar(wallTbl);
               }
            }
         }
         // 左右边缘墙条（带缺口，非整高）
         for (var si:int = 0; si < 2; si++)
         {
            var side:int = si == 0 ? 1 : GRID_W - 2;
            for (y = 2; y < GRID_H - 2; y++)
            {
               if (rnd() < 0.75 && Math.abs(y - GY) > 2 && grid[y][side] == "_")
               {
                  grid[y][side] = wallChar(wallTbl);
               }
            }
         }
         // 掩体墩 2-5 个（实心块，射击掩体）
         var nubN:int = 2 + int(rnd() * 4);
         for (k = 0; k < nubN; k++)
         {
            var ny:int = 2 + int(rnd() * (GRID_H - 4));
            var nx:int = 2 + int(rnd() * (GRID_W - 4));
            if (grid[ny][nx] == "_") grid[ny][nx] = wallChar(wallTbl);
         }
      }
      
      /** v3.1 材质带：2x4 大区主字符（区内 85% 同色） → 墙整体统一 */
      /** 材质带。v6.0：传 zones 时按区×层取主材质（区/层间对比），每层
       *  60% 概率出 1 个区内对比材质补丁区（矩形）；null 则走旧 2×4 均匀 zone */
      private function materialBands(grid:Array, wallTbl:Array, zones:Array = null):void
      {
         if (zones != null)
         {
            var zi:int, li:int;
            var layerMain:Array = [];
            var patches:Array = [];
            for (zi = 0; zi < zones.length; zi++)
            {
               var zl:Array = zones[zi].layers;
               for (li = 0; li < zl.length; li++) layerMain.push(pickWeighted(wallTbl));
               for (li = 0; li < zl.length; li++)
               {
                  if (rnd() >= 0.6) continue;
                  var lt:int = zl[li][0];
                  var lb:int = zl[li][1];
                  var pw2:int = 6 + int(rnd() * 8);
                  var px2:int = zones[zi].x0 + int(rnd() * Math.max(1, zones[zi].x1 - zones[zi].x0 - pw2));
                  var ph3:int = Math.min(lb - lt + 1, 3 + int(rnd() * 3));
                  var py3:int = lt + int(rnd() * Math.max(1, lb - lt - ph3 + 1));
                  patches.push([px2, py3, pw2, ph3, pickWeighted(wallTbl), zi, li]);
               }
            }
            for (var j:int = 0; j < GRID_H; j++)
            {
               for (var i:int = 0; i < GRID_W; i++)
               {
                  if (WALL_CHARS.indexOf(grid[j][i].charAt(0)) >= 0)
                  {
                     // 找所在区×层
                     var ziHit:int = -1, liHit:int = -1;
                     for (zi = 0; zi < zones.length; zi++)
                     {
                        if (i < zones[zi].x0 || i > zones[zi].x1) continue;
                        var zl:Array = zones[zi].layers;
                        for (li = 0; li < zl.length; li++)
                        {
                           if (j >= zl[li][0] && j <= zl[li][1])
                           {
                              var base:int = 0;
                              for (var qi:int = 0; qi < zi; qi++) base += zones[qi].layers.length;
                              ziHit = zi;
                              liHit = base + li;
                           }
                        }
                     }
                     if (ziHit < 0) continue;
                     var ch2:String = (rnd() < 0.90) ? String(layerMain[liHit]) : pickWeighted(wallTbl);
                     for (var pk:int = 0; pk < patches.length; pk++)
                     {
                        if (j >= patches[pk][1] && j < patches[pk][1] + patches[pk][3] &&
                            i >= patches[pk][0] && i < patches[pk][0] + patches[pk][2])
                        {
                           ch2 = (rnd() < 0.85) ? String(patches[pk][4]) : ch2;
                        }
                     }
                     grid[j][i] = ch2;
                  }
               }
            }
            return;
         }
         var zone:Array = [];
         for (var zy:int = 0; zy < 2; zy++)
         {
            zone[zy] = [];
            for (var zx:int = 0; zx < 4; zx++)
            {
               zone[zy][zx] = (rnd() < 0.6 ? wallTbl[0][0] : pickWeighted(wallTbl));
            }
         }
         for (j = 0; j < GRID_H; j++)
         {
            for (i = 0; i < GRID_W; i++)
            {
               if (WALL_CHARS.indexOf(grid[j][i].charAt(0)) >= 0)
               {
                  var main2:String = String(zone[Math.min(int(j / 13), 1)][Math.min(int(i / 12), 3)]);
                  grid[j][i] = (rnd() < 0.90) ? main2 : pickWeighted(wallTbl);
               }
            }
         }
      }
      
      /** v3.1 缺口保护：缺口 3x3 邻域 + 向心隧道强制开放（通道不堵） */
      private function gapGuard(grid:Array):void
      {
         var j:int;
         var i:int;
         for (j = Math.max(0, GY - 1); j < Math.min(GRID_H, GY + 2); j++)
         {
            for (i = 0; i < 3; i++) { if (grid[j][i] == "C") grid[j][i] = "_"; }
            for (i = GRID_W - 3; i < GRID_W; i++) { if (grid[j][i] == "C") grid[j][i] = "_"; }
            for (i = 3; i < 8; i++) { if (grid[j][i] == "C") grid[j][i] = "_"; }
            for (i = GRID_W - 8; i < GRID_W - 3; i++) { if (grid[j][i] == "C") grid[j][i] = "_"; }
         }
         for (i = Math.max(0, GX1 - 1); i < Math.min(GRID_W, GX2 + 2); i++)
         {
            for (j = 0; j < 2; j++) { if (grid[j][i] == "C") grid[j][i] = "_"; }
            for (j = GRID_H - 2; j < GRID_H; j++) { if (grid[j][i] == "C") grid[j][i] = "_"; }
            for (j = 2; j < 7; j++) { if (grid[j][i] == "C") grid[j][i] = "_"; }
            for (j = GRID_H - 7; j < GRID_H - 2; j++) { if (grid[j][i] == "C") grid[j][i] = "_"; }
         }
      }
      
      /** v3.1 quad 区门：中央十字挖通四区 */
      private function quadGates(grid:Array):void
      {
         for (var y:int = 11; y <= 13; y++)
         {
            for (var x:int = 22; x <= 25; x++)
            {
               if (grid[y][x] == "C") grid[y][x] = "_";
            }
         }
         for (x = 21; x <= 26; x++)
         {
            for (y = 11; y <= 13; y += 2)
            {
               if (grid[y][x] == "C") grid[y][x] = "_";
            }
         }
      }

      private function pickDecor(decor:Array, total:int):String
      {
         var r:int = int(rnd() * total);
         var acc:int = 0;
         for (var k:int = 0; k < decor.length; k++)
         {
            acc += int(decor[k][1]);
            if (r < acc)
            {
               return String(decor[k][0]);
            }
         }
         return "-";
      }
      
      private function placeBlocks(grid:Array, regions:Array, blocks:Array, count:int):void
      {
         var placed:int = 0;
         var tries:int = 0;
         while (placed < count && tries < 200)
         {
            tries++;
            var rg:Array = regions[int(rnd() * regions.length)] as Array;
            var x0:int = rg[0];
            var x1:int = rg[1];
            var y0:int = rg[2];
            var y1:int = rg[3];
            var bx:int = x0 + int(rnd() * (Math.max(x0, x1 - BLOCK_W) - x0 + 1));
            var by:int = y0 + int(rnd() * (Math.max(y0, y1 - BLOCK_H) - y0 + 1));
            if (bx + BLOCK_W - 1 > x1) bx = x1 - BLOCK_W + 1;
            if (by + BLOCK_H - 1 > y1) by = y1 - BLOCK_H + 1;
            var ok:Boolean = true;
            for (var dj:int = -1; dj <= BLOCK_H; dj++)
            {
               for (var di:int = -1; di <= BLOCK_W; di++)
               {
                  var ty:int = by + dj;
                  var tx:int = bx + di;
                  if (ty >= 0 && ty < GRID_H && tx >= 0 && tx < GRID_W && grid[ty][tx] != "_")
                  {
                     ok = false;
                     break;
                  }
               }
               if (!ok) break;
            }
            if (!ok) continue;
            var blk:Array = blocks[int(rnd() * blocks.length)] as Array;
            for (dj = 0; dj < BLOCK_H; dj++)
            {
               var brow:Array = String(blk[dj]).split("|");
               for (di = 0; di < BLOCK_W; di++)
               {
                  var code:String = String(brow[di]);
                  code = code.split(" ").join("");
                  if (code.length > 0)
                  {
                     grid[by + dj][bx + di] = code;
                  }
               }
            }
            placed++;
         }
      }
      
      private function bfsFill(grid:Array):void
      {
         var seen:Object = {};
         var qx:Array = [];
         var qy:Array = [];
         var starts:Array = [[GY, 0], [GY, GRID_W - 1], [0, GX1], [0, GX2], [GRID_H - 1, GX1], [GRID_H - 1, GX2]];
         for (var sI:int = 0; sI < starts.length; sI++)
         {
            var sy:int = starts[sI][0];
            var sx:int = starts[sI][1];
            if (WALL_CHARS.indexOf(grid[sy][sx].charAt(0)) < 0)
            {
               seen[sy * GRID_W + sx] = 1;
               qy.push(sy);
               qx.push(sx);
            }
         }
         var head:int = 0;
         var dirs:Array = [[1, 0], [-1, 0], [0, 1], [0, -1]];
         while (head < qx.length)
         {
            var cy:int = qy[head];
            var cx:int = qx[head];
            head++;
            for (var dd:int = 0; dd < 4; dd++)
            {
               var ny:int = cy + dirs[dd][0];
               var nx:int = cx + dirs[dd][1];
               if (ny < 0 || ny >= GRID_H || nx < 0 || nx >= GRID_W) continue;
               var key:int = ny * GRID_W + nx;
               if (seen[key] != null) continue;
               if (WALL_CHARS.indexOf(grid[ny][nx].charAt(0)) >= 0) continue;
               seen[key] = 1;
               qy.push(ny);
               qx.push(nx);
            }
         }
         for (var j:int = 0; j < GRID_H; j++)
         {
            for (var i:int = 0; i < GRID_W; i++)
            {
               if (WALL_CHARS.indexOf(grid[j][i].charAt(0)) < 0 && seen[j * GRID_W + i] == null)
               {
                  grid[j][i] = "C";
               }
            }
         }
      }
      
      /** 合成房预检：行数/列数/字符/options 全检（与 Tile.dec 解析一致） */
      public static function validateRoom(room:XML):Boolean
      {
         try
         {
            var rows:XMLList = room.a;
            if (rows.length() != GRID_H) return false;
            var j:int = 0;
            while (j < GRID_H)
            {
               var cols:Array = String(rows[j]).split(".");
               if (cols.length != GRID_W) return false;
               var i:int = 0;
               while (i < GRID_W)
               {
                  var code:String = String(cols[i]);
                  if (code.length == 0) return false;
                  if (FCHARS.indexOf(code.charAt(0)) < 0) return false;
                  var k:int = 1;
                  while (k < code.length)
                  {
                     if (OCHARS.indexOf(code.charAt(k)) < 0) return false;
                     k++;
                  }
                  i++;
               }
               j++;
            }
            return room.options.length() > 0;
         }
         catch (e:*)
         {
            return false;
         }
         return false;
      }
   }
}