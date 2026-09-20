"""Compare actual tile geometry; author room counts are not inferred from air.

Largest clear rectangle measures excessive empty volume, not the number of
semantic rooms. Generated rrPlan counts are reported separately from natives.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
from statistics import mean, median
import xml.etree.ElementTree as ET

MOD=Path(__file__).resolve().parents[2]
GAME=MOD.parent.parent
WALL=set('ABCDEFGHIJKLMNOPQRST')
SUPPORT=set('-ДЕКНРВГИЙЛМ')

def measure(room):
    grid=[(a.text or '').strip().split('.') for a in room.findall('a')]
    heights=[0]*len(grid[0]); largest=0; air=0
    for row in grid:
        for x,cell in enumerate(row):
            clear=cell[:1] not in WALL and not (set(cell[1:])&SUPPORT)
            heights[x]=heights[x]+1 if clear else 0
            air+=cell[:1] not in WALL
        stack=[]
        for x,h in enumerate(heights+[0]):
            start=x
            while stack and stack[-1][1]>h:
                start,old=stack.pop();largest=max(largest,old*(x-start))
            stack.append((start,h))
    spaces=[s for s in room.findall('rrPlan/space') if s.get('kind')=='volume']
    areas=[(int(s.get('x1'))-int(s.get('x0'))+1)*(int(s.get('floor'))-int(s.get('top'))+1)
           for s in spaces if s.get('role') not in ('roof','street','canal','corridor','hall','workshop','warehouse')]
    return {'maxClearRectangle':largest,'airFraction':air/sum(map(len,grid)),
            'generatedVolumes':len(spaces) if spaces else None,'functionalAreas':areas}

def summarize(rooms):
    data=[measure(r) for r in rooms]
    if not data:return {'rooms':0}
    counts=[d['generatedVolumes'] for d in data if d['generatedVolumes'] is not None]
    areas=[a for d in data for a in d['functionalAreas']]
    return {'rooms':len(rooms),'medianMaxClearRectangle':median(d['maxClearRectangle'] for d in data),
            'meanAirFraction':round(mean(d['airFraction'] for d in data),3),
            'meanGeneratedVolumes':round(mean(counts),2) if counts else None,
            'volumeRange':[min(counts),max(counts)] if counts else None,
            'medianFunctionalArea':median(areas) if areas else None,
            'forms':dict(Counter(r.get('rrForm','authored') for r in rooms))}

def main():
    ap=argparse.ArgumentParser();ap.add_argument('before',type=Path);ap.add_argument('after',type=Path)
    ap.add_argument('--output',type=Path,required=True);args=ap.parse_args()
    pools={key:ET.parse(path).getroot().findall('room') for key,path in [('before',args.before),('after',args.after)]}
    result={'note':'Native ordinary rooms only. Clear rectangle and air fraction are geometric proxies, not semantic room counts.',
            'hashes':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (args.before,args.after)},'scenes':{}}
    for scene in ('plant','stable','sewer','mane'):
        native=ET.parse(GAME/'Rooms'/f'rooms_{scene}.xml').getroot().findall('room')
        native=[r for r in native if r.find('options') is None or not r.find('options').get('tip')]
        row={'nativeOrdinary':summarize(native)}
        row.update({key:summarize([r for r in rooms if r.get('rrTheme')==scene]) for key,rooms in pools.items()})
        result['scenes'][scene]=row
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result['scenes'],ensure_ascii=False,indent=2))

if __name__=='__main__':main()
