"""Verify release evidence and bind the final cosmetic-only build to its tests."""
from pathlib import Path
import hashlib
import json
import zipfile
from datetime import datetime, timezone

root = Path(__file__).resolve().parents[2]
proof = root / "design/v13-content-runtime"
core = "50747c20a59c4be30c56228fd9930c033ea60432ef333d0b6ab8c1fe476e261b"
final = "a5eb49a089835bbc7b670411bbdf32865f5110aeae79f8bc182af3bb4c9cbe46"
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding="utf-8-sig"))

checks = read(proof / "algorithm-checks.json")
assert checks["candidateSha256"] == core and checks["passed"]
assert digest(proof / "algorithm-evidence.zip") == checks["archiveSha256"]
changed = []
for path, expected in checks["files"].items():
    path = path.replace("\\", "/")
    if path.startswith("src/") and digest(root / path) != expected:
        changed.append(path)
assert changed == ["src/rr/RRDebugOverlay.as"], changed
with zipfile.ZipFile(proof / "algorithm-evidence.zip") as z:
    old = z.read(changed[0]).decode("utf-8").replace("\r\n", "\n")
new = (root / changed[0]).read_text(encoding="utf-8")
assert old.replace(
    'pos.x-50,pos.y+9,160,31,20,c);',
    'pos.x-50,\n                  pos.y+(mark.@kind=="security" && mark.@mount=="ceiling"?54:9),160,31,20,c);'
) == new

records = {}
for name, expected in [("ui-lifecycle-final", core), ("population-release-candidate", core),
    ("terminal-approach-plant", core), ("growth-final", core), ("overlay-final", final), ("release-smoke", final)]:
    directory = proof / name
    m = read(directory / "manifest.json")
    assert m["status"] == "complete" and not m["failed"]
    assert m["sourceSha256"]["development/RandomRoomsMod.swf"].lower() == expected
    for group in ("runtimeArtifacts", "captured"):
        for filename, h in m[group].items():
            assert digest(directory / filename) == h.lower(), (name, filename)
    assert digest(directory / "runner.log") == m["runnerLogSha256"].lower()
    assert digest(directory / "cases.xml") == m["casesSha256"].lower()
    records[name] = {"passed": True, "cases": len(m["cases"]), "sha256": expected,
                     "manifestSha256": digest(directory / "manifest.json"), "applicationId": m["appId"]}

growth = []
population = []
for scene in ("plant", "stable", "sewer", "mane"):
    g = read(proof / "growth-final" / f"rrstyle-growth-{scene}-navigation.json")
    assert g["success"] and g["milestones"] == 4
    assert all(r["success"] for r in g["records"])
    assert {r["label"] for r in g["records"] if r["kind"] == "milestone"} == {"new-column", "return-column", "new-row", "return-row"}
    if scene == "sewer": assert g["wetFrames"] == 0
    growth.append({k: g[k] for k in ("scene", "success", "frames", "milestones", "wetFrames", "persistentObjects", "cacheStayedEmpty")})
    p = read(proof / "population-release-candidate" / f"rrstyle-navigation-{scene}-population.json")
    d = read(proof / "population-release-candidate" / f"rrstyle-navigation-{scene}-content-debug.json")
    assert p["passed"] and d["success"]
    population.append({"scene": scene, "rooms": p["rooms"], "objects": len(p["records"]),
        "checks": p["checks"], "zones": d["zones"], "points": d["points"], "ceilings": d["ceilings"],
        "groundTurrets": d["groundTurrets"], "terminals": d["terminals"], "specials": d["specials"], "mirrored": d["mirrored"]})

smoke = read(proof / "release-smoke" / "production-version.json")
assert smoke["loadMode"] == "native-loader" and smoke["runtimeTag"] == "[RR:v13-dv]"
assert "error" not in smoke and smoke["loaderStatus"]["ok_RandomRoomsMod"]
assert digest(root / "release/RandomRoomsMod.swf") == final
assert digest(root / "build/RandomRooms-v13-release-candidate.swf") == final
assert digest(root / "../../pfe.swf") == "b78244657ed407d03808c90e97325509db35f802122835f58933fff8003305ac"

files = list((root / "src").rglob("*.as")) + list((root / "build/style-review/game-harness").glob("*.as")) + [
    root / "build/RandomRooms-v13-release-candidate.swf", root / "build/style-review/game-harness/run-game-captures.ps1",
    root / "build/build-v7.ps1", root / "build/rr-config.xml", Path(__file__)]
archive = proof / "release-evidence.zip"
with zipfile.ZipFile(archive, "x", zipfile.ZIP_DEFLATED) as z:
    for path in files: z.write(path, path.relative_to(root).as_posix())
result = {"passed": True, "releaseSha256": final, "mechanicsCandidateSha256": core,
    "finalDifference": "Only ceiling-turret debug label Y offset; verified exact source substitution.",
    "runs": records, "growth": growth, "population": population,
    "releaseArchiveSha256": digest(archive), "sourceSha256": {p.relative_to(root).as_posix(): digest(p) for p in files},
    "checkedUtc": datetime.now(timezone.utc).isoformat()}
(proof / "runtime-checks.json").write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
deployment = read(proof / "deployment.json")
deployment.update(status="deployed-smoke-passed", smokeCompletedUtc=result["checkedUtc"],
    smokeManifestSha256=records["release-smoke"]["manifestSha256"], smokeApplicationId=records["release-smoke"]["applicationId"],
    smokeMode="Original host manifest loader, F1/F4/F2/F5 and Shift+F3; isolated fresh profile.",
    runtimeChecksSha256=digest(proof / "runtime-checks.json"))
(proof / "deployment.json").write_text(json.dumps(deployment, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
print(json.dumps({"passed": True, "runs": records, "growthScenes": len(growth), "populationRooms": sum(p["rooms"] for p in population)}))
