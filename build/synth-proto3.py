#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RRSynth v3.3 —— 墙为底 + 开凿 离线原型。

范式反转（v3.3）：整图先填满墙（生物群系材质），再"挖"出：
  1. 波浪主廊（左<->右，两端包络归零接缺口，4 宽，行间缓变）
  2. 缺口纵连（上下 4 缺口，3 宽，轻微横漂）；l 型额外竖分支
  3. 随机腔室（房间，毛边+室内掩体墩+3 宽连廊）
  4. hall 中央广场
墙=一个连续背景整块（无碎块），房间/走廊=被明确挖出的特征（清晰分区）。
quad 保留阈值场（voronoi 区心开放）；bunker 保留 SDF 环带。

不变式: 25x48 / 缺口 / BFS 连通 / 墙占比 / 墙连通分量 / 样本 ASCII。
用法: python build/synth-proto3.py [数量]
"""
import math
import random
import sys
from collections import deque

W, H = 48, 25
WALL = set("ABCDEFGHIJKLMNOPQRST")
GY, GX1, GX2 = 12, 23, 24
WALL_RATIO = {"quad": 0.22}
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

def thresh_wall(flat, ratio):
    lo, hi = min(flat), max(flat)
    for _ in range(14):
        mid = (lo + hi) / 2
        if sum(1 for v in flat if v >= mid) / len(flat) > ratio:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2

def quad_field():
    centers = [(7, 7), (41, 7), (7, 18), (41, 18)]
    f = []
    for y in range(H):
        row = []
        for x in range(W):
            ds = sorted(math.hypot(x - cx, y - cy) for cx, cy in centers)
            row.append(ds[0] + 0.7 * ds[1])
        f.append(row)
    return f

def gen_room(rng, rtype, biome="stable", decor=None):
    wall_tbl = BIOME_WALL.get(biome, BIOME_WALL["stable"])
    if rtype in ("corridor", "hall", "l", "split"):
        # v3.3：墙为底整图填满，再挖房间/走廊
        grid = [[pick_weighted(rng, wall_tbl) for _ in range(W)] for _ in range(H)]
        carve_rooms(grid, rtype, rng, wall_tbl)
        material_bands(grid, rng, wall_tbl)
        _apply_boundary_decor(grid, rng, decor, wall_tbl, rtype)
        return grid
    if rtype == "quad":
        # 阈值场保留（voronoi 区心低=开放）
        grid = [["_" for _ in range(W)] for _ in range(H)]
        f = quad_field()
        flat = [v for row in f for v in row]
        th = thresh_wall(flat, WALL_RATIO["quad"])
        for y in range(H):
            for x in range(W):
                if f[y][x] >= th:
                    grid[y][x] = pick_weighted(rng, wall_tbl)
        carve_rooms(grid, rtype, rng, wall_tbl)
        material_bands(grid, rng, wall_tbl)
        _apply_boundary_decor(grid, rng, decor, wall_tbl, rtype)
        return grid
    # bunker：SDF 环带独立画墙
    grid = [["_" for _ in range(W)] for _ in range(H)]
    cen = [(rng.randint(8, W - 9), rng.randint(5, H - 6)) for _ in range(rng.randint(2, 3))]
    for y in range(H):
        for x in range(W):
            d = min(math.hypot(x - cx, y - cy) for cx, cy in cen)
            d += (rng.random() - 0.5) * 1.2
            if 3.4 <= d <= 5.6:
                grid[y][x] = pick_weighted(rng, wall_tbl)
    _apply_boundary_decor(grid, rng, decor, wall_tbl, rtype)
    return grid

PATHDIR = []

def carve_cell(grid, y, x):
    if y < 0 or y >= H or x < 0 or x >= W:
        return
    if grid[y][x] != "_":
        grid[y][x] = "_"
    PATHDIR.append((y, x))

def connect_chamber(grid, cy0, cx0):
    """腔室中心 -> 最近连通细胞（曼哈顿逼近，3 宽）"""
    if not PATHDIR:
        return
    best = min(PATHDIR, key=lambda p: (p[0] - cy0) ** 2 + (p[1] - cx0) ** 2)
    ty, tx = best
    st = 0
    while (ty != cy0 or tx != cx0) and st < 90:
        st += 1
        carve_cell(grid, ty, tx)
        carve_cell(grid, ty, tx + 1)
        carve_cell(grid, ty, tx + 2)
        px = 1 if cx0 > tx else (-1 if cx0 < tx else 0)
        py = 1 if cy0 > ty else (-1 if cy0 < ty else 0)
        if px == 0:
            ty += py
        elif py == 0:
            tx += px
        elif rng.random() < 0.55:
            tx += px
        else:
            ty += py

def link_room(grid, rng, cy0, cx0):
    """房间中心 -> 最近网络细胞（2 宽蜿蜒走道，有机连接房间）"""
    if not PATHDIR:
        return
    best = min(PATHDIR, key=lambda p: (p[0] - cy0) ** 2 + (p[1] - cx0) ** 2)
    y, x = best          # 自网络端起，向房间中心走
    st = 0
    while (y != cy0 or x != cx0) and st < 130:
        st += 1
        carve_cell(grid, y, x)
        carve_cell(grid, y, x + 1)
        dx = cx0 - x
        dy = cy0 - y
        if abs(dx) >= abs(dy):
            x += 1 if dx > 0 else -1
            if rng.random() < 0.25 and y != cy0:
                y += 1 if dy > 0 else -1
        else:
            y += 1 if dy > 0 else -1
            if rng.random() < 0.25 and x != cx0:
                x += 1 if dx > 0 else -1
        x = max(1, min(W - 2, x))
        y = max(1, min(H - 2, y))

def place_room(grid, rng, wall_tbl, cx, cy, cw, ch):
    """房间 = 内部挖空(毛边) + 朝走廊开 1 宽门 + 3 宽门廊 + 封堵多余口。
       使每个房间读作独立房间（门洞进/出），不会并成大空间。"""
    interior = set()
    for y in range(cy, cy + ch):
        for x in range(cx, cx + cw):
            border = (y == cy or y == cy + ch - 1 or x == cx or x == cx + cw - 1)
            if border and rng.random() < 0.22:      # 毛边：边格留墙牙
                continue
            carve_cell(grid, y, x)
            interior.add((y, x))
    if not interior:
        return
    # 门：房间边朝最近走廊细胞，取门面 1 格
    mcy = cy + ch // 2
    mcx = cx + cw // 2
    best = min(PATHDIR, key=lambda p: (p[0] - mcy) ** 2 + (p[1] - mcx) ** 2)
    dyy = best[0] - mcy
    dxx = best[1] - mcx
    if abs(dxx) >= abs(dyy):
        door = (mcy, cx - 1 if dxx <= 0 else cx + cw)
    else:
        door = (cy - 1 if dyy <= 0 else cy + ch, mcx)
    door = (max(0, min(H - 1, door[0])), max(0, min(W - 1, door[1])))
    carve_cell(grid, door[0], door[1])
    # 门廊：门 -> 最近走廊细胞（3 宽）
    ty, tx = best
    dy2, dx2 = door
    for st in range(60):
        carve_cell(grid, ty, tx)
        carve_cell(grid, ty, tx + 1)
        carve_cell(grid, ty, tx + 2)
        if ty == dy2 and tx == dx2:
            break
        px = 1 if dx2 > tx else (-1 if dx2 < tx else 0)
        py = 1 if dy2 > ty else (-1 if dy2 < ty else 0)
        if px == 0:
            ty += py
        elif py == 0:
            tx += px
        elif rng.random() < 0.5:
            tx += px
        else:
            ty += py
    # 封多余嘴：房间边格(非门) 若与房间外开放相邻 → 补墙（只留门洞）
    for (y, x) in interior:
        if (y == cy or y == cy + ch - 1 or x == cx or x == cx + cw - 1) and (y, x) != door:
            if grid[y][x] == "_":
                for dy3, dx3 in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy3, x + dx3
                    if (ny, nx) not in interior and 0 <= ny < H and 0 <= nx < W and grid[ny][nx] == "_":
                        grid[y][x] = pick_weighted(rng, wall_tbl)
                        break

def carve_rooms(grid, rtype, rng, wall_tbl):
    """v3.3 墙为底 + 挖房间/走廊（无固定直线模板，每次形态不同）"""
    global PATHDIR
    PATHDIR = []
    counts = {"corridor": (4, 6), "hall": (3, 5), "l": (4, 6), "split": (6, 9), "quad": (2, 4)}
    n_lo, n_hi = counts.get(rtype, (4, 6))

    # 1) 脊柱：3 宽蜿蜒（左<->右接缺口）
    cy = float(GY)
    A = 1.0 + rng.random() * 2.0
    kk = 0.16 + rng.random() * 0.3
    ph = rng.random() * 6.283
    for x in range(1, W - 1):
        env = math.sin(math.pi * x / (W - 1))
        t = GY + A * env * math.sin(kk * x + ph) + (rng.random() - 0.5) * 1.0
        if t - cy > 1.0:
            t = cy + 1.0
        elif t - cy < -1.0:
            t = cy - 1.0
        t = max(4.0, min(H - 5.0, t))
        cy = t
        yy0 = int(round(t)) - 1
        for yy in range(yy0, yy0 + 3):
            if 1 <= yy < H - 1:
                carve_cell(grid, yy, x)

    # 2) 上/下缺口纵连 3 宽
    for c in (23, 24):
        for y in range(2, 12):
            vcx = max(4, min(W - 5, c + int(round((rng.random() - 0.5) * 4))))
            carve_cell(grid, y, vcx - 1)
            carve_cell(grid, y, vcx)
            carve_cell(grid, y, vcx + 1)
        for y in range(22, 11, -1):
            vcx = max(4, min(W - 5, c + int(round((rng.random() - 0.5) * 4))))
            carve_cell(grid, y, vcx - 1)
            carve_cell(grid, y, vcx)
            carve_cell(grid, y, vcx + 1)

    # 3) hall 中央广场 / l 竖分支
    if rtype == "hall":
        px0 = 12 + rng.randint(0, 6)
        py0 = 7 + rng.randint(0, 3)
        pw = 12 + rng.randint(0, 8)
        ph = 6 + rng.randint(0, 4)
        y = py0
        while y < py0 + ph and y < H - 2:
            x = px0
            while x < px0 + pw and x < W - 2:
                carve_cell(grid, y, x)
                x += 1
            y += 1
    if rtype == "l":
        bx = 28 + rng.randint(0, 10)
        for y in range(20, 5, -1):
            bvcx = max(4, min(W - 5, bx + int(round((rng.random() - 0.5) * 5))))
            carve_cell(grid, y, bvcx - 1)
            carve_cell(grid, y, bvcx)
            carve_cell(grid, y, bvcx + 1)

    # 4) 房间为主体：矩形挖空(毛边) + 2 宽蜿蜒走道连入网络 → 房间间墙自然分隔
    n = n_lo + rng.randint(0, n_hi - n_lo)
    placed = 0
    tries = 0
    while placed < n and tries < 100:
        tries += 1
        cw = 7 + rng.randint(0, 4)          # 7-11
        ch = 5 + rng.randint(0, 3)          # 5-8
        cwx = 2 + rng.randint(0, W - cw - 5)
        cwy = 2 + rng.randint(0, H - ch - 5)
        emptier = sum(1 for y0 in range(cwy, min(cwy + ch, H - 1))
                      for x0 in range(cwx, min(cwx + cw, W - 1)) if grid[y0][x0] == "_")
        if emptier > 0.8 * cw * ch:
            continue
        for y in range(cwy, cwy + ch):
            for x in range(cwx, cwx + cw):
                border = (y == cwy or y == cwy + ch - 1 or x == cwx or x == cwx + cw - 1)
                if border and rng.random() < 0.18:
                    continue
                carve_cell(grid, y, x)
        link_room(grid, rng, cwy + ch // 2, cwx + cw // 2)
        placed += 1

def material_bands(grid, rng, police):
    """材质带：2x4 大区主字符，区内 85% 同色 → 墙整体统一材质感"""
    h, w = len(grid), len(grid[0])
    zone = {}
    for zy in range(2):
        for zx in range(4):
            zone[(zy, zx)] = police[0][0] if rng.random() < 0.6 else pick_weighted(rng, police)
    for y in range(h):
        for x in range(w):
            if grid[y][x] in WALL:
                main = zone[(min(y // 13, 1), min(x // 12, 3))]
                grid[y][x] = main if rng.random() < 0.85 else pick_weighted(rng, police)

def _quad_gates(grid):
    """四区门洞：中央十字挖通四区"""
    for y in (11, 12, 13):
        for x in (22, 23, 24, 25):
            if grid[y][x] in WALL: grid[y][x] = "_"
    for x in (21, 22, 23, 24, 25, 26):
        for y in (11, 13):
            if grid[y][x] in WALL: grid[y][x] = "_"

def gap_guard(grid):
    """缺口保护：缺口 3x3 邻域与向心隧道强制开放 → 通道不被堵"""
    for j in range(max(0, GY - 1), min(H, GY + 2)):
        for i in range(0, 3):
            if grid[j][i] == "C": grid[j][i] = "_"
        for i in range(W - 3, W):
            if grid[j][i] == "C": grid[j][i] = "_"
    for i in range(max(0, GX1 - 1), min(W, GX2 + 2)):
        for j in range(0, 2):
            if grid[j][i] == "C": grid[j][i] = "_"
        for j in range(H - 2, H):
            if grid[j][i] == "C": grid[j][i] = "_"
    # 向心隧道：从缺口往内探 3 格挖通（左右水平 / 上下垂直）
    for j in range(max(0, GY - 1), min(H, GY + 2)):
        for i in range(3, 8):
            if grid[j][i] == "C": grid[j][i] = "_"
        for i in range(W - 8, W - 3):
            if grid[j][i] == "C": grid[j][i] = "_"
    for i in range(max(0, GX1 - 1), min(W, GX2 + 2)):
        for j in range(2, 7):
            if grid[j][i] == "C": grid[j][i] = "_"
        for j in range(H - 7, H - 2):
            if grid[j][i] == "C": grid[j][i] = "_"

def _apply_boundary_decor(grid, rng, decor, wall_tbl, rtype=None):
    for x in range(W):
        grid[0][x] = "A"; grid[H - 1][x] = "A"
    for y in range(H):
        grid[y][0] = "A"; grid[y][W - 1] = "A"
    grid[GY][0] = "_"; grid[GY][W - 1] = "_"
    grid[0][GX1] = "_"; grid[0][GX2] = "_"
    grid[H - 1][GX1] = "_"; grid[H - 1][GX2] = "_"
    # 装饰：开放格按 biome 频率布置（shelf/rear 后缀 + 少量水/杂物），密度微升填房间
    if decor:
        tot = sum(w for _, w in decor)
        for y in range(1, H - 1):
            for x in range(1, W - 1):
                if grid[y][x] == "_" and rng.random() < 0.10:
                    grid[y][x] = "_" + pick_weighted(rng, decor)
    # 掩体桌：少数开放格放"桌子/掩体"
    for _ in range(6):
        y, x = rng.randint(2, H - 3), rng.randint(2, W - 3)
        if grid[y][x] == "_":
            grid[y][x] = "_-"
    if rtype == "quad":
        _quad_gates(grid)
    gap_guard(grid)
    bfs_fill(grid)   # 最后 BFS：确保所有开放格都纳入缺口连通网络

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

def wall_components(grid):
    """墙连通分量数（v3.3 应为 1 + 室内掩体墩数，验证'无破碎'）"""
    seen = set(); comps = 0; sizes = []
    for y in range(H):
        for x in range(W):
            if grid[y][x][0] in WALL and (y, x) not in seen:
                comps += 1; sz = 0; dq = deque([(y, x)]); seen.add((y, x))
                while dq:
                    cy, cx = dq.popleft(); sz += 1
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < H and 0 <= nx < W and (ny, nx) not in seen and grid[ny][nx][0] in WALL:
                            seen.add((ny, nx)); dq.append((ny, nx))
                sizes.append(sz)
    sizes.sort(reverse=True)
    return comps, sizes[:2]

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
    if not (0.15 <= wr <= 0.78):
        errs.append(f"墙占比异常 {wr:.2f}")
    return errs

def main():
    rng = random.Random(20260820)
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 500
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
        decomp_by_type.setdefault(rtype, []).append(wall_components(grid)[0])
        if errs:
            fails += 1
            if fails <= 5:
                print("FAIL", rtype, errs[:2])
    print(f"=== RRSynth v3.3 验证: {n} 房 ===")
    print("不变式失败: " + str(fails))
    for t in TYPES:
        r = ratio_by_type[t]; d = decomp_by_type[t]
        if r:
            print(f"  {t}: 墙占比 平均 {sum(r)/len(r):.2f}   墙连通分量 平均 {sum(d)/len(d):.1f}")
    print("✓ 全部通过" if fails == 0 else "✗ 有失败")
    # 样本
    print("\n=== v3.3 视觉样本 ===")
    decor = load_biome_decor("build/grammar-data2.txt")
    for rtype, biome in [("corridor", "stable"), ("hall", "sewer"), ("l", "plant"), ("split", "mane"), ("bunker", "mane")]:
        grid = gen_room(rng, rtype, biome, decor.get(biome))
        print(f"----- {rtype} (墙 {wall_ratio(grid):.2f}) -----")
        for row in grid:
            print("".join(c if c[0] != "_" or len(c) == 1 else "d" for c in row))

if __name__ == "__main__":
    main()
