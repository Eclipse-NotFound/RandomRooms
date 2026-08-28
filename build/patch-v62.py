# -*- coding: utf-8 -*-
"""v6.2：wallSpot 背墙校验（悬空残余）、门口收窄到门宽（门真阻隔）、
墙材质统一（带级/隔断级单材质）、层界算法化+主层变数、缺口检查路径修复。"""
import io

p = 'src/rr/RRSynth.as'
s = io.open(p, encoding='utf-8').read()

# ---- 1) wallSpot：加背墙校验（物件背后紧邻必须部分是墙——原版 98% 距墙 1 格） ----
old = """            if (x < 0 || y < 0 || x >= GRID_W || y >= GRID_H) continue;
            if (isOpenCell(grid[y][x]) && used[y + "," + x] != true && footOk(grid, x, y, fs, fw)) return [x, y];"""
new = """            if (x < 0 || y < 0 || x >= GRID_W || y >= GRID_H) continue;
            // v6.2 背墙校验：物件背后紧邻必须部分是墙（原版 98% 距墙 1 格；
            // 无校验时物件可立在墙带的洞口背后——"悬空"观感）
            var backWall:Boolean = false;
            for (var bc:int = 0; bc < fs && !backWall; bc++)
            {
               if (side == 0 && y - 1 >= 0 && WALL_CHARS.indexOf(grid[y - 1][x + bc].charAt(0)) >= 0) backWall = true;
               if (side == 1 && y + fw < GRID_H && WALL_CHARS.indexOf(grid[y + fw][x + bc].charAt(0)) >= 0) backWall = true;
               if (side == 2 && x - 1 >= 0 && WALL_CHARS.indexOf(grid[y][x - 1].charAt(0)) >= 0) backWall = true;
               if (side == 3 && x + fs - 1 + 1 < GRID_W && WALL_CHARS.indexOf(grid[y][x + fs].charAt(0)) >= 0) backWall = true;
            }
            if (!backWall) continue;
            if (isOpenCell(grid[y][x]) && used[y + "," + x] != true && footOk(grid, x, y, fs, fw)) return [x, y];"""
assert old in s
s = s.replace(old, new, 1)

# ---- 2) 隔断门口：1 格宽门洞（stdoor 必放填满=真阻隔）+ 敞开口 2-3 宽 ----
start = s.index('                     var nDoor:int = 1 + int(rnd() * 2);')
endmark = '                     (zones[zi].walls as Array).push([wallX, wallW, ltop, lbot]);'
end = s.index(endmark)
new = """                     // v6.2 门洞语义：1 格宽洞（stdoor 1×3 恰好填满→门真阻隔，
                     // 原版门洞宽=门宽）+ 60% 概率一个 2-3 宽敞开口（无门敞通道）
                     doorY = ltop + 1 + int(rnd() * Math.max(1, lbot - ltop - 3));
                     for (var dz:int = 0; dz < 3 && doorY + dz <= lbot; dz++)
                     {
                        grid[doorY + dz][wallX] = "_";
                     }
                     lastDoorSpots.push([wallX, doorY]);
                     if (rnd() < 0.6)
                     {
                        var openY:int = ltop + 1 + int(rnd() * Math.max(1, lbot - ltop - 2));
                        var openW:int = 2 + int(rnd() * 2);
                        for (var oz:int = 0; oz < 3 && openY + oz <= lbot; oz++)
                        {
                           for (w2 = 1; w2 < Math.min(openW, wallW); w2++) grid[openY + oz][wallX + w2] = "_";
                        }
                     }
""" + endmark
s = s[:start] + new + s[end + len(endmark):]

# ---- 3) 层间主洞里的 hatch2：洞已 4-5/3 宽，hatch2 2×1 不再是"盖满"，
#         保留为洞口标识（可踩地板门）——语义对照原版 hatch2 散布，不改放置 ----

# ---- 4) 墙材质统一：墙带带级单材质、竖隔断/区界墙道级单材质 ----
old = """               for (r2 = 0; r2 < bandRows; r2++)
               {
                  for (x2 = zones[zi].x0; x2 <= zones[zi].x1; x2++) grid[bandTop + r2][x2] = wallChar(wallTbl);
               }"""
new = """               var bandCh:String = wallChar(wallTbl);   // v6.2 带级单材质（原版一堵墙一个材质）
               for (r2 = 0; r2 < bandRows; r2++)
               {
                  for (x2 = zones[zi].x0; x2 <= zones[zi].x1; x2++) grid[bandTop + r2][x2] = bandCh;
               }"""
assert old in s
s = s.replace(old, new, 1)

old = """                     var wallCh2:String = wallChar(wallTbl);   // v6.2 道级单材质
                     for (y2 = ltop; y2 <= lbot; y2++)
                     {
                        for (w2 = 0; w2 < wallW; w2++) grid[y2][wallX + w2] = wallCh2;
                     }"""
new = """                     var wallCh2:String = wallChar(wallTbl);   // v6.2 道级单材质
                     for (y2 = ltop; y2 <= lbot; y2++)
                     {
                        for (w2 = 0; w2 < wallW; w2++) grid[y2][wallX + w2] = wallCh2;
                     }"""
# 竖隔断段当前文本（v6.0 缩进 21 空格起）
old2 = """                     for (y2 = ltop; y2 <= lbot; y2++)
                     {
                        for (w2 = 0; w2 < wallW; w2++) grid[y2][wallX + w2] = wallChar(wallTbl);
                     }"""
assert old2 in s
s = s.replace(old2, new, 1)

old = """            for (y2 = 1; y2 <= GRID_H - 2; y2++)
            {
               for (w2 = 0; w2 < zww; w2++) grid[y2][zwx + w2] = wallChar(wallTbl);
            }"""
new = """            var zwCh:String = wallChar(wallTbl);   // v6.2 区界墙单材质
            for (y2 = 1; y2 <= GRID_H - 2; y2++)
            {
               for (w2 = 0; w2 < zww; w2++) grid[y2][zwx + w2] = zwCh;
            }"""
assert old in s
s = s.replace(old, new, 1)

# ---- 5) materialBands 主材质 90%→97%（混杂修复） ----
old = "                     var ch2:String = (rnd() < 0.90) ? String(layerMain[liHit]) : pickWeighted(wallTbl);"
new = "                     var ch2:String = (rnd() < 0.97) ? String(layerMain[liHit]) : pickWeighted(wallTbl);"
assert old in s
s = s.replace(old, new, 1)

io.open(p, 'w', encoding='utf-8', newline='').write(s)

# ---- 6) 缺口检查路径修复（Error #1069：world.loc 不存在 → world.land.locs） ----
p2 = 'src/RandomRoomsMod.as'
s2 = io.open(p2, encoding='utf-8').read()
old = "            var vroom:XML = world.loc[0][0].room;"
new = "            var vroom:XML = world.land.locs[0][0][0].room;"
assert old in s2
s2 = s2.replace(old, new, 1)
io.open(p2, 'w', encoding='utf-8', newline='').write(s2)
print('v6.2 patch ok')
