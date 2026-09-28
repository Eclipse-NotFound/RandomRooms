"""Read archived v13 rooms; prepare an isolated copy of the installed preview.

Does not generate new rooms, write the editor installation, or load a real save.
Run with the bundled Python. The source pools remain unchanged.
"""
from pathlib import Path
import hashlib
import json
import shutil
import xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parent
MOD = HERE.parent.parent
ROOT = MOD.parent.parent
THEMES = ("plant", "stable", "sewer", "mane")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main():
    app = HERE / "probe-app"
    samples = HERE / "samples"
    samples.mkdir(exist_ok=True)
    audit = {"purpose": "archived v13 XML and installed static renderer compatibility",
             "not_tested": ["editor UI roundtrip", "live generation", "AI", "navigation", "performance"],
             "artifacts": {}, "themes": {}}
    assets = ["Editor/Enhancements/EditorTools.swf", "Editor/Enhancements/NativeScene.swf",
              "texture.swf", "texture1.swf", "sprite.swf", "sprite1.swf", "text_zh.xml"]
    for relative in assets:
        source = ROOT / relative
        dest = app / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, dest)
        assert digest(source) == digest(dest)
        audit["artifacts"][relative] = {"bytes": source.stat().st_size, "sha256": digest(source)}
    for relative in ["pfe.swf", "Editor.swf", "mods/RandomRooms/release/RandomRoomsMod.swf"]:
        source = ROOT / relative
        audit["artifacts"][relative] = {"bytes": source.stat().st_size, "sha256": digest(source)}

    cases = []
    for theme in THEMES:
        relative = f"design/v13-content-runtime/population-release-candidate/rrstyle-navigation-{theme}-pool.xml"
        source = MOD / relative
        pool = ET.parse(source).getroot()
        rooms = pool.findall("room")
        errors = []
        object_ids = set()
        back_ids = set()
        cells = set()
        for room in rooms:
            name = room.get("name")
            rows = [(node.text or "").split(".") for node in room.findall("a")]
            if len(rows) != 25 or any(len(row) != 48 for row in rows):
                errors.append(f"{name}: grid shape")
            cells.update(cell for row in rows for cell in row)
            if len((room.findtext("doors") or "").split(".")) != 22:
                errors.append(f"{name}: door slots")
            if room.find("rrPlan") is None:
                errors.append(f"{name}: missing rrPlan")
            if len([obj for obj in room.findall("obj") if obj.get("id") == "player"]) != 1:
                errors.append(f"{name}: player marker count")
            object_ids.update(obj.get("id") for obj in room.findall("obj"))
            back_ids.update(obj.get("id") for obj in room.findall("back"))
        # Deliberately select a non-arrival room rich in actual objects, using
        # native room metadata for the mirror and explicit theme for rendering.
        eligible = [room for room in rooms if room.get("rrPopulation") != "arrival"]
        selected = max(eligible or rooms, key=lambda room: len(room.findall("obj")))
        sample = ET.Element("all", dict(pool.attrib))
        sample.append(ET.fromstring(ET.tostring(pool.find("land"))))
        sample.append(ET.fromstring(ET.tostring(selected)))
        sample_name = f"rooms_{theme}_rr_v13.xml"
        ET.indent(sample, space="  ")
        ET.ElementTree(sample).write(samples / sample_name, encoding="utf-8", xml_declaration=True)
        (app / "samples").mkdir(exist_ok=True)
        shutil.copyfile(samples / sample_name, app / "samples" / sample_name)
        native_pool = ROOT / "Rooms" / f"rooms_{theme}.xml"
        (app / "Rooms").mkdir(exist_ok=True)
        shutil.copyfile(native_pool, app / "Rooms" / native_pool.name)
        audit["themes"][theme] = {
            "source": relative, "source_sha256": digest(source), "rooms": len(rooms),
            "root_attributes": pool.attrib, "serial": pool.find("land").get("serial"),
            "mirrored_rooms": sum(room.get("rrMirror") == "1" for room in rooms),
            "object_ids": sorted(object_ids), "back_ids": sorted(back_ids), "cell_tokens": sorted(cells),
            "structural_errors": errors,
            "sample": {"path": f"samples/{sample_name}", "sha256": digest(samples / sample_name),
                       "room": selected.attrib, "objects": len(selected.findall("obj")),
                       "backs": len(selected.findall("back")), "options": selected.find("options").attrib}}
        assert not errors, errors
        cases.append({"theme": theme, "filename": f"samples/{sample_name}",
                      "region": f"random_{theme}", "mirror": selected.get("rrMirror") == "1"})
    (app / "cases.json").write_text(json.dumps(cases, indent=2), encoding="utf-8")
    (HERE / "audit.json").write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"rooms": sum(t["rooms"] for t in audit["themes"].values()),
                      "cases": cases, "isolated_app": str(app)}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
