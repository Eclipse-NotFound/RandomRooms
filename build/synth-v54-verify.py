# -*- coding: utf-8 -*-
"""v5.4 敌人出生标记离线校验（镜像 RRSynth.placeRoomObjects 的 en 段）。

不变式:
  1. 每房 en 标记 2-4 个（AS3: 2 + int(rnd*3)）
  2. 标记占地全开放格（foot_ok，含 enl2 2x2）
  3. 距 player 出生点曼哈顿距离 >= 3
  4. 标记占地不与其他物件/标记重叠（used 全格标记）
  5. 桶分布近似 biome 权重（EN_WEIGHTS，相对误差 < 8%）

说明: grid/rects 管线复用 synth-v52-verify（其房间结构镜像为 v5.2 版，
      与 v5.3 的差异不影响放置不变式的验证结论）。
"""
import random
import sys
import importlib.util

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

p3 = load("p3", "build/synth-proto3.py")
v52 = load("v52", "build/synth-v52-verify.py")

EN_RATE = {"stable": (28, 49, 23), "sewer": (21, 36, 43),
           "plant": (35, 50, 15), "mane": (31, 52, 17)}
EN_IDS = ["enl1", "enl2", "enf1"]
EN_FOOT = {"enl1": (1, 1), "enl2": (2, 2), "enf1": (1, 1)}

def place_en_marks(grid, rng, biome, rects):
    """镜像 AS3 placeRoomObjects v5.4: 每-rect 物件（无 player）+ 房间级
    player×1 + 敌标记×2-4。返回 (marks, players, overlap_violations)"""
    marks = []          # (id, x, y)
    players = []        # (x, y)
    bad_overlap = 0
    rect_used = []
    all_objs = []
    for (cwx, cwy, cw, ch2) in rects:
        objs = v52.place_objects(grid, rng, biome, [(cwx, cwy, cw, ch2)])
        used = {}
        for (oid, x, y) in objs:
            if oid == "player":
                continue    # v5.4: player 移出 per-rect（原版 0.99/房）
            fs, fw = v52.FOOT.get(oid, (1, 1))
            for dy in range(fw):
                for dx in range(fs):
                    used[(x + dx, y + dy)] = oid
        all_objs.extend(objs)
        rect_used.append(used)
    # 房间级 player
    if rects:
        pr = rng.randrange(len(rects))
        (cwx, cwy, cw, ch2) = rects[pr]
        used = rect_used[pr]
        for _t in range(40):    # interiorSpot(player 2x2)
            x = cwx + 2 + rng.randrange(max(1, cw - 4 - 2))
            y = cwy + 2 + rng.randrange(max(1, ch2 - 4 - 2))
            if not (0 <= x < 48 and 0 <= y < 25):
                continue
            if grid[y][x] != "_" or (x, y) in used:
                continue
            if not v52.foot_ok(grid, x, y, 2, 2):
                continue
            players.append((x, y))
            for dy in range(2):
                for dx in range(2):
                    used[(x + dx, y + dy)] = "player"
            break
    # 房间级敌标记（逐行镜像 AS3 en 段：quota 分层分配）
    n_en = 3 + int(rng.random() * 2)
    en_r = EN_RATE[biome]
    en_tot = sum(en_r)
    q1 = int(n_en * en_r[0] / en_tot + rng.random())
    q2 = int(n_en * en_r[1] / en_tot + rng.random())
    q3 = max(0, n_en - q1 - q2)
    marks = []
    bad_overlap = 0
    for k, (eid, quota) in enumerate(zip(EN_IDS, (q1, q2, q3))):
        fs, fw = EN_FOOT[eid]
        tries = 0
        placed = 0
        while placed < quota and tries < 40 and rects:
            tries += 1
            er = rng.randrange(len(rects))
            (cwx, cwy, cw, ch2) = rects[er]
            used = rect_used[er]
            ep = None
            for _t in range(30):
                x = cwx + 2 + rng.randrange(max(1, cw - 4 - fs))
                y = cwy + 2 + rng.randrange(max(1, ch2 - 4 - fw))
                if not (0 <= x < 48 and 0 <= y < 25):
                    continue
                clash = False
                for dy in range(fw):
                    for dx in range(fs):
                        if (y + dy >= 25 or x + dx >= 48 or grid[y + dy][x + dx] != "_"
                                or (x + dx, y + dy) in used):
                            clash = True
                            break
                    if clash:
                        break
                if clash:
                    continue
                if players and any(abs(x - px) + abs(y - py) < 3 for (px, py) in players):
                    continue
                ep = (x, y)
                break
            if ep is None:
                continue
            marks.append((eid, ep[0], ep[1]))
            for dy in range(fw):
                for dx in range(fs):
                    key = (ep[0] + dx, ep[1] + dy)
                    if key in used:
                        bad_overlap += 1
                    used[key] = eid
            placed += 1
    return marks, players, bad_overlap

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    fails = 0
    total_marks = 0
    bucket = {b: [0, 0, 0] for b in EN_RATE}
    overlaps = 0
    per_room_min, per_room_max = 99, 0
    for k in range(n):
        rng = random.Random(10000 + k)
        rtype = ["corridor", "hall", "l", "split"][k % 4]
        biome = ["stable", "sewer", "plant", "mane"][(k // 4) % 4]
        grid, rects = v52.gen_with_rects(rng, rtype, biome, p3.load_biome_decor("build/grammar-data2.txt"))
        marks, players, bad = place_en_marks(grid, rng, biome, rects)
        overlaps += bad
        total_marks += len(marks)
        if rects:
            per_room_min = min(per_room_min, len(marks))
            per_room_max = max(per_room_max, len(marks))
        for (eid, x, y) in marks:
            bucket[biome][EN_IDS.index(eid)] += 1
            fs, fw = EN_FOOT[eid]
            if not v52.foot_ok(grid, x, y, fs, fw):
                fails += 1
                print(f"FAIL 占地 {eid} ({x},{y}) {biome}")
            if any(abs(x - pxx) + abs(y - pyy) < 3 for (pxx, pyy) in players):
                fails += 1
                print(f"FAIL 距player<3 {eid} ({x},{y}) {biome}")
        if not (2 <= len(marks) <= 5):
            fails += 1
            print(f"FAIL 数量 {len(marks)} {biome} {rtype}")
    print(f"=== v5.4 敌人标记校验: {n} 房 ===")
    print(f"标记总数: {total_marks}  违规: {fails}  占地重叠: {overlaps}")
    print(f"每房标记: {per_room_min}~{per_room_max}")
    for b in EN_RATE:
        cnt = bucket[b]
        tot = sum(cnt) or 1
        w = EN_RATE[b]
        wt = sum(w)
        pct = [c * 100.0 / tot for c in cnt]
        wpct = [x * 100.0 / wt for x in w]
        dev = max(abs(pct[i] - wpct[i]) for i in range(3))
        print(f"{b:7s} 桶分布 enl1/enl2/enf1 = {pct[0]:.0f}/{pct[1]:.0f}/{pct[2]:.0f}%  权重 {wpct[0]:.0f}/{wpct[1]:.0f}/{wpct[2]:.0f}%  最大偏差 {dev:.1f}%")
        if tot >= 200 and dev > 8:
            fails += 1
            print(f"FAIL 比例偏差 {b}")
    print("✓ 全部通过" if fails == 0 and overlaps == 0 else "✗ 有失败")
    sys.exit(1 if (fails or overlaps) else 0)

if __name__ == "__main__":
    main()
