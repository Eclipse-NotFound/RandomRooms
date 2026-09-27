"""Read-only evidence for the danger/value design discussion, not a spawn test."""
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
from xml.etree import ElementTree as ET
from zipfile import ZipFile

MOD = Path(__file__).resolve().parents[2]
GAME = MOD.parent.parent
SOURCE = GAME / 'game-reference/decompiled/1.02/src102/scripts'
OUT = MOD / 'design/danger-value-2026-09-27/native-evidence.json'


def main():
    report = {'scope': 'Static 1.02 source/authoring audit; counts are not runtime probabilities or loot value.',
              'sources': {}, 'nativeOrdinaryRooms': {}, 'comparisonXml': {}}

    def read(path):
        data = path.read_bytes()
        report['sources'][path.relative_to(GAME).as_posix()] = hashlib.sha256(data).hexdigest()
        return data

    data = read(SOURCE / 'fe/AllData.as').decode('utf-8-sig')
    definitions = {}
    for tag in re.findall(r'<obj\b[^>]*>', data):
        attrs = dict(re.findall(r'(\w+)=[\x27\x22]([^\x27\x22]*)[\x27\x22]', tag))
        if attrs.get('id'):
            definitions[attrs['id']] = attrs
    containers = {k: v['cont'] for k, v in definitions.items() if v.get('cont')}
    report['nativeSafeDefaults'] = {k: definitions[k] for k in ('safe', 'wallsafe')}
    keys = ('enl1', 'enl2', 'enf1', 'enc1', 'lov', 'turret', 'landturret',
            'armturret', 'hturret', 'wturret', 'safe', 'wallsafe', 'term1', 'term2')
    for scene in ('plant', 'stable', 'sewer', 'mane'):
        rooms = ET.fromstring(read(GAME / 'Rooms' / f'rooms_{scene}.xml')).findall('room')
        ordinary = [r for r in rooms if r.find('options') is None or not r.find('options').get('tip')]
        counts = Counter(o.get('id') for r in ordinary for o in r.findall('obj'))
        report['nativeOrdinaryRooms'][scene] = {
            'rooms': len(ordinary), 'objects': {k: counts[k] for k in keys},
            'filter': 'options.tip absent or empty; fixed objects and random slots counted separately'}
    archive = MOD / 'design/v12-runtime-comparison/algorithm-evidence.zip'
    read(archive)
    with ZipFile(archive) as z:
        rooms = list(ET.fromstring(z.read('build/style-review/comparison-batch/runtime.xml')).iter('room'))
        for version in ('12.2', '12.3'):
            selected = [r for r in rooms if r.get('rrVersion') == version]
            counts = Counter()
            for room in selected:
                for obj in room.findall('obj'):
                    if obj.get('id') in containers:
                        counts['population' if obj.get('rrContent') else 'furnishing'] += 1
            report['comparisonXml'][version] = {
                'rooms': len(selected), 'nativeContObjects': dict(counts),
                'boundary': 'Generated XML objects whose native definition has cont; not actual loot items, coin value or runtime instance count.'}
    for rel in ('fe/loc/Location.as', 'fe/loc/Land.as', 'fe/serv/Interact.as',
                'fe/serv/LootGen.as', 'fe/unit/UnitTurret.as'):
        read(SOURCE / rel)
    for rel in ('src/rr/RRPopulation.as', 'src/rr/RREcology.as', 'src/rr/RRFurnish.as',
                'src/rr/RRSynth.as', 'src/rr/RRArchitecture.as', 'src/rr/RRExpedition.as'):
        read(MOD / rel)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'ordinaryRooms': {k: v['rooms'] for k, v in report['nativeOrdinaryRooms'].items()},
                      'comparisonXml': report['comparisonXml']}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
