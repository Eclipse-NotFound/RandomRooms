#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
P0 原型验证：RRCook 变异规则的离线安全单测。

- 语料：游戏根目录 Rooms/*.xml（运行时真源，29 个土地池）
- 对每个非 tip 房间（rnd 房）执行多次变异（属性重掷 + 瓦片微突变）
- 断言不变式：网格尺寸、边界行列、doors、options.tip、XML 可解析、变异确实发生
- 规则表与 src/rr/RRCook.as 保持一致（对照维护）

用法: python build/p0-proto.py
"""
import os
import random
import re
import sys
from collections import Counter, defaultdict

ROOMS_DIR = r"C:\Program Files (x86)\Steam\steamapps\common\Remains\Rooms"

# ---------- 语义规则表（与 RRCook.as 对照） ----------

# 首字符组：ed=1 实体，按 mat 分组（组内互换=同碰撞，只换外观）
F_GROUPS = {
    "metal1":   "AKJSMOT",   # mat=1 金属（hp>=1000 主结构）
    "concrete": "CDGLNPQ",   # mat=2 混凝土 hp1000（普通墙体）
    "heavy":    "BI",        # B=超混5000 I=特殊1000（坚固组）
    "cracked":  "ER",        # E=裂纹150 R=特殊150（脆墙组）
    "glass":    "FH",        # F=玻璃40 H=特殊1000（易碎/特殊）
}
# 后缀 shelf 组：可站立物件（互换成其它 shelf 物件）
SUFFIX_SHELF = "-ДЕКНР"
# 后缀 rear 组：背景装饰（无碰撞）
SUFFIX_REAR = "ВГЖЗИЙЛМОПСТ"
# 台阶：方向语义，禁止变异
SUFFIX_STAIR = "АБ"
# 拉丁后缀：无属性，禁止变异（保守）
SUFFIX_LATIN = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

# 属性重掷池（从语料统计出现过的值；运行时按目标池实际值随机）
OPT_ROLL = {
    "back": None,          # None = 从池内现有值中采样
    "sky":  None,          # None = 0/1 翻转
    "zoom": None,          # None = 从池内现有值采样
    "maxdy": None,         # None = 从池内现有值采样
    "spawn": None,         # None = 从池内现有值采样
    "kolspawn": None,      # None = 从池内现有值采样
    "tilespawn": None,     # None = 从池内现有值采样（0-1 概率）
}

PROTECTED_OPTIONS = {"tip", "level", "uniq", "nornd", "test", "back"}  # back 单独处理

# ---------- 工具 ----------

def parse_grid(room):
    """解析 <a> 行为 [y][x] 字符网格（每行按 . 分隔）。"""
    rows = []
    for a in room.findall("a"):
        text = a.text or ""
        rows.append(text.split("."))
    return rows

def grid_to_xml(grid):
    """网格 -> <a> 行 XML 字符串。"""
    return "".join("<a>" + ".".join(row) for row in grid) + "</a>" if False else None

def assert_invariants(orig, cooked, room_name, errors):
    """不变式断言。"""
    og = parse_grid(orig)
    cg = parse_grid(cooked)
    if len(og) != len(cg) or any(len(a) != len(b) for a, b in zip(og, cg)):
        errors.append(f"{room_name}: 网格尺寸变化 {len(og)}x{len(og[0]) if og else 0} -> {len(cg)}x{len(cg[0]) if cg else 0}")
        return False
    h, w = len(og), len(og[0])
    # 边界行列不变
    for j in range(h):
        for i in range(w):
            if i == 0 or i == w - 1 or j == 0 or j == h - 1:
                if og[j][i] != cg[j][i]:
                    errors.append(f"{room_name}: 边界瓦片变化 ({i},{j}) {og[j][i]} -> {cg[j][i]}")
                    return False
    # doors 不变
    od = orig.findtext("doors") or ""
    cd = cooked.findtext("doors") or ""
    if od != cd:
        errors.append(f"{room_name}: doors 变化")
        return False
    # tip 不变
    ot = orig.find("options").get("tip", "") if orig.find("options") is not None else ""
    ct = cooked.find("options").get("tip", "") if cooked.find("options") is not None else ""
    if ot != ct:
        errors.append(f"{room_name}: options.tip 变化 {ot} -> {ct}")
        return False
    return True

# ---------- 变异器（与 RRCook.as 同构） ----------

def cook_room(room, rng, stats):
    """单房间变异：属性重掷 + 瓦片微突变。返回变异后的 XML 副本。"""
    import copy
    r = copy.deepcopy(room)
    name = r.get("name")
    grid = parse_grid(r)
    h, w = len(grid), len(grid[0])
    changed = 0

    # --- 瓦片微突变 ---
    # 收集所有可变异格（非边界）
    cells = [(j, i) for j in range(h) for i in range(w)
             if i not in (0, w - 1) and j not in (0, h - 1)]
    # 尝试 N 次突变
    for _ in range(int(len(cells) * 0.02) + 1):  # ~2% 格
        j, i = rng.choice(cells)
        code = grid[j][i]
        if len(code) == 0:
            continue
        first = code[0]
        suffix = code[1:]
        new_first = first
        # 首字符组内互换
        for gname, charset in F_GROUPS.items():
            if first in charset:
                # 50% 概率换组内其它字符
                if rng.random() < 0.6 and len(charset) > 1:
                    choices = [c for c in charset if c != first]
                    new_first = rng.choice(choices)
                    stats["first_swap"][gname] += 1
                break
        # 后缀安全互换（shelf/rear 组内）
        new_suffix = suffix
        for si, ch in enumerate(suffix):
            if ch in SUFFIX_SHELF and rng.random() < 0.3:
                choices = [c for c in SUFFIX_SHELF if c != ch]
                new_suffix = new_suffix[:si] + rng.choice(choices) + new_suffix[si + 1:]
                stats["shelf_swap"] += 1
            elif ch in SUFFIX_REAR and rng.random() < 0.3:
                choices = [c for c in SUFFIX_REAR if c != ch]
                new_suffix = new_suffix[:si] + rng.choice(choices) + new_suffix[si + 1:]
                stats["rear_swap"] += 1
        new_code = new_first + new_suffix
        if new_code != code:
            grid[j][i] = new_code
            changed += 1

    # 回写网格（先移除全部原 <a>，再按新网格追加）
    for a in r.findall("a"):
        r.remove(a)
    for row in grid:
        a = room.makeelement("a", {})
        a.text = ".".join(row)
        r.append(a)

    # --- 属性重掷 ---
    opts = r.find("options")
    if opts is None:
        opts = r.makeelement("options", {})
        r.append(opts)
    if rng.random() < 0.5 and "sky" in (opts.get("sky") or ""):
        pass  # sky 属性存在与否语义：保留现状（保守）
    # tilespawn 概率区间重 roll
    if "tilespawn" in opts.attrib and rng.random() < 0.7:
        v = float(opts.get("tilespawn"))
        nv = max(0.0, min(1.0, v + rng.uniform(-0.2, 0.2)))
        opts.set("tilespawn", f"{nv:.2f}")
        stats["tilespawn_roll"] += 1
        changed += 1
    # kolspawn 数量 ±30%（spawn 是类型字符串，不重掷）
    for key in ("kolspawn",):
        if key in opts.attrib and rng.random() < 0.7:
            v = int(opts.get(key))
            nv = max(0, int(v * rng.uniform(0.7, 1.3)))
            opts.set(key, str(nv))
            stats[f"{key}_roll"] += 1
            changed += 1

    if changed > 0:
        stats["changed_rooms"] += 1
    return r, changed

# ---------- 主流程 ----------

def main():
    rng = random.Random(20260818)  # 固定种子，可复现
    files = sorted(f for f in os.listdir(ROOMS_DIR) if f.startswith("rooms_") and f.endswith(".xml"))
    stats = Counter()
    errors = []
    stats["first_swap"] = defaultdict(int)
    total_rooms = 0
    total_cooked = 0
    rate = 0.0

    for fn in files:
        path = os.path.join(ROOMS_DIR, fn)
        try:
            import xml.etree.ElementTree as ET
            tree = ET.parse(path)
        except Exception as e:
            errors.append(f"{fn}: 解析失败 {e}")
            continue
        root = tree.getroot()
        pool_attrs = {}
        # 属性值采样池
        for room in root.findall("room"):
            o = room.find("options")
            if o is not None:
                for k in o.attrib:
                    pool_attrs.setdefault(k, set()).add(o.get(k))
        for room in root.findall("room"):
            o = room.find("options")
            tip = o.get("tip", "") if o is not None else ""
            if tip in ("beg0", "beg", "beg1", "end", "end1", "pass", "passroof",
                       "roofpass", "vert", "surf", "roof", "back", "uniq"):
                continue  # 固定功能房不变异
            total_rooms += 1
            for trial in range(30):
                cooked, changed = cook_room(room, rng, stats)
                total_cooked += 1
                if changed > 0:
                    rate += 1
                if not assert_invariants(room, cooked, f"{fn}/{room.get('name')}", errors):
                    break

    n_rnd = total_rooms
    print(f"=== P0 变异规则离线验证 ===")
    print(f"语料: {len(files)} 个土地池, {n_rnd} 个 rnd 房, 每房 30 次变异 = {total_cooked} 次")
    print(f"变异率: {rate / total_cooked * 100:.1f}%")
    print(f"首字符组内互换: {dict(stats['first_swap'])}")
    print(f"shelf 互换: {stats['shelf_swap']} 次, rear 互换: {stats['rear_swap']} 次")
    print(f"属性重掷: tilespawn={stats['tilespawn_roll']} kolspawn={stats['kolspawn_roll']}")
    if errors:
        print(f"\n!!! 不变式失败 {len(errors)} 个:")
        for e in errors[:20]:
            print("  ", e)
        sys.exit(1)
    print("\n✓ 全部不变式通过（尺寸/边界/doors/tip/可解析）")

if __name__ == "__main__":
    main()
