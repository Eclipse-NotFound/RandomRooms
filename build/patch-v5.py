# -*- coding: utf-8 -*-
"""替换 RRSynth.as 中 v4 块（PROFILE 常量 + profileGen + drawBand + drawBits）为 v5 骨架生成"""
lines = open(r"C:\Program Files (x86)\Steam\steamapps\common\Remains\mods\RandomRooms\src\rr\RRSynth.as", encoding="utf-8").read().split("\n")
# 1-based 行号: 149-338 为 v4 块
start, end = 149, 338

new_block = '''      /** v5 房间-走廊骨架生成：
       * 1) 整图填墙（biome 材质）→ 2) 干净矩形房间(间距约束) 挖空
       * 3) 2 宽 L 形走廊网络：每房间连入生成树 + 6 缺口连入 → 房间-通道分明
       * 4) 边界 0/24 行 0/47 列整墙 + 6 缺口（干净边框）
       * 5) 材质带(2x4 区 90% 主字符) → 墙体区域统一不拼贴
       * 6) 装饰排仅安全地板纹理（排除 *水/K网格/-横梁/台阶/楼梯）
       * 7) 水池成片(sewer/plant)；连通修复由 finishStripRoom 完成 */
      private function v5Skeleton(grid:Array, bIdx:int, rtype:String, wallTbl:Array, decor:Array):void
      {
         var j:int, i:int, y:int, x:int, k:int;
         // 1) 填墙
         for (j = 0; j < GRID_H; j++)
         {
            for (i = 0; i < GRID_W; i++)
            {
               grid[j][i] = wallChar(wallTbl);
            }
         }
         // 2) 房间
         var nLo:int, nHi:int, cwLo:int, cwHi:int, chLo:int, chHi:int;
         if (rtype == "hall") { nLo = 5; nHi = 6; cwLo = 9; cwHi = 12; chLo = 6; chHi = 9; }
         else if (rtype == "split") { nLo = 8; nHi = 10; cwLo = 8; cwHi = 12; chLo = 6; chHi = 9; }
         else { nLo = 6; nHi = 8; cwLo = 8; cwHi = 12; chLo = 6; chHi = 9; }
         var n:int = nLo + int(rnd() * (nHi - nLo + 1));
         var pat:Object = {};
         var patArr:Array = [];
         var rooms:Array = [];
         var placed:int = 0;
         var tries:int = 0;
         var bi:int = 0;
         var bands:Array = [[2, 7], [8, 15], [16, 21]];
         while (placed < n && tries < 160)
         {
            tries++;
            var cw:int = cwLo + int(rnd() * (cwHi - cwLo + 1));
            var ch2:int = chLo + int(rnd() * (chHi - chLo + 1));
            var cwx:int = 2 + int(rnd() * (GRID_W - cw - 4));
            var band:Array = bands[bi % 3] as Array;
            bi++;
            var cwy:int = band[0] + int(rnd() * (band[1] - band[0] + 1));
            if (cwy > GRID_H - ch2 - 2) cwy = GRID_H - ch2 - 2;
            var ok:Boolean = true;
            for (y = cwy - 1; y <= cwy + ch2 + 1; y++)
            {
               for (x = cwx - 1; x <= cwx + cw + 1; x++)
               {
                  if (y >= 0 && y < GRID_H && x >= 0 && x < GRID_W && pat[y + "," + x] == true)
                  {
                     ok = false;
                     break;
                  }
               }
               if (!ok) break;
            }
            if (!ok) continue;
            for (y = cwy; y < cwy + ch2; y++)
            {
               for (x = cwx; x < cwx + cw; x++)
               {
                  if (WALL_CHARS.indexOf(grid[y][x].charAt(0)) >= 0) grid[y][x] = "_";
                  pat[y + "," + x] = true;
                  patArr.push([y, x]);
               }
            }
            rooms.push([cwx + int(cw / 2), cwy + int(ch2 / 2)]);
            placed++;
         }
         // 3) 走廊网络：每房间 2 宽 L 形连入网络 + 6 缺口连入
         var order:Array = rooms.slice();
         for (k = order.length - 1; k > 0; k--)
         {
            var sw:int = int(rnd() * (k + 1));
            var tmp:Array = order[k];
            order[k] = order[sw];
            order[sw] = tmp;
         }
         for (k = 0; k < order.length; k++)
         {
            linkL2(grid, pat, patArr, int(order[k][0]), int(order[k][1]));
         }
         var gs:Array = [[GY, 0], [GY, GRID_W - 1], [0, GX1], [0, GX2], [GRID_H - 1, GX1], [GRID_H - 1, GX2]];
         for (k = 0; k < gs.length; k++)
         {
            var gy2:int = gs[k][0];
            var gx2:int = gs[k][1];
            if (pat[gy2 + "," + gx2] != true) linkL2(grid, pat, patArr, gx2, gy2);
         }
         // 4) 材质带（90% 主字符）
         materialBands(grid, wallTbl);
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
         // 6) 装饰排：仅安全地板纹理后缀
         var safeDec:Array = safeDecor(decor);
         if (safeDec.length > 0)
         {
            var den:Number = bIdx == 0 ? 0.40 : (bIdx == 1 ? 0.30 : (bIdx == 2 ? 0.28 : 0.34));
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
                        if (dx2 < GRID_W - 1 && grid[y][dx2] == "_") grid[y][dx2] = "_" + pickWeighted(safeDec);
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
         // 7) 水池成片（sewer/plant）
         var pools:int = bIdx == 1 ? (1 + int(rnd() * 3)) : (bIdx == 2 ? (1 + int(rnd() * 2)) : 0);
         for (k = 0; k < pools; k++)
         {
            var pw:int = 5 + int(rnd() * 7);
            var ph2:int = 1 + int(rnd() * 3);
            var px:int = 2 + int(rnd() * (GRID_W - pw - 4));
            var py:int = 2 + int(rnd() * (GRID_H - ph2 - 3));
            for (y = py; y < py + ph2; y++)
            {
               for (x = px; x < px + pw; x++)
               {
                  if (grid[y][x] == "_") grid[y][x] = "_*";
               }
            }
         }
      }

      /** 2 宽 L 形走廊：最近开放格 -> (tx,ty)（目标=房间中心/缺口） */
      private function linkL2(grid:Array, pat:Object, patArr:Array, tx:int, ty:int):void
      {
         if (patArr.length == 0) return;
         var bi:int = 0;
         var bd:Number = 1e9;
         for (var k:int = 0; k < patArr.length; k++)
         {
            var dy:Number = patArr[k][0] - ty;
            var dx:Number = patArr[k][1] - tx;
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
         var out:Array = [];
         if (decor == null) return out;
         var bad:String = "*-,КАБВГЖЗИЙЛМОПСТНРK";
         for (var k:int = 0; k < decor.length; k++)
         {
            var ch:String = String(decor[k][0]);
            if (bad.indexOf(ch) < 0) out.push(decor[k]);
         }
         return out;
      }
'''

lines[start - 1:end] = [new_block]
open(r"C:\Program Files (x86)\Steam\steamapps\common\Remains\mods\RandomRooms\src\rr\RRSynth.as", "w", encoding="utf-8").write("\n".join(lines))
print("replaced lines", start, "-", end)
