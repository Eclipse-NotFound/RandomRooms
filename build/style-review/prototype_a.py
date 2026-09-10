"""Prototype A: deterministic continuity pass over real v6.6 generated XML.
Keeps geometry, objects and physics suffixes unchanged. This isolates visual noise.
Not a replacement generator and not wired into the mod.
"""
import argparse
from collections import Counter
from copy import deepcopy
from pathlib import Path
import sys
import xml.etree.ElementTree as ET
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from render_dump import WALL, parse_log

def clean_grid(grid):
    result = deepcopy(grid)
    dominant = Counter(c[0] for row in grid for c in row if c[0] in WALL).most_common(1)[0][0]
    # One structural material per connected piece; do not randomize tile-by-tile.
    for y,row in enumerate(grid):
        for x,cell in enumerate(row):
            if cell[0] in WALL:
                result[y][x] = dominant + cell[1:]
    # Find large open rectangles; a room region receives one background motif.
    candidates = set()
    for top in range(25):
        valid = [True] * 48
        for bottom in range(top,25):
            valid = [ok and grid[bottom][x][0] == "_" for x,ok in enumerate(valid)]
            start = None
            for x in range(49):
                if x < 48 and valid[x]:
                    if start is None:start=x
                elif start is not None:
                    if x-start >= 4 and bottom-top+1 >= 3:
                        candidates.add((start,top,x,bottom+1))
                    start=None
    ordered = sorted(candidates,key=lambda r:(-((r[2]-r[0])*(r[3]-r[1])),r))
    painted=set()
    for x0,y0,x1,y1 in ordered:
        cells=[(x,y) for y in range(y0,y1) for x in range(x0,x1) if (x,y) not in painted]
        if len(cells)<8:continue
        backgrounds=Counter(grid[y][x][1:2] for x,y in cells if len(grid[y][x]) > 1 and grid[y][x][1] in "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        background = backgrounds.most_common(1)[0][0] if backgrounds else ""
        for x,y in cells:
            code=grid[y][x]
            # Preserve all navigation/render layers after the leading Latin backdrop.
            tail=code[2:] if len(code)>1 and code[1] in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" else code[1:]
            result[y][x]="_"+background+tail
            painted.add((x,y))
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input")
    parser.add_argument("output")
    args=parser.parse_args()
    source=Path(args.input)
    if source.suffix.lower()==".xml":
        tree=ET.parse(source).getroot()
    else:
        records,_=parse_log(source.read_text(encoding="utf-8",errors="replace"))
        tree=ET.Element("all")
        for record in records:
            room=ET.SubElement(tree,"room",name=record["name"])
            for row in record["grid"]:ET.SubElement(room,"a").text=".".join(row)
            for tag,key in (("obj","objs"),("back","backs")):
                for oid,x,y in record[key]:ET.SubElement(room,tag,id=oid,x=str(x),y=str(y))
            ET.SubElement(room,"options")
    count=0
    for room in tree.findall("room"):
        rows=room.findall("a")
        grid=[(a.text or "").strip().split(".") for a in rows]
        clean=clean_grid(grid)
        for y,row in enumerate(grid):
            for x,old in enumerate(row):
                new=clean[y][x]
                assert (old[0] in WALL)==(new[0] in WALL)
                # Keep water, beams, stairs and Cyrillic suffixes byte-for-byte.
                physical=lambda c:"".join(ch for ch in c[1:] if ch not in "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
                assert physical(old)==physical(new)
                count+=old!=new
        room.set("prototype","A-continuity-only")
        for a,row in zip(rows,clean):a.text=".".join(row)
    ET.indent(tree)
    ET.ElementTree(tree).write(args.output,encoding="utf-8",xml_declaration=True)
    print(f"Prototype A: {len(tree.findall('room'))} rooms; {count} material/background cells changed; collision mask unchanged")

if __name__=="__main__":main()
