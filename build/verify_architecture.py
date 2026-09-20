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
    # Native rust, steel and concrete shelves share collision semantics.
    g = [(a.text or '').strip().replace('Е','-').replace('К','-').split('.') for a in room.findall('a')]
    if len(g) != 25 or set(map(len,g)) != {48}:
        return ['dimensions'], {}
    def terrain_solid(x,y):
        return not (0<=x<48 and 0<=y<25) or g[y][x][0] in WALL
    glass={(int(o.get('x')),yy) for o in room.findall('obj') if o.get('rrFixture')=='window'
           for yy in (int(o.get('y'))-1,int(o.get('y')))}
    def solid(x,y):
        return terrain_solid(x,y) or (x,y) in glass
    def support(x,y):
        return solid(x,y+1) or '-' in g[y+1][x]
    ports=list(map(int,(room.findtext('doors') or '').split('.')))
    check(len(ports)==22,'22 boundary slots')
    holes=set()
    for p,n in enumerate(ports):
        if n<2: continue
        if 6<=p<=10 or p>=17:
            x=5+9*(p-17 if p>=17 else p-6)
            ys=(0,1) if p>=17 else (23,24)
            xs=(x,x+1)
        else:
            y=3+4*(p-11 if p>=11 else p)
            xs=(0,1) if p>=11 else (46,47)
            ys=tuple(range(y-n+1,y+1))
        for x in xs:
            for y in ys:
                check(not solid(x,y),f'blocked port {p}@{x},{y}')
                if x in (0,47) or y in (0,24): holes.add((x,y))
    actual={(x,y) for y in range(25) for x in range(48)
            if (x in (0,47) or y in (0,24)) and not solid(x,y)}
    check(actual==holes,f'undeclared boundary holes: {sorted(actual^holes)}')
    shafts = set()
    for y in range(25):
        for x in range(48):
            if 'А' not in g[y][x]: continue
            shafts.update(((x-1,y),(x,y)))
            if y and 'А' not in g[y-1][x]:
                check(y>=2 and all(not solid(xx,yy) for xx in (x-1,x) for yy in (y-1,y-2)),f'ladder head {x},{y}')
                check(any(solid(xx,y) or '-' in g[y][xx] for xx in (x-2,x+1) if 0<=xx<48),f'ladder landing {x},{y}')
            check(not solid(x-1,y),f'shaft width at {x},{y}')

    used=set()
    objs=room.findall('obj')
    check(len({o.get('code') for o in objs})==len(objs),'duplicate object code')
    check(sum(o.get('id')=='player' for o in objs)==1,'player count')
    for o in objs:
        oid=o.get('id'); x=int(o.get('x')); y=int(o.get('y'))
        if oid.startswith('en'): continue
        if oid=='player': w,h,d=2,2,{}
        else:
            d=DEFS['object_defs'].get(oid)
            check(d is not None,f'unknown furniture {oid}')
            if d is None: continue
            w=int(d.get('size',1)); h=max(int(d.get('wid',1)),(int(d.get('scy',0))+39)//40)
            allowed={'hack_robot','hack_lock','work','lab','stove','robocell','alarm','electro_check'}
            check(not d.get('allact') or (o.get('rrContent') and d.get('allact') in allowed),f'script dependency {oid}')
        cells={(xx,yy) for xx in range(x,x+w) for yy in range(y-h+1,y+1)}
        check(all(not terrain_solid(xx,yy) and '-' not in g[yy][xx] for xx,yy in cells),f'object wall/platform {oid}@{x},{y}')
        check(not (cells&used),f'object overlap {oid}@{x},{y}')
        fixture=o.get('rrFixture')
        if fixture=='hatch':
            check(w==2 and h==1 and 3<=y<=20,f'hatch dimensions/boundary {x},{y}')
            check(cells<=shafts,f'hatch must cover ladder {x},{y}')
            check(all(solid(xx,y) or '-' in g[y][xx] for xx in (x-1,x+2)),f'hatch frame {x},{y}')
        else: check(not(cells&shafts),f'object blocks shaft {oid}@{x},{y}')
        if fixture in ('door','hatch') or oid=='stdoor':
            check(o.get('lock')=='0' and o.get('mine')=='0',f'route door lock/trap {x},{y}')
        if fixture=='door':
            check(solid(x,y-h) and support(x,y),f'door frame {x},{y}')
        if fixture=='window':
            check(w==1 and h==2 and solid(x,y-2) and solid(x,y+1),f'window frame {x},{y}')
            check(all(not terrain_solid(xx,yy) for xx in (x-1,x+1) for yy in (y-1,y)),f'window sides {x},{y}')
        used.update(cells)
        if o.get('rrMount')=='ceiling':
            check(all(terrain_solid(xx,y-h) for xx in range(x,x+w)),f'ceiling support {oid}@{x},{y}')
        elif o.get('rrMount')=='wall':
            check(terrain_solid(x-1,y) or terrain_solid(x+w,y),f'wall mount {oid}@{x},{y}')
        elif o.get('rrMount')=='swim':
            check('*' in g[y][x],f'swim requires water {oid}@{x},{y}')
        elif not int(d.get('wall',0)):
            check(all(support(xx,y) for xx in range(x,x+w)),f'object support {oid}@{x},{y}')
    # A player's two-cell clearance must connect every usable floor to spawn.
    clear={(x,y) for x in range(47) for y in range(1,24)
           if all(not solid(xx,yy) for xx in (x,x+1) for yy in (y-1,y))}
    player=next(o for o in objs if o.get('id')=='player')
    spawn=(int(player.get('x')),int(player.get('y')))
    check(spawn in clear,'spawn clearance')
    visited={spawn}; q=deque(visited)
    while q:
        x,y=q.popleft()
        for p in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
            if p in clear and p not in visited: visited.add(p);q.append(p)
    floors={p for p in clear if support(p[0],p[1]) and support(p[0]+1,p[1])}
    isolated=floors-visited
    check(not isolated,f'isolated floor clearances: {len(isolated)}, e.g. {sorted(isolated)[:4]}')
    fixture_counts=Counter(o.get('rrFixture') for o in objs if o.get('rrFixture'))
    if room.get('rrRevision')=='7.1':
        check(all(fixture_counts[k]>=1 for k in ('door','hatch','window')),'missing architectural fixture')
    return failures,dict(objects=len(objs),backs=len(room.findall('back')),isolated_floor_cells=len(isolated),fixtures=dict(fixture_counts),
                         kind=room.get('rrKind'),theme=room.get('rrTheme'))


def main():
    ap=argparse.ArgumentParser();ap.add_argument('files',nargs='+',type=Path);ap.add_argument('--output',type=Path)
    args=ap.parse_args();results=[];errors=[]
    for path in args.files:
        rooms=ET.parse(path).getroot().findall('room')
        generated=[r for r in rooms if r.get('rrGen') in ('space-v7','space-v8','space-v9','space-v10')]
        if not generated: errors.append(dict(file=str(path),room=None,errors=['No generated rooms; empty evidence cannot pass']))
        stats=[]
        for r in generated:
            fail,st=verify(r);stats.append(st)
            if fail: errors.append(dict(file=str(path),room=r.get('name'),errors=fail))
        results.append(dict(file=str(path),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),rooms=len(generated),
                            kinds=dict(Counter(s.get('kind') for s in stats)),themes=dict(Counter(s.get('theme') for s in stats)),
                            fixtures=dict(sum((Counter(s.get('fixtures',{})) for s in stats),Counter())),
                            object_mean=sum(s.get('objects',0) for s in stats)/max(1,len(stats)),
                            back_mean=sum(s.get('backs',0) for s in stats)/max(1,len(stats))))
    report=dict(passed=not errors,inputs=results,failed_rooms=len(errors),errors=errors)
    if args.output: args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(passed=not errors,inputs=results,failed_rooms=len(errors),examples=errors[:8]),ensure_ascii=False,indent=2))
    raise SystemExit(1 if errors else 0)

if __name__=='__main__': main()
