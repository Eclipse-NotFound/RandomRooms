"""Read-only native-room evidence for the fracture design investigation.

Counts are authored XML occurrences, never encounter probabilities or a damage score.
The generated capture input copies author geometry and adds provenance attributes only.
"""
import copy
import hashlib
import json
import re
import sys
from collections import Counter
from pathlib import Path
import xml.etree.ElementTree as ET

MOD = Path(__file__).resolve().parents[2]
GAME = MOD.parents[1]
OUT = MOD / 'design/fracture-study-2026-09-28'
NEW = [('plant', 54), ('stable', 9), ('stable', 17), ('stable', 22),
       ('stable', 48), ('sewer', 18), ('mane', 0), ('mane', 60), ('mane', 46)]
OLD = [('plant', 16, 'assets/native-scenes-2026-09-20/rrstyle-native-scene-examples-0-room.png'),
       ('stable', 20, 'assets/native-scenes-2026-09-20/rrstyle-native-scene-examples-4-room.png'),
       ('sewer', 9, 'assets/native-scenes-2026-09-20/rrstyle-native-scene-examples-6-room.png'),
       ('sewer', 19, 'assets/native-scenes-2026-09-20/rrstyle-native-scene-examples-8-room.png'),
       ('mane', 26, 'partition-preview-v12-3/native-captures/rrstyle-mass-native-reference-3-room.png'),
       ('mane', 45, 'assets/native-scenes-2026-09-20/rrstyle-native-scene-examples-10-room.png'),
       ('mane', 51, 'assets/native-scenes-2026-09-20/rrstyle-native-scene-examples-11-room.png')]


def describe(room, index, line):
    grid = [a.text.strip().split('.') for a in room.findall('a')]
    assert len(grid) == 25 and all(len(row) == 48 for row in grid)
    inner = [grid[y][x] for y in range(1, 24) for x in range(1, 47)]
    front = Counter(t[0] for t in inner if t[0] in 'ABCDEFGHIJKLMNOPQRST')
    backs = Counter(b.get('id') for b in room.findall('back'))
    obj = Counter(o.get('id') for o in room.findall('obj'))
    opt = room.find('options')
    return dict(index=index, name=room.get('name'), line=line,
                tip=opt.get('tip', '') if opt is not None else '',
                frontMaterials=dict(front), solidCells=sum(front.values()),
                backObjects=dict(backs), backPlacements=[dict(b.attrib) for b in room.findall('back')], objects=dict(obj),
                holeObjects=sum(n for k, n in backs.items() if k.startswith(('hole', 'chole'))),
                heapObjects=sum(n for k, n in backs.items() if k.startswith('heap')),
                grid=grid, options=dict(opt.attrib) if opt is not None else {})


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    OUT.mkdir(parents=True, exist_ok=True)
    reference = ET.Element('examples', source='external-native-1.02-fracture-study')
    scenes, lookup = [], {}
    for scene in ('plant', 'stable', 'sewer', 'mane'):
        path = GAME / 'Rooms' / f'rooms_{scene}.xml'
        raw = path.read_text(encoding='utf-8-sig')
        rooms = ET.fromstring(raw).findall('room')
        lines = [raw.count('\n', 0, m.start()) + 1 for m in re.finditer(r'<room\s', raw)]
        descriptions = []
        for i, room in enumerate(rooms):
            d = describe(room, i, lines[i])
            lookup[scene, i] = (room, d)
            descriptions.append({k: v for k, v in d.items() if k != 'grid'})
        ordinary = [d for d in descriptions if not d['tip']]
        scenes.append(dict(scene=scene, source=path.relative_to(GAME).as_posix(),
                           sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                           total=len(rooms), ordinary=len(ordinary),
                           ordinaryWithHole=sum(d['holeObjects'] > 0 for d in ordinary),
                           ordinaryWithHeap=sum(d['heapObjects'] > 0 for d in ordinary),
                           rooms=descriptions))
    examples = []
    for n, (scene, i) in enumerate(NEW):
        original, d = lookup[scene, i]
        r = copy.deepcopy(original)
        for k, v in dict(rrTheme=scene, sourceIndex=str(i), sourceFile=f'Rooms/rooms_{scene}.xml').items():
            r.set(k, v)
        reference.append(r)
        examples.append(dict(scene=scene, image=f'native-captures/rrstyle-fracture-native-reference-{n}-room.png',
                             capture='new-native', **d))
    for scene, i, image in OLD:
        examples.append(dict(scene=scene, image='../' + image, capture='previous-native', **lookup[scene, i][1]))
    # A roof normally receives ramka=6 -> backform=2 from Land, which a
    # one-room beg0 capture does not supply. Reproduce the background context
    # explicitly in a separate fixture, without editing native geometry.
    roof = copy.deepcopy(lookup['mane', 46][0])
    roof.set('rrTheme', 'mane')
    roof.set('sourceIndex', '46')
    roof.set('sourceFile', 'Rooms/rooms_mane.xml')
    roof.find('options').set('backform', '2')
    roof.find('options').set('transpfon', '1')
    roof_reference = ET.Element('examples', source='native-roof-background-context')
    roof_reference.append(roof)
    ET.indent(roof_reference)
    ET.ElementTree(roof_reference).write(MOD / 'build/style-review/fracture-roof-context.xml', encoding='utf-8', xml_declaration=True)
    for d in examples:
        if d['scene'] == 'mane' and d['index'] == 46:
            d['image'] = 'roof-context/rrstyle-fracture-roof-context-room.png'
            d['captureNote'] = 'Explicit backform=2/transpfon=1 restore the normal roof background. Outer boundary remains isolated.'
    ET.indent(reference)
    ET.ElementTree(reference).write(MOD / 'build/style-review/fracture-native-reference.xml',
                                    encoding='utf-8', xml_declaration=True)
    result = dict(scope='Four external 1.02 scene pools; XML occurrences, not spawn probabilities. '
                        'Solid cells: first character A-T, interior only. Decorations and physical holes are separate.',
                  scenes=scenes, examples=examples)
    (OUT / 'native-evidence.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    all_data = (GAME / 'game-reference/decompiled/1.02/src102/scripts/fe/AllData.as').read_text(encoding='utf-8')
    hole_sizes = {}
    for raw_tag in re.findall(r'<back\s[^>]+/>', all_data):
        node = ET.fromstring(raw_tag)
        if node.get('id', '').startswith(('hole', 'chole')):
            hole_sizes[node.get('id')] = [int(node.get('x2')), int(node.get('y2'))]
    page_data = dict(scenes=[{k: v for k, v in s.items() if k != 'rooms'} for s in scenes],
                     examples=examples, holeSizes=hole_sizes)
    (OUT / 'evidence-data.js').write_text('window.FRACTURE_DATA=' + json.dumps(page_data, ensure_ascii=False, separators=(',', ':')) + ';\n', encoding='utf-8')
    print(json.dumps([{k: v for k, v in s.items() if k != 'rooms'} for s in scenes], ensure_ascii=False, indent=2))
    print('New native capture cases:', [(s, i, lookup[s, i][1]['name']) for s, i in NEW])


if __name__ == '__main__':
    main()
