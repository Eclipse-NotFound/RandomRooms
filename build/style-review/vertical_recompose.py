"""Read-only author-room study and throwaway whole-height block prototype.

Run from the Remains root. Writes only beside this script, under composite/.
No gameplay source imports, no deployment, no random tunnel/geometry repair.
"""
from __future__ import annotations

import copy
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent / "composite"
BIOMES = ("stable", "sewer", "plant", "mane")
WIDTH, HEIGHT = 48, 25


def data_xml():
    src = (ROOT / "game-reference/decompiled/1.02/src102/scripts/fe/AllData.as").read_text(encoding="utf-8-sig")
    return ET.fromstring(src[src.index("<all>"):src.rindex("</all>") + 6])


DATA = data_xml()
FRONT_FORMS = {e.get("id"): dict(e.attrib) for e in DATA.findall("mat") if e.get("ed") == "1"}
OTHER_FORMS = {e.get("id"): dict(e.attrib) for e in DATA.findall("mat") if e.get("ed") != "1"}
DEFS = {tag: {e.get("id"): e for e in DATA.findall(tag)} for tag in ("obj", "back")}


def navigation(token):
    """Tile.dec navigation fields, including suffix platforms and stairs."""
    phis = shelf = stair = diagonal = water = z = 0
    for index, ch in enumerate(token):
        if index == 0 and ch == "_":
            continue
        if ch == "*":
            water = 1
        elif ch in ",;:":
            z = ",;:".index(ch) + 1
        else:
            form = (FRONT_FORMS if index == 0 else OTHER_FORMS).get(ch, {})
            if int(form.get("phis", "0")):
                phis = int(form["phis"])
            if "shelf" in form:
                shelf = 1
            if "stair" in form:
                stair = int(form["stair"])
            if "diagon" in form:
                diagonal = int(form["diagon"])
    return phis, shelf, stair, diagonal, water, z


def extent(e):
    definition = DEFS[e.tag].get(e.get("id"))
    if definition is None:
        raise ValueError(f"unknown {e.tag} {e.get('id')}")
    x = float(e.get("x", "0"))
    key = "size" if e.tag == "obj" else "x2"
    width = max(1, float(definition.get(key, "1")))
    if e.get("w"):
        # Scaled back sprites use scX, while mirror placement uses w as width.
        # Conservative bound covers both rather than silently cutting a sprite.
        width = max(width, float(e.get("w")), width * float(e.get("w")))
    return x, x + width


def load_rooms(biome):
    path = ROOT / "Rooms" / f"rooms_{biome}.xml"
    result = []
    for index, xml in enumerate(ET.parse(path).getroot().findall("room")):
        if xml.find("options").get("tip", ""):
            continue
        grid = [e.text.split(".") for e in xml.findall("a")]
        assert len(grid) == HEIGHT and all(len(row) == WIDTH for row in grid)
        result.append({"index": index, "name": xml.get("name"), "xml": xml, "grid": grid,
                       "nav": [[navigation(t) for t in row] for row in grid], "biome": biome})
    return result


def permitted(room):
    xml = room["xml"]
    if xml.find("options").get("back"):
        return False
    for e in xml.findall("obj"):
        if set(e.attrib) - {"id", "code", "x", "y", "turn", "lock", "vis", "tr"}:
            return False
        if e.get("id") not in DEFS["obj"]:
            return False
    for e in xml.findall("back"):
        if set(e.attrib) - {"id", "x", "y", "w", "h", "a", "vis"}:
            return False
        if e.get("id") not in DEFS["back"]:
            return False
    return True


def clear_cut(room, cut):
    return not any(lo < cut < hi for tag in ("obj", "back")
                   for e in room["xml"].findall(tag) for lo, hi in [extent(e)])


def visual_options(room):
    # Entire-room backwall/water/lighting cannot vary inside one combined room.
    keys = ("backwall", "color", "colorfon", "wtip", "wrad", "wopac", "water", "rad", "vis")
    return tuple(room["xml"].find("options").get(k, "") for k in keys)


