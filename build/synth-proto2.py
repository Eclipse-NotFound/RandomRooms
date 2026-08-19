#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RRSynth v2 原型 —— 道路模板 × 生物群系分组块。

解决 v1 两个设计缺陷：
  1. 材质混搭 → 整房只用单一 biome 组块；
  2. 无道路 → vcorr(纵向走廊)/hall(大厅) 道路模板：先画贯穿开放带，
     块只贴道路两侧分区，道路保持开放→ 有明显道路与分区。

验证：尺寸/缺口/道路存在/连通性/biome 一致。输出 ASCII 样本目检。
用法: python build/synth-proto2.py [样本数]
"""
import random
import sys
from collections import Counter, deque, defaultdict

GRID_W = 48
GRID_H = 25
BLOCK_W, BLOCK_H = 6, 4
WALL = set("ABCDEFGHIJKLMNOPQRST")
GY = 12
GX1, GX2 = 23, 24

def load_biomes(path):
    bio_blocks = defaultdict(list)
    bio_decor = defaultdict(list)
    cur = None
    lines = open(path, encoding="utf-8").read().splitlines()
    i = 0
    while i < len(lines):
        ln = lines[i]
        if ln.startswith("== BIOME"):
            cur = ln.split()[-1]
            i += 1
            continue
        if cur is None:
            i += 1
            continue
        if ln.startswith("BLOCK "):
            blk = [lines[i+k].strip().split("|") for k in range(1, BLOCK_H+1)]
            bio_blocks[cur].append(blk)
            i += BLOCK_H + 1
            continue
        if ln.startswith("DECOR"):
            for p in ln.split()[1:]:
                if ":" in p:
                    ch, c = p.split(":", 1)
                    bio_decor[cur].append((ch, int(c)))
            i += 1
            continue
        i += 1
    return bio_blocks, bio_decor

def place_blocks(grid, regions, blocks, rng, count):
    placed = 0
    tries = 0
    while placed < count and tries < 200:
        tries += 1
        x0, x1, y0, y1 = rng.choice(regions)
        bx = rng.randint(x0, max(x0, x1 - BLOCK_W))
        by = rng.randint(y0, max(y0, y1 - BLOCK_H))
        if bx + BLOCK_W - 1 > x1:
            bx = x1 - BLOCK_W + 1
        if by + BLOCK_H - 1 > y1:
            by = y1 - BLOCK_H + 1
        ok = True
        for dj in range(-1, BLOCK_H + 1):
            for di in range(-1, BLOCK_W + 1):
                yy, xx = by + dj, bx + di
                if 0 <= yy < GRID_H and 0 <= xx < GRID_W and grid[yy][xx] != "_":
                    ok = False
                    break
            if not ok:
                break
        if not ok:
            continue
        blk = rng.choice(blocks)
        for dj in range(BLOCK_H):
            for di in range(BLOCK_W):
                code = blk[dj][di]
                if code:
                    grid[by + dj][bx + di] = code
        placed += 1
    return placed

def gen_v2(rng, biome, rtype, bio_blocks, bio_decor):
    blocks = bio_blocks[biome]
    decor = bio_decor[biome]
    dtotal = sum(w for _, w in decor)
    grid = [["_" for _ in range(GRID_W)] for _ in range(GRID_H)]
    for i in range(GRID_W):
        grid[0][i] = "A"; grid[GRID_H-1][i] = "A"
    for j in range(GRID_H):
        grid[j][0] = "A"; grid[j][GRID_W-1] = "A"
    # 缺口
    grid[GY][0] = "_"; grid[GY][GRID_W-1] = "_"
    grid[0][GX1] = "_"; grid[0][GX2] = "_"
    grid[GRID_H-1][GX1] = "_"; grid[GRID_H-1][GX2] = "_"

    if rtype == "vcorr":
        # 中央纵向走廊：列 18-29 开放；两侧（列 2-17 / 30-45）贴块（高密度）
        road_cols = range(18, 30)
        side = [(2, 16, 2, 22), (31, 45, 2, 22)]
        place_blocks(grid, side, blocks, rng, 9 + rng.randint(0, 3))
        # 走廊两侧沿廊装饰带（列 17 / 30）→ 走廊边界分明
        for j in range(2, 23):
            for i in (17, 30):
                if grid[j][i] == "_" and rng.random() < 0.5:
                    grid[j][i] = "_" + pick_decor(rng, decor, dtotal)
        # 走廊内稀疏装饰
        for j in range(2, 23):
            for i in road_cols:
                if grid[j][i] == "_" and rng.random() < 0.02:
                    grid[j][i] = "_" + pick_decor(rng, decor, dtotal)
    else:  # hall
        road = range(5, 20), range(8, 40)
        edge = [(2, 45, 2, 4), (2, 45, 20, 22), (2, 7, 5, 19), (40, 45, 5, 19)]
        place_blocks(grid, edge, blocks, rng, 6 + rng.randint(0, 3))
        road_y = road[0]
        road_x = road[1]
        for j in road_y:
            for i in road_x:
                if grid[j][i] == "_" and rng.random() < 0.04:
                    grid[j][i] = "_" + pick_decor(rng, decor, dtotal)
    return grid

def pick_decor(rng, decor, total):
    r = rng.randint(0, total - 1)
    acc = 0
    for ch, w in decor:
        acc += w
        if r < acc:
            return ch
    return "-"

def bfs(grid):
    seen = set()
    dq = deque()
    for s in [(GY,0),(GY,GRID_W-1),(0,GX1),(0,GX2),(GRID_H-1,GX1),(GRID_H-1,GX2)]:
        if grid[s[0]][s[1]][0] not in WALL:
            seen.add(s); dq.append(s)
    while dq:
        y, x = dq.popleft()
        for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
            ny, nx = y+dy, x+dx
            if 0 <= ny < GRID_H and 0 <= nx < GRID_W and (ny,nx) not in seen:
                if grid[ny][nx][0] not in WALL:
                    seen.add((ny,nx)); dq.append((ny,nx))
    return seen

def validate(grid, rtype):
    errs = []
    if len(grid) != GRID_H or any(len(r) != GRID_W for r in grid):
        errs.append("尺寸")
    if grid[GY][0] in WALL or grid[GY][-1] in WALL or grid[0][GX1] in WALL or grid[-1][GX2] in WALL:
        errs.append("缺口被封")
    seen = bfs(grid)
    for j in range(GRID_H):
        for i in range(GRID_W):
            if grid[j][i][0] not in WALL and (j, i) not in seen:
                errs.append(f"孤岛({j},{i})")
                return errs
    if rtype == "vcorr":
        for j in range(2, 23):
            for i in range(18, 30):
                if grid[j][i][0] in WALL:
                    errs.append(f"走廊被封({j},{i})")
                    return errs
    return errs

def main():
    rng = random.Random(20260819)
    bio_blocks, bio_decor = load_biomes("build/grammar-data2.txt")
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 200
    fails = 0
    for k in range(n):
        biome = rng.choice(["stable", "sewer"])
        rtype = rng.choice(["vcorr", "hall"])
        grid = gen_v2(rng, biome, rtype, bio_blocks, bio_decor)
        errs = validate(grid, rtype)
        if errs:
            fails += 1
            if fails <= 3:
                print("FAIL", biome, rtype, errs[:3])
    print(f"=== RRSynth v2 验证: {n} 房 ===")
    print("不变式失败: " + str(fails))
    print("✓ 全部通过" if fails == 0 else "✗ 有失败")

    # 视觉样本
    print("\n=== 视觉样本 ===")
    for biome, rtype in [("stable","vcorr"), ("sewer","hall"), ("plant","vcorr"), ("mane","hall")]:
        grid = gen_v2(rng, biome, rtype, bio_blocks, bio_decor)
        print(f"--- {biome}/{rtype} ---")
        for row in grid:
            print("".join(c.ljust(2) for c in row))

if __name__ == "__main__":
    main()
