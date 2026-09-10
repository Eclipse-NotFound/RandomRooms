# -*- coding: utf-8 -*-
"""Read RandomRooms DUMP logs without losing version/session boundaries.
python build/render_dump.py log.txt output.png --all --summary summary.json
PNG is a structural map, not a screenshot of the game.
"""
import argparse
import json
import re
import struct
import zlib
from collections import Counter
from pathlib import Path
import xml.etree.ElementTree as ET

WALL = set("ABCDEFGHIJKLMNOPQRST")
PREFIX = re.compile(r"^\[RR:[^\]]+\]\s*")
FOOTPRINTS = {
    "player": (2, 2), "mcrate2": (2, 2), "box": (2, 2),
    "woodbox": (2, 2), "enl2": (2, 2), "locker": (2, 3),
    "bookcase": (2, 3), "checkpoint": (2, 3), "bed": (4, 1),
    "couch": (2, 1), "table": (2, 1), "table2": (2, 1),
    "chest": (2, 1), "hatch2": (2, 1), "stdoor": (1, 3),
    "door1": (1, 2), "radbarrel": (1, 2), "filecab": (1, 2),
    "mcrate1": (2, 2), "bigbox": (3, 2), "bigmed": (2, 3),
    "table1": (2, 1), "instr1": (2, 2), "medbox": (1, 1),
    "wcup": (1, 1), "wallcab": (1, 1), "cup": (2, 2),
    "ccup": (1, 1), "tap": (1, 2), "fridge": (1, 2), "trash": (1, 1),
}

def parse_log(text, latest_session=True):
    """Only closed, dimensionally valid blocks; partial blocks are reported."""
    rooms, warnings = [], []
    current = None
    session = 0
    batch = 0
    for lineno, raw in enumerate(text.splitlines(), 1):
        line = PREFIX.sub("", raw).strip()
        if "RRDiag init," in line:
            if current:
                warnings.append(f"line {lineno}: new session interrupted {current['name']}")
            current = None
            session += 1
            batch = 0
        if line.startswith("refreshLandPool:") and "展示馆" in line:
            batch += 1
        elif line.startswith("C-POOL "):
            batch += 1
        if line.startswith("DUMP-BEGIN "):
            if current:
                warnings.append(f"line {lineno}: missing END for {current['name']}")
            parts = line.split()
            current = dict(name=parts[1], grid=[], objs=[], backs=[],
                           attributes=dict(p.split("=", 1) for p in parts[2:] if "=" in p),
                           session=session, batch=batch)
        elif current and line.startswith("DUMP-ROW "):
            current["grid"].append(line[9:].split("."))
        elif current and line.startswith(("DUMP-OBJ ", "DUMP-BACK ")):
            parts = line.split()
            try:
                key = "objs" if parts[0] == "DUMP-OBJ" else "backs"
                current[key].append((parts[1], int(parts[2]), int(parts[3])))
            except (ValueError, IndexError):
                warnings.append(f"line {lineno}: invalid object record")
                current["invalid"] = True
        elif line == "DUMP-END" and current:
            valid = len(current["grid"]) == 25 and all(
                len(row) == 48 and all(row) for row in current["grid"])
            if valid and not current.get("invalid"):
                rooms.append(current)
            else:
                warnings.append(f"line {lineno}: rejected malformed {current['name']}")
            current = None
        if "LOG CAPPED" in line:
            warnings.append(f"line {lineno}: log capped; batch may be incomplete")
    if current:
        warnings.append(f"EOF: incomplete {current['name']}")
    if latest_session:
        rooms = [room for room in rooms if room["session"] == session]
    return rooms, warnings

def from_xml(room):
    def objects(tag):
        return [(o.get("id", ""), int(o.get("x", "0")), int(o.get("y", "0")))
                for o in room.findall(tag)]
    return dict(name=room.get("name", ""), grid=[
        (a.text or "").strip().split(".") for a in room.findall("a")],
        objs=objects("obj"), backs=objects("back"),
        attributes=dict(room.attrib), session=0, batch=0)

def read_rooms(path):
    path = Path(path)
    if path.suffix.lower() == ".xml":
        root = ET.parse(path).getroot()
        return [from_xml(r) for r in root.findall("room")], []
    return parse_log(path.read_text(encoding="utf-8", errors="replace"))

