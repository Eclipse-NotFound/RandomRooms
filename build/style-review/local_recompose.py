"""Strict local authored-zone replacement, deliberately separate from production."""
from __future__ import annotations
import copy
import hashlib
import importlib.util
import json
from collections import defaultdict
from pathlib import Path
import xml.etree.ElementTree as ET

spec = importlib.util.spec_from_file_location("vertical_recompose", Path(__file__).with_name("vertical_recompose.py"))
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)
spec_h = importlib.util.spec_from_file_location("horizontal_recompose", Path(__file__).with_name("horizontal_recompose.py"))
h = importlib.util.module_from_spec(spec_h)
spec_h.loader.exec_module(h)
OUT = Path(__file__).resolve().parent / "local"
SIZES = [(w, hi) for w in (8, 12, 16, 20, 24) for hi in (4, 6, 8, 12) if w * hi >= 64]


def bounds(room):
    result = []
    for tag in ("obj", "back"):
        for e in room["xml"].findall(tag):
            x0, x1 = v.extent(e)
            y0, y1 = h.vertical_extent(e)
            result.append((x0, y0, x1, y1, e))
    return result


def contents(boxes, x, y, w, hi):
    included = []
    for x0, y0, x1, y1, e in boxes:
        if x0 >= x + w or x1 <= x or y0 >= y + hi or y1 <= y:
            continue
        if x0 < x or x1 > x + w or y0 < y or y1 > y + hi:
            return None
        if e.get("id") == "player":
            return None  # Keep the host spawn(s), replacing only inhabited zones.
        included.append(e)
    return included


def border_offsets(w, hi):
    return [(dx, dy) for dy in range(-1, hi + 1) for dx in range(-1, w + 1)
            if dx <= 0 or dx >= w - 1 or dy <= 0 or dy >= hi - 1]


def local_identity(elements, x, y):
    return sorted((e.tag, e.get("id"), float(e.get("x")) - x, float(e.get("y")) - y)
                  for e in elements)


def build(host, donor, hw, dw, name):
    x, y, w, hi, els_h = hw
    dx, dy, _, _, els_d = dw
    grid = [list(row) for row in host["grid"]]
    for j in range(hi):
        grid[y + j][x:x + w] = donor["grid"][dy + j][dx:dx + w]
    root = copy.deepcopy(host["xml"])
    root.set("name", name)
    for old in list(root.findall("a")):
        root.remove(old)
    for row_index, row in enumerate(grid):
        node = ET.Element("a")
        node.text = ".".join(row)
        root.insert(row_index, node)
    remove_keys = {(e.tag, ET.tostring(e, encoding="unicode")) for e in els_h}
    for child in list(root):
        if (child.tag, ET.tostring(child, encoding="unicode")) in remove_keys:
            root.remove(child)
    for i, e in enumerate(els_d):
        child = copy.deepcopy(e)
        child.set("x", str(int(float(e.get("x")) - dx + x)))
        child.set("y", str(int(float(e.get("y")) - dy + y)))
        if child.tag == "obj":
            child.set("code", hashlib.sha256(f"{name}:{i}".encode()).hexdigest()[:16])
        root.append(child)
    return root


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    output = ET.Element("all")
    reports, search = [], {}
    for biome in v.BIOMES:
        rooms = [r for r in v.load_rooms(biome) if v.permitted(r)]
        windows = defaultdict(list)
        clear_count = 0
        for room in rooms:
            boxes = bounds(room)
            opts = v.visual_options(room)
            for w, hi in SIZES:
                offsets = border_offsets(w, hi)
                for y in range(1, v.HEIGHT - hi):
                    for x in range(1, v.WIDTH - w):
                        els = contents(boxes, x, y, w, hi)
                        if els is None or len(els) < 2:
                            continue
                        # A functional zone must contain navigable interior space.
                        if sum(room["nav"][yy][xx][0] == 0 for yy in range(y, y + hi) for xx in range(x, x + w)) < w * hi // 3:
                            continue
                        clear_count += 1
                        key = (w, hi, opts, tuple(room["nav"][y + oy][x + ox] for ox, oy in offsets))
                        windows[key].append((room, (x, y, w, hi, els)))
        candidates = []
        identities = set()
        for key, bucket in windows.items():
            if len({id(r) for r, win in bucket}) < 2:
                continue
            for host, hw in bucket:
                for donor, dw in bucket:
                    if host is donor:
                        continue
                    x, y, w, hi, eh = hw
                    dx, dy, _, _, ed = dw
                    changed = sum(host["nav"][y+j][x+i] != donor["nav"][dy+j][dx+i]
                                  for j in range(hi) for i in range(w))
                    ih, iid = local_identity(eh, x, y), local_identity(ed, dx, dy)
                    if changed < 8 or ih == iid:
                        continue
                    uniq = (host["index"], donor["index"], tuple(ih), tuple(iid), changed)
                    if uniq in identities:
                        continue
                    identities.add(uniq)
                    candidates.append((changed, host, donor, hw, dw))
        candidates.sort(key=lambda z: (-z[0], -(z[3][2] * z[3][3])))
        selected_pairs = set()
        selected = []
        for changed, host, donor, hw, dw in candidates:
            pair = host["index"], donor["index"]
            if pair in selected_pairs:
                continue
            selected_pairs.add(pair)
            selected.append((changed, host, donor, hw, dw))
            if len(selected) == 4:
                break
        for changed, host, donor, hw, dw in selected:
            name = f"local_{biome}_{len(reports)}"
            root = build(host, donor, hw, dw, name)
            output.append(root)
            x, y, w, hi, eh = hw
            dx, dy, _, _, ed = dw
            meta = {"name": name, "biome": biome,
                    "host": {"index": host["index"], "name": host["name"]},
                    "donor": {"index": donor["index"], "name": donor["name"]},
                    "target_rect_xywh": [x, y, w, hi], "source_rect_xywh": [dx, dy, w, hi],
                    "removed_elements": len(eh), "copied_elements": len(ed),
                    "changed_navigation_cells": changed, "navigation_border_mismatches": 0,
                    "cut_objects": 0, "cut_backs": 0, "geometry_repairs": 0,
                    "exterior_and_doors": "unchanged host", "retained_host_player_count": sum(e.get("id") == "player" for e in root.findall("obj")),
                    "material_token_changes_on_internal_border": sum(host["grid"][y+oy][x+ox] != donor["grid"][dy+oy][dx+ox]
                        for ox,oy in border_offsets(w,hi) if 0<=ox<w and 0<=oy<hi)}
            reports.append(meta)
        search[biome] = {"eligible_rooms": len(rooms), "noncutting_windows": clear_count,
                         "distinct_candidate_records": len(candidates), "selected": len(selected)}
    ET.indent(output)
    ET.ElementTree(output).write(OUT / "rooms_local.xml", encoding="utf-8", xml_declaration=True)
    report = {"scope": "throwaway local functional-zone prototype; not gameplay tested", "search": search,
              "manifest": reports, "limits": ["boundary navigation matches both an internal and an external ring",
              "obj vertical bound uses y+1-wid..y+1; back uses y..y+y2; conservative scaled bounds",
              "player markers and external navigation/doors are unchanged from host",
              "no geometry edits, no individually relocated furniture, no new noise",
              "local sprite overspill and actual movement still require game visual checks"]}
    (OUT / "manifest.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
