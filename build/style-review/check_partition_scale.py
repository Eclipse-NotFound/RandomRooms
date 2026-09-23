"""Check exported scale requirements independently of the AS3 planner.

Use a batch with several seeds per fixed scene/use/port condition. This checks
rectangular planning outputs, not real movement, furniture fit or aesthetics.
"""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET

SPECIAL = {'workshop', 'warehouse', 'hall', 'canal', 'roof', 'street'}
MAX_HEIGHT = {'plant': 6, 'stable': 5, 'sewer': 5, 'mane': 7}


def check(source):
    rooms = list(ET.parse(source).getroot())
    assert rooms, 'No rooms exported'
    counts = defaultdict(set)
    floor_count = ordinary = 0
    all_counts = []
    for room in rooms:
        assert room.get('rrRevision') == '12-prototype-2', room.attrib
        scene = room.get('rrTheme')
        volumes = room.findall("rrPlan/space[@kind='volume']")
        assert len(volumes) == int(room.get('rrP_count')) == int(room.get('rrP_requested'))
        all_counts.append(len(volumes))
        counts[(scene, room.get('rrForm'), room.findtext('doors'))].add(len(volumes))
        floors = Counter((v.get('top'), v.get('floor')) for v in volumes)
        if room.get('rrP_layout') == 'storeys':
            assert max(floors.values()) >= 2, ('No shared ceiling/floor', room.attrib)
            floor_count += 1
        for volume in volumes:
            role = volume.get('role')
            height = int(volume.get('floor')) - int(volume.get('top')) + 1
            if role not in SPECIAL:
                minimum = 4 if role in {'living', 'kitchen', 'medical'} else 3
                assert minimum <= height <= MAX_HEIGHT[scene], (room.attrib, volume.attrib)
                ordinary += 1
    varied = sum(len(values) > 1 for values in counts.values())
    assert varied == len(counts), 'Use a multi-seed batch; fixed conditions must show varying counts'
    return dict(passed=True, input=str(source), sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                rooms=len(rooms), ordinarySpacesWithinSceneHeightBounds=ordinary,
                storeyLayoutsWithSharedCeilingAndFloor=floor_count,
                actualCountEqualsRequested=len(rooms), countRange=[min(all_counts), max(all_counts)],
                fixedConditions=len(counts), fixedConditionsWithVaryingCounts=varied,
                scope='Exported prototype requirements; not physics or gameplay proof.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = check(args.input)
    args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result))
