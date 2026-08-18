#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RRSynth M2 —— 合成房生成器原型（离线验证）。

算法（路线 A 模板拼接）：
  1. 48x24 网格全空地（`_`）；
  2. 外圈边界墙（语料最常见 'A'）；
  3. 内部随机铺 5-8 个墙块（词典来自 grammar-data.txt）；
  4. 空地 5% 加装饰后缀（语料频率加权）；
  5. 统一缺口（左右=行12，上下=列23/24）——生成器直接画；
  6. BFS 可达性：所有空地连通（从 6 个缺口格出发）；
     不可达空地回填墙；
  7. 不变式断言批量验证。

用法: python build/synth-proto.py [生成数]
"""
import random
import re
import sys
from collections import Counter

GRID_W = 48
GRID_H = 24
BLOCK_W = 6
BLOCK_H = 4
WALLCHARS = set("ABCDEFGHIJKLMNOPQRST")
# 缺口（与 RRCook.normalizeGaps 一致）
GY = 12
GX1, GX2 = 23, 24

def load_blocks(path):
    """从 grammar-data.txt 解析块词典。"""
    blocks = []
    lines = open(path, encoding="utf-8").read().splitlines()
    i = 0
    while i < len(lines):
        if lines[i].startswith("BLOCK "):
            rows = []
            for k in range(1, BLOCK_H + 1):
                rows.append(lines[i + k].strip().split("|"))
            blocks.append(rows)
            i += BLOCK_H + 1
        else:
            i += 1
    return blocks

DECOR_WEIGHTS = [("-", 5058), ("Е", 4437), ("Р", 1371), ("К", 1261),
                 ("Д", 571), ("И", 470), ("Й", 414), ("В", 399),
                 ("Н", 378), ("Г", 350), ("М", 117), ("Л", 115)]

def gen_room(rng, blocks):
    grid = [["_" for _ in range(GRID_W)] for _ in range(GRID_H)]
    # 外圈边界墙
    for i in range(GRID_W):
        grid[0][i] = "A"
        grid[GRID_H - 1][i] = "A"
    for j in range(GRID_H):
        grid[j][0] = "A"
        grid[j][GRID_W - 1] = "A"
    # 统一缺口
    for (gy, gx1, gx2) in [(GY, GX1, GX2)]:
        grid[gy][0] = "_"
        grid[gy][GRID_W - 1] = "_"
        grid[0][gx1] = "_"
        grid[0][gx2] = "_"
        grid[GRID_H - 1][gx1] = "_"
        grid[GRID_H - 1][gx2] = "_"
    # 铺块
    nblocks = rng.randint(5, 8)
    placed = 0
    attempts = 0
    while placed < nblocks and attempts < 120:
        attempts += 1
        blk = rng.choice(blocks)
        bx = rng.randint(2, GRID_W - 2 - BLOCK_W)
        by = rng.randint(2, GRID_H - 2 - BLOCK_H)
        # 与已铺块最小间距 1（避免大面积连墙）
        ok = True
        for dj in range(-1, BLOCK_H + 1):
            for di in range(-1, BLOCK_W + 1):
                y, x = by + dj, bx + di
                if 0 <= y < GRID_H and 0 <= x < GRID_W and grid[y][x] != "_":
                    ok = False
                    break
            if not ok:
                break
        if not ok:
            continue
        for dj in range(BLOCK_H):
            for di in range(BLOCK_W):
                code = blk[dj][di]
                if code:
                    grid[by + dj][bx + di] = code
        placed += 1
    # 装饰后缀（空地 5%）
    total = sum(w for _, w in DECOR_WEIGHTS)
    for j in range(1, GRID_H - 1):
        for i in range(1, GRID_W - 1):
            if grid[j][i] == "_" and rng.random() < 0.05:
                r = rng.randint(0, total - 1)
                acc = 0
                for ch, w in DECOR_WEIGHTS:
                    acc += w
                    if r < acc:
                        grid[j][i] = ch
                        break
    # BFS 可达性（从缺口格出发）
    from collections import deque
    starts = [(GY, 0), (GY, GRID_W - 1), (0, GX1), (0, GX2), (GRID_H - 1, GX1), (GRID_H - 1, GX2)]
    seen = set()
    dq = deque()
    for s in starts:
        if grid[s[0]][s[1]][0] not in WALLCHARS:
            seen.add(s)
            dq.append(s)
    while dq:
        y, x = dq.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < GRID_H and 0 <= nx < GRID_W and (ny, nx) not in seen:
                if grid[ny][nx][0] not in WALLCHARS:
                    seen.add((ny, nx))
                    dq.append((ny, nx))
    # 不可达空地回填墙
    filled = 0
    for j in range(GRID_H):
        for i in range(GRID_W):
            if grid[j][i][0] not in WALLCHARS and (j, i) not in seen:
                grid[j][i] = "C"
                filled += 1
    return grid, placed, filled

def assert_invariants(grid, name):
    errs = []
    if len(grid) != GRID_H or any(len(r) != GRID_W for r in grid):
        errs.append("尺寸错误")
    # 缺口
    if grid[GY][0][0] in WALLCHARS or grid[GY][GRID_W - 1][0] in WALLCHARS:
        errs.append("左右缺口被封")
    if grid[0][GX1][0] in WALLCHARS or grid[GRID_H - 1][GX2][0] in WALLCHARS:
        errs.append("上下缺口被封")
    # 墙占比
    cells = [c for row in grid for c in row]
    wall = sum(1 for c in cells if c[0] in WALLCHARS)
    ratio = wall / len(cells)
    if ratio > 0.5:
        errs.append(f"墙占比过高 {ratio:.2f}")
    if errs:
        print(f"[FAIL] {name}: {errs}")
        return False
    return True

def main():
    rng = random.Random(20260818)
    blocks = load_blocks("build/grammar-data.txt")
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 200
    stats = Counter()
    fails = 0
    for k in range(n):
        grid, placed, filled = gen_room(rng, blocks)
        stats["placed"] += placed
        stats["filled"] += filled
        if not assert_invariants(grid, f"syn_{k}"):
            fails += 1
            if fails <= 3:
                for row in grid:
                    print("  " + "|".join(row))
    print(f"=== RRSynth 原型验证: {n} 房 ===")
    print(f"平均铺块 {stats['placed']/n:.1f} / 回填墙 {stats['filled']/n:.1f} 格")
    print(f"不变式失败: {fails}")
    print("✓ 全部通过" if fails == 0 else "✗ 有失败")

if __name__ == "__main__":
    main()
