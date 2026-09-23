"""Audit version inputs, neighboring ports and the frozen v12.2 source."""
from pathlib import Path
import hashlib
import json
import subprocess
import xml.etree.ElementTree as ET
import zipfile

root = Path(__file__).resolve().parents[2]
output = root / 'design/v12-runtime-comparison'
batch = root / 'build/style-review/comparison-batch'
rooms = ET.parse(batch / 'runtime.xml').getroot().findall('room')

def mirror(slot):
    return slot + 11 if slot < 6 else 16 - slot if slot < 11 else slot - 11 if slot < 17 else 38 - slot

def ports(room):
    values = list(map(int, room.findtext('doors').split('.')))
    return [values[mirror(p)] for p in range(22)] if room.get('rrMirror') == '1' else values

maps = {(r.get('rrVersion'), r.get('rrTheme'), int(r.get('x')), int(r.get('y'))): r for r in rooms}
assert len(maps) == 512
paired = adjacent = 0
for (version, theme, x, y), room in maps.items():
    if version == '12.2':
        other = maps['12.3', theme, x, y]
        assert ports(room) == ports(other)
        assert room.get('rrSeed') == other.get('rrSeed')
        assert room.get('rrMirror') == other.get('rrMirror')
        paired += 1
    if (version, theme, x+1, y) in maps:
        assert ports(room)[:6] == ports(maps[version, theme, x+1, y])[11:17]
        adjacent += 1
    if (version, theme, x, y+1) in maps:
        assert ports(room)[6:11] == ports(maps[version, theme, x, y+1])[17:22]
        adjacent += 1

imports = '\n   import rr.RREcology;\n   import rr.RRPorts;\n   import rr.RRScene;\n   import rr.RRSeed;\n'
frozen = []
for path in sorted((root / 'src/rr/v122').glob('*.as')):
    restored = path.read_text(encoding='utf-8').replace('package rr.v122\n{' + imports, 'package rr\n{', 1)
    original = subprocess.check_output(['git', 'show', '93e7fef:src/rr/' + path.name], cwd=root).decode('utf-8')
    assert restored == original, path.name
    frozen.append(path.name)
assert len(frozen) == 7
results = json.loads((batch / 'results.json').read_text(encoding='utf-8'))
assert results['parity'] == 1024 and results['maps'] == 512 and not results['failures']
report = dict(passed=True, pairedRooms=paired, adjacentEdges=adjacent, frozenV122Sources=frozen,
              parityReplays=results['parity'], runtimeRooms=results['maps'])
paths = list((root / 'src').rglob('*.as')) + [root / 'build/RandomRooms-v12-comparison-candidate.swf',
    batch / 'runtime.xml', batch / 'results.json', root / 'build/style-review/harness/ComparisonBatch.as',
    root / 'build/style-review/harness/run-comparison.ps1', Path(__file__)]
archive = output / 'algorithm-evidence.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as zip_file:
    for path in paths:
        zip_file.write(path, path.relative_to(root))
report['archiveSha256'] = hashlib.sha256(archive.read_bytes()).hexdigest()
(output / 'input-equivalence.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report))
