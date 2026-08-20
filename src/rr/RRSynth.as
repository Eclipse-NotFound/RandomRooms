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
            f = valueNoise();
         }
         else if (rtype == "quad")
         {
            f = quadField();
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
         
         // 二分阈值 -> 墙（材质场）
         var th:Number = threshWall(f, wallRatio(rtype));
         for (j = 0; j < GRID_H; j++)
         {
            for (i = 0; i < GRID_W; i++)
            {
               var v:Number = f[j][i];
               if (v >= 0 && v >= th)
               {
                  grid[j][i] = wallChar(wallTbl);
               }
            }
         }
         debugStages.push(["thresh th=" + th.toFixed(4), wallCount(grid)]);
         pathCells = [];
         carveRooms(grid, rtype);
         debugStages.push(["carve", wallCount(grid)]);
         thinWalls(grid);
         debugStages.push(["thin", wallCount(grid)]);
         materialBands(grid, wallTbl);
         debugStages.push(["material", wallCount(grid)]);
         applyBoundaryAndDecor(grid, decor, wallTbl, rtype);
         debugStages.push(["final", wallCount(grid)]);
         return grid;
      }
      
      /** 值噪声场（低分辨率双线性插值） */
      private function valueNoise():Array
      {
         var cw:int = 6;
         var ch:int = 5;
         var gw:int = int((GRID_W + cw - 1) / cw) + 1;
         var gh:int = int((GRID_H + ch - 1) / ch) + 1;
         var g:Array = [];
         for (var gy:int = 0; gy < gh; gy++)
         {
            g[gy] = [];
            for (var gx:int = 0; gx < gw; gx++)
            {
               g[gy][gx] = rnd();
            }
         }
         var f:Array = [];
         for (var y:int = 0; y < GRID_H; y++)
         {
            f[y] = [];
            for (var x:int = 0; x < GRID_W; x++)
            {
               var fx:Number = x / cw;
               var fy:Number = y / ch;
               var x0:int = int(fx);
               var y0:int = int(fy);
               var dx:Number = fx - x0;
               var dy:Number = fy - y0;
               var x1:int = Math.min(x0 + 1, gw - 1);
               var y1:int = Math.min(y0 + 1, gh - 1);
               var a:Number = g[y0][x0];
               var b:Number = g[y0][x1];
               var c2:Number = g[y1][x0];
               var dd:Number = g[y1][x1];
               f[y][x] = (a * (1 - dx) + b * dx) * (1 - dy) + (c2 * (1 - dx) + dd * dx) * dy;
            }
         }
         return f;
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
      
      private function wallRatio(rtype:String):Number
      {
         switch (rtype)
         {
            case "hall": return 0.23;
            case "quad": return 0.22;
            case "l": return 0.25;
            case "split": return 0.30;
            default: return 0.26;
         }
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
                  if (grid[j][i] == "_" && rnd() < 0.07)
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
      
      /** v3.2 有机房间-走廊：波浪主廊 + 缺口纵连 + 随机腔室（无固定直线模板）
       * 取代 v3.1 固定直线 roadWalls（旧模板：corridor=双竖墙分三区 / hall=上下双横墙） */
      private function carveRooms(grid:Array, rtype:String):void
      {
         var x:int, y:int, yy:int, k:int;
         // 参数集（每次掷随机 -> 每次形态不同）
         var nCham:int;
         var plaza:Boolean = false;
         var vWander:Number = 4;          // 缺口纵连的横漂幅度
         switch (rtype)
         {
            case "hall":
               nCham = 2 + int(rnd() * 2); plaza = true; break;
            case "l":
               nCham = 2 + int(rnd() * 2); vWander = 9; break;
            case "split":
               nCham = 3 + int(rnd() * 3); break;
            default: // corridor
               nCham = 1 + int(rnd() * 2); break;
         }

         // 1) 主波浪走廊：左<->右，两端 sin 包络归零稳住缺口 GY，行间缓变保连续
         var A:Number = 1.0 + rnd() * 2.4;
         var kk:Number = 0.18 + rnd() * 0.4;
         var ph:Number = rnd() * 6.283;
         var cyPrev:Number = GY;
         for (x = 1; x < GRID_W - 1; x++)
         {
            var env:Number = Math.sin(Math.PI * x / (GRID_W - 1));
            var target:Number = GY + A * env * Math.sin(kk * x + ph) + (rnd() - 0.5) * 1.2;
            if (target - cyPrev > 1.2) target = cyPrev + 1.2;
            else if (target - cyPrev < -1.2) target = cyPrev - 1.2;
            target = Math.max(4, Math.min(GRID_H - 5, target));
            cyPrev = target;
            for (yy = int(target) - 1; yy <= int(target) + 1; yy++)
            {
               if (yy >= 1 && yy < GRID_H - 1) carveCell(grid, yy, x);
            }
         }

         // 2) 上/下缺口纵连（列 23/24，轻微横漂）
         var cArr:Array = [23, 24];
         for (k = 0; k < cArr.length; k++)
         {
            var c:int = cArr[k];
            for (y = 2; y <= 11; y++)
            {
               var vcx:int = c + Math.round((rnd() - 0.5) * vWander);
               vcx = Math.max(3, Math.min(GRID_W - 4, vcx));
               carveCell(grid, y, vcx);
               carveCell(grid, y, Math.min(vcx + 1, GRID_W - 2));
            }
            for (y = 22; y >= 12; y--)
            {
               var vcx2:int = c + Math.round((rnd() - 0.5) * vWander);
               vcx2 = Math.max(3, Math.min(GRID_W - 4, vcx2));
               carveCell(grid, y, vcx2);
               carveCell(grid, y, Math.min(vcx2 + 1, GRID_W - 2));
            }
         }

         // 3) 中央广场（hall 专属大房间）
         if (plaza)
         {
            var px0:int = 9 + int(rnd() * 9);
            var py0:int = 5 + int(rnd() * 6);
            var pw:int = 18 + int(rnd() * 9);
            var ph2:int = 8 + int(rnd() * 5);
            for (y = py0; y < py0 + ph2 && y < GRID_H - 2; y++)
            {
               for (x = px0; x < px0 + pw && x < GRID_W - 2; x++)
               {
                  carveCell(grid, y, x);
               }
            }
         }

         // 4) 随机腔室（房间）+ 就近连廊
         for (k = 0; k < nCham; k++)
         {
            var cw:int = 5 + int(rnd() * 6);         // 5-10
            var ch3:int = 5 + int(rnd() * 5);        // 5-9
            var cwx:int = 2 + int(rnd() * (GRID_W - cw - 4));
            var cwy:int = 2 + int(rnd() * (GRID_H - ch3 - 4));
            for (y = cwy; y < cwy + ch3; y++)
            {
               for (x = cwx; x < cwx + cw; x++)
               {
                  carveCell(grid, y, x);
               }
            }
            connectChamber(grid, cwy + int(ch3 / 2), cwx + int(cw / 2));
         }

         // 通道宽度保护：确保任何 2 宽通道不被稀疏墙体残留堵死（留待 bfsFill 兜底）
      }

      /** 挖一格（_ 开放）并入连通细胞表 */
      private function carveCell(grid:Array, y:int, x:int):void
      {
         if (y < 0 || y >= GRID_H || x < 0 || x >= GRID_W) return;
         if (grid[y][x] != "_") grid[y][x] = "_";
         pathCells.push([y, x]);
      }

      /** 腔室中心 -> 最近走廊/连通细胞（曼哈顿逼近 2 宽） */
      private function connectChamber(grid:Array, cy0:int, cx0:int):void
      {
         if (pathCells.length == 0) return;
         var bi:int = 0;
         var bd:Number = 1e9;
         for (var k:int = 0; k < pathCells.length; k++)
         {
            var dy:Number = pathCells[k][0] - cy0;
            var dx:Number = pathCells[k][1] - cx0;
            var d:Number = dy * dy + dx * dx;
            if (d < bd) { bd = d; bi = k; }
         }
         var ty:int = pathCells[bi][0];
         var tx:int = pathCells[bi][1];
         var st:int = 0;
         while ((ty != cy0 || tx != cx0) && st < 90)
         {
            st++;
            carveCell(grid, ty, tx);
            carveCell(grid, ty, Math.min(tx + 1, GRID_W - 2));
            var px:int = cx0 > tx ? 1 : (cx0 < tx ? -1 : 0);
            var py:int = cy0 > ty ? 1 : (cy0 < ty ? -1 : 0);
            if (px == 0) ty += py;
            else if (py == 0) tx += px;
            else if (rnd() < 0.55) tx += px;
            else ty += py;
         }
      }
      
      /** v3.2 墙瘦化：8 邻墙>=7 挖 40% ×2 遍 → 厚块蚀成蜿蜒连续墙带
       * （旧 n8>=13 是死条件——8 邻最多 8，从不触发，墙一直维持厚块） */
      private function thinWalls(grid:Array):void
      {
         function n8(y:int, x:int):int
         {
            var n:int = 0;
            for (var dy:int = -1; dy <= 1; dy++)
            {
               for (var dx:int = -1; dx <= 1; dx++)
               {
                  if (dy == 0 && dx == 0) continue;
                  var yy:int = y + dy;
                  var xx:int = x + dx;
                  if (yy >= 0 && yy < GRID_H && xx >= 0 && xx < GRID_W && WALL_CHARS.indexOf(grid[yy][xx].charAt(0)) >= 0)
                  {
                     n++;
                  }
               }
            }
            return n;
         }
         for (var pass:int = 0; pass < 2; pass++)
         {
            for (var j:int = 3; j < GRID_H - 3; j++)
            {
               for (var i:int = 3; i < GRID_W - 3; i++)
               {
                  if (WALL_CHARS.indexOf(grid[j][i].charAt(0)) >= 0 && n8(j, i) >= 7 && rnd() < 0.40)
                  {
                     grid[j][i] = "_";
                  }
               }
            }
         }
      }
      
      /** v3.1 材质带：2x4 大区主字符（区内 85% 同色） → 墙整体统一 */
      private function materialBands(grid:Array, wallTbl:Array):void
      {
         var zone:Array = [];
         for (var zy:int = 0; zy < 2; zy++)
         {
            zone[zy] = [];
            for (var zx:int = 0; zx < 4; zx++)
            {
               zone[zy][zx] = (rnd() < 0.6 ? wallTbl[0][0] : pickWeighted(wallTbl));
            }
         }
         for (var j:int = 0; j < GRID_H; j++)
         {
            for (var i:int = 0; i < GRID_W; i++)
            {
               if (WALL_CHARS.indexOf(grid[j][i].charAt(0)) >= 0)
               {
                  var main:String = String(zone[Math.min(int(j / 13), 1)][Math.min(int(i / 12), 3)]);
                  grid[j][i] = (rnd() < 0.85) ? main : pickWeighted(wallTbl);
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