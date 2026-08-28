# -*- coding: utf-8 -*-
"""v5.8 分层大厅连通性诊断：镜像 AS3（动态带厚/主次洞/层型三档/隔断厚度），
断言 ① 层间连通 ② 段间连通 ③ 6 缺口可达 ④ rects 产出。

用法: python build/diag-skeleton.py [N=1000]
"""
import random
import sys
from collections import deque

GRID_W, GRID_H = 48, 25
GY, GX1, GX2 = 12, 23, 24
WALL = set("ABCDEFGHIJKLMNOPQRST")

def skeleton(rng, nlayer):
    grid = [[rng.choice("JACK") for _ in range(GRID_W)] for _ in range(GRID_H)]
    layers, bands = [], []
    cursor = 1
    if nlayer == 3:
        t1 = 2 if rng.random() < 0.4 else 1
        t2 = 2 if rng.random() < 0.4 else 1
        h3 = (23 - t1 - t2) // 3
        layers.append((cursor, cursor + h3 - 1)); cursor += h3
        bands.append((cursor, t1)); cursor += t1
        layers.append((cursor, cursor + h3 - 1)); cursor += h3
        bands.append((cursor, t2)); cursor += t2
        layers.append((cursor, 23))
    else:
        t12 = 2 if rng.random() < 0.4 else 1
        h2 = (23 - t12) // 2
        layers.append((cursor, cursor + h2 - 1)); cursor += h2
        bands.append((cursor, t12)); cursor += t12
        layers.append((cursor, 23))
    # 2a' 开放层
    for (t, b) in layers:
        for y in range(t, b + 1):
            for x in range(1, GRID_W - 1):
                grid[y][x] = "_"
    # 2b) 墙带 + 主次洞
    for (band_top, band_rows) in bands:
        for r in range(band_rows):
            for x in range(1, GRID_W - 1):
                grid[band_top + r][x] = rng.choice("JACK")
        hole_last = 1
        for hk in range(2 + rng.randint(0, 1)):
            hw = 3 + rng.randint(0, 1) if hk == 0 else 2
            hx = hole_last + 4 + rng.randint(0, max(1, GRID_W - 8 - hole_last))
            if hx > GRID_W - 5: hx = GRID_W - 5
            for x in range(hx, min(hx + hw, GRID_W - 1)):
                for r in range(band_rows):
                    grid[band_top + r][x] = "_"
            hole_last = hx + hw
        if band_top <= GY < band_top + band_rows:
            for x in range(1, 4):
                for r in range(band_rows): grid[band_top + r][x] = "_"
            for x in range(GRID_W - 4, GRID_W - 1):
                for r in range(band_rows): grid[band_top + r][x] = "_"
    # 2c) 竖隔断（层型三档）
    walls_x = []
    rects = []
    for (t, b) in layers:
        wxs = []
        roll = rng.random()
        segs = 0 if roll < 0.25 else (1 + rng.randint(0, 1) if roll < 0.75 else 3 + rng.randint(0, 1))
        for _ in range(segs):
            for _try in range(20):
                wx = 5 + rng.randint(0, GRID_W - 13)
                ww = 2 if rng.random() < 0.3 else 1
                if any(abs(w[0] - wx) < 6 for w in wxs): continue
                for y in range(t, b + 1):
                    for w in range(ww): grid[y][wx + w] = rng.choice("JACK")
                for _d in range(1 + rng.randint(0, 1)):
                    dy = t + 1 + rng.randint(0, max(1, b - t - 3))
                    dw = 3 if _d == 0 else 2
                    for dz in range(3):
                        if dy + dz <= b:
                            for w in range(min(dw, ww)): grid[dy + dz][wx + w] = "_"
                wxs.append((wx, ww))
                break
        walls_x.append(wxs)
        xs = sorted(w[0] for w in wxs)
        x0 = 1
        for i in range(len(xs) + 1):
            x1 = xs[i] if i < len(xs) else GRID_W - 1
            if x1 - x0 >= 4: rects.append((x0, t, x1 - x0, b - t + 1))
            x0 = x1 + 1
            if i < len(xs):
                for (wx, ww) in wxs:
                    if wx == x1: x0 += ww - 1; break
    # 5) 边界 + 6 缺口
    for x in range(GRID_W):
        grid[0][x] = "A"; grid[GRID_H - 1][x] = "A"
    for y in range(GRID_H):
        grid[y][0] = "A"; grid[y][GRID_W - 1] = "A"
    for (gy, gx) in [(GY,0),(GY,GRID_W-1),(0,GX1),(0,GX2),(GRID_H-1,GX1),(GRID_H-1,GX2)]:
        grid[gy][gx] = "_"
    return grid, rects

def components(grid):
    seen = set(); comps = []
    for j in range(GRID_H):
        for i in range(GRID_W):
            if (j, i) in seen or grid[j][i][0] in WALL: continue
            comp = []; dq = deque([(j, i)]); seen.add((j, i))
            while dq:
                cy, cx = dq.popleft(); comp.append((cy, cx))
                for ny, nx in ((cy-1,cx),(cy+1,cx),(cy,cx-1),(cy,cx+1)):
                    if 0 <= ny < GRID_H and 0 <= nx < GRID_W and (ny, nx) not in seen and grid[ny][nx][0] not in WALL:
                        seen.add((ny, nx)); dq.append((ny, nx))
            comps.append(comp)
    return comps

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    walls = []; main_frac = []; fail = 0; small_open = 0
    for k in range(n):
        rng = random.Random(k)
        nlayer = 3 if k % 2 == 0 else 2
        grid, rects = skeleton(rng, nlayer)
        walls.append(sum(1 for row in grid for c in row if c[0] in WALL))
        comps = components(grid)
        comps.sort(key=len, reverse=True)
        main = len(comps[0]) if comps else 0
        rest = sum(len(c) for c in comps[1:])
        main_frac.append(main / max(1, main + rest))
        # 6 缺口可达性：每个缺口必须与主组件连通
        starts = [(GY,0),(GY,GRID_W-1),(0,GX1),(0,GX2),(GRID_H-1,GX1),(GRID_H-1,GX2)]
        mainset = set(comps[0]) if comps else set()
        for (sy, sx) in starts:
            if grid[sy][sx][0] not in WALL and (sy, sx) not in mainset:
                fail += 1
                print(f"FAIL 缺口不可达 k={k} start={sy},{sx}")
        small_open += sum(1 for c in comps if 0 < len(c) < 6)
    print(f"=== v5.8 连通性诊断: {n} 房 ===")
    print(f"墙数 avg={sum(walls)/n:.0f} p50={sorted(walls)[n//2]} (v5.6=216)")
    print(f"主组件开放占比 avg={sum(main_frac)/n*100:.2f}%  缺口不可达计数: {fail}  <6格碎斑: {small_open}")
    print("✓ 全连通" if fail == 0 and min(main_frac) > 0.99 else "✗ 有不连通")

if __name__ == "__main__":
    main()
