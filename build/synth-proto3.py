#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RRSynth v4 —— 行谱结构生成（离线原型）。

核心思想：原版每个 biome 的**行墙谱**（逐行墙密度）就是它的结构指纹：
  - mane: 墙只在 0/8/16/24 行（8 行周期，3 个开放分区）
  - sewer/plant: 每 4 行一个峰（块行结构）
  - stable: 4 行周期但基线高
生成时逐行按谱采样墙量（×抖动），横向随机画实心墙带段（1-2 厚、6-22 长、
两端留边道）→ 垂直结构由谱保证、水平全自由 → 有机重组、无拼贴。

其余构件（语料实测分布）:
  竖带 0-2 (锚定列 8/24/40, 低频) / 边缘条 col1/46 (biome 概率)
  水体成片池 (sewer/plant) / 装饰排 (密度 per biome) / Z 层栅格行 (低频)
收尾: 6 缺口强制开放 + 连通修复 (小口袋填墙/大口袋 2 宽 L 连廊)

不变式: 25x48 / 缺口 / BFS 连通 / 墙占比≈语料 / 样本 ASCII
用法: python build/synth-proto3.py [数量]
"""
import random
import sys
from collections import deque

W, H = 48, 25
WALL = set("ABCDEFGHIJKLMNOPQRST")
GY, GX1, GX2 = 12, 23, 24
TYPES = ["corridor", "hall", "l", "split"]

BIOME_WALL = {
    "stable": [("J", 43), ("A", 27), ("K", 20), ("G", 6), ("H", 4)],
    "sewer": [("L", 63), ("A", 23), ("M", 5), ("I", 4), ("H", 3)],
    "plant": [("C", 56), ("G", 13), ("D", 9), ("B", 9), ("A", 6), ("H", 5)],
    "mane": [("N", 55), ("A", 22), ("B", 16), ("D", 4), ("E", 2)],
}

# 行墙谱（语料实测，25 行）：P(该行格为墙)
PROFILE = {
    "stable": [0.73, 0.25, 0.20, 0.28, 0.33, 0.32, 0.24, 0.27, 0.54, 0.32, 0.22, 0.24, 0.44, 0.28, 0.30, 0.22, 0.45, 0.26, 0.20, 0.30, 0.43, 0.20, 0.16, 0.17, 0.74],
    "sewer": [0.81, 0.34, 0.21, 0.39, 0.55, 0.30, 0.19, 0.27, 0.53, 0.35, 0.31, 0.29, 0.46, 0.35, 0.29, 0.27, 0.47, 0.35, 0.35, 0.33, 0.59, 0.39, 0.17, 0.20, 0.81],
    "mane": [0.72, 0.06, 0.07, 0.08, 0.14, 0.07, 0.03, 0.04, 0.74, 0.18, 0.13, 0.09, 0.14, 0.08, 0.04, 0.10, 0.71, 0.07, 0.04, 0.04, 0.10, 0.03, 0.02, 0.04, 0.72],
    "plant": [0.49, 0.18, 0.14, 0.14, 0.47, 0.15, 0.12, 0.12, 0.45, 0.16, 0.15, 0.22, 0.52, 0.17, 0.12, 0.10, 0.53, 0.20, 0.16, 0.27, 0.49, 0.20, 0.12, 0.13, 0.58],
}

# 装饰密度区间 / 水池数 / 边缘墙率
DECOR_R = {"stable": (0.45, 0.60), "sewer": (0.30, 0.40), "plant": (0.28, 0.38), "mane": (0.36, 0.46)}
POOLS = {"stable": (0, 0), "sewer": (1, 3), "plant": (1, 2), "mane": (0, 0)}
EDGE_P = {"stable": 0.30, "sewer": 0.40, "plant": 0.25, "mane": 0.18}

def load_biome_decor(path):
    dec = {}
    cur = None
    for ln in open(path, encoding="utf-8").read().splitlines():
        if ln.startswith("== BIOME"):
            cur = ln.split()[-1]; dec[cur] = []; continue
        if cur is not None and ln.startswith("DECOR"):
            for p2 in ln.split()[1:]:
                if ":" in p2:
                    ch, c = p2.split(":", 1); dec[cur].append((ch, int(c)))
    return dec

def pick_weighted(rng, table):
    tot = sum(w for _, w in table)
    r = rng.randrange(tot)
    acc = 0
    for ch, w in table:
        acc += w
        if r < acc:
            return ch

def gen_room(rng, rtype, biome="stable", decor=None):
    wall_tbl = BIOME_WALL.get(biome, BIOME_WALL["stable"])
    prof = PROFILE[biome]
    grid = [["_" for _ in range(W)] for _ in range(H)]

    # 1) 逐行按谱采样墙量 -> 横向随机画实心带段（1 格厚：垂直结构已由谱承载）
    tfac = {"corridor": 1.0, "hall": 0.85, "l": 1.0, "split": 1.15}[rtype]
    for y in range(H):
        target = int(prof[y] * W * (0.85 + rng.random() * 0.3) * tfac)
        guard = 0
        while guard < 40:
            guard += 1
            have = sum(1 for c in grid[y] if c and c[0] in WALL)
            if have >= target:
                break
            runlen = rng.randint(6, 22)
            if rng.random() < 0.15:
                runlen = rng.randint(1, 5)      # 少量短段/单格
            runlen = min(runlen, target - have + 6)   # 限长防超调，段保持实心
            x0 = rng.randint(2, max(2, W - runlen - 3))
            for k in range(runlen):
                xx = x0 + k
                if xx < W - 2 and grid[y][xx] == "_":
                    grid[y][xx] = pick_weighted(rng, wall_tbl)

    # 2) 竖带 0-2（锚定列 8/24/40，低频）
    for _ in range(2):
        if rng.random() < 0.6:
            continue
        x = [8, 24, 40][rng.randrange(3)] + rng.randint(-2, 2)
        x = max(2, min(W - 3, x))
        hseg = rng.randint(6, 18)
        y0 = 2 + rng.randint(0, H - hseg - 2)
        tw = 1 if rng.random() < 0.8 else 2
        for yy in range(y0 + 1, y0 + hseg - 1):
            for xx in range(x, min(x + tw, W - 1)):
                if grid[yy][xx] == "_":
                    grid[yy][xx] = pick_weighted(rng, wall_tbl)

    # 3) 边缘条 col1/46（带缺口）
    for side in (1, W - 2):
        for y in range(1, H - 1):
            if rng.random() < EDGE_P[biome] and abs(y - GY) > 2 and grid[y][side] == "_":
                grid[y][side] = pick_weighted(rng, wall_tbl)

    # 4) 水体：成片池
    for _ in range(rng.randint(*POOLS[biome])):
        pw = rng.randint(4, 12)
        ph = rng.randint(1, 4)
        px = 2 + rng.randint(0, W - pw - 4)
        py = 2 + rng.randint(0, H - ph - 3)
        for yy in range(py, py + ph):
            for xx in range(px, px + pw):
                if grid[yy][xx] == "_":
                    grid[yy][xx] = "_*"

    # 5) 装饰排（成排 2-8 格，密度 per biome）
    decor_tbl = decor.get(biome) if decor else None
    if decor_tbl:
        dlo, dhi = DECOR_R[biome]
        for y in range(1, H - 1):
            x = 1
            while x < W - 1:
                if grid[y][x] == "_" and rng.random() < dlo + rng.random() * (dhi - dlo):
                    L = rng.randint(2, 8)
                    for k in range(L):
                        xx = x + k
                        if xx < W - 1 and grid[y][xx] == "_":
                            grid[y][xx] = "_" + pick_weighted(rng, decor_tbl)
                    x += L
                else:
                    x += 1

    # 6) Z 层栅格行（低频）
    for _ in range(2):
        if rng.random() < 0.5:
            continue
        y = rng.randint(2, H - 3)
        x = rng.randint(1, W - 12)
        L = rng.randint(4, 12)
        for k in range(L):
            if grid[y][x + k] == "_":
                grid[y][x + k] = "_;"

    # 7) 收尾：6 缺口 + 连通修复
    grid[GY][0] = "_"; grid[GY][W - 1] = "_"
    grid[0][GX1] = "_"; grid[0][GX2] = "_"
    grid[H - 1][GX1] = "_"; grid[H - 1][GX2] = "_"
    repair(grid)
    return grid

def repair(grid):
    seen = [[False] * W for _ in range(H)]
    qy, qx, main_open = [], [], []
    for (sy, sx) in [(GY, 0), (GY, W - 1), (0, GX1), (0, GX2), (H - 1, GX1), (H - 1, GX2)]:
        if not seen[sy][sx] and grid[sy][sx][0] not in WALL:
            seen[sy][sx] = True
            qy.append(sy); qx.append(sx); main_open.append((sy, sx))
    h = 0
    while h < len(qx):
        cy, cx = qy[h], qx[h]; h += 1
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = cy + dy, cx + dx
            if 0 <= ny < H and 0 <= nx < W and not seen[ny][nx] and grid[ny][nx][0] not in WALL:
                seen[ny][nx] = True
                qy.append(ny); qx.append(nx); main_open.append((ny, nx))
    for j in range(H):
        for i in range(W):
            if seen[j][i] or grid[j][i][0] in WALL:
                continue
            comp = []
            cqy, cqx = [j], [i]
            seen[j][i] = True
            ch = 0
            while ch < len(cqx):
                cy2, cx2 = cqy[ch], cqx[ch]; ch += 1
                comp.append((cy2, cx2))
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = cy2 + dy, cx2 + dx
                    if 0 <= ny < H and 0 <= nx < W and not seen[ny][nx] and grid[ny][nx][0] not in WALL:
                        seen[ny][nx] = True
                        cqy.append(ny); cqx.append(nx)
            if len(comp) < 16:
                for (y, x) in comp:
                    grid[y][x] = "C"
            else:
                connector(grid, seen, comp, main_open)

def connector(grid, seen, comp, main_open):
    bi = bm = 0
    bd = 1e9
    for a in range(len(comp)):
        for b in range(len(main_open)):
            d = (comp[a][0] - main_open[b][0]) ** 2 + (comp[a][1] - main_open[b][1]) ** 2
            if d < bd:
                bd = d; bi = a; bm = b
    y0, x0 = comp[bi]
    y1, x1 = main_open[bm]
    if random.random() < 0.5:
        h_run(grid, seen, x0, x1, y0, 2)
        v_run(grid, seen, y0, y1, x1, 2)
    else:
        v_run(grid, seen, y0, y1, x0, 2)
        h_run(grid, seen, x0, x1, y1, 2)

def h_run(grid, seen, xa, xb, y, w):
    for x in range(min(xa, xb), max(xa, xb) + 1):
        for dy in range(w):
            yy = y + dy
            if 0 <= yy < H:
                grid[yy][x] = "_"
                seen[yy][x] = True

def v_run(grid, seen, ya, yb, x, w):
    for y in range(min(ya, yb), max(ya, yb) + 1):
        for dx in range(w):
            xx = x + dx
            if 0 <= xx < W:
                grid[y][xx] = "_"
                seen[y][xx] = True

def wall_ratio(grid):
    return sum(1 for row in grid for c in row if c[0] in WALL) / (W * H)

def validate(grid, rtype):
    errs = []
    if len(grid) != H or any(len(r) != W for r in grid):
        errs.append("尺寸")
    for s in [(GY, 0), (GY, W - 1), (0, GX1), (0, GX2), (H - 1, GX1), (H - 1, GX2)]:
        if grid[s[0]][s[1]][0] in WALL:
            errs.append("缺口被封"); return errs
    seen = set()
    dq = deque([(GY, 0), (GY, W - 1), (0, GX1), (0, GX2), (H - 1, GX1), (H - 1, GX2)])
    seen.update(dq)
    while dq:
        y, x = dq.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < H and 0 <= nx < W and (ny, nx) not in seen and grid[ny][nx][0] not in WALL:
                seen.add((ny, nx)); dq.append((ny, nx))
    for y in range(H):
        for x in range(W):
            if grid[y][x][0] not in WALL and (y, x) not in seen:
                errs.append(f"孤岛({y},{x})"); return errs
    wr = wall_ratio(grid)
    if not (0.08 <= wr <= 0.60):
        errs.append(f"墙占比 {wr:.2f}")
    return errs

def main():
    rng = random.Random(20260820)
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    fails = 0
    stats = {}
    decor = load_biome_decor("build/grammar-data2.txt")
    for k in range(n):
        rtype = rng.choice(TYPES)
        biome = rng.choice(list(BIOME_WALL.keys()))
        grid = gen_room(rng, rtype, biome, decor)
        errs = validate(grid, rtype)
        stats.setdefault(rtype, []).append(wall_ratio(grid))
        if errs:
            fails += 1
            if fails <= 6:
                print("FAIL", rtype, biome, errs[:2])
    print(f"=== RRSynth v4 验证: {n} 房 ===")
    print("不变式失败:", fails)
    for t, rs in stats.items():
        print(f"  {t}: 墙占比 平均 {sum(rs)/len(rs):.2f}")
    print("✓ 全部通过" if fails == 0 else "✗ 有失败")
    print("\n=== v4 视觉样本 ===")
    for rtype, biome in [("corridor", "stable"), ("hall", "sewer"), ("l", "plant"), ("split", "mane")]:
        grid = gen_room(rng, rtype, biome, decor)
        print("=" * 62, rtype, biome, "墙%.2f" % wall_ratio(grid))
        for row in grid:
            print("".join("#" if c[0] in WALL else ("~" if "*" in c else ("·" if c[0] == "_" and len(c) > 1 else " ")) for c in row))

if __name__ == "__main__":
    main()
