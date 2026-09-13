"""Archive generated XML evidence without changing its original bytes."""
import hashlib
import json
from pathlib import Path
import zipfile

ROOT=Path(__file__).resolve().parent
DEST=ROOT.parents[1]/'knowledge/experiments/generator-v8-evidence'

def main():
    files=[]
    for stem in ('generated-v8-final','generated-v8-secondary'):
        files.extend(ROOT/(stem+suffix) for suffix in ('.xml','-cooked.xml','-map.xml','-manifest.json'))
        manifest=json.loads((ROOT/(stem+'-manifest.json')).read_text(encoding='utf-8-sig'))
        if hashlib.sha256((ROOT/(stem+'.xml')).read_bytes()).hexdigest().lower()!=manifest['outputSha256'].lower():
            raise ValueError('Baseline hash mismatch '+stem)
        for src,expected in manifest['sources'].items():
            actual=hashlib.sha256((ROOT.parents[1]/'src'/src).read_bytes()).hexdigest()
            if actual.lower()!=expected.lower(): raise ValueError('Source changed since export: '+src)
    files.extend(ROOT/name for name in ('v8-final-check.json','v8-diversity.json','v8-secondary-check.json','v8-secondary-diversity.json'))
    DEST.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(DEST/'generated-samples.zip','w',zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
        hashes={}
        for file in files:
            content=file.read_bytes(); hashes[file.name]=hashlib.sha256(content).hexdigest()
            archive.writestr(file.name,content)
        archive.writestr('sha256.json',json.dumps(hashes,indent=2)+'\n')
    print(DEST/'generated-samples.zip')

if __name__=='__main__': main()
