"""Freeze a failed run honestly, including only artifacts written in its time window."""
import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import shutil

ap=argparse.ArgumentParser();ap.add_argument('source',type=Path);ap.add_argument('destination',type=Path)
args=ap.parse_args();src=args.source;dst=args.destination
m=json.loads((src/'manifest.json').read_text(encoding='utf-8-sig'))
if m.get('status')!='failed':raise ValueError('Expected failed manifest')
start=datetime.fromisoformat(m['startedUtc'].replace('Z','+00:00')).timestamp()-2
dst.mkdir(exist_ok=True)
for p in src.iterdir():
    if p.is_file() and (p.name in ('manifest.json','cases.xml','runner.log') or p.stat().st_mtime>=start):
        shutil.copy2(p,dst/p.name)
if not (dst/'cases.xml').exists() and (src.parent/'cases.xml').exists():
    shutil.copy2(src.parent/'cases.xml',dst/'cases.xml')
index={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in dst.iterdir() if p.name!='evidence-index.json'}
(dst/'evidence-index.json').write_text(json.dumps(index,indent=2)+'\n',encoding='utf-8')
print(f'Frozen failed run {m["appId"]}: {len(index)} artifacts')
