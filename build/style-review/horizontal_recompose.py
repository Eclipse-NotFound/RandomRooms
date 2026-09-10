"""Throwaway whole-floor replacement search; imports the read-only corpus loader."""
from __future__ import annotations

import copy
import json
import importlib.util
from pathlib import Path
import xml.etree.ElementTree as ET

spec = importlib.util.spec_from_file_location("vertical_recompose", Path(__file__).with_name("vertical_recompose.py"))
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)

OUT = Path(__file__).resolve().parent / "horizontal"


def vertical_extent(e):
    definition = v.DEFS[e.tag][e.get("id")]
    y = float(e.get("y", "0"))
    if e.tag == "obj":
        height = max(1, float(definition.get("wid", "1")))
        return y + 1 - height, y + 1
    height = max(1, float(definition.get("y2", "1")))
    if e.get("h"):
        height = max(height, float(e.get("h")), height * float(e.get("h")))
    return y, y + height


def clear(room, y):
    return not any(lo < y < hi for tag in ("obj", "back") for e in room["xml"].findall(tag)
                   for lo, hi in [vertical_extent(e)])


def signature(room, y):
    return tuple(tuple(row) for row in room["nav"][y - 1:y + 1])


def combine(host, donor, a, b, c, d, name):
    grid = host["grid"][:a] + donor["grid"][b:c] + host["grid"][d:]
    nav = host["nav"][:a] + donor["nav"][b:c] + host["nav"][d:]
    # Full exterior navigation stays compatible with inherited host doors.
    if any(nav[y][x] != host["nav"][y][x] for y in range(v.HEIGHT) for x in (0, v.WIDTH - 1)):
        return None
    root = ET.Element("room", name=name)
    for row in grid:
        ET.SubElement(root, "a").text = ".".join(row)
    for source, lo, hi, dy in ((host, 0, a, 0), (donor, b, c, a - b), (host, d, v.HEIGHT, 0)):
        for tag in ("obj", "back"):
            for e in source["xml"].findall(tag):
                top, bottom = vertical_extent(e)
                anchor = float(e.get("y"))
                if lo <= anchor < hi:
                    if top < lo and lo != 0 or bottom > hi and hi != v.HEIGHT:
                        return None
                    new = copy.deepcopy(e)
                    new.set("y", str(int(anchor + dy)))
                    root.append(new)
    if sum(e.get("id") == "player" for e in root.findall("obj")) != 1:
        return None
    root.append(copy.deepcopy(host["xml"].find("doors")))
    root.append(copy.deepcopy(host["xml"].find("options")))
    changed = sum(nav[y][x] != host["nav"][y][x] for y in range(v.HEIGHT) for x in range(v.WIDTH))
    if changed < 20:
        return None
    return root, {"name": name, "host": {"index": host["index"], "name": host["name"]},
                  "donor": {"index": donor["index"], "name": donor["name"]},
                  "replaced_host_rows": [a, d - 1], "copied_donor_rows": [b, c - 1],
                  "navigation_mismatches_at_seams": 0, "navigation_boundary_changes": 0,
                  "cut_objects": 0, "cut_backs": 0, "geometry_repair_cells": 0,
                  "changed_navigation_cells_vs_host": changed, "player_count": 1}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    results, search = [], {}
    output = ET.Element("all")
    for biome in v.BIOMES:
        rooms = [r for r in v.load_rooms(biome) if v.permitted(r)]
        cuts = {id(r): [y for y in range(2, 24) if clear(r, y)] for r in rooms}
        candidates = []
        hashes = set()
        for host in rooms:
            for donor in rooms:
                if host is donor or v.visual_options(host) != v.visual_options(donor):
                    continue
                for a in cuts[id(host)]:
                    for b in cuts[id(donor)]:
                        if signature(host, a) != signature(donor, b):
                            continue
                        for c in cuts[id(donor)]:
                            d = a + c - b
                            if not 4 <= c - b <= 16 or d not in cuts[id(host)]:
                                continue
                            if signature(host, d) != signature(donor, c):
                                continue
                            result = combine(host, donor, a, b, c, d, f"floor_{biome}_{len(candidates)}")
                            if result is None:
                                continue
                            root, meta = result
                            key = tuple(e.text for e in root.findall("a"))
                            if key in hashes:
                                continue
                            hashes.add(key)
                            candidates.append((root, meta))
        candidates.sort(key=lambda x: -x[1]["changed_navigation_cells_vs_host"])
        selected = candidates[:4]
        for root, meta in selected:
            output.append(root)
            results.append(meta)
        search[biome] = {"eligible_rooms": len(rooms), "clear_row_cuts": sum(map(len, cuts.values())),
                         "qualified_compositions": len(candidates), "selected": len(selected)}
    ET.indent(output)
    ET.ElementTree(output).write(OUT / "rooms_horizontal.xml", encoding="utf-8", xml_declaration=True)
    report = {"search": search, "manifest": results, "scope": "no gameplay validation; strict no-cut whole-floor search"}
    (OUT / "manifest.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
