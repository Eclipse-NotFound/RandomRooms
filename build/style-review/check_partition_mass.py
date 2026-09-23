"""Verify actual mass and merge geometry and the exported logical grouping."""
from collections import Counter
from pathlib import Path
import argparse
import hashlib
import json
import xml.etree.ElementTree as ET
from audit_native_mass import mass_metrics


def check(path):
    rooms=ET.parse(path).getroot().findall('room');assert rooms
    totals=Counter();counts=[]
    for room in rooms:
        assert room.get('rrRevision')=='12-prototype-3'
        grid=[a.text.strip().split('.') for a in room.findall('a')]
        volumes=room.findall("rrPlan/space[@kind='volume']");groups=list(range(len(volumes)))
        assert len(volumes)==int(room.get('rrP_requested'))==int(room.get('rrP_count'))
        occupied=set()
        def cells(r):
            return {(x,y) for x in range(int(r.get('x0')),int(r.get('x1'))+1) for y in range(int(r.get('top')),int(r.get('floor'))+1)}
        for volume in volumes+room.findall('rrPlan/mass'):
            footprint=cells(volume)
            assert all(1<=x<=46 and 1<=y<=23 for x,y in footprint)
            assert not occupied&footprint
            occupied.update(footprint)
        merges=room.findall('rrPlan/merge');totals['merges']+=len(merges)
        for merge in merges:
            a,b=int(merge.get('a')),int(merge.get('b'));ga,gb=groups[a],groups[b]
            assert ga!=gb,'Merge must join distinct rooms'
            cut=cells(merge)
            assert all(grid[y][x][0] not in 'ABCDEFGHIJKLMNOPQRST' for x,y in cut),'Merge was filled in later'
            if merge.get('axis')=='side':
                assert len({x for x,y in cut})==1 and len(cut)>=3
            else:
                assert merge.get('axis')=='floor' and len({y for x,y in cut})==1 and len(cut)>=5
            assert any((x+dx,y+dy) in cells(volumes[a]) for x,y in cut for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)])
            assert any((x+dx,y+dy) in cells(volumes[b]) for x,y in cut for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)])
            groups=[ga if value==gb else value for value in groups]
            totals['axis_'+merge.get('axis')]+=1
        assert len(set(groups))==int(room.get('rrP_rooms'))
        assert max(Counter(groups).values())<=3
        for i,v in enumerate(volumes):
            assert all((groups[i]==groups[j])==(v.get('room')==w.get('room')) for j,w in enumerate(volumes))
        totals['rectangles']+=len(volumes);totals['plannedMasses']+=len(room.findall('rrPlan/mass'))
        metrics=mass_metrics(room);totals['roomsWithRealThickBlock']+=metrics['thickCells']>0
        counts.append(len(set(groups)))
    return dict(passed=True,input=str(path),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),samples=len(rooms),
                countRange=[min(counts),max(counts)],**totals,scope='Real solid tiles and explicit broad merges; no movement or semantic native-room count proof.')


if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('input',type=Path);ap.add_argument('--output',type=Path,required=True);args=ap.parse_args()
    result=check(args.input);args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print(json.dumps(result))
