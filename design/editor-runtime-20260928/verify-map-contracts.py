"""Check current legacy map outputs without overwriting historical evidence."""
from pathlib import Path
import hashlib,json,xml.etree.ElementTree as ET,zipfile
HERE=Path(__file__).resolve().parent;MOD=HERE.parent.parent
source=MOD/'build/style-review/comparison-batch/runtime.xml'
rooms=ET.parse(source).getroot().findall('room')
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
report=dict(passed=True,mapRooms=len(maps),pairedInputs=paired,adjacentPairs=adjacent,sourceSHA256=hashlib.sha256(source.read_bytes()).hexdigest())
(HERE/'algorithm/map-contracts.json').write_text(json.dumps(report,indent=2)+'\n','utf-8')
archive=HERE/'release-evidence.zip'
with zipfile.ZipFile(archive,'a',zipfile.ZIP_DEFLATED) as z:
    name='algorithms/comparison-batch/runtime.xml'
    assert name not in z.namelist(),'Already archived; preserve evidence'
    z.write(source,name)
print(json.dumps(report))