def metrics(room):
    grid = room["grid"]
    solid = lambda x, y: grid[y][x][0] in WALL
    anchors, below = Counter(), Counter()
    no_solid_support = []
    # Diagnostic only: shelves, stairs, water, wall fixtures, and engine physics
    # require an actual game check. Never call this a floating-object verdict.
    for oid, x, y in room["objs"]:
        if not (0 <= x < 48 and 0 <= y < 25):
            continue
        anchors[grid[y][x]] += 1
        if y + 1 < 25:
            below[grid[y + 1][x]] += 1
        width = FOOTPRINTS.get(oid, (1, 1))[0]
        if y + 1 >= 25 or not any(solid(xx, y + 1) for xx in range(x, min(48, x + width))):
            no_solid_support.append(oid)
    wall_pairs = wall_changes = bg_pairs = bg_changes = 0
    for y in range(25):
        for x in range(48):
            for nx, ny in ((x + 1, y), (x, y + 1)):
                if nx >= 48 or ny >= 25:
                    continue
                a, b = grid[y][x], grid[ny][nx]
                if a[0] in WALL and b[0] in WALL:
                    wall_pairs += 1
                    wall_changes += a[0] != b[0]
                if a[0] == b[0] == "_":
                    bg_pairs += 1
                    bg_changes += a[1:2] != b[1:2]
    return dict(name=room["name"], session=room["session"], batch=room["batch"],
                wall_fraction=sum(solid(x, y) for y in range(25) for x in range(48)) / 1200,
                wall_material_change_rate=wall_changes / max(1, wall_pairs),
                open_texture_change_rate=bg_changes / max(1, bg_pairs),
                objects=len(room["objs"]), backs=len(room["backs"]),
                anchor_cells=dict(anchors), below_anchor_cells=dict(below),
                no_solid_support_candidates=no_solid_support,
                bottom_open=sum(not solid(x, 24) for x in range(48)),
                note="Structural proxies only; not a style score or physical reachability proof.")

BG = {"R": (75,94,102), "P": (99,87,79), "O": (70,90,74),
      "F": (69,78,93), "Q": (83,87,91), "N": (93,89,77),
      "B": (88,76,86), "H": (70,87,82), "C": (89,81,72),
      "W": (98,93,73), "M": (80,91,87), "L": (76,81,97)}
def cellcol(code):
    if code[0] in WALL:
        if code[0] in "AKJSMOT": return (183,189,188)
        if code[0] in "CDGLNPQ": return (157,146,129)
        return (143,157,173)
    if "*" in code: return (65,119,161)
    return BG.get(code[1:2], (33,41,49))

def raster(room, scale=12, objects=True):
    grid = room["grid"]
    pixels = [[cellcol(grid[y // scale][x // scale])
               for x in range(48 * scale)] for y in range(25 * scale)]
    def rect(x0, y0, x1, y1, color):
        for y in range(max(0,y0), min(len(pixels),y1)):
            for x in range(max(0,x0), min(len(pixels[0]),x1)):
                pixels[y][x] = color
    for y, row in enumerate(grid):
        for x, code in enumerate(row):
            if "-" in code or any(c in code for c in "ДЕКНР"):
                rect(x*scale,(y+1)*scale-2,(x+1)*scale,(y+1)*scale,(134,187,171))
            if "А" in code or "Б" in code:
                for d in range(scale):
                    px = d if "А" in code else scale-1-d
                    rect(x*scale+px,y*scale+d,x*scale+px+1,y*scale+d+2,(153,204,188))
    if objects:
        for _,x,y in room["backs"]:
            rect(x*scale+scale//3,y*scale+scale//3,x*scale+2*scale//3,y*scale+2*scale//3,(210,176,96))
        for oid,x,y in room["objs"]:
            w,h = FOOTPRINTS.get(oid,(1,1))
            color = (115,207,140) if oid == "player" else (227,117,106) if oid.startswith("en") else (204,174,110)
            x0,x1 = x*scale+1,(x+w)*scale-1
            y0,y1 = (y-h+1)*scale+1,(y+1)*scale-1
            rect(x0,y0,x1,y0+2,color);rect(x0,y1-2,x1,y1,color)
            rect(x0,y0,x0+2,y1,color);rect(x1-2,y0,x1,y1,color)
    return pixels

def write_png(path, pixels):
    h,w = len(pixels),len(pixels[0])
    raw = b"".join(b"\0"+b"".join(bytes(p) for p in row) for row in pixels)
    def chunk(tag,data):
        return struct.pack(">I",len(data))+tag+data+struct.pack(">I",zlib.crc32(tag+data)&0xffffffff)
    data = b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",w,h,8,2,0,0,0))
    data += chunk(b"IDAT",zlib.compress(raw))+chunk(b"IEND",b"")
    Path(path).write_bytes(data)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log")
    parser.add_argument("output", nargs="?", default="build/dump_render.png")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--summary")
    parser.add_argument("--scale", type=int, default=12, choices=range(2,33))
    args = parser.parse_args()
    rooms,warnings = read_rooms(args.log)
    if not rooms:
        parser.exit(1,"No complete rooms in selected session.\n"+"\n".join(warnings)+"\n")
    selected = rooms if args.all else rooms[-1:]
    rendered = [raster(r,args.scale) for r in selected]
    width,height = 48*args.scale,25*args.scale
    cols = min(4,len(rendered)); rows=(len(rendered)+cols-1)//cols; gap=8
    pixels=[[(17,23,29)]*(cols*(width+gap)+gap) for _ in range(rows*(height+gap)+gap)]
    for n,pic in enumerate(rendered):
        ox=(n%cols)*(width+gap)+gap;oy=(n//cols)*(height+gap)+gap
        for y,row in enumerate(pic):pixels[oy+y][ox:ox+width]=row
    write_png(args.output,pixels)
    summary=dict(complete_rooms=len(rooms),rendered=len(selected),warnings=warnings,rooms=[metrics(r) for r in rooms])
    if args.summary:Path(args.summary).write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding="utf-8")
    print(json.dumps(dict(complete_rooms=len(rooms),rendered=len(selected),warnings=warnings),ensure_ascii=False))

if __name__ == "__main__":
    main()
