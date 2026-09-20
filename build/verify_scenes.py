"""Scene contract audit of actual AS3 exports, with native asset definitions.
The dry-space flood is a necessary clearance check, not a physics simulation.
Directed return validation runs in AS3; native movement is tested separately.
"""
import argparse
from collections import Counter, deque
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET
from verify_architecture import _data, WALL

BACKS = {e.get('id'): e for e in _data.findall('back')}
RULES = {
    'plant': dict(walls=set('C'), doors={'door1','door1b','door2'}, hatches={'hatch1','hatch2'},
                  windows={'window1'}, beam='-', music='music_plant_1', backwall='tBackWall',
                  forms={'production','storage_hall','service_wing'}),
    'stable': dict(walls=set('JK'), doors={'stdoor'}, hatches={'hatch2'}, windows={'window2'},
                   beam='Е', music='music_stable_1', backwall='tStConcrete',
                   forms={'quarters','atrium_ring','service_cluster'}),
    'sewer': dict(walls=set('LM'), doors={'door1','door1b'}, hatches={'hatch1','hatch2'},
                  windows={'window1'}, beam='-', music='music_sewer_1', backwall='tMossy',
                  forms={'canal_gallery','cistern','pump_chain'}),
    'mane': dict(walls=set('N'), doors={'door1','door1a'}, hatches={'hatch1','hatch2'},
                 windows={'window1','window2'}, beam='К', music='music_mane_1', backwall='sky',
                 forms={'courtyard','broken_facade','roof_passage'}),
}


