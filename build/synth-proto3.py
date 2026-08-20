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
WALL_RATIO = {"corridor": 0.25, "hall": 0.18, "quad": 0.30, "l": 0.24, "bunker": 0.28}
TYPES = ["corridor", "hall", "quad", "l", "bunker"]

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

def gen_room(rng, rtype):
    grid = [["_" for _ in range(W)] for _ in range(H)]
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
                    grid[y][x] = "C"
        for x in range(W):
            grid[0][x] = "A"; grid[H - 1][x] = "A"
        for y in range(H):
            grid[y][0] = "A"; grid[y][W - 1] = "A"
        grid[GY][0] = "_"; grid[GY][W - 1] = "_"
        grid[0][GX1] = "_"; grid[0][GX2] = "_"
        grid[H - 1][GX1] = "_"; grid[H - 1][GX2] = "_"
        bfs_fill(grid)
        return grid
    # 除 bunker 外：二分阈值 + 开放掩码(-1)保留
    flat = [v for row in f for v in row if v >= 0]
    th = thresh_wall(flat, WALL_RATIO[rtype])
    for y in range(H):
        for x in range(W):
            v = f[y][x]
            if v >= 0 and v >= th:
                grid[y][x] = "C"
    for x in range(W):
        grid[0][x] = "A"; grid[H - 1][x] = "A"
    for y in range(H):
        grid[y][0] = "A"; grid[y][W - 1] = "A"
    grid[GY][0] = "_"; grid[GY][W - 1] = "_"
    grid[0][GX1] = "_"; grid[0][GX2] = "_"
    grid[H - 1][GX1] = "_"; grid[H - 1][GX2] = "_"
    bfs_fill(grid)
    return grid

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
    for k in range(n):
        rtype = rng.choice(TYPES)
        grid = gen_room(rng, rtype)
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
    for rtype in ["corridor", "hall", "quad", "l", "bunker"]:
        grid = gen_room(rng, rtype)
        print(f"----- {rtype} (墙 {wall_ratio(grid):.2f}) -----")
        for row in grid:
            print("".join(c.ljust(2) for c in row))

if __name__ == "__main__":
    main()
