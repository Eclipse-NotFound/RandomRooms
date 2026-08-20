#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RRSynth v3 —— M1 场合成器离线原型。

四种连续场技法：
  1. value_noise  值噪声 → 双阈值 → 弯曲连续墙带（corridor/hall 主用）
  2. sdf          距离场 → 圆/椭圆掩体环墙（bunker）
  3. voronoi      区心分区 → 区界墙（quad）
  4. tunnel       锚点间挖隧道（保证缺口连通；l 形折角）

房间类型: corridor / hall / quad / l / bunker
墙密度按类型（percentile 精确控制）：corr25 hall20 quad30 l25 bunker28
不变式: 25x48 / 缺口 / 墙占比 / BFS 连通 / 样本 ASCII。
用法: python build/synth-proto3.py [数量]
"""
import math
import random
import sys
from collections import deque

W, H = 48, 25
WALL = set("ABCDEFGHIJKLMNOPQRST")
GY, GX1, GX2 = 12, 23, 24
WALL_RATIO = {"corridor": 0.17, "hall": 0.12, "quad": 0.22, "l": 0.14, "bunker": 0.20}
TYPES = ["corridor", "hall", "quad", "l", "bunker"]

# M2a：生物群系墙材质（语料统计权重）——生成时墙格按权重分配
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
    return table[0][0]

def value_noise(rng, cw=6, ch=5):
    """低分辨率随机场 → 双线性插值 → HxW 连续场 [0,1]"""
    gw, gh = (W + cw - 1) // cw + 1, (H + ch - 1) // ch + 1
    g = [[rng.random() for _ in range(gw)] for _ in range(gh)]
    f = [[0.0] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            gx = x / cw; gy = y / ch
            x0, y0 = int(gx), int(gy)
            dx, dy = gx - x0, gy - y0
            a = g[y0][x0]; b = g[y0][min(x0 + 1, gw - 1)]
            c = g[min(y0 + 1, gh - 1)][x0]; d = g[min(y0 + 1, gh - 1)][min(x0 + 1, gw - 1)]
            v = (a * (1 - dx) + b * dx) * (1 - dy) + (c * (1 - dx) + d * dx) * dy
            f[y][x] = v
    return f

def sdf_field(rng, centers=None):
    """距离场：到最近掩体中心的距离；环带 [r1,r2] 成墙"""
    if centers is None:
        n = rng.randint(2, 3)
        centers = [(rng.randint(8, W - 9), rng.randint(5, H - 6)) for _ in range(n)]
    f = [[0.0] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            f[y][x] = min(math.hypot(x - cx, y - cy) for cx, cy in centers)
    return f, centers

def percentile_thresh(f, ratio):
    vals = sorted(v for row in f for v in row)
    k = int(len(vals) * (1 - ratio))
    return vals[min(k, len(vals) - 1)]

def thresh_wall(flat, ratio):
    """二分阈值：使 f>=th 的格占比≈ratio（对聚集分布鲁棒）"""
    if not flat:
        return 0.5
    lo, hi = min(flat), max(flat)
    for _ in range(14):
        mid = (lo + hi) / 2
        cnt = sum(1 for v in flat if v >= mid) / len(flat)
        if cnt > ratio:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2

def gen_room(rng, rtype, biome="stable", decor=None):
    grid = [["_" for _ in range(W)] for _ in range(H)]
    wall_tbl = BIOME_WALL.get(biome, BIOME_WALL["stable"])
    if rtype == "corridor":
        f = value_noise(rng)
        for y in range(H):
            for x in range(18, 30):
                f[y][x] = -1.0
    elif rtype == "hall":
        f = value_noise(rng)
        for y in range(5, 20):
            for x in range(8, 40):
                f[y][x] = -1.0
    elif rtype == "quad":
        # 四区心：固定四个象限中心（避免挤在一起）
        centers = [(7, 7), (41, 7), (7, 18), (41, 18)]
        f = [[0.0] * W for _ in range(H)]
        for y in range(H):
            for x in range(W):
                ds = sorted(math.hypot(x - cx, y - cy) for cx, cy in centers)
                f[y][x] = ds[0] + 0.7 * ds[1]
    elif rtype == "l":
        f = value_noise(rng)
        for y in range(18, 23):
            for x in range(W):
                f[y][x] = -1.0
        for x in range(32, 41):
            for y in range(H):
                f[y][x] = -1.0
    else:  # bunker：SDF 环带独立画墙
        cen = [(rng.randint(8, W - 9), rng.randint(5, H - 6)) for _ in range(rng.randint(2, 3))]
        for y in range(H):
            for x in range(W):
                d = min(math.hypot(x - cx, y - cy) for cx, cy in cen)
                d += (rng.random() - 0.5) * 1.2
                if 3.4 <= d <= 5.6:
                    grid[y][x] = pick_weighted(rng, wall_tbl)
        _apply_boundary_decor(grid, rng, decor, wall_tbl, rtype)
        return grid
    # 除 bunker 外：二分阈值 + 开放掩码(-1)保留
    flat = [v for row in f for v in row if v >= 0]
    th = thresh_wall(flat, WALL_RATIO[rtype])
    for y in range(H):
        for x in range(W):
            v = f[y][x]
            if v >= 0 and v >= th:
                grid[y][x] = pick_weighted(rng, wall_tbl)   # M2a 材质场
    road_walls(grid, rtype, rng)     # v3.1 道路边墙线
    thin_walls(grid, rng)            # v3.1 墙瘦化（防山）
    material_bands(grid, rng, wall_tbl)  # v3.1 材质带
    _apply_boundary_decor(grid, rng, decor, wall_tbl, rtype)
    return grid

def _quad_gates(grid):
    """四区门洞：在区界中心线挖 2 格门洞（上下/左右十字）"""
    for y in (11, 12, 13):
        for x in (22, 23, 24, 25):
            if grid[y][x] == "C": grid[y][x] = "_"
    for x in (21, 22, 23, 24, 25, 26):
        for y in (11, 13):
            if grid[y][x] == "C": grid[y][x] = "_"
    # 四区对角连通：区界 45 度线挖门洞（简化：中央十字已足够）

def thin_walls(grid, rng):
    """墙瘦化：厚块核心挖空（3x3 8 邻墙>=13 挖 45%）×2 遍 → 墙缩成轮廓线"""
    h, w = len(grid), len(grid[0])
    def n8(y, x):
        return sum(1 for dy in (-1,0,1) for dx in (-1,0,1)
                   if (dy or dx) and 0 <= y+dy < h and 0 <= x+dx < w and grid[y+dy][x+dx] in WALL)
    for _ in range(2):
        for y in range(3, h-3):
            for x in range(3, w-3):
                if grid[y][x] in WALL and n8(y, x) >= 13 and rng.random() < 0.45:
                    grid[y][x] = "_"

def material_bands(grid, rng, police):
    """材质带：低频区域主字符（2x2 大区各取一个主字符，区内 85% 同色）"""
    h, w = len(grid), len(grid[0])
    zone = {}
    for zy in range(2):
        for zx in range(4):
            zone[(zy,zx)] = police[0][0] if rng.random()<0.6 else pick_weighted(rng, police)
    for y in range(h):
        for x in range(w):
            if grid[y][x] in WALL:
                main = zone[(min(y//13,1), min(x//12,3))]
                grid[y][x] = main if rng.random() < 0.85 else pick_weighted(rng, police)

def road_walls(grid, rtype, rng=None):
    """道路边墙线：沿开放带两侧播 1 格实墙（限播，防墙占比失控）"""
    if rtype == "corridor":
        for y in range(3, 22):
            for x in (18, 29):
                if grid[y][x] == "_":
                    grid[y][x] = "C"
    elif rtype == "hall":
        for x in range(8, 40):
            for y in (3, 21):
                if grid[y][x] == "_":
                    grid[y][x] = "C"
    elif rtype == "l":
        # 仅开放带内侧一行、隔格播（限播）
        for x in range(31, 41, 2):
            for y in range(3, 21):
                if grid[y][x] == "_":
                    grid[y][x] = "C"

def gap_guard(grid):
    """缺口保护：缺口 3x3 邻域与向心隧道强制开放 → 通道不被堵"""
    for j in range(max(0,GY-1), min(H,GY+2)):
        for i in range(0, 3):
            if grid[j][i] == "C": grid[j][i] = "_"
        for i in range(W-3, W):
            if grid[j][i] == "C": grid[j][i] = "_"
    for i in range(max(0,GX1-1), min(W,GX2+2)):
        for j in range(0, 2):
            if grid[j][i] == "C": grid[j][i] = "_"
        for j in range(H-2, H):
            if grid[j][i] == "C": grid[j][i] = "_"
    # 向心隧道：从缺口往内探 3 格挖通（左右水平 / 上下垂直）
    for j in range(max(0,GY-1), min(H,GY+2)):
        for i in range(3, 8):
            if grid[j][i] == "C": grid[j][i] = "_"
        for i in range(W-8, W-3):
            if grid[j][i] == "C": grid[j][i] = "_"
    for i in range(max(0,GX1-1), min(W,GX2+2)):
        for j in range(2, 7):
            if grid[j][i] == "C": grid[j][i] = "_"
        for j in range(H-7, H-2):
            if grid[j][i] == "C": grid[j][i] = "_"


def _apply_boundary_decor(grid, rng, decor, wall_tbl, rtype=None):
    for x in range(W):
        grid[0][x] = "A"; grid[H - 1][x] = "A"
    for y in range(H):
        grid[y][0] = "A"; grid[y][W - 1] = "A"
    grid[GY][0] = "_"; grid[GY][W - 1] = "_"
    grid[0][GX1] = "_"; grid[0][GX2] = "_"
    grid[H - 1][GX1] = "_"; grid[H - 1][GX2] = "_"
    # M2b 装饰掩体：开放格按 biome 频率稀疏布置（shelf/rear 后缀 + 少量掩体墙）
    if decor:
        tot = sum(w for _, w in decor)
        for y in range(1, H - 1):
            for x in range(1, W - 1):
                if grid[y][x] == "_" and rng.random() < 0.07:
                    grid[y][x] = "_" + pick_weighted(rng, decor)
    # 掩体：少数开放格放"桌子/掩体"
    for _ in range(6):
        y, x = rng.randint(2, H - 3), rng.randint(2, W - 3)
        if grid[y][x] == "_":
            grid[y][x] = "-"
    if rtype == "quad":
        _quad_gates(grid)
    gap_guard(grid)
    bfs_fill(grid)   # 最后 BFS：确保上面所有挖洞都纳入连通性

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
    n = sum(1 for row in grid for c in row if c[0] in WALL)
    return n / (W * H)

def validate(grid, rtype):
    errs = []
    if len(grid) != H or any(len(r) != W for r in grid):
        errs.append("尺寸")
    if grid[GY][0] in WALL or grid[GY][-1] in WALL or grid[0][GX1] in WALL or grid[-1][GX2] in WALL:
        errs.append("缺口被封")
    seen = set()
    for s in [(GY, 0), (GY, W - 1), (0, GX1), (0, GX2), (H - 1, GX1), (H - 1, GX2)]:
        if grid[s[0]][s[1]][0] not in WALL:
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
    if wr > 0.5 or wr < 0.1:
        errs.append(f"墙占比异常 {wr:.2f}")
    return errs

def main():
    rng = random.Random(20260819)
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 500
    fails = 0
    ratio_by_type = {}
    decor = load_biome_decor("build/grammar-data2.txt")
    for k in range(n):
        rtype = rng.choice(TYPES)
        biome = rng.choice(list(BIOME_WALL.keys()))
        grid = gen_room(rng, rtype, biome, decor.get(biome))
        errs = validate(grid, rtype)
        ratio_by_type.setdefault(rtype, []).append(wall_ratio(grid))
        if errs:
            fails += 1
            if fails <= 5:
                print("FAIL", rtype, errs[:2])
    print(f"=== RRSynth v3 M1 验证: {n} 房 ===")
    print("不变式失败: " + str(fails))
    for t in TYPES:
        r = ratio_by_type[t]
        if r:
            print(f"  {t}: 墙占比 平均 {sum(r)/len(r):.2f}")
    print("✓ 全部通过" if fails == 0 else "✗ 有失败")
    # 样本
    print("\n=== M1 视觉样本 ===")
    decor = load_biome_decor("build/grammar-data2.txt")
    for rtype, biome in [("corridor", "stable"), ("hall", "sewer"), ("l", "plant"), ("bunker", "mane")]:
        grid = gen_room(rng, rtype, biome, decor.get(biome))
        print(f"----- {rtype} (墙 {wall_ratio(grid):.2f}) -----")
        for row in grid:
            print("".join(c.ljust(2) for c in row))

if __name__ == "__main__":
    main()
