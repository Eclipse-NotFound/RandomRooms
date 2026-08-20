# -*- coding: utf-8 -*-
"""一次性补丁：RRSynth.as 同步 v3.1（thin/material/road_walls/gap_guard/quad_gates + 阈值降+走廊收窄）"""
p = "src/rr/RRSynth.as"
s = open(p, encoding="utf-8").read()

# 1) wallRatio 降（补偿 road_walls 新增墙）
s = s.replace('''      private function wallRatio(rtype:String):Number
      {
         switch (rtype)
         {
            case "hall": return 0.18;
            case "quad": return 0.3;
            case "l": return 0.24;
            default: return 0.25;
         }
      }''',
'''      private function wallRatio(rtype:String):Number
      {
         switch (rtype)
         {
            case "hall": return 0.12;
            case "quad": return 0.22;
            case "l": return 0.14;
            default: return 0.17;
         }
      }''')

# 2) corridor 掩码收窄 20-27
s = s.replace('''            if (rtype == "corridor")
            {
               for (j = 0; j < GRID_H; j++) { for (i = 18; i <= 29; i++) { f[j][i] = -1; } }
            }''',
'''            if (rtype == "corridor")
            {
               for (j = 0; j < GRID_H; j++) { for (i = 20; i <= 27; i++) { f[j][i] = -1; } }
            }''')

# 3) 非 bunker 阈值墙后调用 v3.1 三函数（在 applyBoundaryAndDecor 前）
s = s.replace('''         var th:Number = threshWall(f, wallRatio(rtype));
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
         applyBoundaryAndDecor(grid, decor, wallTbl);
         return grid;
      }''',
'''         var th:Number = threshWall(f, wallRatio(rtype));
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
         roadWalls(grid, rtype);
         thinWalls(grid);
         materialBands(grid, wallTbl);
         applyBoundaryAndDecor(grid, decor, wallTbl, rtype);
         return grid;
      }''')

# 4) bunker 分支传 rtype
s = s.replace('''            applyBoundaryAndDecor(grid, decor, wallTbl);
            return grid;''',
'''            applyBoundaryAndDecor(grid, decor, wallTbl, rtype);
            return grid;''')

# 5) applyBoundaryAndDecor：加 rtype 参数；掩体后 quad_gates + gapGuard + bfs（最后）
s = s.replace('''      private function applyBoundaryAndDecor(grid:Array, decor:Array, wallTbl:Array):void''',
'''      private function applyBoundaryAndDecor(grid:Array, decor:Array, wallTbl:Array, rtype:String = null):void''')
s = s.replace('''         for (var m:int = 0; m < 6; m++)
         {
            j = 2 + int(rnd() * (GRID_H - 4));
            i = 2 + int(rnd() * (GRID_W - 4));
            if (grid[j][i] == "_")
            {
               grid[j][i] = "-";
            }
         }
         bfsFill(grid);
      }''',
'''         for (var m:int = 0; m < 6; m++)
         {
            j = 2 + int(rnd() * (GRID_H - 4));
            i = 2 + int(rnd() * (GRID_W - 4));
            if (grid[j][i] == "_")
            {
               grid[j][i] = "-";
            }
         }
         if (rtype == "quad")
         {
            quadGates(grid);
         }
         gapGuard(grid);
         bfsFill(grid);
      }
      
      /** v3.1 道路边墙线（限播，防墙占比失控） */
      private function roadWalls(grid:Array, rtype:String):void
      {
         var j:int;
         var i:int;
         if (rtype == "corridor")
         {
            for (j = 3; j < 22; j++)
            {
               for each (var cx:int in [18, 29])
               {
                  if (grid[j][cx] == "_") grid[j][cx] = "C";
               }
            }
         }
         else if (rtype == "hall")
         {
            for (i = 8; i < 40; i++)
            {
               for each (var cy:int in [3, 21])
               {
                  if (grid[cy][i] == "_") grid[cy][i] = "C";
               }
            }
         }
         else if (rtype == "l")
         {
            for (i = 31; i < 41; i += 2)
            {
               for (j = 3; j < 21; j++)
               {
                  if (grid[j][i] == "_") grid[j][i] = "C";
               }
            }
         }
      }
      
      /** v3.1 墙瘦化：3x3 8 邻墙>=13 挖 45%，两遍 → 墙缩成轮廓线 */
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
                  if (yy >= 0 && yy < GRID_H && xx >= 0 && xx < GRID_W && FCHARS.indexOf(grid[yy][xx].charAt(0)) >= 0)
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
                  if (FCHARS.indexOf(grid[j][i].charAt(0)) >= 0 && n8(j, i) >= 13 && rnd() < 0.45)
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
               if (FCHARS.indexOf(grid[j][i].charAt(0)) >= 0)
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
      }''')

open(p, "w", encoding="utf-8").write(s)
print("RRSynth v3.1 AS3 同步完成")
