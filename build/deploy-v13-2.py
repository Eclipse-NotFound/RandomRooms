"""Install the tested v13.2 bytes only; host/editor files are baseline guards."""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, os, shutil, uuid

MOD=Path(__file__).resolve().parent.parent; GAME=MOD.parent.parent
EVIDENCE=MOD/'design/v13-2-spatial-encounters'
RECORD=EVIDENCE/'deployment.json'
TARGET=MOD/'release/RandomRoomsMod.swf'
CANDIDATE=MOD/'build/RandomRooms-v13-2-final.swf'
BEFORE='356ad62f2340101f0cc0f39803a0af3e33fbb33b3227e7614d076ad6745cf2bf'
AFTER='2fe250215885c6b4023357f7948e8a92928ec62b8ae8970a675b936d1103d976'
GUARDS={
 'pfe.swf':'c631cbf3511b6ee303f533d08d51511fe0eb702f43e5db17f5241d8576c64867',
 'application.xml':'70dd3b085e5f6c66c03693cf68ce5e93a4e4136dd745d40d1a5b2a49863ba236',
 'mods/loader-manifest.txt':'2d4a64a608a6482168fbfe9e8cd7bb53f006ab1f8993fcc737cf9d32f2293592',
 'Editor.swf':'e99e231f83128ea24cd13b2ae36b0dd294e5180a16f54ba3c7b3cb8fa24d99fd',
 'Editor/Enhancements/EditorTools.swf':'d7ad493f19867c96b600599151275877349a7dbf2155794be42483656ae0f002',
 'Editor/Enhancements/NativeScene.swf':'fcb620b9f4dc25eb3b4b54d420dfdf2549894472e8d0a331f06cdc321fc7cba7',
 'mods/RandomRooms/release/RandomRoomsEditor.swf':'fb1537f54b2c32af02aca771cb09366441fb74ca01ee3a6099e35c4d3a35dfd8',
}
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text('utf-8-sig'))
def save(p,v): p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n','utf-8')
def unchanged():
    for name,sha in GUARDS.items(): assert digest(GAME/name)==sha, 'External change: '+name
def replace(source):
    stage=TARGET.with_name(TARGET.name+'.pending-'+uuid.uuid4().hex)
    try:
        with stage.open('xb') as f:f.write(source.read_bytes())
        assert digest(stage)==digest(source)
        os.replace(stage,TARGET)
    finally:
        if stage.exists():stage.unlink()
def native(folder):
    root=EVIDENCE/folder; m=read(root/'manifest.json')
    assert m['status']=='complete' and not m['failed'] and m['exitCode']==0,folder
    assert m['hostSha256'].lower()==GUARDS['pfe.swf']
    assert m['sourceSha256']['development/RandomRoomsMod.swf'].lower()==AFTER,folder
    for group in ('captured','runtimeArtifacts'):
        for name,sha in m[group].items():assert digest(root/name)==sha.lower(),name
    assert digest(root/'runner.log')==m['runnerLogSha256'].lower()
    assert digest(root/'cases.xml')==m['casesSha256'].lower()
    return m
def preflight():
    unchanged();assert digest(TARGET)==BEFORE;assert digest(CANDIDATE)==AFTER
    a=read(EVIDENCE/'algorithm-validation.json')
    assert a['passed'] and a['candidateSHA256']==AFTER and a['maps']==192
    assert a['legacyParity']==1024 and a['legacyMaps']==512 and a['adjacentPairs']==896
    assert a['contentResult']['independence']==32 and not a['contentResult']['failures']
    assert digest(EVIDENCE/'algorithm-evidence.zip')==a['evidenceSHA256']
    for name,sha in a['sources'].items():assert digest(MOD/name)==sha,name
    for folder in ('population-final','terminal-final','growth-final'):native(folder)
    assert read(EVIDENCE/'render-results.json')['status']=='passed'
    return a
def deploy():
    assert not RECORD.exists(),'Never overwrite a deployment record'
    a=preflight()
    backup=MOD/'build/release-backups'/('spaces-v13-2-'+datetime.now().strftime('%Y%m%d-%H%M%S'))
    backup.mkdir(parents=True,exist_ok=False);old=backup/'RandomRoomsMod.swf'
    shutil.copyfile(TARGET,old);assert digest(old)==BEFORE
    record=dict(status='backed-up',before=BEFORE,after=AFTER,bytes=CANDIDATE.stat().st_size,
        backup=str(old),target=str(TARGET),unchangedFiles=GUARDS,
        authorization='Continued user-authorized RandomRooms implementation and installation; latest requested encounter/layout/mass improvements.',
        algorithmEvidenceSHA256=a['evidenceSHA256'])
    save(RECORD,record)
    try:
        unchanged();assert digest(TARGET)==BEFORE;replace(CANDIDATE);assert digest(TARGET)==AFTER
        unchanged();record.update(status='installed-awaiting-smoke',installedUTC=datetime.now(timezone.utc).isoformat());save(RECORD,record)
    except Exception:
        rollback();raise
    print(json.dumps(record,ensure_ascii=False,indent=2))
def rollback():
    r=read(RECORD);old=Path(r['backup'])
    assert TARGET.resolve()==Path(r['target']).resolve()
    assert old.resolve().is_relative_to((MOD/'build/release-backups').resolve())
    assert digest(TARGET) in (BEFORE,AFTER),'Later release detected; refuse overwrite'
    assert digest(old)==BEFORE
    replace(old);assert digest(TARGET)==BEFORE
    r.update(status='rolled-back',rolledBackUTC=datetime.now(timezone.utc).isoformat());save(RECORD,r)
    print('Restored the recorded v13.1 main module.')
def finish():
    try:
        r=read(RECORD);assert r['status']=='installed-awaiting-smoke';assert digest(TARGET)==AFTER;unchanged()
        m=native('release-smoke');assert len(m['cases'])==3
        version=read(EVIDENCE/'release-smoke/production-version.json')
        assert version['runtimeTag']=='[RR:v13.2-spaces]'
        r.update(status='installed-and-smoke-passed',smokeAppId=m['appId'],verifiedUTC=datetime.now(timezone.utc).isoformat())
        save(RECORD,r);print('v13.2 installed; native loader and UI smoke passed.')
    except Exception:
        rollback();raise
if __name__=='__main__':
    ap=argparse.ArgumentParser();g=ap.add_mutually_exclusive_group()
    g.add_argument('--rollback',action='store_true');g.add_argument('--finish',action='store_true');g.add_argument('--check',action='store_true')
    args=ap.parse_args()
    if args.rollback:rollback()
    elif args.finish:finish()
    elif args.check:preflight();print('Preflight passed; no files installed.')
    else:deploy()
