# -*- coding: utf-8 -*-
"""原版房间语料结构分析：墙占比 / 块格热力图 / 行墙谱 / 连通性"""
import xml.etree.ElementTree as ET
import glob, os, sys
from collections import defaultdict

ROOMS = r"C:\Program Files (x86)\Steam\steamapps\common\Remains\Rooms"
WALL = set("ABCDEFGHIJKLMNOPQRST")
TIP = {"beg0","beg","beg1","end","end1","pass","passroof","roofpass","vert","surf","roof","back","uniq"}

data = defaultdict(list)
bad = 0
for fn in sorted(glob.glob(os.path.join(ROOMS, "rooms_*.xml"))):
    land = os.path.basename(fn).replace("rooms_", "").replace(".xml", "")
    tree = ET.parse(fn)
    for room in tree.getroot().findall("room"):
        o = room.find("options")
        tip = o.get("tip", "") if o is not None else ""
        if tip in TIP:
            continue
        g = [a.text.split(".") for a in room.findall("a")]
        if len(g) != 25 or any(len(r) != 48 for r in g):
            bad += 1
            continue
        data[land].append(g)

print("可用:", sum(len(v) for v in data.values()), "跳过:", bad)

def is_wall(c):
    return bool(c) and c[0] in WALL

for land, grids in data.items():
    if len(grids) < 8:
        continue
    ratios = [sum(1 for r in g for c in r if is_wall(c)) / 1200 for g in grids]
    print("\n== %s n=%d 墙占比 均%.3f 中%.3f 范围%.2f-%.2f" % (
        land, len(grids), sum(ratios)/len(ratios), sorted(ratios)[len(ratios)//2],
        min(ratios), max(ratios)))
    hm = [[0.0]*8 for _ in range(7)]
    for g in grids:
        for j in range(25):
            for i in range(48):
                if is_wall(g[j][i]):
                    hm[min(j//4,6)][i//6] += 1
    print("块格热力图(6行x8列 墙占比):")
    for row in hm:
        print("  " + " ".join("%.2f" % (v/len(grids)) for v in row))
    rows = [0.0]*25
    for g in grids:
        for j in range(25):
            rows[j] += sum(1 for c in g[j] if is_wall(c))/48
    print("行墙谱:", " ".join("%.2f" % (v/len(grids)) for v in rows))
