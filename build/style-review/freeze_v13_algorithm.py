"""Freeze v13 algorithm evidence without replacing any v12 release evidence."""
from pathlib import Path
import hashlib
import json
import xml.etree.ElementTree as ET
import zipfile

root = Path(__file__).resolve().parents[2]
dest = root / "design/v13-content-runtime"
batch = root / "build/style-review/content-batch"
legacy = root / "build/style-review/comparison-batch"
candidate = root / "build/RandomRooms-v13-operator-candidate.swf"
expected = "50747c20a59c4be30c56228fd9930c033ea60432ef333d0b6ab8c1fe476e261b"

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

assert digest(candidate) == expected
content = json.loads((batch / "results.json").read_text(encoding="utf-8"))
previous = json.loads((legacy / "results.json").read_text(encoding="utf-8"))
assert content["maps"] == 192 and content["independence"] == 32 and not content["failures"]
assert previous["parity"] == 1024 and previous["maps"] == 512 and not previous["failures"]

def mirror(slot):
    return slot + 11 if slot < 6 else 16 - slot if slot < 11 else slot - 11 if slot < 17 else 38 - slot

def ports(room):
    values = list(map(int, room.findtext("doors").split(".")))
    return [values[mirror(p)] for p in range(22)] if room.get("rrMirror") == "1" else values

rooms = ET.parse(legacy / "runtime.xml").getroot().findall("room")
maps = {(r.get("rrVersion"), r.get("rrTheme"), int(r.get("x")), int(r.get("y"))): r for r in rooms}
paired = adjacent = 0
for (version, scene, x, y), room in maps.items():
    if version == "12.2":
        other = maps["12.3", scene, x, y]
        assert ports(room) == ports(other)
        assert room.get("rrSeed") == other.get("rrSeed") and room.get("rrMirror") == other.get("rrMirror")
        paired += 1
    if (version, scene, x+1, y) in maps:
        assert ports(room)[:6] == ports(maps[version, scene, x+1, y])[11:17]
        adjacent += 1
    if (version, scene, x, y+1) in maps:
        assert ports(room)[6:11] == ports(maps[version, scene, x, y+1])[17:22]
        adjacent += 1
frozen = []
old_archive = root / "design/v12-runtime-comparison/algorithm-evidence.zip"
old_record = json.loads((old_archive.parent / "input-equivalence.json").read_text(encoding="utf-8"))
assert digest(old_archive) == old_record["archiveSha256"]
# The public repository's image-removal rewrite changed historical commit IDs.
# Use the hash-verified deployed release archive instead of a now-missing SHA.
with zipfile.ZipFile(old_archive) as old:
    for path in sorted((root / "src/rr/v122").glob("*.as")):
        original = old.read(path.relative_to(root).as_posix()).decode("utf-8").replace("\r\n", "\n")
        assert path.read_text(encoding="utf-8") == original, path.name
        frozen.append(path.name)
assert len(frozen) == 7 and paired == 256 and adjacent == 896

archive = dest / "algorithm-evidence.zip"
paths = list((root / "src").rglob("*.as")) + [candidate, Path(__file__),
    root / "build/build-v7.ps1", root / "build/rr-config.xml",
    root / "build/style-review/harness/ContentBatch.as", root / "build/style-review/harness/ComparisonBatch.as",
    root / "build/style-review/harness/run-comparison.ps1", batch / "ContentBatch.swf", batch / "rooms.xml", batch / "results.json",
    legacy / "ComparisonBatch.swf", legacy / "runtime.xml", legacy / "results.json"]
with zipfile.ZipFile(archive, "x", zipfile.ZIP_DEFLATED) as z:
    for path in paths:
        z.write(path, str(path.relative_to(root)))
report = {
    "passed": True, "candidateSha256": expected,
    "contentRooms": content["maps"], "valueIndependencePairs": content["independence"],
    "turrets": content["turrets"], "terminals": content["terminals"],
    "legacyParityReplays": previous["parity"], "legacyMapRooms": previous["maps"],
    "legacyVersionInputPairs": paired, "legacyAdjacentEdges": adjacent, "frozenV122Sources": frozen,
    "legacySourceArchiveSha256": digest(old_archive),
    "archiveSha256": digest(archive), "archiveBytes": archive.stat().st_size,
    "files": {str(p.relative_to(root)): digest(p) for p in paths},
    "limits": ["Static AS3 generation checks; native play evidence is archived separately.",
               "Same seed value-only pairs preserve geometry, ecology, main enemies and turrets, not every secondary hazard."]
}
(dest / "algorithm-checks.json").write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
print(json.dumps({k:v for k,v in report.items() if k != "files"}, ensure_ascii=False))
