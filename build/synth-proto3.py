#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RRSynth v5 —— 房间-走廊骨架生成（离线原型）。

算法（回应实机反馈：碎片化水/框架地板、墙体拼贴、房间-通道不明显、要算法不要调参）：
  1. 整图填墙（biome 材质，2x4 材质带 → 墙体区域统一不拼贴）
  2. 房间（chambers）：3-8 个干净矩形，间距约束互不粘连，挖空
  3. 走廊网络：每房间 2 宽 L 形连入网络（生成树）+ 6 缺口连入网络 → 房间-通道分明
  4. 边界：0/24 行、0/47 列整墙 + 6 缺口（干净边框，游戏 ramka 渲染整齐）
  5. 装饰排：仅安全地板纹理后缀（拉丁 A-Z 排除 K=Сетка 网格地板/框架地板；
     排除 * 水、- 横梁、台阶、楼梯）→ 无碎片化水/框架
  6. 水体：仅 sewer/plant 成片池（置于开放区）
  7. 连通修复（小口袋填墙/大口袋 2 宽 L 连廊）

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
SPECIAL = set("*-,КАБВГЖЗИЙЛМОПСТНР")   # 装饰排排除：水/横梁/台阶/楼梯/网格
SPECIAL.add("K")                          # K=Сетка 网格地板（框架地板）

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

