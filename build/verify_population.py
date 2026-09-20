"""Independent checks for native gameplay objects, using exported AS3 rooms."""
import argparse,json,hashlib
from collections import Counter
from pathlib import Path
import xml.etree.ElementTree as ET
from verify_architecture import verify,DEFS

DANGER={'enemy','security','hazard','trigger','damager'}
def check_room(room):
    failures,stats=verify(room)
    def require(ok,message):
        if not ok: failures.append(message)
    objs=room.findall('obj'); content=[o for o in objs if o.get('rrContent')]
    uids={o.get('uid'):o for o in content}
    require(len(uids)==len(content),'unique content uid')
    spawn=next(o for o in objs if o.get('id')=='player')
    groups={}
    native_clear=set()
    for slot,amount in enumerate(map(int,room.findtext('doors').split('.'))):
        if amount<2: continue
        if slot<6 or 11<=slot<17:
            end=3+4*(slot if slot<6 else slot-11)
            native_clear.update((x,y) for x in (range(42,48) if slot<6 else range(6)) for y in range(end-(2 if amount>2 else 1),end+1))
        else:
            left=5+9*(slot-17 if slot>=17 else slot-6)
            native_clear.update((x,y) for x in range(left-(1 if amount>2 else 0),left+2+(1 if amount>2 else 0)) for y in (range(3) if slot>=17 else range(22,25)))
    for o in content:
        oid=o.get('id'); kind=o.get('rrContent');d=DEFS['object_defs'].get(oid,{})
        require(bool(d),'unknown native object '+oid)
        w=max(1,int(d.get('size',1)));h=max(1,int(d.get('wid',1)))
        require(not any((x,y) in native_clear for x in range(int(o.get('x')),int(o.get('x'))+w) for y in range(int(o.get('y'))-h+1,int(o.get('y'))+1)), 'native exit clearing '+oid)
        require(not any(o.get(k) for k in ('prob','npc','quest','trigger')),'story dependency '+oid)
        require(not oid.startswith('boss'),'boss excluded')
        if kind in DANGER:
            require(abs(int(o.get('x'))-int(spawn.get('x')))+abs(int(o.get('y'))-int(spawn.get('y')))>=8,'spawn danger '+oid)
            require(room.get('rrPopulation') not in ('showroom','arrival','quiet'),'peaceful room danger '+oid)
        if oid=='elpanel': require(o.get('open')=='1','electric room must start off')
        if o.get('allid'):groups.setdefault(o.get('allid'),[]).append(o)
        for scr in o.findall('scr'):
            require(scr.get('act')=='unlock' and scr.get('targ') in uids,'local switch target')
            if scr.get('targ') in uids: require(uids[scr.get('targ')].get('rrContent')=='reward','switch must target optional reward')
        if oid=='term1':require(any(x.get('rrContent')=='security' and 'turret' in x.get('id') for x in content),'robot terminal without security')
        if oid=='term2':require(any(x.get('id')=='wallsafe' for x in content),'lock terminal without hackable cache')
        if room.get('rrTheme')=='sewer':require(oid not in ('raider','merc','slaver','zebra','alicorn','robot','protect','gutsy','eqd','term1','term2'),'sewer scene leak '+oid)
    for group,parts in groups.items():
        require(len(parts)==2 and {o.get('rrContent') for o in parts}=={'trigger','damager'},'incomplete circuit '+group)
        if len(parts)==2: require(4<=abs(int(parts[0].get('x'))-int(parts[1].get('x')))<=8,'circuit separation '+group)
    return failures,stats

def main():
    ap=argparse.ArgumentParser();ap.add_argument('xml',type=Path);ap.add_argument('--output',type=Path);a=ap.parse_args()
    rooms=ET.parse(a.xml).getroot().findall('room'); failures=[];counts=Counter();moods=Counter();themes={}
    if not rooms: failures.append({'room':None,'errors':['no rooms']})
    for r in rooms:
        errors,_=check_room(r)
        if errors:failures.append({'room':r.get('name'),'errors':errors})
        moods[r.get('rrPopulation')]+=1
        for o in r.findall('obj'):
            if o.get('rrContent'):
                counts[o.get('id')]+=1;themes.setdefault(r.get('rrTheme'),Counter())[o.get('rrContent')]+=1
    result={'file':str(a.xml),'sha256':hashlib.sha256(a.xml.read_bytes()).hexdigest(),'rooms':len(rooms),'passed':not failures,'moods':moods,'objects':counts,'themes':themes,'failures':failures}
    if a.output:a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k!='failures'},ensure_ascii=False));print('failures',len(failures))
    for f in failures[:8]:print(f)
    raise SystemExit(bool(failures))
if __name__=='__main__':main()
