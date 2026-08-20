# -*- coding: utf-8 -*-
"""v3.6 AS3 逻辑离线镜像验证：条带链 + 缺口 + 连通修复（含 seen 标记修复）
数据直接解析 src/rr/RRStripData.as（与运行时同一份数据）。"""
import random
import re
import sys
from collections import deque

W, H = 48, 25
WALL = set("ABCDEFGHIJKLMNOPQRST")
GY, GX1, GX2 = 12, 23, 24

# ---- 解析 RRStripData.as ----
src = open("src/rr/RRStripData.as", encoding="utf-8").read()
DATA = {}
for bio in ("STABLE", "SEWER", "PLANT", "MANE"):
    def grab(name):
        m = re.search(name + r':String = "([^"]*)"', src)
        return m.group(1)
    strips = [s.split("|") for s in grab("S_" + bio).split("~")]
    weights = grab("W_" + bio).split(",")
    bands = grab("B_" + bio).split(",")
    trans = {}
    for t in grab("T_" + bio).split(";"):
        if ":" not in t:
            continue
        a, rest = t.split(":", 1)
        b, c = rest.split(",", 1)
        trans.setdefault(int(a), []).append([int(b), int(c)])
    DATA[bio.lower()] = dict(strips=strips, weights=[int(x) for x in weights],
                             bands=[int(x) for x in bands], trans=trans)

def pick_idx(rng, cand, candw):
    tot = sum(candw)
    if tot <= 0:
        return cand[0]
    r = rng.randrange(tot)
    acc = 0
    for k, w in enumerate(candw):
        acc += w
        if r < acc:
            return cand[k]
    return cand[-1]

def strip_chain(rng, bio, rtype):
    D = DATA[bio]
    n = len(D["strips"])
    if rtype == "hall":
        pref = lambda m: m == 0
    elif rtype == "split":
        pref = lambda m: m != 0
    elif rtype == "corridor":
        pref = lambda m: (m & 3) != 0
    else:
        pref = None
    prev = -1
    grid = [[""] * W for _ in range(24)]
    for r in range(6):
        if prev >= 0 and prev in D["trans"]:
            cand = [t[0] for t in D["trans"][prev]]
            candw = [t[1] for t in D["trans"][prev]]
        else:
            cand = list(range(n))
            candw = list(D["weights"])
        pick = None
        if pref is not None and rng.random() < 0.7:
            sub = [(i, w) for i, w in zip(cand, candw) if pref(D["bands"][i])]
            if sub:
                pick = pick_idx(rng, [s[0] for s in sub], [s[1] for s in sub])
        if pick is None:
            pick = pick_idx(rng, cand, candw)
        cells = D["strips"][pick]
        for dy in range(4):
            for x in range(W):
                grid[r * 4 + dy][x] = cells[dy * W + x]
        prev = pick
    return grid

def finish(grid):
    full = [row[:] for row in grid] + [["A"] * W]
    full[H - 1][GX1] = "_"
    full[H - 1][GX2] = "_"
    full[GY][0] = "_"
    full[GY][W - 1] = "_"
    full[0][GX1] = "_"
    full[0][GX2] = "_"
    return full

def repair(grid):
    seen = [[False] * W for _ in range(H)]
    qy, qx, main_open = [], [], []
    starts = [(GY, 0), (GY, W - 1), (0, GX1), (0, GX2), (H - 1, GX1), (H - 1, GX2)]
    for (sy, sx) in starts:
        if not seen[sy][sx] and grid[sy][sx][0] not in WALL:
            seen[sy][sx] = True
            qy.append(sy); qx.append(sx); main_open.append((sy, sx))
    h = 0
    while h < len(qx):
        cy, cx = qy[h], qx[h]
        h += 1
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
                cy2, cx2 = cqy[ch], cqx[ch]
                ch += 1
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

def validate(grid, rtype):
    errs = []
    if len(grid) != H or any(len(r) != W for r in grid):
        errs.append("尺寸")
    for s in [(GY, 0), (GY, W - 1), (0, GX1), (0, GX2), (H - 1, GX1), (H - 1, GX2)]:
        if grid[s[0]][s[1]][0] in WALL:
            errs.append("缺口被封")
            return errs
    seen = set()
    dq = deque([(GY, 0), (GY, W - 1), (0, GX1), (0, GX2), (H - 1, GX1), (H - 1, GX2)])
    seen.update(dq)
    while dq:
        y, x = dq.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < H and 0 <= nx < W and (ny, nx) not in seen and grid[ny][nx][0] not in WALL:
                seen.add((ny, nx))
                dq.append((ny, nx))
    for y in range(H):
        for x in range(W):
            if grid[y][x][0] not in WALL and (y, x) not in seen:
                errs.append(f"孤岛({y},{x})")
                return errs
    wr = sum(1 for r in grid for c in r if c[0] in WALL) / (W * H)
    if not (0.08 <= wr <= 0.60):
        errs.append(f"墙占比 {wr:.2f}")
    return errs

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    fails = 0
    stats = {}
    for k in range(n):
        rng = random.Random(k)
        rtype = ["corridor", "hall", "l", "split"][k % 4]
        bio = ["stable", "sewer", "plant", "mane"][(k // 4) % 4]
        grid = finish(strip_chain(rng, bio, rtype))
        repair(grid)
        errs = validate(grid, rtype)
        stats.setdefault(rtype, []).append(sum(1 for r in grid for c in r if c[0] in WALL) / 1200)
        if errs:
            fails += 1
            if fails <= 6:
                print("FAIL", rtype, bio, errs[:2])
    print(f"=== v3.6 AS3 镜像验证: {n} 房 ===")
    print("不变式失败:", fails)
    for t, rs in stats.items():
        print(f"  {t}: 墙占比 平均 {sum(rs)/len(rs):.2f}")
    print("✓ 全部通过" if fails == 0 else "✗ 有失败")
    # 样本
    for k, (rt, bio) in enumerate([("corridor", "stable"), ("hall", "sewer"), ("split", "mane")]):
        grid = finish(strip_chain(random.Random(7 + k), bio, rt))
        repair(grid)
        print("=" * 62, rt, bio, "墙%.2f" % (sum(1 for r in grid for c in r if c[0] in WALL) / 1200))
        for row in grid:
            print("".join("#" if c[0] in WALL else ("·" if c[0] == "_" and len(c) > 1 else " ") for c in row))

if __name__ == "__main__":
    main()
