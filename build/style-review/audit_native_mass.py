"""Native solid-volume evidence. Does not infer authored room counts."""
from pathlib import Path
import argparse
import copy
import hashlib
import json
import statistics
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[2]
GAME=ROOT.parents[1]
EXAMPLES={'plant':[14,24,44],'stable':[1,20,19],'sewer':[7,18,19],'mane':[51,26,45]}


def mass_metrics(room):
    grid=[a.text.strip().split('.') for a in room.findall('a')]
    solid={(x,y) for y in range(1,24) for x in range(1,47) if grid[y][x][0] in 'ABCDEFGHIJKLMNOPQRST'}
    thick=set()
    for y in range(1,22):
        for x in range(1,43):
            block={(xx,yy) for xx in range(x,x+5) for yy in range(y,y+3)}
            if block<=solid: thick.update(block)
    return {'solidCells':len(solid),'solidPercent':round(100*len(solid)/(46*23),2),'thickCells':len(thick)}


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();scenes=[];reference=ET.Element('examples',source='native-external-1.02')
    for scene,ids in EXAMPLES.items():
        source=GAME/'Rooms'/f'rooms_{scene}.xml';rooms=ET.parse(source).getroot().findall('room')
        ordinary=[dict(index=i,name=r.get('name'),**mass_metrics(r)) for i,r in enumerate(rooms) if not r.find('options').get('tip','')]
        scenes.append(dict(scene=scene,source=source.relative_to(GAME).as_posix(),sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
            ordinaryRooms=len(ordinary),meanSolidPercent=round(statistics.mean(r['solidPercent'] for r in ordinary),2),
            withThickBlock=sum(r['thickCells']>0 for r in ordinary),rooms=ordinary,
            examples=[dict(index=i,name=rooms[i].get('name')) for i in ids]))
        index={'plant':24,'stable':20,'sewer':19,'mane':26}[scene]
        room=copy.deepcopy(rooms[index]);room.set('rrTheme',scene);room.set('sourceIndex',str(index));room.set('sourceFile',source.relative_to(GAME).as_posix());reference.append(room)
    report={'scope':'Interior solid tiles exclude the outer frame. Thick cells belong to at least one solid 5-by-3 tile rectangle. No room-count or author-probability inference.', 'scenes':scenes}
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    ET.indent(reference);ET.ElementTree(reference).write(ROOT/'build/style-review/mass-native-reference.xml',encoding='utf-8',xml_declaration=True)
    print(json.dumps([{k:v for k,v in s.items() if k not in ('rooms','examples')} for s in scenes]))


if __name__=='__main__':main()
