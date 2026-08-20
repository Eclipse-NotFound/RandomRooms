#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RRSynth v3.5 —— 原版分区墙生成器（离线原型）。

基于原版语料（525 房）统计实证：
  - 墙占比低（stable 0.16-0.36 / plant 0.08-0.30 / mane 0.15-0.21）
  - 墙=1-2 格厚的**横向分区墙带**（部分宽度、带缺口），把房间分成横排区块，
    区块之间靠**边缘通道 + 墙带内部缺口**连通
  - 左右边缘有带缺口的墙条；开放地面铺满装饰后缀
  - 极少大块墙体

生成流程：
  1. 整图开放 + 高密度装饰
  2. 2-5 条横向分区墙带（1-2 格厚、部分宽、≥2 缺口）+ 0-3 条竖向分区墙
  3. 左右边缘墙条（带缺口）；少量掩体墩
  4. 边界/缺口/BFS 兜底

不变式: 25x48 / 缺口 / BFS 连通 / 墙占比 / 样本 ASCII
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
    grid = [["_" for _ in range(W)] for _ in range(H)]
    # 1) 横向分区墙带：锚定层高 {4,12,20}±1（原版 0/8/16 行的块层结构），
    #    1-2 格厚，部分宽度，≥2 缺口 + 两端留边道
    n_h = {"corridor": 3, "hall": 2, "l": 3, "split": 5}[rtype]
    for _ in range(n_h):
        y = [4, 12, 20][rng.randint(0, 2)] + rng.randint(-1, 1)
        y = max(2, min(H - 3, y))
        wseg = rng.randint(24, 44)
        x0 = rng.randint(2, W - wseg - 2)
        thick = 1 if rng.random() < 0.7 else 2
        ng = rng.randint(2, 4)
        gaps = set(x0 + rng.randint(0, wseg - 1) for _ in range(ng))
        seg = set(range(x0, x0 + wseg)) - gaps - set(range(x0, x0 + 2)) - set(range(x0 + wseg - 2, x0 + wseg))
        for yy in range(y, min(y + thick, H - 1)):
            for x in seg:
                grid[yy][x] = pick_weighted(rng, wall_tbl)
    # 2) 竖向分区墙：锚定列 {8,24,40}±1，1-2 宽，部分高，≥1 缺口 + 两端留通道
    n_v = {"corridor": 1, "hall": 0, "l": 2, "split": 3}[rtype]
    for _ in range(n_v):
        x = [8, 24, 40][rng.randint(0, 2)] + rng.randint(-1, 1)
        x = max(2, min(W - 3, x))
        hseg = rng.randint(6, 18)
        y0 = rng.randint(2, H - hseg - 2)
        thick2 = 1 if rng.random() < 0.8 else 2
        ng = rng.randint(1, 2)
        gaps = set(y0 + rng.randint(0, hseg - 1) for _ in range(ng))
        seg = set(range(y0, y0 + hseg)) - gaps - set(range(y0, y0 + 1)) - set(range(y0 + hseg - 1, y0 + hseg))
        for xx in range(x, min(x + thick2, W - 1)):
            for y in seg:
                grid[y][xx] = pick_weighted(rng, wall_tbl)
    # 3) 左右边缘墙条（带缺口，非整高）
    for side in (1, W - 2):
        for y in range(2, H - 2):
            if rng.random() < 0.75 and abs(y - GY) > 2:
                grid[y][side] = pick_weighted(rng, wall_tbl)
    # 4) 掩体墩（少量实心块，射击掩体）
    for _ in range(rng.randint(2, 5)):
        y = rng.randint(2, H - 3)
        x = rng.randint(2, W - 3)
        if grid[y][x] == "_":
            grid[y][x] = pick_weighted(rng, wall_tbl)
    # 5) 装饰：开放格高密度后缀（原版房间铺满装饰）
    if decor:
        for y in range(1, H - 1):
            for x in range(1, W - 1):
                if grid[y][x] == "_" and rng.random() < 0.16:
                    grid[y][x] = "_" + pick_weighted(rng, decor)
    # 6) 掩体桌
    for _ in range(6):
        y, x = rng.randint(2, H - 3), rng.randint(2, W - 3)
        if grid[y][x] == "_":
            grid[y][x] = "_-"
    _apply_boundary(grid)
    return grid

