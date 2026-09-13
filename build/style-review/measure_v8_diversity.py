"""Measure exported AS3 rooms, not a Python reimplementation of generation.

Graph fingerprints ignore node order, coordinates, theme and reflection. Distinct
WL fingerprints certify different graphs; matching ones may still differ, so the
reported count is a lower bound on connectivity diversity.
"""
from collections import Counter, deque
import argparse
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET

WALL=set('ABCDEFGHIJKLMNOPQRST')

def digest(text):
    return hashlib.sha256(text.encode()).hexdigest()

def measure(path):
    rooms=ET.parse(path).getroot().findall('room')
    floors=Counter(); shapes=Counter(); cycles=Counter(); degrees=Counter(); ports=Counter()
    sizes=Counter(); attempts=Counter(); graphs=set(); long_rooms=0; planned_rooms=0
    for room in rooms:
        grid=[a.text.strip().split('.') for a in room.findall('a')]
        for y in range(1,24):
            run=0
            for x in range(48):
                floor=grid[y][x][0] in WALL or '-' in grid[y][x]
                run=run+1 if floor and grid[y-1][x][0] not in WALL else 0
                if run>=6: floors[y]+=1; break
        has_plan=room.find('rrPlan') is not None
        planned_rooms+=has_plan
        edges=[(int(e.get('a')),int(e.get('b'))) for e in room.findall('rrPlan/link')]
        if edges:
            n=max(max(e) for e in edges)+1
            adjacency=[set() for _ in range(n)]
            for a,b in edges: adjacency[a].add(b);adjacency[b].add(a)
            cycles[len(edges)-n+1]+=1; sizes[n]+=1
            degree=tuple(sorted(map(len,adjacency))); degrees[str(degree)]+=1
            labels=list(map(str,map(len,adjacency)))
            for _ in range(9):
                labels=[digest(labels[i]+':'+','.join(sorted(labels[j] for j in adjacency[i]))) for i in range(n)]
            fingerprint=digest(','.join(sorted(labels)))
            graphs.add(fingerprint)
        shape=tuple(sorted((int(r.get('x1'))-int(r.get('x0'))+1,int(r.get('floor'))-int(r.get('top'))+1)
                           for r in room.findall('rrPlan/space') if r.get('kind','volume')=='volume'))
        if has_plan: shapes[shape]+=1
        for p,a in enumerate(map(int,room.findtext('doors').split('.'))):
            if a>=2: ports[p]+=1
        attempts[int(room.get('rrAttempts','1'))]+=1
        long_rooms+=any(int(l.get('bottom'))-int(l.get('top'))>12 for l in room.findall('rrPlan/ladder'))
    return dict(path=str(path),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),rooms=len(rooms),
                exposed_floor_bands_at_row=dict(sorted(floors.items())),rooms_with_plan_metadata=planned_rooms,
                volumes=dict(sizes) if planned_rooms else None,cycle_rank=dict(cycles) if planned_rooms else None,
                degree_sequences=dict(degrees) if planned_rooms else None,
                connectivity_types_lower_bound=len(graphs) if planned_rooms else None,
                size_combinations=len(shapes) if planned_rooms else None,
                slots=dict(sorted(ports.items())),attempts=dict(attempts),
                rooms_with_ladder_longer_than_12_tiles=long_rooms if planned_rooms else None)

def verify_map(path):
    root=ET.parse(path).getroot(); nodes={};errors=[]
    for room in root.findall('room'):
        a=list(map(int,room.findtext('doors').split('.')))
        if room.get('rrMirror')=='1':
            b=[0]*22
            for i,n in enumerate(a):
                j=i+11 if i<6 else 16-i if i<11 else i-11 if i<17 else 38-i
                b[j]=n
            a=b
        nodes[int(room.get('x')),int(room.get('y'))]=a
    graph={key:set() for key in nodes}; aligned=0; vertical_pairs=0
    for (x,y),a in nodes.items():
        for dx,dy,start,end in [(1,0,0,6),(0,1,6,11)]:
            key=x+dx,y+dy
            if key not in nodes: continue
            b=nodes[key]
            for p in range(start,end):
                if a[p]!=b[p+11]: errors.append(f'mismatch {(x,y)} port {p}')
                if a[p]>=2 and b[p+11]>=2: graph[x,y].add(key);graph[key].add((x,y))
        if any(a[p]>=2 for p in range(6,11)) and any(a[p]>=2 for p in range(17,22)):
            vertical_pairs+=1
            aligned+=any(a[p]>=2 and a[p+11]>=2 for p in range(6,11))
        if x==0 and any(a[11:17]): errors.append(f'left exterior {(x,y)}')
        if y==0 and any(a[17:]): errors.append(f'top exterior {(x,y)}')
    q=deque([(0,0)]); seen={(0,0)}
    while q:
        for n in graph[q.popleft()]-seen: seen.add(n);q.append(n)
    if len(seen)!=len(nodes): errors.append(f'disconnected {len(seen)}/{len(nodes)}')
    if root.get('orderIndependent')!='true': errors.append('AS3 order independence not checked')
    return dict(path=str(path),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),rooms=len(nodes),
                connected=len(seen),two_vertical_ports=vertical_pairs,aligned_top_bottom=aligned,errors=errors)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('new',type=Path);ap.add_argument('--old',type=Path)
    ap.add_argument('--map',type=Path);ap.add_argument('--output',required=True,type=Path);args=ap.parse_args()
    result={'new':measure(args.new)}
    if args.old: result['old']=measure(args.old)
    if args.map: result['map']=verify_map(args.map)
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    compact={k:{a:b for a,b in v.items() if a not in ('degree_sequences','slots')} for k,v in result.items()}
    print(json.dumps(compact,ensure_ascii=False,indent=2))
    if result.get('map',{}).get('errors'): raise SystemExit(1)

if __name__=='__main__': main()
