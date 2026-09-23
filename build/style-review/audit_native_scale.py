"""Measure explicit terrain clearance bands, not inferred author-room counts."""
from collections import Counter
from pathlib import Path
import argparse
import copy
import hashlib
import json
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[2]
GAME=ROOT.parents[1]
SOLID=set('ABCDEFGHIJKLMNOPQRST')
SHELF_OR_SLOPE={chr(n) for n in range(1042,1059)}|{'-'}
EXAMPLES={'plant':[6,14,24,44,28],'stable':[1,19,28],'sewer':[7,19],'mane':[51,45]}


def collect(scene):
    path=GAME/'Rooms'/f'rooms_{scene}.xml'
    rooms=ET.parse(path).getroot().findall('room'); bands=[]; ordinary=0
    for index,room in enumerate(rooms):
        options=room.find('options')
        if options is not None and options.get('tip',''): continue
        ordinary+=1
        grid=[(a.text or '').strip().split('.') for a in room.findall('a')]
        assert len(grid)==25 and all(len(row)==48 for row in grid)
        for ceiling in range(24):
            for floor in range(ceiling+4,25):
                valid=[]
                for x in range(48):
                    bounded=grid[ceiling][x][:1] in SOLID and grid[floor][x][:1] in SOLID
                    clear=all(grid[y][x][:1] not in SOLID and not(set(grid[y][x][1:])&SHELF_OR_SLOPE)
                              for y in range(ceiling+1,floor))
                    if bounded and clear: valid.append(x)
                start=previous=None
                for x in valid+[100]:
                    if previous is None or x!=previous+1:
                        if start is not None and previous-start+1>=5:
                            bands.append(dict(roomIndex=index,roomName=room.get('name'),x0=start,x1=previous,
                                              ceilingY=ceiling,floorY=floor,clearHeight=floor-ceiling-1))
                        start=x
                    previous=x
    return dict(scene=scene,source=str(path.relative_to(GAME)),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                ordinaryRooms=ordinary,bands=len(bands),heights=dict(sorted(Counter(b['clearHeight'] for b in bands).items())),
                examples=[{'index':i,'name':rooms[i].get('name')} for i in EXAMPLES[scene]],bandDetails=bands)


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);args=ap.parse_args()
    report={'scope':'Terrain bands bounded above and below by solid tiles, no intervening solid/beam/slope, width >=5, height >=3. Vertical ladders allowed. Objects and side walls ignored. Not author-room counts, probabilities or gameplay clearance.',
            'scenes':[collect(scene) for scene in EXAMPLES]}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    reference=ET.Element('examples',source='native-external-1.02')
    for scene,index in [('plant',24),('stable',19),('sewer',19),('mane',51)]:
        room=copy.deepcopy(ET.parse(GAME/'Rooms'/f'rooms_{scene}.xml').getroot().findall('room')[index])
        room.set('rrTheme',scene);room.set('sourceIndex',str(index));room.set('sourceFile',f'Rooms/rooms_{scene}.xml')
        reference.append(room)
    ET.indent(reference);ET.ElementTree(reference).write(ROOT/'build/style-review/scale-native-reference.xml',encoding='utf-8',xml_declaration=True)
    print(json.dumps([{k:v for k,v in s.items() if k not in ('bandDetails','examples')} for s in report['scenes']],ensure_ascii=False))


if __name__=='__main__': main()
