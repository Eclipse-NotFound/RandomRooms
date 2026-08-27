# -*- coding: utf-8 -*-
"""v5.6 分层大厅范式诊断：量化开放率/连通性/rects 产出。

结构：2-3 个开放层 × 1 行层间墙带（2-3 个 2-3 宽洞）× 层内竖隔断
（1 格厚全层高，每道 1-2 个 2 宽门口）。

用法: python build/diag-skeleton.py [N=1000] [nlayer=2|3]
"""
import random
import sys
from collections import deque

GRID_W, GRID_H = 48, 25
GY, GX1, GX2 = 12, 23, 24
WALL = set("ABCDEFGHIJKLMNOPQRST")

LAYERS3 = [(1, 7), (9, 15), (17, 23)]
BANDS3 = [8, 16]
LAYERS2 = [(1, 11), (13, 23)]
BANDS2 = [12]

def skeleton(rng, nlayer):
    grid = [[rng.choice("JACK") for _ in range(GRID_W)] for _ in range(GRID_H)]
    layers = LAYERS3 if nlayer == 3 else LAYERS2
    bands = BANDS3 if nlayer == 3 else BANDS2
    # 2a) 开放层
    for (t, b) in layers:
        for y in range(t, b + 1):
            for x in range(1, GRID_W - 1):
                grid[y][x] = "_"
    # 2b) 层间墙带 + 洞
    for band in bands:
        for x in range(1, GRID_W - 1):
            grid[band][x] = rng.choice("JACK")
        hole_last = 1
        for _ in range(2 + rng.randint(0, 1)):
            hx = hole_last + 4 + rng.randint(0, max(1, GRID_W - 8 - hole_last))
            if hx > GRID_W - 5: hx = GRID_W - 5
            hw = 2 + rng.randint(0, 1)
            for x in range(hx, min(hx + hw, GRID_W - 1)):
                grid[band][x] = "_"
            hole_last = hx + hw
        if band == GY:
            for x in range(1, 4): grid[band][x] = "_"
            for x in range(GRID_W - 4, GRID_W - 1): grid[band][x] = "_"
    # 2c) 竖隔断
    walls_x = []
    rects = []
    for (t, b) in layers:
        wxs = []
        segs = 1 + rng.randint(0, 1)
        for _ in range(segs):
            for _try in range(20):
                wx = 6 + rng.randint(0, GRID_W - 15)
                if any(abs(w - wx) < 5 for w in wxs): continue
                for y in range(t, b + 1): grid[y][wx] = rng.choice("JACK")
                for _d in range(1 + rng.randint(0, 1)):
                    dy = t + 1 + rng.randint(0, max(1, b - t - 2))
                    grid[dy][wx] = "_"
                    if dy + 1 <= b: grid[dy + 1][wx] = "_"
                wxs.append(wx)
                break
        walls_x.append(wxs)
        # 2d) rects
        xs = sorted(wxs)
        x0 = 1
        for i in range(len(xs) + 1):
            x1 = xs[i] if i < len(xs) else GRID_W - 1
            if x1 - x0 >= 4:
                rects.append((x0, t, x1 - x0, b - t + 1))
            x0 = x1 + 1
    # 5) 边界 + 6 缺口
    for x in range(GRID_W):
        grid[0][x] = "A"; grid[GRID_H - 1][x] = "A"
    for y in range(GRID_H):
        grid[y][0] = "A"; grid[y][GRID_W - 1] = "A"
    for (gy, gx) in [(GY, 0), (GY, GRID_W - 1), (0, GX1), (0, GX2), (GRID_H - 1, GX1), (GRID_H - 1, GX2)]:
        grid[gy][gx] = "_"
    return grid, rects

def wallcount(grid):
    return sum(1 for row in grid for c in row if c[0] in WALL)

def components(grid):
    seen = set()
    comps = []
    for j in range(GRID_H):
        for i in range(GRID_W):
            if (j, i) in seen or grid[j][i][0] in WALL: continue
            comp = []
            dq = deque([(j, i)]); seen.add((j, i))
            while dq:
                cy, cx = dq.popleft(); comp.append((cy, cx))
                for ny, nx in ((cy-1,cx),(cy+1,cx),(cy,cx-1),(cy,cx+1)):
                    if 0 <= ny < GRID_H and 0 <= nx < GRID_W and (ny, nx) not in seen and grid[ny][nx][0] not in WALL:
                        seen.add((ny, nx)); dq.append((ny, nx))
            comps.append(comp)
    return comps

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    walls, main_frac, small, rect_counts = [], [], 0, []
    multi = 0
    for k in range(n):
        rng = random.Random(k)
        nlayer = 3 if k % 2 == 0 else 2
        grid, rects = skeleton(rng, nlayer)
        w = wallcount(grid)
        walls.append(w)
        comps = components(grid)
        comps.sort(key=len, reverse=True)
        main = len(comps[0]) if comps else 0
        rest = sum(len(c) for c in comps[1:])
        main_frac.append(main / max(1, main + rest))
        small += sum(1 for c in comps if 0 < len(c) < 6)
        if len(comps) > 1 and rest > 0: multi += 1
        rect_counts.append(len(rects))
    print(f"=== v5.6 分层大厅诊断: {n} 房 ===")
    print(f"墙数 avg={sum(walls)/len(walls):.0f}  p10={sorted(walls)[n//10]}  p50={sorted(walls)[n//2]}  p90={sorted(walls)[n*9//10]}  (v5.4=748, 合格线<=430)")
    print(f"主组件开放占比 avg={sum(main_frac)/n*100:.1f}%  多组件房: {multi}  <6 格碎斑总数: {small}")
    print(f"rects/房 avg={sum(rect_counts)/n:.1f}  min={min(rect_counts)}")

if __name__ == "__main__":
    main()