def safe_decor(tbl):
    return [(ch, c) for ch, c in tbl if ch not in SPECIAL]

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
    grid = [[pick_weighted(rng, wall_tbl) for _ in range(W)] for _ in range(H)]
    pat = set()

    # 1) 房间：干净矩形，间距约束（外扩1格不得撞已开放），挖空
    n_lo, n_hi = {"corridor": (6, 8), "hall": (5, 7), "l": (6, 8), "split": (8, 11)}[rtype]
    cw_lo, cw_hi = (9, 13) if rtype == "hall" else (8, 13)
    ch_lo, ch_hi = (7, 10) if rtype == "hall" else (6, 10)
    n = n_lo + rng.randint(0, n_hi - n_lo)
    rooms = []
    placed = 0
    tries = 0
    bi = 0
    while placed < n and tries < 160:
        tries += 1
        cw = rng.randint(cw_lo, cw_hi)
        ch = rng.randint(ch_lo, ch_hi)
        cwx = 2 + rng.randint(0, W - cw - 4)
        band = [(2, 6), (8, 14), (16, 21)][bi % 3]
        bi += 1
        cwy = min(band[0] + rng.randint(0, max(0, band[1] - band[0])), H - ch - 2)
        ok = True
        for y in range(cwy - 2, cwy + ch + 2):
            for x in range(cwx - 2, cwx + cw + 2):
                if 0 <= y < H and 0 <= x < W and (y, x) in pat:
                    ok = False
                    break
            if not ok:
                break
        if not ok:
            continue
        for y in range(cwy, cwy + ch):
            for x in range(cwx, cwx + cw):
                if grid[y][x] in WALL:
                    grid[y][x] = "_"
                pat.add((y, x))
        rooms.append((cwx + cw // 2, cwy + ch // 2))
        placed += 1

    # 2) 走廊网络：每房间 2 宽 L 形连入网络（生成树）；随后 6 缺口连入
    order = rooms[:]
    rng.shuffle(order)
    for (cx0, cy0) in order:
        link_l(grid, pat, cx0, cy0, rng)
    for (gx, gy) in [(GY, 0), (GY, W - 1), (0, GX1), (0, GX2), (H - 1, GX1), (H - 1, GX2)]:
        if (gy, gx) not in pat:
            link_l(grid, pat, gx, gy, rng)
    for _ in range(rng.randint(2, 4)):
        if len(rooms) < 2:
            break
        ra = rng.randrange(len(rooms))
        rb = rng.randrange(len(rooms))
        if ra == rb:
            continue
        link_l(grid, pat, rooms[rb][0], rooms[rb][1], rng)

    # 3) 材质带（2x4 大区主字符 90%）→ 墙体区域统一不拼贴
    material_bands(grid, rng, wall_tbl)

    # 4) 边界：0/24 行、0/47 列整墙 + 6 缺口
    for x in range(W):
        grid[0][x] = pick_weighted(rng, wall_tbl)
        grid[H - 1][x] = pick_weighted(rng, wall_tbl)
    for y in range(H):
        grid[y][0] = pick_weighted(rng, wall_tbl)
        grid[y][W - 1] = pick_weighted(rng, wall_tbl)
    grid[GY][0] = "_"; grid[GY][W - 1] = "_"
    grid[0][GX1] = "_"; grid[0][GX2] = "_"
    grid[H - 1][GX1] = "_"; grid[H - 1][GX2] = "_"

    # 5) 装饰排：仅安全地板纹理后缀
    decor_tbl = safe_decor(decor.get(biome)) if decor and decor.get(biome) else None
    if decor_tbl:
        den = {"stable": 0.40, "sewer": 0.30, "plant": 0.28, "mane": 0.34}[biome]
        for y in range(1, H - 1):
            x = 1
            while x < W - 1:
                if grid[y][x] == "_" and rng.random() < den:
                    L = rng.randint(2, 6)
                    for k in range(L):
                        xx = x + k
                        if xx < W - 1 and grid[y][xx] == "_":
                            grid[y][xx] = "_" + pick_weighted(rng, decor_tbl)
                    x += L
                else:
                    x += 1

    # 6) 水体：成片池（仅 sewer/plant，置于开放区）
    pools = {"sewer": (1, 3), "plant": (1, 2)}.get(biome, (0, 0))
    for _ in range(rng.randint(*pools)):
        pw = rng.randint(5, 11)
        ph = rng.randint(1, 3)
        px = 2 + rng.randint(0, W - pw - 4)
        py = 2 + rng.randint(0, H - ph - 3)
        for yy in range(py, py + ph):
            for xx in range(px, px + pw):
                if grid[yy][xx] == "_":
                    grid[yy][xx] = "_*"

    # 7) 连通修复
    repair(grid)
    return grid

def link_l(grid, pat, tx, ty, rng):
    """2 宽 L 形走廊：最近开放格 -> (tx,ty)（目标=房间中心/缺口）"""
    if not pat:
        return
    best = min(pat, key=lambda p: (p[0] - ty) ** 2 + (p[1] - tx) ** 2)
    y, x = best
    st = 0
    while (y, x) != (ty, tx) and st < 120:
        st += 1
        for k in range(2):
            if 0 <= x + k < W and grid[y][x + k] in WALL:
                grid[y][x + k] = "_"
            pat.add((y, x + k))
        dx = tx - x
        dy = ty - y
        if abs(dx) >= abs(dy):
            x += 1 if dx > 0 else -1
        else:
            y += 1 if dy > 0 else -1
        y = max(1, min(H - 2, y))
        x = max(1, min(W - 2, x))
    for k in range(2):
        if 0 <= x + k < W and grid[y][x + k] in WALL:
            grid[y][x + k] = "_"
        pat.add((y, x + k))

def material_bands(grid, rng, police):
    zone = {}
    for zy in range(2):
        for zx in range(4):
            zone[(zy, zx)] = police[0][0] if rng.random() < 0.6 else pick_weighted(rng, police)
    for y in range(H):
        for x in range(W):
            if grid[y][x] in WALL:
                main = zone[(min(y // 13, 1), min(x // 12, 3))]
                grid[y][x] = main if rng.random() < 0.9 else pick_weighted(rng, police)

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
    if not (0.30 <= wr <= 0.75):
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
    print(f"=== RRSynth v5 验证: {n} 房 ===")
    print("不变式失败:", fails)
    for t, rs in stats.items():
        print(f"  {t}: 墙占比 平均 {sum(rs)/len(rs):.2f}")
    print("✓ 全部通过" if fails == 0 else "✗ 有失败")
    print("\n=== v5 视觉样本 ===")
    for rtype, biome in [("corridor", "stable"), ("hall", "sewer"), ("l", "plant"), ("split", "mane")]:
        grid = gen_room(rng, rtype, biome, decor)
        print("=" * 62, rtype, biome, "墙%.2f" % wall_ratio(grid))
        for row in grid:
            print("".join("#" if c[0] in WALL else ("~" if "*" in c else ("·" if c[0] == "_" and len(c) > 1 else " ")) for c in row))

if __name__ == "__main__":
    main()
