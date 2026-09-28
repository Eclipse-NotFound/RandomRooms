"""Compare frozen v13.1 and current AS3 samples; no generation in Python."""
import collections, hashlib, json, math, pathlib, statistics, xml.etree.ElementTree as ET, zipfile
ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = pathlib.Path(__file__).resolve().parent
WORK = ROOT / 'build/spatial-v132'
WORK.mkdir(parents=True, exist_ok=True)
OLD = WORK / 'baseline.xml'
if not OLD.exists():
    with zipfile.ZipFile(ROOT / 'design/editor-runtime-20260928/release-evidence.zip') as z:
        OLD.write_bytes(z.read('algorithms/content-batch/rooms.xml'))

def summarize(path):
    scenes = {}
    for scene in ('plant', 'stable', 'sewer', 'mane'):
        rows = []
        for room in ET.parse(path).getroot().findall('room'):
            if room.get('rrTheme') != scene: continue
            g = [a.text.split('.') for a in room.findall('a')]
            solid = {(x,y) for y in range(1,24) for x in range(1,47) if g[y][x][0] in 'ABCDEFGHIJKLMNOPQRST'}
            thick = set()
            for y in range(1,22):
                for x in range(1,43):
                    cells = {(xx,yy) for yy in range(y,y+3) for xx in range(x,x+5)}
                    if cells <= solid: thick |= cells
            defenders = [(int(p.get('x')),int(p.get('y'))) for p in room.findall('rrPlan/point') if p.get('kind') in ('enemy','security')]
            pairs = [math.dist(a,b) for i,a in enumerate(defenders) for b in defenders[:i]]
            rows.append(dict(seed=room.get('rrSeed'), solid=len(solid)/1058, thick=len(thick)/1058,
                defenders=len(defenders), closePairs=sum(d<4 for d in pairs), nearest=min(pairs) if pairs else None,
                layout=room.get('rrP_layout'), attempts=int(room.get('rrAttempts')), rooms=len(room.findall('rrPlan/zone')),
                recesses=int(room.get('rrP_recesses','0')), caches=len(room.findall('rrPlan/cache'))))
        scenes[scene] = dict(samples=len(rows),meanSolid=statistics.mean(r['solid'] for r in rows),
            meanThick=statistics.mean(r['thick'] for r in rows),meanDefenders=statistics.mean(r['defenders'] for r in rows),
            closePairs=sum(r['closePairs'] for r in rows),minSpacing=min((r['nearest'] for r in rows if r['nearest'] is not None),default=None),
            layouts=dict(collections.Counter(r['layout'] for r in rows)),meanRooms=statistics.mean(r['rooms'] for r in rows),
            maxAttempts=max(r['attempts'] for r in rows),recesses=sum(r['recesses'] for r in rows),caches=sum(r['caches'] for r in rows))
    return {'source':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'scenes':scenes}

results={'before':summarize(OLD)}
new=ROOT/'build/style-review/content-batch/rooms.xml'
if new.exists() and ET.parse(new).getroot().find('room').get('rrRevision')=='13.2': results['after']=summarize(new)
(OUT/'metrics.json').write_text(json.dumps(results,indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps(results,indent=2,ensure_ascii=False))
