"""Measure native wall fixture anchors against the nearest terrain support below.
This is a placement sample, not an interaction or probability model.
"""
from pathlib import Path
from collections import Counter
import json, re, xml.etree.ElementTree as ET

MOD = Path(__file__).resolve().parent.parent
GAME = MOD.parent.parent
IDS = ('term1','term2','term3','knop1','knop2','knop3','knop4','wallsafe','elpanel','alarm')
counts = {key: Counter() for key in IDS}
details = []
for scene in ('plant','stable','sewer','mane'):
    for room in ET.parse(GAME/'Rooms'/f'rooms_{scene}.xml').getroot().findall('room'):
        grid = [(r.text or '').strip().split('.') for r in room.findall('a')]
        if len(grid) != 25: continue
        for obj in room.findall('obj'):
            key = obj.get('id')
            if key not in IDS: continue
            x,y = int(obj.get('x')),int(obj.get('y'))
            floor = next((j-1 for j in range(y+1,25) if grid[j][x][0] in 'ABCDEFGHIJKLMNOPQRST' or '-' in grid[j][x]),None)
            if floor is None: continue
            lift = floor-y
            counts[key][lift] += 1
            details.append(dict(scene=scene,room=room.get('name'),id=key,x=x,y=y,floor=floor,lift=lift))
text = (GAME/'game-reference/decompiled/1.02/src102/scripts/fe/AllData.as').read_text('utf-8')
definitions = {}
for key in IDS:
    match = re.search(r'<obj\b[^>]*\bid=[\'\"]'+key+r'[\'\"][^>]*>',text)
    definitions[key] = match.group(0) if match else None
result = dict(note='floor = last free grid row above solid or shelf, lift = floor - object XML y; rows are 40 px.',counts={k:dict(v) for k,v in counts.items()},definitions=definitions,details=details)
dest=MOD/'design/editor-runtime-20260928/native-fixture-heights.json'
dest.parent.mkdir(exist_ok=True)
dest.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n','utf-8')
print(json.dumps({k:result[k] for k in ('counts','definitions')},ensure_ascii=False,indent=2))
