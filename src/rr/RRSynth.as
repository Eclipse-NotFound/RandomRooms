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
            // v3.5 原版分区墙：开放为底（网格已是 _），薄分区墙带+缺口
            // （原版语料实证：墙占比 0.15-0.36，墙=1-2 格厚部分宽度横/竖带）
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
         
         pathCells = [];
         carveRooms(grid, rtype, wallTbl);
         debugStages.push(["carve", wallCount(grid)]);
         materialBands(grid, wallTbl);
         debugStages.push(["material", wallCount(grid)]);
         applyBoundaryAndDecor(grid, decor, wallTbl, rtype);
         debugStages.push(["final", wallCount(grid)]);
         return grid;
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