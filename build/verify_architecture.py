"""Check actual AS3 output against game geometry/AllData contracts.
No Python generator mirror: inputs must be exported by the AIR/real-game harness.
Connectivity here checks clearance only; real movement is a separate game probe.
"""
import argparse
from collections import Counter, deque
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET

WALL = set('ABCDEFGHIJKLMNOPQRST')
ROOT = Path(__file__).resolve().parent
ALL_DATA = ROOT.parents[2]/'game-reference/decompiled/1.02/src102/scripts/fe/AllData.as'
_source = ALL_DATA.read_text(encoding='utf-8-sig')
_data = ET.fromstring(_source[_source.index('<all>'):_source.rindex('</all>')+6])
DEFS = {'object_defs': {o.get('id'): dict(o.attrib) for o in _data.findall('obj')}}


def verify(room):
    failures = []
    def check(value, detail):
        if not value: failures.append(detail)
    g = [(a.text or '').strip().split('.') for a in room.findall('a')]
    if len(g) != 25 or set(map(len,g)) != {48}:
        return ['dimensions'], {}
    def solid(x,y):
        return not (0<=x<48 and 0<=y<25) or g[y][x][0] in WALL
    def support(x,y):
        return solid(x,y+1) or '-' in g[y+1][x]
    connector = room.get('rrKind') == 'connector'
    expected = [0]*22
    expected[5]=expected[16]=3
    if connector: expected[8]=expected[19]=2
    check((room.findtext('doors') or '').split('.') == list(map(str,expected)), '22 boundary ports')
    for y in (0,24):
        holes = [x for x in range(48) if not solid(x,y)]
        check(holes == ([23,24] if connector else []), f'boundary {y}: {holes}')
    for x in (0,1,2,45,46,47):
        check(all(not solid(x,y) for y in (21,22,23)), f'horizontal opening {x}')
    shafts = set()
    for y in range(25):
        for x in range(48):
            if 'А' not in g[y][x]: continue
            shafts.update(((x-1,y),(x,y)))
            if y and 'А' not in g[y-1][x]:
                check(y>=2 and all(not solid(xx,yy) for xx in (x-1,x) for yy in (y-1,y-2)),f'ladder head {x},{y}')
                check(any(solid(xx,y) or '-' in g[y][xx] for xx in (x-2,x+1) if 0<=xx<48),f'ladder landing {x},{y}')
            if 'А' in g[y][x] and connector and x==24:
                check(not solid(23,y),f'shaft width at {y}')
    check(bool(shafts),'no ladder')
    used=set()
    objs=room.findall('obj')
    check(len({o.get('code') for o in objs})==len(objs),'duplicate object code')
    check(sum(o.get('id')=='player' for o in objs)==1,'player count')
    for o in objs:
        oid=o.get('id'); x=int(o.get('x')); y=int(o.get('y'))
        if oid.startswith('en'): continue
        if oid=='player': w,h,d=2,2,{}
        elif oid=='stdoor':
            w,h,d=1,3,{}
            check(o.get('lock')=='0' and o.get('mine')=='0',f'route door lock/trap {x},{y}')
        else:
            d=DEFS['object_defs'].get(oid)
            check(d is not None,f'unknown furniture {oid}')
            if d is None: continue
            w=int(d.get('size',1)); h=max(int(d.get('wid',1)),(int(d.get('scy',0))+39)//40)
            check(not d.get('allact'),f'script dependency {oid}')
        cells={(xx,yy) for xx in range(x,x+w) for yy in range(y-h+1,y+1)}
        check(all(not solid(xx,yy) and '-' not in g[yy][xx] for xx,yy in cells),f'object wall/platform {oid}@{x},{y}')
        check(not (cells&used),f'object overlap {oid}@{x},{y}')
        check(not(cells&shafts),f'object blocks shaft {oid}@{x},{y}')
        used.update(cells)
        if not int(d.get('wall',0)):
            check(all(support(xx,y) for xx in range(x,x+w)),f'object support {oid}@{x},{y}')
    # A player's two-cell clearance must connect every usable floor to spawn.
    clear={(x,y) for x in range(47) for y in range(1,24)
           if all(not solid(xx,yy) for xx in (x,x+1) for yy in (y-1,y))}
    visited={(1,23)}; q=deque(visited)
    while q:
        x,y=q.popleft()
        for p in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
            if p in clear and p not in visited: visited.add(p);q.append(p)
    floors={p for p in clear if support(p[0],p[1]) and support(p[0]+1,p[1])}
    isolated=floors-visited
    check(not isolated,f'isolated floor clearances: {len(isolated)}, e.g. {sorted(isolated)[:4]}')
    return failures,dict(objects=len(objs),backs=len(room.findall('back')),isolated_floor_cells=len(isolated),
                         kind=room.get('rrKind'),theme=room.get('rrTheme'))


def main():
    ap=argparse.ArgumentParser();ap.add_argument('files',nargs='+',type=Path);ap.add_argument('--output',type=Path)
    args=ap.parse_args();results=[];errors=[]
    for path in args.files:
        rooms=ET.parse(path).getroot().findall('room')
        generated=[r for r in rooms if r.get('rrGen')=='space-v7']
        if not generated: errors.append(dict(file=str(path),room=None,errors=['No generated rooms; empty evidence cannot pass']))
        stats=[]
        for r in generated:
            fail,st=verify(r);stats.append(st)
            if fail: errors.append(dict(file=str(path),room=r.get('name'),errors=fail))
        results.append(dict(file=str(path),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),rooms=len(generated),
                            kinds=dict(Counter(s.get('kind') for s in stats)),themes=dict(Counter(s.get('theme') for s in stats)),
                            object_mean=sum(s.get('objects',0) for s in stats)/max(1,len(stats)),
                            back_mean=sum(s.get('backs',0) for s in stats)/max(1,len(stats))))
    report=dict(passed=not errors,inputs=results,failed_rooms=len(errors),errors=errors)
    if args.output: args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(passed=not errors,inputs=results,failed_rooms=len(errors),examples=errors[:8]),ensure_ascii=False,indent=2))
    raise SystemExit(1 if errors else 0)

if __name__=='__main__': main()