def signature(room, cut):
    return tuple(tuple(row[cut - 1:cut + 1]) for row in room["nav"])


def summary(room):
    xml, grid, nav = room["xml"], room["grid"], room["nav"]
    obj = Counter(e.get("id") for e in xml.findall("obj"))
    back = Counter(e.get("id") for e in xml.findall("back"))
    def occupied(field):
        return sum(bool(t[field]) for row in nav for t in row)
    return {"index": room["index"], "name": room["name"], "objects": sum(obj.values()),
            "backs": sum(back.values()), "obj_types": dict(obj), "back_types": dict(back),
            "solid_cells": occupied(0), "shelf_cells": occupied(1), "ladder_cells": occupied(2),
            "diagonal_cells": occupied(3), "water_cells": occupied(4),
            "open_cells_per_row": [sum(t[0] == 0 for t in row) for row in nav],
            "left_open_y": [y for y in range(HEIGHT) if nav[y][0][0] == 0],
            "right_open_y": [y for y in range(HEIGHT) if nav[y][-1][0] == 0],
            "top_open_x": [x for x in range(WIDTH) if nav[0][x][0] == 0],
            "bottom_open_x": [x for x in range(WIDTH) if nav[-1][x][0] == 0],
            "options": dict(xml.find("options").attrib)}


def combine(pieces, name):
    """Copy entire source blocks and all their objects; keep one player marker."""
    root = ET.Element("room", name=name)
    grid = [[] for _ in range(HEIGHT)]
    xoffset = 0
    provenance = []
    marks = []
    for source, left, right in pieces:
        for y in range(HEIGHT):
            grid[y].extend(source["grid"][y][left:right])
        for tag in ("obj", "back"):
            for e in source["xml"].findall(tag):
                x, end = extent(e)
                if left <= x < right:
                    assert end <= right or right == WIDTH
                    new = copy.deepcopy(e)
                    shifted = x - left + xoffset
                    new.set("x", str(int(shifted)) if shifted.is_integer() else str(shifted))
                    if new.tag == "obj" and new.get("id") == "player":
                        marks.append(new)
                    else:
                        root.append(new)
        provenance.append({"biome": source["biome"], "room_index": source["index"], "room_name": source["name"],
                           "source_x": [left, right - 1], "output_x": [xoffset, xoffset + right - left - 1]})
        xoffset += right - left
    assert xoffset == WIDTH
    for y, row in enumerate(grid):
        node = ET.Element("a")
        node.text = ".".join(row)
        root.insert(y, node)
    if len(marks) != 1:
        return None
    root.append(marks[0])
    # Host-core replacement keeps the original outside boundary and doors.
    host = pieces[0][0]
    assert pieces[-1][0] is host
    root.append(copy.deepcopy(host["xml"].find("doors")))
    root.append(copy.deepcopy(host["xml"].find("options")))
    # Object code is an identity, not a visual relationship; ensure uniqueness.
    codes = set()
    for n, e in enumerate(root.findall("obj")):
        if e.get("code") in codes:
            e.set("code", hashlib.sha256(f"{name}:{n}".encode()).hexdigest()[:16])
        codes.add(e.get("code"))
    seams = []
    for i in range(len(pieces) - 1):
        a, al, ar = pieces[i]
        b, bl, br = pieces[i + 1]
        assert signature(a, ar) == signature(b, bl)
        mismatch = sum(a["grid"][y][ar + dx] != b["grid"][y][bl + dx]
                       for y in range(HEIGHT) for dx in (-1, 0))
        seams.append({"output_x": provenance[i + 1]["output_x"][0], "navigation_mismatches": 0,
                      "full_token_mismatches_of_50": mismatch, "cut_objects": 0, "cut_backs": 0})
    return root, {"name": name, "provenance": provenance, "seams": seams,
                  "player_count": 1, "geometry_repair_cells": 0,
                  "boundary_and_doors": "unchanged from host", "options": dict(root.find("options").attrib)}


