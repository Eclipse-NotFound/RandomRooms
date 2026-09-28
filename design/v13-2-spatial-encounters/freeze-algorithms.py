"""Freeze this revision's exact source/bytes and validate historical map contracts."""
from pathlib import Path
import hashlib, json, xml.etree.ElementTree as ET, zipfile

HERE=Path(__file__).resolve().parent; MOD=HERE.parent.parent
EXPECTED='2fe250215885c6b4023357f7948e8a92928ec62b8ae8970a675b936d1103d976'
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
binary=MOD/'build/RandomRooms-v13-2-final.swf'
assert digest(binary)==EXPECTED
archive=HERE/'algorithm-evidence.zip'
assert not archive.exists(), 'Do not replace frozen evidence'
content=MOD/'build/style-review/content-batch'
legacy=MOD/'build/style-review/comparison-batch'
result=json.loads((content/'results.json').read_text('utf-8-sig'))
previous=json.loads((legacy/'results.json').read_text('utf-8-sig'))
assert result['maps']==192 and not result['failures']
assert not previous['failures']
rooms=ET.parse(legacy/'runtime.xml').getroot().findall('room')
def ports(room):
    raw=list(map(int,room.findtext('doors').split('.')))
    if room.get('rrMirror')!='1': return raw
    def mirror(p): return p+11 if p<6 else 16-p if p<11 else p-11 if p<17 else 38-p
    return [raw[mirror(p)] for p in range(22)]
maps={(r.get('rrVersion'),r.get('rrTheme'),int(r.get('x')),int(r.get('y'))):r for r in rooms}
assert len(maps)==512
paired=adjacent=0
for (version,theme,x,y),room in maps.items():
    if version=='12.2':
        other=maps['12.3',theme,x,y]
        assert ports(room)==ports(other)
        assert (room.get('rrSeed'),room.get('rrMirror'))==(other.get('rrSeed'),other.get('rrMirror'))
        paired+=1
    if (version,theme,x+1,y) in maps:
        assert ports(room)[:6]==ports(maps[version,theme,x+1,y])[11:17];adjacent+=1
    if (version,theme,x,y+1) in maps:
        assert ports(room)[6:11]==ports(maps[version,theme,x,y+1])[17:22];adjacent+=1
sources={str(p.relative_to(MOD)).replace('\\','/'):digest(p) for p in sorted((MOD/'src').rglob('*.as'))}
report=dict(passed=True,candidateSHA256=EXPECTED,candidateBytes=binary.stat().st_size,
    maps=result['maps'],legacyParity=previous.get('parity'),legacyMaps=len(maps),
    pairedInputs=paired,adjacentPairs=adjacent,contentResult={k:v for k,v in result.items() if k!='cases'},
    legacyResult={k:v for k,v in previous.items() if k!='cases'},sources=sources)
with zipfile.ZipFile(archive,'x',zipfile.ZIP_DEFLATED) as z:
    z.write(binary,'candidate/RandomRoomsMod.swf')
    for root in [MOD/'src',content,legacy]:
        for p in sorted(root.rglob('*')):
            if p.is_file() and p.suffix in ('.as','.xml','.json','.swf','.txt'):
                z.write(p,str(p.relative_to(MOD)).replace('\\','/'))
    for p in [MOD/'build/style-review/harness/ContentBatch.as',MOD/'build/style-review/harness/ComparisonBatch.as',
              MOD/'build/spatial-v132/baseline.xml',HERE/'metrics.json']:
        if p.exists():z.write(p,str(p.relative_to(MOD)).replace('\\','/'))
report['evidenceSHA256']=digest(archive)
(HERE/'algorithm-validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n','utf-8')
print(json.dumps({k:v for k,v in report.items() if k not in ('sources','contentResult','legacyResult')}))
