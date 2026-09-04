# -*- coding: utf-8 -*-
"""v6.3：门重做为原版墙顶模式（语料实证 stdoor 100% 站水平墙带顶部、下方紧邻墙）、
wallSpot 背墙校验重做（治书架/储物柜/油桶浮空）、6 缺口向内贯通隧道（治合成房
之间无通道）、缺口检查日志路径修复（Error #1069）。"""
import io

p = 'src/rr/RRSynth.as'
s = io.open(p, encoding='utf-8').read()

# ---- 1) 门位收集重做：竖隔断/区界门口不再放门（通行口保留），门改收墙顶位 ----
# 1a) 区界墙门口：删门位收集
old = """               for (var dz:int = 0; dz < 3; dz++)
               {
                  for (w2 = 0; w2 < zww; w2++) grid[doorY + dz][zwx + w2] = "_";
               }
               lastDoorSpots.push([zwx, doorY]);"""
new = """               for (var dz:int = 0; dz < 3; dz++)
               {
                  for (w2 = 0; w2 < zww; w2++) grid[doorY + dz][zwx + w2] = "_";
               }"""
assert old in s, 'zone wall door'
s = s.replace(old, new, 1)

# 1b) 竖隔断门口：删门位收集
old = """                        for (var dz:int = 0; dz < 3 && doorY + dz <= lbot; dz++)
                        {
                           for (w2 = 0; w2 < Math.min(doorW, wallW); w2++) grid[doorY + dz][wallX + w2] = "_";
                        }
                        lastDoorSpots.push([wallX, doorY]);"""
new = """                        for (var dz:int = 0; dz < 3 && doorY + dz <= lbot; dz++)
                        {
                           for (w2 = 0; w2 < Math.min(doorW, wallW); w2++) grid[doorY + dz][wallX + w2] = "_";
                        }"""
assert old in s, 'partition door'
s = s.replace(old, new, 1)

# 1c) 层间墙带循环：洞挖完后收墙顶门位（原版模式：门立于墙带顶部、下方紧邻墙）
old = """               // 十字动线：GX1/GX2 列对齐洞（若落在区内）
               if (rnd() < 0.6)
               {"""
new = """               // v6.3 墙顶门（原版实证：stdoor/door1 100% 站水平墙带顶部，
               // 下方紧邻墙列，非嵌竖墙）：每条墙带 65% 在顶部放 1 扇门
               if (rnd() < 0.65)
               {
                  var doorCx:int = zones[zi].x0 + 2 + int(rnd() * Math.max(1, zones[zi].x1 - zones[zi].x0 - 4));
                  if (WALL_CHARS.indexOf(grid[bandTop][doorCx].charAt(0)) >= 0 &&
                      bandTop - 1 >= 1 && isOpenCell(grid[bandTop - 1][doorCx]))
                  {
                     lastDoorSpots.push([doorCx, bandTop - 1]);
                  }
               }
               // 十字动线：GX1/GX2 列对齐洞（若落在区内）
               if (rnd() < 0.6)
               {"""
assert old in s, 'band top door'
s = s.replace(old, new, 1)

# ---- 2) 全局门放置段：校验改为原版模式（锚点开放 + 下方一格是墙） ----
old = """         var dFoot2:Array = objFoot(doorId);
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
         }"""
new = """         for (k = 0; k < lastDoorSpots.length; k++)
         {
            var dsp:Array = lastDoorSpots[k] as Array;
            var dsx:int = int(dsp[0]);
            var dsy:int = int(dsp[1]);
            if (usedGlobal[dsy + "," + dsx] == true) continue;
            // 原版门模式：锚点格开放 + 正下方一格是墙（贴墙立式门）
            if (!isOpenCell(grid[dsy][dsx])) continue;
            if (dsy + 1 >= GRID_H || WALL_CHARS.indexOf(grid[dsy + 1][dsx].charAt(0)) < 0) continue;
            if (dsy - 2 < 1) continue;
            lastObjs.push([doorId, genCode(), dsx, dsy]);
            usedGlobal[dsy + "," + dsx] = true;
         }"""
assert old in s, 'global door'
s = s.replace(old, new, 1)

# ---- 3) wallSpot 背墙校验（重做 v6.2 正确部分） ----
old = """            if (x < 0 || y < 0 || x >= GRID_W || y >= GRID_H) continue;
            if (isOpenCell(grid[y][x]) && used[y + "," + x] != true && footOk(grid, x, y, fs, fw)) return [x, y];"""
