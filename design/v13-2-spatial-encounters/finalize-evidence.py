"""Create an immutable final release evidence bundle after normal-loader smoke."""
from pathlib import Path
import hashlib, json, zipfile

HERE=Path(__file__).resolve().parent; MOD=HERE.parent.parent
def read(p):return json.loads(p.read_text('utf-8-sig'))
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
deployment=read(HERE/'deployment.json')
assert deployment['status']=='installed-and-smoke-passed'
assert digest(MOD/'release/RandomRoomsMod.swf')==deployment['after']
out=HERE/'release-evidence.zip';assert not out.exists(),'Preserve frozen evidence'
folders=('population-final','terminal-final','growth-final','release-smoke')
summary={}
for folder in folders:
    m=read(HERE/folder/'manifest.json')
    assert m['status']=='complete' and not m['failed']
    assert m['sourceSha256']['development/RandomRoomsMod.swf'].lower()==deployment['after']
    summary[folder]=dict(appId=m['appId'],cases=m['cases'],manifestSHA256=digest(HERE/folder/'manifest.json'))
population=[]
for p in (HERE/'population-final').glob('*-population.json'):
    r=read(p);assert r['passed']
    population.append(dict(caseId=r['caseId'],rooms=r['rooms'],checks=r['checks']))
growth=[]
for p in (HERE/'growth-final').glob('*-navigation.json'):
    r=read(p);assert r['success'] and r['growth'] and r['milestones']==4
    # A successful run with cacheStayedEmpty=false had no eligible starting
    # container. NavigationProbe.finish fails separately if consumed loot returns.
    growth.append({k:r[k] for k in ('caseId','scene','frames','milestones','success','wetFrames','reason','persistentObjects','cacheStayedEmpty')})
assert len(growth)==4
sources={str(p.relative_to(MOD)).replace('\\','/'):digest(p) for p in sorted((MOD/'src').rglob('*.as'))}
assert sources==read(HERE/'algorithm-validation.json')['sources']
with zipfile.ZipFile(out,'x',zipfile.ZIP_DEFLATED) as z:
    z.write(MOD/'release/RandomRoomsMod.swf','installed/RandomRoomsMod.swf')
    for root in (MOD/'src',MOD/'build/style-review/game-harness',MOD/'build/style-review/harness'):
        paths=root.rglob('*.as') if root.name=='src' else root.glob('*.as')
        for p in sorted(paths):z.write(p,str(p.relative_to(MOD)).replace('\\','/'))
    for folder in folders:
        for p in sorted((HERE/folder).iterdir()):
            if p.suffix in ('.json','.xml','.log'):z.write(p,folder+'/'+p.name)
    for p in sorted((MOD/'build/spatial-v132/render').glob('*.xml')):z.write(p,'render-inputs/'+p.name)
    for name in ('metrics.json','algorithm-validation.json','deployment.json','render-results.json','render-inputs.json','render-execution.json'):
        z.write(HERE/name,name)
    for folder,session in (('growth-final','visual-app'),('release-smoke','app')):
        p=MOD/'build/style-review/game-harness'/session/'mods/TDFC/release/TDFCMod.swf'
        assert digest(p)==read(HERE/folder/'manifest.json')['driverSha256'].lower()
        z.write(p,'test-drivers/'+folder+'.swf')
index=dict(candidateSHA256=deployment['after'],releaseEvidenceSHA256=digest(out),
    algorithmEvidenceSHA256=digest(HERE/'algorithm-evidence.zip'),native=summary,population=population,growth=growth,
    scope='Exact main module bytes; separate isolated native content, movement and normal-loader UI tests. No real save access; no long combat balance test.')
(HERE/'evidence-index.json').write_text(json.dumps(index,ensure_ascii=False,indent=2)+'\n','utf-8')
print(json.dumps(dict(candidate=index['candidateSHA256'],nativeRuns=len(summary),populationCases=len(population),growthCases=len(growth),releaseEvidenceSHA256=index['releaseEvidenceSHA256'])))
