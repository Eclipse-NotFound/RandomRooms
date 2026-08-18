#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RRSynth M1 —— 语料结构块提取 v2。

修正理解：fForms 首字符全是实体墙；`_` 是空地（可通行）；
oForms 后缀是装饰/可站物件。生成器 = 空地网格 + 墙块 + 装饰后缀。

提取：
  1. 墙块词典：6x4 切片，墙占比 [0.10, 0.55]（有掩体感不窒息），
     按出现频率加权，去重后输出前 N 个；
  2. 装饰后缀频率：空地上挂后缀的分布（shelf/rear）；
  3. 边界墙字符频率（外圈）。
产物输出到 stdout。
"""
import xml.etree.ElementTree as ET
import glob
import os
from collections import Counter

ROOMS_DIR = r"C:\Program Files (x86)\Steam\steamapps\common\Remains\Rooms"
BLOCK_W = 6
BLOCK_H = 4
TIP_ROOMS = {"beg0","beg","beg1","end","end1","pass","passroof","roofpass","vert","surf","roof","back","uniq"}
WALLCHARS = set("ABCDEFGHIJKLMNOPQRST")
SUFFIX_SHELF = "-ДЕКНР"
SUFFIX_REAR = "ВГЖЗИЙЛМОПСТ"

def is_rnd(room):
    o = room.find("options")
    tip = o.get("tip", "") if o is not None else ""
    return tip not in TIP_ROOMS

def parse_grid(room):
    return [a.text.split(".") for a in room.findall("a")]

def main():
    blocks = Counter()
    decor = Counter()
    edge = Counter()
    total = 0
    
    for fn in sorted(glob.glob(os.path.join(ROOMS_DIR, "rooms_*.xml"))):
        tree = ET.parse(fn)
        for room in tree.getroot().findall("room"):
            if not is_rnd(room):
                continue
            grid = parse_grid(room)
            h, w = len(grid), len(grid[0])
            total += 1
            # 装饰后缀：内部空地带后缀
            for j in range(1, h - 1):
                for i in range(1, w - 1):
                    code = grid[j][i]
                    if code and code[0] == "_" and len(code) > 1:
                        for ch in code[1:]:
                            if ch in SUFFIX_SHELF + SUFFIX_REAR:
                                decor[ch] += 1
            # 墙块：6x4 切片，墙占比筛选
            for j in range(2, h - BLOCK_H, 2):
                for i in range(2, w - BLOCK_W, 2):
                    block = tuple("|".join(grid[j + dj][i:i + BLOCK_W]) for dj in range(BLOCK_H))
                    cells = [c for row in block for c in row.split("|")]
                    wall = sum(1 for c in cells if c and c[0] in WALLCHARS)
                    ratio = wall / (BLOCK_W * BLOCK_H)
                    if 0.10 <= ratio <= 0.55:
                        blocks[block] += 1
            # 边界墙字符
            for j in (0, h - 1):
                for i in range(w):
                    c = grid[j][i]
                    if c and c[0] in WALLCHARS:
                        edge[c[0]] += 1
            for j in range(h):
                for i in (0, w - 1):
                    c = grid[j][i]
                    if c and c[0] in WALLCHARS:
                        edge[c[0]] += 1
    
    print(f"// 语料: {total} rnd 房; 结构块样本 {len(blocks)}")
    top = blocks.most_common(36)
    print(f"// 墙块词典（前 {len(top)}，出现频率降序）")
    for b, cnt in top:
        print(f"BLOCK {cnt}")
        for row in b:
            print("  " + row)
    print("// 装饰后缀频率（shelf/rear）:")
    print("  ", dict(decor.most_common(16)))
    print("// 边界墙字符频率:")
    print("  ", dict(edge.most_common(8)))

if __name__ == "__main__":
    main()
