"""Freeze only files attributed to a completed native capture run."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('destination',type=Path)
    ap.add_argument('--session',choices=('app','visual-app'),default='app'); args=ap.parse_args()
    app=Path(__file__).resolve().parent/'game-harness'/args.session; source=app/'captures'
    manifest=json.loads((source/'manifest.json').read_text(encoding='utf-8-sig'))
    if manifest.get('status')!='complete' or manifest.get('failed'): raise ValueError('Run did not pass')
    files={}
    for key in ('captured','runtimeArtifacts'):
        value=manifest.get(key,{})
        if isinstance(value,dict): files.update(value)
    if not any(name.endswith('.png') for name in files): raise ValueError('No image hashes in manifest')
    for name,expected in files.items():
        actual=hashlib.sha256((source/name).read_bytes()).hexdigest()
        if actual.lower()!=expected.lower(): raise ValueError('Hash mismatch '+name)
    for path,key in ((source/'runner.log','runnerLogSha256'),(app/'cases.xml','casesSha256')):
        if hashlib.sha256(path.read_bytes()).hexdigest().lower()!=manifest[key].lower(): raise ValueError('Hash mismatch '+path.name)
    args.destination.mkdir(parents=True,exist_ok=False)
    for name in files: shutil.copy2(source/name,args.destination/name)
    for name in ('manifest.json','runner.log'): shutil.copy2(source/name,args.destination/name)
    shutil.copy2(app/'cases.xml',args.destination/'cases.xml')
    print(f'Frozen {len(files)} verified artifacts: {args.destination}')

if __name__=='__main__': main()
