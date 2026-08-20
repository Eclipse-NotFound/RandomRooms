# -*- coding: utf-8 -*-
"""把 synth-proto3.py 同步到 v3.2：删固定直线 road_walls，
   改为有机 波浪主廊+缺口纵连+随机腔室；新增 split 型。"""
import re, sys

P = "C:/Program Files (x86)/Steam/steamapps/common/Remains/mods/RandomRooms/build/synth-proto3.py"
src = open(P, encoding="utf-8").read()

# 1) WALL_RATIO 扩展 split + 调密（corridor/hall/l/split 被打洞后需略高）
s_ratio = src
old_ratio = 'WALL_RATIO = {"corridor": 0.17, "hall": 0.12, "quad": 0.22, "l": 0.14, "bunker": 0.20}'
new_ratio = 'WALL_RATIO = {"corridor": 0.16, "hall": 0.13, "quad": 0.22, "l": 0.15, "split": 0.15, "bunker": 0.20}'
assert old_ratio in s_ratio, "ratio line not found"
s_ratio = s_ratio.replace(old_ratio, new_ratio)

# 2) 去掉 gen_room 里的固定强制开放矩形（corridor/hall/l）→ 纯场
old_f = '''    if rtype == "corridor":
        f = value_noise(rng)
        for y in range(H):
            for x in range(18, 30):
                f[y][x] = -1.0
    elif rtype == "hall":
        f = value_noise(rng)
        for y in range(5, 20):
            for x in range(8, 40):
                f[y][x] = -1.0
    elif rtype == "quad":'''
new_f = '''    if rtype in ("corridor", "hall", "l", "split"):
        f = value_noise(rng)
    elif rtype == "quad":'''
assert old_f in s_ratio, "field block not found"
s_ratio = s_ratio.replace(old_f, new_f)

# 3) 删掉 l 的独立场分支（并入上面线性组）
old_l = '''    elif rtype == "l":
        f = value_noise(rng)
        for y in range(18, 23):
            for x in range(W):
                f[y][x] = -1.0
        for x in range(32, 41):
            for y in range(H):
                f[y][x] = -1.0
    else:  # bunker'''
new_l = '''    else:  # bunker'''
assert old_l in s_ratio, "l block not found"
s_ratio = s_ratio.replace(old_l, new_l)

# 4) 调用点: road_walls -> carve_rooms
old_call = '    road_walls(grid, rtype, rng)     # v3.1 道路边墙线\n'
assert old_call in s_ratio, "road_walls call not found"
s_ratio = s_ratio.replace(old_call, '    carve_rooms(grid, rtype, rng)  # v3.2 有机房间-走廊\n')

# 5) 替换 road_walls 定义体为 carve_rooms + 辅助函数
old_def = src[src.index('def road_walls(grid, rtype, rng=None):'):src.index('def gap_guard(grid):')]
new_def = '''def carve_rooms(grid, rtype, rng):
    """v3.2 有机房间-走廊：波浪主廊 + 缺口纵连 + 随机腔室（无固定直线模板）"""
    global PATHDIR
    PATHDIR = []
    params = {
        "corridor": (1, 2, False, 4),
        "hall":     (2, 4, True,  4),
        "l":        (2, 4, False, 9),
        "split":    (3, 6, False, 4),
    }
    n_lo, n_hi, plaza_v, wander = params[rtype]

    # 1) 主波浪走廊（左<->右，两端 sin 包络归零接缺口，行间缓变）
    cy = float(GY)
    A = 1.0 + rng.random() * 2.4
    kk = 0.18 + rng.random() * 0.4
    ph = rng.random() * 6.283
    for x in range(1, W - 1):
        env = math.sin(math.pi * x / (W - 1))
        t = GY + A * env * math.sin(kk * x + ph) + (rng.random() - 0.5) * 1.2
        if t - cy > 1.2:
            t = cy + 1.2
        elif t - cy < -1.2:
            t = cy - 1.2
        t = max(4.0, min(H - 5.0, t))
        cy = t
        yy0 = int(round(t)) - 1
        for yy in range(yy0, yy0 + 3):
            if 1 <= yy < H - 1:
                carve_cell(grid, yy, x)

    # 2) 上/下缺口纵连（列 23/24，轻微横漂）
    for c in (23, 24):
        for y in range(2, 12):
            vcx = max(3, min(W - 4, c + int(round((rng.random() - 0.5) * wander))))
            carve_cell(grid, y, vcx)
            carve_cell(grid, y, min(vcx + 1, W - 2))
        for y in range(22, 11, -1):
            vcx = max(3, min(W - 4, c + int(round((rng.random() - 0.5) * wander))))
            carve_cell(grid, y, vcx)
            carve_cell(grid, y, min(vcx + 1, W - 2))

    # 3) 中央广场（hall）
    if plaza_v:
        px0 = 9 + rng.randint(0, 8)
        py0 = 5 + rng.randint(0, 5)
        pw = 18 + rng.randint(0, 8)
        ph = 8 + rng.randint(0, 4)
        y = py0
        while y < py0 + ph and y < H - 2:
            x = px0
            while x < px0 + pw and x < W - 2:
                carve_cell(grid, y, x)
                x += 1
            y += 1

    # 4) 随机腔室 + 就近连廊
    n = n_lo + rng.randint(0, n_hi - n_lo)
    for _ in range(n):
        cw = 5 + rng.randint(0, 5)
        ch = 5 + rng.randint(0, 4)
        cwx = 2 + rng.randint(0, W - cw - 4)
        cwy = 2 + rng.randint(0, H - ch - 4)
        for y in range(cwy, cwy + ch):
            for x in range(cwx, cwx + cw):
                carve_cell(grid, y, x)
        connect_chamber(grid, cwy + ch // 2, cwx + cw // 2)


PATHDIR = []


def carve_cell(grid, y, x):
    if y < 0 or y >= H or x < 0 or x >= W:
        return
    if grid[y][x] != "_":
        grid[y][x] = "_"
    if PATHDIR is not None:
        PATHDIR.append((y, x))


def connect_chamber(grid, cy0, cx0):
    if not PATHDIR:
        return
    best = min(PATHDIR, key=lambda p: (p[0] - cy0) ** 2 + (p[1] - cx0) ** 2)
    ty, tx = best
    st = 0
    while (ty != cy0 or tx != cx0) and st < 90:
        st += 1
        carve_cell(grid, ty, tx)
        carve_cell(grid, ty, min(tx + 1, W - 2))
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


'''
s_ratio = s_ratio.replace(old_def, new_def)

# 6) 校验清单加 split
old_chk = '    for rtype, biome in [("corridor", "stable"), ("hall", "sewer"), ("l", "plant"), ("bunker", "mane")]:'
new_chk = '    for rtype, biome in [("corridor", "stable"), ("hall", "sewer"), ("l", "plant"), ("split", "mane"), ("bunker", "mane")]:'
assert old_chk in s_ratio, "check list not found"
s_ratio = s_ratio.replace(old_chk, new_chk)

open(P, "w", encoding="utf-8").write(s_ratio)
print("patched OK")
