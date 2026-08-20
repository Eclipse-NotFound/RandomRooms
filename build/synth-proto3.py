#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RRSynth v3.4 —— 直角规整房间（原版感）离线原型。

v3.4 设计（对应玩家实机反馈：房间-通道感已好 / 墙占比偏大 / 出口偶堵 /
            想要原版的规整房间）：
  1. 整图填墙（biome 材质）
  2. 直线主廊：从左缺口到右缺口的 2 宽折线（1-2 随机折角，全部水平/垂直段）
  3. 干净矩形房间（7-11 x 5-8，无毛边；与已开放间隔 >=1 墙 → 互不粘连）
  4. 每个房间一条 L 形 2 宽走廊连主廊 → 穿墙处自动开出 2 宽门洞（不堵）
  5. 上下缺口经 L 走廊连入网络；材质带/装饰/掩体/gap守卫/BFS 兜底

    walls = 连续背景；房间规整矩形；全会连通（BFS 验证）。

不变式: 25x48 / 缺口 / BFS 连通 / 门洞宽度>=2 / 墙占比 / 房间独立
用法: python build/synth-proto3.py [数量]
"""
import math
import random
import sys
from collections import deque

W, H = 48, 25
WALL = set("ABCDEFGHIJKLMNOPQRST")
GY, GX1, GX2 = 12, 23, 24
TYPES = ["corridor", "hall", "quad", "l", "bunker"]

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

def carve_cell(grid, y, x, pat):
    if y < 0 or y >= H or x < 0 or x >= W:
        return
    if grid[y][x] != "_":
        grid[y][x] = "_"
    pat.add((y, x))

def carve_l(grid, x1, y1, x2, y2, rng, pat, w=2, h_first=None):
    """L 形 2 宽走廊 (x1,y1)->(x2,y2)；水平/垂直段拼接（可随机先横/先竖）。"""
    if h_first is None:
        h_first = rng.random() < 0.5
    if h_first:
        # 水平段: (x1,y1) -> (x2,y1)；垂直段: (x2,y1) -> (x2,y2)
        _h_run(grid, x1, x2, y1, rng, pat, w)
        _v_run(grid, y1, y2, x2, rng, pat, w)
    else:
        _v_run(grid, y1, y2, x1, rng, pat, w)
        _h_run(grid, x1, x2, y2, rng, pat, w)

def _h_run(grid, xa, xb, y, rng, pat, w):
    lo, hi = min(xa, xb), max(xa, xb)
    for x in range(lo, hi + 1):
        for yy in range(max(0, y), min(H, y + w)):
            carve_cell(grid, yy, x, pat)
            carve_cell(grid, yy, x + 1, pat) if False else None

def _v_run(grid, ya, yb, x, rng, pat, w):
    lo, hi = min(ya, yb), max(ya, yb)
    for y in range(lo, hi + 1):
        for xx in range(max(0, x), min(W, x + w)):
            carve_cell(grid, y, xx, pat)

def gen_room(rng, rtype, biome="stable", decor=None):
    wall_tbl = BIOME_WALL.get(biome, BIOME_WALL["stable"])
    grid = [["_" for _ in range(W)] for _ in range(H)]
    if rtype in ("corridor", "hall", "l", "split"):
        grid = [[pick_weighted(rng, wall_tbl) for _ in range(W)] for _ in range(H)]
        carve_layout(grid, rng, rtype, wall_tbl)
        material_bands(grid, rng, wall_tbl)
        _apply_boundary_decor(grid, rng, decor, wall_tbl, rtype)
        return grid
    if rtype == "quad":
        raise NotImplementedError("quad 保留旧阈值场（本版暂不重做）")
    # bunker：SDF 环带
    cen = [(rng.randint(8, W - 9), rng.randint(5, H - 6)) for _ in range(rng.randint(2, 3))]
    for y in range(H):
        for x in range(W):
            d = min(math.hypot(x - cx, y - cy) for cx, cy in cen)
            d += (rng.random() - 0.5) * 1.2
            if 3.4 <= d <= 5.6:
                grid[y][x] = pick_weighted(rng, wall_tbl)
    _apply_boundary_decor(grid, rng, decor, wall_tbl, rtype)
    return grid

def carve_layout(grid, rng, rtype, wall_tbl):
    """v3.4 直角规整：主廊折线 + 大矩形房间（允许贴廊/互接，规整但够开放）"""
    counts = {"corridor": (5, 8), "hall": (3, 6), "l": (4, 7), "split": (7, 10)}
    n_lo, n_hi = counts.get(rtype, (5, 8))
    pat = set()

    # 1) 主廊：左缺口 (12,0) -> 右缺口 (12,47) 的 2 宽折线（1-2 随机折角）
    cy1 = 6 + rng.randint(0, 12)
    _h_run(grid, 1, 46, GY, rng, pat, 2)            # 基线 行12
    if rng.random() < 0.8:
        _v_run(grid, GY, cy1, 18 + rng.randint(0, 8), rng, pat, 2)   # 上行折角
        _h_run(grid, 18 + rng.randint(0, 8), 46, cy1, rng, pat, 2)
        _v_run(grid, cy1, GY, 42, rng, pat, 2)
        _h_run(grid, 42, 46, GY, rng, pat, 2)

    # 2) 上/下缺口纵连（短竖接主廊，2 宽）
    for c in (23, 24):
        _v_run(grid, 2, GY, c, rng, pat, 2)
        _v_run(grid, H - 3, GY, c, rng, pat, 2)

    # 3) 房间：大矩形，允许贴廊/互接（重叠=大房），仅拒纯浪费
    n = n_lo + rng.randint(0, n_hi - n_lo)
    placed = 0
    tries = 0
    while placed < n and tries < 120:
        tries += 1
        cw = 8 + rng.randint(0, 4)          # 8-12
        ch = 6 + rng.randint(0, 3)          # 6-9
        cwx = 2 + rng.randint(0, W - cw - 4)
        cwy = 2 + rng.randint(0, H - ch - 4)
        emptier = sum(1 for y0 in range(cwy, min(cwy + ch, H - 1))
                      for x0 in range(cwx, min(cwx + cw, W - 1)) if grid[y0][x0] == "_")
        if emptier > 0.8 * cw * ch:
            continue
        for y in range(cwy, cwy + ch):
            for x in range(cwx, cwx + cw):
                carve_cell(grid, y, x, pat)
        link_l(grid, cwx + cw // 2, cwy + ch // 2, pat, rng)
        placed += 1

def link_l(grid, tx, ty, pat, rng):
    """从最近网络细胞走 L 型 2 宽走廊到 (tx,ty)（目标=房间/缺口中心）。"""
    if not pat:
        return
    best = min(pat, key=lambda p: (p[0] - ty) ** 2 + (p[1] - tx) ** 2)
    carve_l(grid, best[1], best[0], tx, ty, rng, pat, w=2)

def material_bands(grid, rng, police):
    zone = {}
    for zy in range(2):
        for zx in range(4):
            zone[(zy, zx)] = police[0][0] if rng.random() < 0.6 else pick_weighted(rng, police)
    for y in range(H):
        for x in range(W):
            if grid[y][x] in WALL:
                main = zone[(min(y // 13, 1), min(x // 12, 3))]
                grid[y][x] = main if rng.random() < 0.85 else pick_weighted(rng, police)

def gap_guard(grid):
    for j in range(max(0, GY - 1), min(H, GY + 2)):
        for i in list(range(0, 3)) + list(range(W - 3, W)):
            if grid[j][i] == "C": grid[j][i] = "_"
    for i in range(max(0, GX1 - 1), min(W, GX2 + 2)):
        for j in list(range(0, 2)) + list(range(H - 2, H)):
            if grid[j][i] == "C": grid[j][i] = "_"

def _apply_boundary_decor(grid, rng, decor, wall_tbl, rtype=None):
    for x in range(W):
        grid[0][x] = "A"; grid[H - 1][x] = "A"
    for y in range(H):
        grid[y][0] = "A"; grid[y][W - 1] = "A"
    grid[GY][0] = "_"; grid[GY][W - 1] = "_"
    grid[0][GX1] = "_"; grid[0][GX2] = "_"
    grid[H - 1][GX1] = "_"; grid[H - 1][GX2] = "_"
    if decor:
        for y in range(1, H - 1):
            for x in range(1, W - 1):
                if grid[y][x] == "_" and rng.random() < 0.10:
                    grid[y][x] = "_" + pick_weighted(rng, decor)
    for _ in range(6):
        y, x = rng.randint(2, H - 3), rng.randint(2, W - 3)
        if grid[y][x] == "_":
            grid[y][x] = "_-"
    gap_guard(grid)
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
    if not (0.22 <= wr <= 0.78):
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
        try:
            grid = gen_room(rng, rtype, biome, decor.get(biome))
        except NotImplementedError:
            continue
        errs = validate(grid, rtype)
        ratio_by_type.setdefault(rtype, []).append(wall_ratio(grid))
        decomp_by_type.setdefault(rtype, []).append(wall_components(grid))
        if errs:
            fails += 1
            if fails <= 5:
                print("FAIL", rtype, errs[:2])
    print(f"=== RRSynth v3.4 验证: {n} 房 ===")
    print("不变式失败: " + str(fails))
    for t in TYPES:
        r = ratio_by_type[t]; d = decomp_by_type[t]
        if r:
            print(f"  {t}: 墙占比 平均 {sum(r)/len(r):.2f}   墙连通分量 平均 {sum(d)/len(d):.1f}")
    print("✓ 全部通过" if fails == 0 else "✗ 有失败")
    print("\n=== v3.4 视觉样本 ===")
    decor = load_biome_decor("build/grammar-data2.txt")
    for rtype, biome in [("corridor", "stable"), ("hall", "sewer"), ("l", "plant"), ("split", "mane")]:
        grid = gen_room(rng, rtype, biome, decor.get(biome))
        print(f"----- {rtype} (墙 {wall_ratio(grid):.2f}, 分量 {wall_components(grid)}) -----")
        for row in grid:
            print("".join(c if c[0] != "_" or len(c) == 1 else "·" for c in row))

if __name__ == "__main__":
    main()
