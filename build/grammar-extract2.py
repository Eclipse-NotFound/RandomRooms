#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RRSynth v2 —— 分组块词典 + 装饰提取（按生物群系/土地）。

解决 v1 两个设计缺陷：
  1. 材质混搭：块词典按土地分组，生成时整房只用一组（biom 一致）；
  2. 无道路：由生成器（synth-proto2）按道路模板铺设，块只贴道路两侧。

输出分组数据到 build/grammar-data2.txt（供 RRGrammar v2 生成）。
"""
import xml.etree.ElementTree as ET
import glob
import os
from collections import Counter, defaultdict

ROOMS_DIR = r"C:\Program Files (x86)\Steam\steamapps\common\Remains\Rooms"
BIOME_LANDS = {   # 土地 -> 生物群系组（初始：stable / sewer / 其它归入"general"）
    "stable": "stable",
    "sewer": "sewer",
    "mane": "mane",
    "plant": "plant",
}
BLOCK_W, BLOCK_H = 6, 4
WALLCHARS = set("ABCDEFGHIJKLMNOPQRST")
TIP = {"beg0","beg","beg1","end","end1","pass","passroof","roofpass","vert","surf","roof","back","uniq"}

def main():
    blocks = defaultdict(list)   # biome -> list[(block,count)]
    decor = defaultdict(Counter)
    for fn in sorted(glob.glob(os.path.join(ROOMS_DIR, "rooms_*.xml"))):
        land = os.path.basename(fn).replace("rooms_","").replace(".xml","")
        biome = BIOME_LANDS.get(land, "general")
        tree = ET.parse(fn)
        for room in tree.getroot().findall("room"):
            o = room.find("options")
            tip = o.get("tip","") if o is not None else ""
            if tip in TIP: continue
            grid = [a.text.split(".") for a in room.findall("a")]
            h, w = len(grid), len(grid[0])
            # 装饰后缀频率
            for j in range(1, h-1):
                for i in range(1, w-1):
                    code = grid[j][i]
                    if code and code[0] == "_" and len(code) > 1:
                        for ch in code[1:]:
                            decor[biome][ch] += 1
            # 块（墙占比 10-55%）
            for j in range(2, h-BLOCK_H, 2):
                for i in range(2, w-BLOCK_W, 2):
                    block = tuple("|".join(grid[j+dj][i:i+BLOCK_W]) for dj in range(BLOCK_H))
                    cells = [c for row in block for c in row.split("|")]
                    wall = sum(1 for c in cells if c and c[0] in WALLCHARS)
                    ratio = wall / (BLOCK_W * BLOCK_H)
                    if 0.10 <= ratio <= 0.55:
                        blocks[biome].append((block, ratio))

    # 输出：每个 biome 前 N 个高频块 + 装饰
    out = open("build/grammar-data2.txt", "w", encoding="utf-8")
    for biome in ["stable", "sewer", "plant", "mane", "general"]:
        bl = blocks[biome]
        if not bl:
            continue
        cnt = Counter(b for b, _ in bl)
        top = cnt.most_common(16)
        out.write(f"== BIOME {biome}\n")
        for b, c in top:
            out.write(f"BLOCK {c}\n")
            for row in b:
                out.write(row + "\n")
        dc = decor[biome]
        tot = sum(dc.values())
        out.write("DECOR")
        for ch, c in dc.most_common(12):
            out.write(f" {ch}:{c}")
        out.write(f" (total {tot})\n")
    out.close()
    print("grammar-data2.txt 输出完成")
    for biome in blocks:
        print(f"  {biome}: 块样本 {len(blocks[biome])}, 装饰 {sum(decor[biome].values())}")

if __name__ == "__main__":
    main()
