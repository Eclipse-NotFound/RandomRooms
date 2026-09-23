"""Aggregate successful cases, retaining each parent run's honest status."""
import hashlib
import json
from pathlib import Path
from xml.etree import ElementTree as ET

MOD = Path(__file__).resolve().parents[2]
ROOT = MOD / 'design/v12-runtime-comparison'
CANDIDATE = '8e0e8a83e0de96d0ca6f5162dd81f226b53cf8f0634f0ad073e9e3829ba292e9'
SOURCES = [
    ('12.2', 'plant', 'driver-descending-flight-failed'),
    ('12.2', 'stable', 'driver-descending-flight-failed'),
    ('12.2', 'sewer', 'growth-12.2-sewer'),
    ('12.2', 'mane', 'growth-12.2-mane'),
    ('12.3', 'plant', 'driver-hanging-ladder-failed'),
    ('12.3', 'stable', 'growth-12.3-stable-sewer-mane'),
    ('12.3', 'sewer', 'growth-12.3-stable-sewer-mane'),
    ('12.3', 'mane', 'growth-12.3-stable-sewer-mane'),
]


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def main():
    rows = []
    for version, scene, folder in SOURCES:
        source = ROOT / folder
        manifest = read_json(source / 'manifest.json')
        assert manifest['sourceSha256']['development/RandomRoomsMod.swf'].lower() == CANDIDATE
        if manifest['status'] == 'complete':
            hashes = manifest['runtimeArtifacts']
        else:
            assert manifest['status'] == 'failed'
            hashes = read_json(source / 'evidence-index.json')
        names = [f'rrstyle-growth-{scene}-{suffix}' for suffix in (
            'navigation.json', 'after-growth-topology.json', 'after-growth-pool.xml')]
        for name in names:
            assert hashlib.sha256((source / name).read_bytes()).hexdigest() == hashes[name].lower(), name
        nav = read_json(source / names[0])
        topology = read_json(source / names[1])
        pool = ET.parse(source / names[2]).getroot()
        assert nav['success'] and nav['milestones'] == 4 and nav['growth']
        assert nav['persistentObjects'] > 0 and nav['wetFrames'] == 0
        assert not topology['issues'] and topology['generatedPoolRooms'] == 64
        rooms = list(pool.findall('room'))
        assert len(rooms) == 64
        assert all(r.get('rrVersion') == version and r.get('rrMasterSeed') == '20260818' for r in rooms)
        # The driver fails if a consumed cache refills. False with success
        # therefore means no loot cache existed at that case's starting anchor.
        rows.append(dict(version=version, scene=scene, success=True,
            frames=nav['frames'], persistentObjects=nav['persistentObjects'],
            cacheCheck='passed' if nav['cacheStayedEmpty'] else 'no cache at anchor',
            milestones=4, wetFrames=nav['wetFrames'], finalRooms=len(rooms),
            source=folder, parentRunStatus=manifest['status'], appId=manifest['appId']))
    report = dict(candidateSha256=CANDIDATE, seed=20260818, passedCases=len(rows),
        boundary='Per-case native movement results; a successful case does not change a later failed parent run to passed.',
        cases=rows)
    (ROOT / 'growth-results.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
