# -*- coding: utf-8 -*-
"""临时补丁脚本：RRSynth genGrid 替换为 v3 场生成（一次性）"""
p = "src/rr/RRSynth.as"
s = open(p, encoding="utf-8").read()
start = s.index("      /** 核心生成 */")
end = s.index("      private function pickDecor")
new = '''      /** 核心生成：场驱动（v3） */
      public function genGrid(biome:String, rtype:String):Array
      {
         var bIdx:int = RRGrammar.BIOME_ORDER.indexOf(biome);
         if (bIdx < 0) bIdx = 0;
         var wallTbl:Array = RRGrammar.BIOME_WALLS[bIdx] as Array;
         var decor:Array = RRGrammar.BIOME_DECORS[bIdx] as Array;
         if (rtype == null || rtype.length == 0)
         {
            rtype = rnd() < 0.5 ? "corridor" : "hall";
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
         
         var f:Array = null;
         if (rtype == "corridor" || rtype == "hall" || rtype == "l")
         {
            f = valueNoise();
            if (rtype == "corridor")
            {
               for (j = 0; j < GRID_H; j++) { for (i = 18; i <= 29; i++) { f[j][i] = -1; } }
            }
            else if (rtype == "hall")
            {
               for (j = 5; j <= 19; j++) { for (i = 8; i <= 39; i++) { f[j][i] = -1; } }
            }
            else
            {
               for (j = 18; j <= 22; j++) { for (i = 0; i < GRID_W; i++) { f[j][i] = -1; } }
               for (i = 32; i <= 40; i++) { for (j = 0; j < GRID_H; j++) { f[j][i] = -1; } }
            }
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
            applyBoundaryAndDecor(grid, decor, wallTbl);
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
         applyBoundaryAndDecor(grid, decor, wallTbl);
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
            case "hall": return 0.18;
            case "quad": return 0.3;
            case "l": return 0.24;
            default: return 0.25;
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
      
      private function wallChar(wallTbl:Array):String
      {
         return pickWeighted(wallTbl);
      }
      
      /** 边界/缺口 + 装饰掩体层 + BFS */
      private function applyBoundaryAndDecor(grid:Array, decor:Array, wallTbl:Array):void
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
               grid[j][i] = "-";
            }
         }
         bfsFill(grid);
      }

'''
s = s[:start] + new + s[end:]
open(p, "w", encoding="utf-8").write(s)
print("patch ok")
