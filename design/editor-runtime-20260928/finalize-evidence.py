from pathlib import Path
from collections import Counter
from datetime import datetime,timezone
import hashlib,json,shutil,zipfile,xml.etree.ElementTree as ET
HERE=Path(__file__).resolve().parent;MOD=HERE.parent.parent;GAME=MOD.parent.parent
def read(p): return json.loads(p.read_text('utf-8-sig'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v): p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n','utf-8')

deployment=read(HERE/'deployment.json');assert deployment['status']=='installed-awaiting-smoke'
for row in deployment['files']: assert sha(Path(row['target']))==row['after']
for path,key in [('pfe.swf','hostSHA256'),('Editor.swf','editorSHA256'),('mods/loader-manifest.txt','manifestSHA256')]: assert sha(GAME/path)==deployment[key]
smoke=read(HERE/'release-smoke/manifest.json');assert smoke['status']=='complete' and smoke['nativeLoaderSmoke']
assert smoke['sourceSha256']['native-loader/RandomRoomsMod.swf'].lower()==deployment['files'][0]['after']
assert read(HERE/'release-smoke/production-version.json')['runtimeTag']=='[RR:v13.1-editor]'
assert 'NATIVE-LOADER Shift+F5 complete export' in (HERE/'release-smoke/runner.log').read_text('utf-8')
editor=read(HERE/'results.json');assert editor['status']=='passed' and len(editor['cases'])==4
for path,item in read(HERE/'probe-inputs.json').items(): assert sha(Path(path))==item['sha256']

fixtures=Counter();summary=[];all_rooms=0
for scene in ['plant','stable','sewer','mane']:
    result=read(HERE/'population'/f'rrstyle-navigation-{scene}-content-debug.json')
    assert result['success'];all_rooms+=result['rooms']
    fixtures.update(r['id'] for r in result['wallFixtures'])
    pop=read(HERE/'population'/f'rrstyle-navigation-{scene}-population.json');assert pop['passed']
    summary.append(dict(scene=scene,rooms=result['rooms'],fixtures=len(result['wallFixtures']),export=result['export'],checks=pop.get('checks')))
alg_dir=HERE/'algorithm';alg_dir.mkdir(exist_ok=True)
for folder in ['content-batch','comparison-batch']:
    src=MOD/'build/style-review'/folder/'results.json';assert not read(src)['failures'];shutil.copyfile(src,alg_dir/(folder+'.json'))
validation=dict(status='passed',version='13.1-editor',rooms=all_rooms,fixtures=dict(fixtures),scenes=summary,editorChecks=editor['checks'],nativeLoaderCases=smoke['cases'],dateUTC=datetime.now(timezone.utc).isoformat())
write(HERE/'validation.json',validation)

# Preserve build sources and exact candidate binaries outside the public repo.
archive=HERE/'release-evidence.zip'
with zipfile.ZipFile(archive,'x',zipfile.ZIP_DEFLATED) as z:
    for file in sorted((MOD/'src').rglob('*.as')): z.write(file,'mod/'+str(file.relative_to(MOD)).replace('\\','/'))
    for file in [MOD/'build/rr-config.xml',MOD/'build/build-v7.ps1',MOD/'build/build-editor.ps1',MOD/'release/RandomRoomsMod.swf',MOD/'release/RandomRoomsEditor.swf',GAME/'Editor/Enhancements/EditorTools.swf']:
        z.write(file,str(file.relative_to(GAME)).replace('\\','/'))
    for folder in ['content-batch','comparison-batch']:
        for name in ['results.json','rooms.xml']:
            file=MOD/'build/style-review'/folder/name
            if file.exists(): z.write(file,'algorithms/'+folder+'/'+name)
deployment['status']='verified';deployment['verifiedUTC']=validation['dateUTC'];write(HERE/'deployment.json',deployment)
files={str(p.relative_to(HERE)).replace('\\','/'):sha(p) for p in HERE.rglob('*') if p.is_file() and 'probe-app' not in p.parts and p.name!='evidence-index.json'}
write(HERE/'evidence-index.json',files)
print(json.dumps(validation,ensure_ascii=False,indent=2))