def _apply_boundary(grid):
    for x in range(W):
        grid[0][x] = "A"; grid[H - 1][x] = "A"
    for y in range(H):
        grid[y][0] = "A"; grid[y][W - 1] = "A"
    grid[GY][0] = "_"; grid[GY][W - 1] = "_"
    grid[0][GX1] = "_"; grid[0][GX2] = "_"
    grid[H - 1][GX1] = "_"; grid[H - 1][GX2] = "_"
    bfs_fill(grid)

def bfs_fill(grid):
    seen = set(); dq = deque()
    for s in [(GY, 0), (GY, W - 1), (0, GX1), (0, GX2), (H - 1, GX1), (H - 1, GX2)]:
        if grid[s[0]][s[1]][0] not in WALL:
            seen.add(s); dq.append(s)
    while dq:
        y, x = dq.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < H and 0 <= nx < W and (ny, nx) not in seen and grid[ny][nx][0] not in WALL:
                seen.add((ny, nx)); dq.append((ny, nx))
    for y in range(H):
        for x in range(W):
            if grid[y][x][0] not in WALL and (y, x) not in seen:
                grid[y][x] = "C"

def wall_ratio(grid):
    return sum(1 for row in grid for c in row if c[0] in WALL) / (W * H)

def wall_components(grid):
    seen = set(); comps = 0
    for y in range(H):
        for x in range(W):
            if grid[y][x][0] in WALL and (y, x) not in seen:
                comps += 1; dq = deque([(y, x)]); seen.add((y, x))
                while dq:
                    cy, cx = dq.popleft()
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < H and 0 <= nx < W and (ny, nx) not in seen and grid[ny][nx][0] in WALL:
                            seen.add((ny, nx)); dq.append((ny, nx))
    return comps

def validate(grid, rtype):
    errs = []
    if len(grid) != H or any(len(r) != W for r in grid):
        errs.append("尺寸")
    for s in [(GY, 0), (GY, W - 1), (0, GX1), (0, GX2), (H - 1, GX1), (H - 1, GX2)]:
        if grid[s[0]][s[1]][0] in WALL:
            errs.append("缺口被封"); return errs
    seen = set()
    for s in [(GY, 0), (GY, W - 1), (0, GX1), (0, GX2), (H - 1, GX1), (H - 1, GX2)]:
        seen.add(s)
    dq = deque(seen)
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
    if not (0.12 <= wr <= 0.55):
        errs.append(f"墙占比异常 {wr:.2f}")
    return errs

def main():
    rng = random.Random(20260820)
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    fails = 0
    ratio_by_type = {}
    decomp_by_type = {}
    decor = load_biome_decor("build/grammar-data2.txt")
    for k in range(n):
        rtype = rng.choice(TYPES)
        biome = rng.choice(list(BIOME_WALL.keys()))
        grid = gen_room(rng, rtype, biome, decor.get(biome))
        errs = validate(grid, rtype)
        ratio_by_type.setdefault(rtype, []).append(wall_ratio(grid))
        decomp_by_type.setdefault(rtype, []).append(wall_components(grid))
        if errs:
            fails += 1
            if fails <= 5:
                print("FAIL", rtype, errs[:2])
    print(f"=== RRSynth v3.5 验证: {n} 房 ===")
    print("不变式失败: " + str(fails))
    for t in TYPES:
        r = ratio_by_type[t]; d = decomp_by_type[t]
        if r:
            print(f"  {t}: 墙占比 平均 {sum(r)/len(r):.2f}   墙连通分量 平均 {sum(d)/len(d):.1f}")
    print("✓ 全部通过" if fails == 0 else "✗ 有失败")
    print("\n=== v3.5 视觉样本 ===")
    decor = load_biome_decor("build/grammar-data2.txt")
    for rtype, biome in [("corridor", "stable"), ("hall", "sewer"), ("l", "plant"), ("split", "mane")]:
        grid = gen_room(rng, rtype, biome, decor.get(biome))
        print(f"----- {rtype} (墙 {wall_ratio(grid):.2f}, 分量 {wall_components(grid)}) -----")
        for row in grid:
            print("".join(c if c[0] != "_" or len(c) == 1 else "·" for c in row))

if __name__ == "__main__":
    main()
