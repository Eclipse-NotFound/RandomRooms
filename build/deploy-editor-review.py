"""Deploy only validated RandomRooms/editor candidates; preserve host loaders.
Rollback restores exactly the files recorded here, and refuses external changes.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, shutil

MOD=Path(__file__).resolve().parent.parent; GAME=MOD.parent.parent
EVIDENCE=MOD/'design/editor-runtime-20260928'
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text('utf-8-sig'))
def save(p,value): p.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n','utf-8')

def deploy():
    record=EVIDENCE/'deployment.json'
    if record.exists(): raise RuntimeError('Deployment record already exists; do not overwrite evidence.')
    base=read(EVIDENCE/'baseline.json')
    for path in ['Editor.swf','Editor/Enhancements/EditorTools.swf','Editor/Enhancements/NativeScene.swf','pfe.swf','mods/RandomRooms/release/RandomRoomsMod.swf']:
        assert digest(GAME/path)==base[path],f'Installed baseline changed: {path}'
    assert digest(GAME/'Editor/Enhancements/src/EditorTools.as')==base['EditorTools.as'],'EditorTools source changed'
    candidate=MOD/'build/RandomRooms-v13-1-candidate.swf'
    for folder in ['population','terminal-approach']:
        result=read(EVIDENCE/folder/'manifest.json')
        assert result['status']=='complete' and not result['failed'],folder
        assert result['sourceSha256']['development/RandomRoomsMod.swf'].lower()==digest(candidate)
        for name,sha in result['runtimeArtifacts'].items(): assert digest(EVIDENCE/folder/name)==sha.lower(),name
    assert read(EVIDENCE/'results.json')['status']=='passed'
    assert read(MOD/'build/style-review/content-batch/results.json')['maps']==192
    assert not read(MOD/'build/style-review/content-batch/results.json')['failures']
    assert not read(MOD/'build/style-review/comparison-batch/results.json')['failures']
    tested=read(EVIDENCE/'probe-inputs.json')
    for file in ['EditorTools.swf','RandomRoomsEditor.swf']:
        path=MOD/'build/editor'/file
        assert tested[str(path)]['sha256']==digest(path),'Untested editor binary'
    targets=[(candidate,MOD/'release/RandomRoomsMod.swf'),
             (MOD/'build/editor/RandomRoomsEditor.swf',MOD/'release/RandomRoomsEditor.swf'),
             (MOD/'build/editor/EditorTools.swf',GAME/'Editor/Enhancements/EditorTools.swf'),
             (MOD/'src/editor/bridge/EditorTools.as',GAME/'Editor/Enhancements/src/EditorTools.as')]
    backup=MOD/'build/release-backups'/('editor-v13-1-'+datetime.now().strftime('%Y%m%d-%H%M%S'))
    backup.mkdir(parents=True,exist_ok=False)
    rows=[]
    for source,target in targets:
        relative=target.relative_to(GAME); old=backup/relative
        existed=target.exists()
        if existed: old.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(target,old);assert digest(old)==digest(target)
        rows.append(dict(source=str(source),target=str(target),backup=str(old) if existed else None,before=digest(target) if existed else None,after=digest(source),bytes=source.stat().st_size))
    result=dict(status='backed-up',authorized='User explicitly requested implementation and installation on 2026-09-28',backup=str(backup),files=rows,hostSHA256=digest(GAME/'pfe.swf'),editorSHA256=digest(GAME/'Editor.swf'),manifestSHA256=digest(GAME/'mods/loader-manifest.txt'))
    save(record,result)
    try:
        for row in rows:
            target=Path(row['target']);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(row['source'],target);assert digest(target)==row['after']
        result['status']='installed-awaiting-smoke';result['installedUTC']=datetime.now(timezone.utc).isoformat();save(record,result)
    except Exception:
        rollback();raise
    print(json.dumps(dict(status=result['status'],backup=str(backup),files=[dict(target=r['target'],sha256=r['after']) for r in rows]),ensure_ascii=False,indent=2))

def rollback():
    record=EVIDENCE/'deployment.json'; data=read(record)
    for row in data['files']:
        target=Path(row['target'])
        assert str(target.resolve()).lower().startswith(str(GAME.resolve()).lower()+'\\'),target
        if target.exists(): assert digest(target) in (row['before'],row['after']),'External edit; manual merge required'
    for row in data['files']:
        target=Path(row['target'])
        if row['backup']:
            source=Path(row['backup']);assert digest(source)==row['before'];shutil.copyfile(source,target)
        elif target.exists(): target.unlink()  # Only this explicitly recorded new module.
    data['status']='rolled-back';data['rolledBackUTC']=datetime.now(timezone.utc).isoformat();save(record,data)
    print('Restored the recorded pre-deployment files.')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--rollback',action='store_true');args=parser.parse_args()
    rollback() if args.rollback else deploy()