new = """            if (x < 0 || y < 0 || x >= GRID_W || y >= GRID_H) continue;
            // 背墙校验（原版 98% 竖高家具距墙 1 格；采样边背后必须部分是墙，
            // 否则物件立在洞口/开放区边缘=悬空观感）
            var backWall:Boolean = false;
            for (var bc:int = 0; bc < fs && !backWall; bc++)
            {
               if (side == 0 && y - 1 >= 0 && WALL_CHARS.indexOf(grid[y - 1][x + bc].charAt(0)) >= 0) backWall = true;
               if (side == 1 && y + fw < GRID_H && WALL_CHARS.indexOf(grid[y + fw][x + bc].charAt(0)) >= 0) backWall = true;
               if (side == 2 && x - 1 >= 0 && WALL_CHARS.indexOf(grid[y - 0][x - 1].charAt(0)) >= 0) backWall = true;
               if (side == 3 && x + fs < GRID_W && WALL_CHARS.indexOf(grid[y][x + fs].charAt(0)) >= 0) backWall = true;
            }
            if (!backWall) continue;
            if (isOpenCell(grid[y][x]) && used[y + "," + x] != true && footOk(grid, x, y, fs, fw)) return [x, y];"""
assert old in s, 'wallSpot'
s = s.replace(old, new, 1)

# ---- 4) 缺口贯通隧道：finishStripRoom 在 repair 前，从每缺口向内挖 2 宽通道 ----
old = """      private function finishStripRoom(grid:Array):void
      {
         grid[GY][0] = "_";
         grid[GY][GRID_W - 1] = "_";
         grid[0][GX1] = "_";
         grid[0][GX2] = "_";
         grid[GRID_H - 1][GX1] = "_";
         grid[GRID_H - 1][GX2] = "_";
         repairConnectivity(grid);
      }"""
new = """      private function finishStripRoom(grid:Array):void
      {
         grid[GY][0] = "_";
         grid[GY][GRID_W - 1] = "_";
         grid[0][GX1] = "_";
         grid[0][GX2] = "_";
         grid[GRID_H - 1][GX1] = "_";
         grid[GRID_H - 1][GX2] = "_";
         // v6.3 缺口贯通隧道：从每缺口向内逐层挖 2 宽通道，直到接上开放区
         // （最多 7 步）。任何分层/隔断结构下缺口→房内可达（跨合成房通行的
         // 房内侧保证；此前无此步——分层结构恰好把缺口堵在墙外=合成房之间
         // 无通道的直接根因）
         carveGapTunnel(grid, GY, 0, 1, 0);      // 左缺口 → 向右
         carveGapTunnel(grid, GY, GRID_W - 1, -1, 0); // 右缺口 → 向左
         carveGapTunnel(grid, 0, GX1, 0, 1);     // 上缺口1 → 向下
         carveGapTunnel(grid, 0, GX2, 0, 1);     // 上缺口2
         carveGapTunnel(grid, GRID_H - 1, GX1, 0, -1); // 下缺口1 → 向上
         carveGapTunnel(grid, GRID_H - 1, GX2, 0, -1); // 下缺口2
         repairConnectivity(grid);
      }

      /** 缺口向内隧道（2 宽×N 长；遇开放区即停） */
      private function carveGapTunnel(grid:Array, gy:int, gx2:int, dx:int, dy:int):void
      {
         var cy:int = gy;
         var cx:int = gx2;
         for (var step:int = 0; step < 7; step++)
         {
            cy += dy;
            cx += dx;
            if (cy < 1 || cy > GRID_H - 2 || cx < 1 || cx > GRID_W - 2) return;
            // 前方 2 格（垂直于前进方向排开）都开放 → 已接上开放区，停
            var aOpen:Boolean = isOpenCell(grid[cy][cx]);
            var bcy:int = dy != 0 ? cy : cy + 1;
            var bcx:int = dy != 0 ? cx + 1 : cx;
            var bOpen:Boolean = bcy < GRID_H && bcx < GRID_W && isOpenCell(grid[bcy][bcx]);
            if (aOpen && bOpen) return;
            grid[cy][cx] = "_";
            if (bcy < GRID_H && bcx < GRID_W) grid[bcy][bcx] = "_";
         }
      }"""
assert old in s, 'finishStripRoom'
s = s.replace(old, new, 1)

io.open(p, 'w', encoding='utf-8', newline='').write(s)

# ---- 5) 缺口检查路径修复 ----
p2 = 'src/RandomRoomsMod.as'
s2 = io.open(p2, encoding='utf-8').read()
old = "            var vroom:XML = world.loc[0][0].room;"
new = "            var vroom:XML = world.land.locs[0][0][0].room;"
assert old in s2, 'vroom path'
s2 = s2.replace(old, new, 1)
io.open(p2, 'w', encoding='utf-8', newline='').write(s2)
print('v6.3 patch ok')
