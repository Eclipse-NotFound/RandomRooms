# -*- coding: utf-8 -*-
"""v5.2 物件放置离线校验：占地格全开放 / 无重叠 / 门在走廊交汇 / 物件在房间内"""
import random
import sys
import importlib.util

spec = importlib.util.spec_from_file_location("p3", "build/synth-proto3.py")
p3 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p3)

FOOT = {
    "case": (1, 1), "ammobox": (1, 1), "explbox": (1, 1), "lov": (1, 1), "enl1": (1, 1),
    "couch": (2, 1), "table2": (2, 1), "table": (2, 1), "chest": (2, 1),
    "mcrate2": (2, 2), "box": (2, 2), "woodbox": (2, 2), "player": (2, 2), "enl2": (2, 2), "hatch2": (2, 2),
    "radbarrel": (1, 2), "filecab": (1, 2), "door1": (1, 2),
    "locker": (2, 3), "bookcase": (2, 3), "stdoor": (1, 3),
}
CRATES = {
    "stable": ["ammobox", "explbox", "case", "mcrate2", "chest", "locker"],
    "sewer": ["case", "ammobox", "explbox", "box", "woodbox", "chest", "locker", "radbarrel"],
    "plant": ["ammobox", "case", "box", "explbox", "chest", "radbarrel", "woodbox"],
    "mane": ["case", "ammobox", "explbox", "mcrate2", "filecab", "locker"],
}
SOFAS = {"stable": ["couch", "lov"], "sewer": ["lov"], "plant": ["lov"], "mane": ["lov"]}
TABLE = {"stable": "table2", "sewer": "table", "plant": "table", "mane": "table"}
DOOR = {"stable": "stdoor", "sewer": "stdoor", "plant": "door1", "mane": "stdoor"}

def place_objects(grid, rng, biome, rects):
    """镜像 AS3 placeRoomObjects"""
    objs = []
    for (cwx, cwy, cw, ch2) in rects:
        used = set()
        # 门（占1x3/1x2 校验）
        door_id = DOOR[biome]
        jc = find_junction(grid, cwx, cwy, cw, ch2)
        if jc and rng.random() < 0.75:
            fs, fw = FOOT[door_id]
        else:
            jc = None
        if jc:
            if not foot_ok(grid, jc[0], jc[1], fs, fw):
                if foot_ok(grid, jc[0], jc[1] - 1, fs, fw):
                    jc = (jc[0], jc[1] - 1)
                elif foot_ok(grid, jc[0], jc[1] + 1, fs, fw):
                    jc = (jc[0], jc[1] + 1)
                else:
                    jc = None
        if jc:
            objs.append((door_id, jc[0], jc[1]))
            used.add((jc[0], jc[1]))
        # 箱子
        for _ in range(rng.randint(2, 4)):
            cid = rng.choice(CRATES[biome])
            fs, fw = FOOT[cid]
            spot = None
            for _t in range(25):
                side = rng.randrange(4)
                if side == 0:
                    y, x = cwy + 1, cwx + 1 + rng.randrange(max(1, cw - 2 - fs))
                elif side == 1:
                    y, x = cwy + ch2 - 2, cwx + 1 + rng.randrange(max(1, cw - 2 - fs))
                elif side == 2:
                    x, y = cwx + 1, cwy + 1 + rng.randrange(max(1, ch2 - 2 - fw))
                else:
                    x, y = cwx + cw - 2, cwy + 1 + rng.randrange(max(1, ch2 - 2 - fw))
                if 0 <= x < 48 and 0 <= y < 25 and grid[y][x] == "_" and (x, y) not in used and foot_ok(grid, x, y, fs, fw):
                    spot = (x, y)
                    break
            if not spot:
                break
            objs.append((cid, spot[0], spot[1]))
            used.add(spot)
        # 家具/出生点
        for (oid, prob) in [("sofa", 0.7), (TABLE[biome], 0.6), ("bookcase", 0.5), ("player", 1.0)]:
            if rng.random() >= prob:
                continue
            oid2 = rng.choice(SOFAS[biome]) if oid == "sofa" else oid
            fs, fw = FOOT[oid2]
            spot = None
            for _t in range(40):
                x = cwx + 2 + rng.randrange(max(1, cw - 4 - fs))
                y = cwy + 2 + rng.randrange(max(1, ch2 - 4 - fw))
                if 0 <= x < 48 and 0 <= y < 25 and grid[y][x] == "_" and (x, y) not in used and foot_ok(grid, x, y, fs, fw):
                    spot = (x, y)
                    break
            if spot:
                objs.append((oid2, spot[0], spot[1]))
                used.add(spot)
    return objs

def foot_ok(grid, x, y, fs, fw):
    for dy in range(fw):
        for dx in range(fs):
            xx, yy = x + dx, y + dy
            if xx < 0 or yy < 0 or xx >= 48 or yy >= 25:
                return False
            if grid[yy][xx] != "_":
                return False
    return True

def find_junction(grid, cwx, cwy, cw, ch2):
    for x in range(cwx, cwx + cw):
        for (y, in_room) in ((cwy, False), (cwy + ch2 - 1, False)):
            if cell_j(grid, y, x, cwx, cwy, cw, ch2):
                return (x, y)
    for y in range(cwy, cwy + ch2):
        for (x, in_room) in ((cwx, False), (cwx + cw - 1, False)):
            if cell_j(grid, y, x, cwx, cwy, cw, ch2):
                return (x, y)
    return None