def audit(room):
    errors = []
    def need(ok, why):
        if not ok: errors.append(why)
    scene = room.get('rrTheme')
    if scene not in RULES: return ['unknown scene'], {}
    rule = dict(RULES[scene])
    if room.get('rrGen')=='space-v11':
        rule['walls']={'plant':set('CD'),'stable':set('JK'),'sewer':set('ILM'),'mane':set('DN')}[scene]
        rule['doors']={'plant':{'door1','door2','door3'},'stable':{'stdoor','door1b','door2'},
                       'sewer':{'door1','door3'},'mane':{'door1','door1a'}}[scene]
        if scene=='sewer': rule['forms']=rule['forms']|{'dry_tunnels'}
        if scene=='mane' and room.get('rrRevision')=='11.1':
            rule['forms']={'apartments','offices','commercial','ruined','rooftops','street_links'}
    g = [(a.text or '').strip().split('.') for a in room.findall('a')]
    if len(g) != 25 or {len(row) for row in g} != {48}: return ['dimensions'], {}
    def solid(x,y): return not (0 <= x < 48 and 0 <= y < 25) or g[y][x][0] in WALL
    walls = {c[0] for row in g for c in row if c[0] in WALL}
    beams = {b for row in g for c in row for b in '-ДЕКНР' if b in c}
    need(walls <= rule['walls'], 'foreign foreground walls: '+str(walls-rule['walls']))
    backgrounds={c[1] for row in g for c in row if len(c)>1 and c[1] in WALL}
    allowed_backgrounds={'plant':set('CDFBJ'),'stable':set('OQNPR'),'sewer':set('CTES'),'mane':set('CDJH')}
    if room.get('rrGen')=='space-v11': allowed_backgrounds={'plant':set('BCDH'),'stable':set('OQNPR'),'sewer':set('ESH'),'mane':set('CDJH')}
    need(backgrounds <= allowed_backgrounds[scene], 'foreign background wall')
    need(beams <= {rule['beam']}, 'foreign platform material')
    need(room.get('rrForm') in rule['forms'], 'foreign spatial form')
    opt = room.find('options')
    for attr in ('music','backwall'):
        expected = rule[attr]
        if room.get('rrGen') == 'space-v11' and scene == 'mane' and attr == 'backwall':
            expected = 'sky' if room.get('rrForm') == 'roof_passage' else 'tWindows'
            if room.get('rrRevision')=='11.1':
                expected={'rooftops':'sky','street_links':'tWindows2'}.get(room.get('rrForm'),'tWindows')
        need(opt.get(attr) == expected, 'wrong '+attr)
    ids = Counter(o.get('id') for o in room.findall('obj'))
    backs = Counter(b.get('id') for b in room.findall('back'))
    for obj in room.findall('obj'):
        fixture = obj.get('rrFixture')
        if fixture: need(obj.get('id') in rule['hatches' if fixture=='hatch' else fixture+'s'], 'foreign '+fixture+': '+obj.get('id'))
    exclusive = {'stabledoor': 'stable', 'stwindow': 'stable', 'fwindow': 'plant', 'zavod1':'plant'}
    for bid, owner in exclusive.items():
        # These are this generator's contextual rules; some native maps also
        # reuse factory windows, so this does not claim global asset exclusivity.
        if scene != owner: need(not backs[bid], 'foreign contextual facility '+bid)
    if scene == 'sewer':
        need(not (set(ids)&{'couch','bed','fridge','bookcase'}), 'domestic sewer fallback')
        need(not backs['monitor'], 'unconditional sewer control wall')
    for b in room.findall('back'):
        bid=b.get('id'); d=BACKS.get(bid)
        if d is None: errors.append('unknown native back '+bid); continue
        x,y=int(b.get('x')),int(b.get('y')); w,h=int(d.get('x2','1')),int(d.get('y2','1'))
        need(all(not solid(xx,yy) for xx in range(x,x+w) for yy in range(y,y+h)),
             f'back intersects structure {bid}@{x},{y} ({w}x{h})')
    wet={(x,y) for y,row in enumerate(g) for x,c in enumerate(row) if '*' in c}
    pools=room.findall('rrPlan/water')
    needs_water=scene=='sewer' and room.get('rrForm')!='dry_tunnels'
    need(bool(wet) == needs_water, 'scene water presence')
    if scene=='sewer':
        need(opt.get('wtip')=='1' and opt.get('wrad')=='3', 'native sewer water options')
        documented=set()
        for p in pools:
            lo,hi,top,bottom,deck=(int(p.get(k)) for k in ('x0','x1','top','bottom','deck'))
            documented.update((x,y) for x in range(lo,hi+1) for y in range(top,bottom+1))
            need(deck<top, 'dry deck is not above water')
            need(all(solid(x,bottom+1) for x in range(lo,hi+1)), 'basin bottom leaks')
            need(all(solid(x,y) for x in (lo-1,hi+1) for y in range(top,bottom+1)), 'basin side leaks')
        need(documented==wet, 'undocumented water cells')
        # Remove every pose touching water, including the player's upper body.
        glass={(int(o.get('x')),int(o.get('y'))-dy) for o in room.findall('obj')
               if o.get('rrFixture')=='window' for dy in (0,1)}
        clear={(x,y) for x in range(47) for y in range(1,25)
               if all(not solid(xx,yy) and (xx,yy) not in wet|glass
                      for xx in (x,x+1) for yy in (y-1,y))}
        spawn=room.find("obj[@id='player']"); start=(int(spawn.get('x')),int(spawn.get('y')))
        need(start in clear, 'wet or blocked spawn')
        seen={start}; todo=deque(seen)
        while todo:
            x,y=todo.popleft()
            for p in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                if p in clear and p not in seen: seen.add(p);todo.append(p)
        ports=list(map(int,room.findtext('doors').split('.')))
        for p,n in enumerate(ports):
            if n<2: continue
            if p>=17: pose=(5+9*(p-17),1)
            elif p>=11: pose=(0,4*(p-11)+3)
            elif p>=6: pose=(5+9*(p-6),24)
            else: pose=(46,4*p+3)
            need(pose in seen, 'port has no dry clearance path '+str(p))
    spaces=room.findall('rrPlan/space')
    roles=Counter(s.get('role') for s in spaces if s.get('kind')=='volume')
    if scene=='plant': need(bool(roles['workshop']+roles['warehouse']), 'missing working bay')
    if scene=='sewer' and needs_water: need(bool(roles['canal']), 'missing canal space')
    if scene=='mane':
        if room.get('rrRevision')=='11.1':
            expected={'street_links':'street','rooftops':'roof'}.get(room.get('rrForm'),'building')
            need(room.get('rrDistrict')==expected,'city district differs from form')
            need(bool(roles['street']+roles['roof'])==(expected!='building'),'indoor/outdoor district mismatch')
        else: need(bool(roles['street']+roles['roof']), 'missing outside space')
    return errors, dict(scene=scene,form=room.get('rrForm'),water=len(wet),roles=dict(roles),
                        doors={o.get('id'):ids[o.get('id')] for o in room.findall('obj') if o.get('rrFixture')=='door'})


def main():
    ap=argparse.ArgumentParser();ap.add_argument('files',nargs='+',type=Path);ap.add_argument('--output',type=Path)
    a=ap.parse_args();errors=[];results=[]
    for path in a.files:
        rooms=[r for r in ET.parse(path).getroot().findall('room') if r.get('rrGen') in ('space-v9','space-v10','space-v11')]
        if not rooms: errors.append({'file':str(path),'errors':['no scene-aware rooms']})
        counts=Counter(); forms=Counter();waters=Counter()
        for r in rooms:
            err,stats=audit(r)
            if err: errors.append(dict(file=str(path),room=r.get('name'),errors=err))
            counts[stats.get('scene')]+=1;forms[stats.get('form')]+=1;waters[stats.get('scene')]+=stats.get('water',0)
        results.append(dict(file=str(path),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),rooms=len(rooms),
                            scenes=dict(counts),forms=dict(forms),waterTiles=dict(waters)))
    report=dict(passed=not errors,inputs=results,failedRooms=len(errors),errors=errors)
    if a.output:a.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({**report,'errors':errors[:6]},ensure_ascii=False,indent=2))
    raise SystemExit(bool(errors))


if __name__=='__main__':main()
