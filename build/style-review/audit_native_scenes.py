"""Read the actual external room corpus, without modifying game references.

Counts are authoring frequencies, NOT runtime spawn probabilities. Keep entry,
ordinary, roof/pass and back/unique rooms separate so exceptional fixtures do
not silently become a scene's ordinary population.
"""
from collections import Counter
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET

MOD = Path(__file__).resolve().parents[2]
GAME = MOD.parent.parent
SCENES = ('plant', 'stable', 'sewer', 'mane')
SOLID = set('ABCDEFGHIJKLMNOPQRST')


def room_record(room, index):
    grid = [(a.text or '').strip().split('.') for a in room.findall('a')]
    opt = room.find('options')
    options = dict(opt.attrib) if opt is not None else {}
    tip = options.get('tip', '')
    group = ('ordinary' if not tip else 'entry' if tip.startswith('beg') else
             'district' if tip in ('roof', 'pass', 'passroof') else 'special')
    walls, backgrounds, features = Counter(), Counter(), Counter()
    for row in grid:
        for code in row:
            if code[:1] in SOLID: walls[code[0]] += 1
            if len(code) > 1 and code[1] in SOLID: backgrounds[code[1]] += 1
            for c in code[1:]:
                if c not in SOLID: features[c] += 1
    return dict(index=index, name=room.get('name'), tip=tip, group=group,
                options=options, walls=dict(walls), backgrounds=dict(backgrounds),
                features=dict(features), openCells=sum(c.startswith('_') for row in grid for c in row),
                objects=dict(Counter(o.get('id') for o in room.findall('obj'))),
                backs=dict(Counter(o.get('id') for o in room.findall('back'))))


def collect():
    report = {'sources': {}, 'scenes': {}}
    for scene in SCENES:
        path = GAME/'Rooms'/f'rooms_{scene}.xml'
        rooms = ET.parse(path).getroot().findall('room')
        report['sources'][str(path.relative_to(GAME))] = hashlib.sha256(path.read_bytes()).hexdigest()
        records = [room_record(r, i) for i, r in enumerate(rooms)]
        grouped = {}
        for group in ('ordinary', 'entry', 'district', 'special'):
            items = [r for r in records if r['group'] == group]
            summary = {'rooms': len(items)}
            for field in ('walls', 'backgrounds', 'features', 'objects', 'backs'):
                frequency = Counter(k for r in items for k in r[field])
                count = sum((Counter(r[field]) for r in items), Counter())
                summary[field] = {k: {'rooms': frequency[k], 'count': count[k]} for k in sorted(count)}
            grouped[group] = summary
        report['scenes'][scene] = {'count': len(rooms), 'groups': grouped, 'rooms': records}
    return report


if __name__ == '__main__':
    output = MOD/'build/style-review/native-scene-corpus.json'
    report = collect()
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({s: {g: v['rooms'] for g, v in r['groups'].items()}
                      for s, r in report['scenes'].items()}, ensure_ascii=False, indent=2))