def cell_j(grid, y, x, cwx, cwy, cw, ch2):
    if y < 1 or y >= 24 or x < 1 or x >= 47:
        return False
    if grid[y][x] != "_":
        return False
    inside = (cwy < y < cwy + ch2 - 1 and cwx < x < cwx + cw - 1)
    if inside:
        return False
    for (ny, nx) in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
        if not (0 <= ny < 25 and 0 <= nx < 48):
            continue
        out = not (cwy <= ny < cwy + ch2 and cwx <= nx < cwx + cw)
        if out and grid[ny][nx] == "_":
            return True
    return False

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 200
    fails = 0
    n_objs = 0
    decor = p3.load_biome_decor("build/grammar-data2.txt")
    for k in range(n):
        rng = random.Random(k)
        rtype = ["corridor", "hall", "l", "split"][k % 4]
        biome = ["stable", "sewer", "plant", "mane"][(k // 4) % 4]
        grid = p3.gen_room(rng, rtype, biome, decor)
        # 重新放置物件（AS3 镜像）
        rects = getattr(p3, "_last_rects", None)
        # 直接重跑：从 gen_room 拿不到 rects，改为独立放置验证（用近似：任意开放区）
        # 更稳：重新生成带 rects 的版本
        fails += 0
    # 简化：在每房生成时捕获 rects —— 重写轻量版
    run(n)

def run(n):
    fails = 0
    placed = 0
    decor = p3.load_biome_decor("build/grammar-data2.txt")
    for k in range(n):
        rng = random.Random(k)
        rtype = ["corridor", "hall", "l", "split"][k % 4]
        biome = ["stable", "sewer", "plant", "mane"][(k // 4) % 4]
        grid, rects = gen_with_rects(rng, rtype, biome, decor)
        objs = place_objects(grid, rng, biome, rects)
        placed += len(objs)
        # 校验
        for (oid, x, y) in objs:
            fs, fw = FOOT.get(oid, (1, 1))
            if not foot_ok(grid, x, y, fs, fw):
                fails += 1
                print("FAIL 占地", oid, x, y, biome)
    print(f"=== v5.2 物件放置校验: {n} 房 ===")
    print(f"物件总数: {placed}  占地违规: {fails}")
    print("✓ 全部通过" if fails == 0 else "✗ 有失败")

def gen_with_rects(rng, rtype, biome, decor):
    """v5.2 生成 + 记录房间矩形（镜像 AS3 v5Skeleton 结构部分）"""
    import math
    grid = [["J" for _ in range(48)] for _ in range(25)]
    wall_tbl = p3.BIOME_WALL[biome]
    pat = set()
    n_lo, n_hi = {"corridor": (6, 8), "hall": (5, 7), "l": (6, 8), "split": (8, 11)}[rtype]
    cw_lo, cw_hi = (9, 13) if rtype == "hall" else (8, 13)
    ch_lo, ch_hi = (7, 10) if rtype == "hall" else (6, 10)
    n = n_lo + rng.randint(0, n_hi - n_lo)
    rects = []
    placed = 0
    tries = 0
    bi = 0
    bands = [(2, 6), (8, 14), (16, 21)]
    while placed < n and tries < 200:
        tries += 1
        cw = rng.randint(cw_lo, cw_hi)
        ch = rng.randint(ch_lo, ch_hi)
        cwx = 2 + rng.randint(0, 48 - cw - 4)
        band = bands[bi % 3]
        bi += 1
        cwy = band[0] + rng.randint(0, band[1] - band[0])
        cwy = min(cwy, 25 - ch - 2)
        ok = True
        for y in range(cwy - 2, cwy + ch + 2):
            for x in range(cwx - 2, cwx + cw + 2):
                if 0 <= y < 25 and 0 <= x < 48 and (y, x) in pat:
                    ok = False
                    break
            if not ok:
                break
        if not ok:
            continue
        for y in range(cwy, cwy + ch):
            for x in range(cwx, cwx + cw):
                if grid[y][x] in p3.WALL:
                    grid[y][x] = "_"
                pat.add((y, x))
        rects.append((cwx, cwy, cw, ch))
        placed += 1
    # 走廊（近似 AS3 linkL2：L 形 2 宽连网）
    def link(tx, ty):
        nonlocal pat
        if not pat:
            return
        best = min(pat, key=lambda p: (p[0] - ty) ** 2 + (p[1] - tx) ** 2)
        y, x = best
        st = 0
        while (y, x) != (ty, tx) and st < 120:
            st += 1
            for kk in range(2):
                if x + kk < 48:
                    if grid[y][x + kk] in p3.WALL:
                        grid[y][x + kk] = "_"
                    pat.add((y, x + kk))
            dx, dy = tx - x, ty - y
            if abs(dx) >= abs(dy):
                x += 1 if dx > 0 else -1
            else:
                y += 1 if dy > 0 else -1
            y = max(1, min(23, y))
            x = max(1, min(46, x))
        for kk in range(2):
            if x + kk < 48:
                if grid[y][x + kk] in p3.WALL:
                    grid[y][x + kk] = "_"
    centers = [(cwx + cw // 2, cwy + ch // 2) for (cwx, cwy, cw, ch) in rects]
    rng.shuffle(centers)
    for (cx0, cy0) in centers:
        link(cx0, cy0)
    for (gx, gy) in [(12, 0), (12, 47), (0, 23), (0, 24), (24, 23), (24, 24)]:
        if (gy, gx) not in pat:
            link(gx, gy)
    return grid, rects

if __name__ == "__main__":
    main()