def main():
    assert navigation("C")[0] == 1 and navigation("_C")[0] == 0
    assert navigation("C_C")[0] == 1
    assert navigation("_А")[2] == 1 and navigation("_Б")[2] == -1
    assert navigation("_Е")[1] == 1 and navigation("_В")[3] == 1
    OUT.mkdir(parents=True, exist_ok=True)
    all_summary, search = {}, {}
    generated = ET.Element("all")
    manifest = []
    for biome in BIOMES:
        ordinary = load_rooms(biome)
        all_summary[biome] = [summary(r) for r in ordinary]
        rooms = [r for r in ordinary if permitted(r)]
        cuts = {id(r): [c for c in range(6, 43) if clear_cut(r, c)] for r in rooms}
        lookup = defaultdict(list)
        for r in rooms:
            for c in cuts[id(r)]:
                lookup[(signature(r, c), visual_options(r))].append((r, c))
        candidates = []
        distinct_geometry = set()
        for host in rooms:
            for a in cuts[id(host)]:
                if not 6 <= a <= 30:
                    continue
                for donor, b in lookup[(signature(host, a), visual_options(host))]:
                    if donor is host:
                        continue
                    for c in cuts[id(donor)]:
                        width = c - b
                        d = a + width
                        if not 12 <= width <= 30 or d > 42 or d not in cuts[id(host)]:
                            continue
                        if signature(donor, c) != signature(host, d):
                            continue
                        # Avoid cosmetic-only near-copies as a false novelty result.
                        changed = sum(host["nav"][y][a + x] != donor["nav"][y][b + x]
                                      for y in range(HEIGHT) for x in range(width))
                        if changed < 20:
                            continue
                        result = combine([(host, 0, a), (donor, b, c), (host, d, WIDTH)],
                                         f"proto_{biome}_{len(candidates)}")
                        if result is None:
                            continue
                        root, meta = result
                        key = tuple(e.text for e in root.findall("a"))
                        if key in distinct_geometry:
                            continue
                        distinct_geometry.add(key)
                        meta.update({"changed_navigation_cells_vs_host": changed,
                                     "donor_area_percent": round(100 * width / WIDTH, 1)})
                        candidates.append((root, meta))
        candidates.sort(key=lambda pair: (-pair[1]["changed_navigation_cells_vs_host"],
                                         sum(s["full_token_mismatches_of_50"] for s in pair[1]["seams"])))
        # Representative diversity: each host/donor pair once, at most four.
        selected = []
        pairs = set()
        for root, meta in candidates:
            key = tuple(p["room_index"] for p in meta["provenance"][:2])
            if key in pairs:
                continue
            pairs.add(key)
            selected.append((root, meta))
            if len(selected) == 4:
                break
        for root, meta in selected:
            generated.append(root)
            manifest.append(meta)
        search[biome] = {"ordinary_rooms": len(ordinary), "dependency_safe_rooms": len(rooms),
                         "noncutting_cut_positions": sum(map(len, cuts.values())),
                         "qualified_unique_compositions": len(candidates), "selected": len(selected)}
    ET.indent(generated, space="  ")
    ET.ElementTree(generated).write(OUT / "rooms_composite.xml", encoding="utf-8", xml_declaration=True)
    report = {"scope": "throwaway geometry/style prototype; no gameplay validation", "search": search,
              "manifest": manifest, "limits": ["same biome and matching whole-room visual options",
              "25-row two-column navigation signatures match at both seams",
              "no obj/back crosses a seam; XML pixel footprint is conservatively estimated from AllData",
              "12..30 column donor replaces host core; original host outer boundary/doors retained",
              "dependencies/special rooms excluded; exactly one retained player marker",
              "background/material changes are reported, not accepted as visually validated",
              "jump reachability, triggers, sprite spill, full maps, and gameplay remain untested"]}
    (OUT / "manifest.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    (OUT / "ordinary-corpus-statistics.json").write_text(json.dumps(all_summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
