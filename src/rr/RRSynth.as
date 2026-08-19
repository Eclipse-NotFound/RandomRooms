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
      
      public static const BIOMES:Array = ["stable", "sewer", "plant", "mane"];
      
      private static const BLOCK_W:int = 6;
      private static const BLOCK_H:int = 4;
      private static const GY:int = 12;
      private static const GX1:int = 23;
      private static const GX2:int = 24;
      
      public var rnd:Function;
      
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
      
      /** 核心生成 */
      public function genGrid(biome:String, rtype:String):Array
      {
         var bIdx:int = RRGrammar.BIOME_ORDER.indexOf(biome);
         if (bIdx < 0) bIdx = 0;
         var blocks:Array = RRGrammar.BIOME_BLOCKS[bIdx] as Array;
         var decor:Array = RRGrammar.BIOME_DECORS[bIdx] as Array;
         if (decor == null || decor.length == 0)
         {
            decor = RRGrammar.BIOME_DECORS[0] as Array;
         }
         var dtotal:int = 0;
         for (var di2:int = 0; di2 < decor.length; di2++)
         {
            dtotal += int(decor[di2][1]);
         }
         if (rtype == null || rtype.length == 0)
         {
            rtype = rnd() < 0.5 ? "vcorr" : "hall";
         }
         
         var grid:Array = [];
         for (var j:int = 0; j < GRID_H; j++)
         {
            grid[j] = [];
            for (var i:int = 0; i < GRID_W; i++)
            {
               grid[j][i] = "_";
            }
         }
         for (i = 0; i < GRID_W; i++)
         {
            grid[0][i] = "A";
            grid[GRID_H - 1][i] = "A";
         }
         for (j = 0; j < GRID_H; j++)
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
         
         if (rtype == "vcorr")
         {
            placeBlocks(grid, [[2, 16, 2, 22], [31, 45, 2, 22]], blocks, 9 + int(rnd() * 4));
            for (j = 2; j < GRID_H - 2; j++)
            {
               for each (var ecol:int in [17, 30])
               {
                  if (grid[j][ecol] == "_" && rnd() < 0.5)
                  {
                     grid[j][ecol] = "_" + pickDecor(decor, dtotal);
                  }
               }
            }
            for (j = 2; j < GRID_H - 2; j++)
            {
               for (i = 18; i < 30; i++)
               {
                  if (grid[j][i] == "_" && rnd() < 0.02)
                  {
                     grid[j][i] = "_" + pickDecor(decor, dtotal);
                  }
               }
            }
         }
         else
         {
            placeBlocks(grid, [[2, 45, 2, 4], [2, 45, 20, 22], [2, 7, 5, 19], [40, 45, 5, 19]],
                        blocks, 6 + int(rnd() * 4));
            for (j = 5; j < 20; j++)
            {
               for (i = 8; i < 40; i++)
               {
                  if (grid[j][i] == "_" && rnd() < 0.04)
                  {
                     grid[j][i] = "_" + pickDecor(decor, dtotal);
                  }
               }
            }
         }
         
         bfsFill(grid);
         return grid;
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
            if (FCHARS.indexOf(grid[sy][sx].charAt(0)) >= 0)
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
               if (FCHARS.indexOf(grid[ny][nx].charAt(0)) >= 0) continue;
               seen[key] = 1;
               qy.push(ny);
               qx.push(nx);
            }
         }
         for (var j:int = 0; j < GRID_H; j++)
         {
            for (var i:int = 0; i < GRID_W; i++)
            {
               if (FCHARS.indexOf(grid[j][i].charAt(0)) < 0 && seen[j * GRID_W + i] == null)
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