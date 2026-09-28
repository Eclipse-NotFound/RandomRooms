"""One-time vendor snapshot; fails if the destination already exists."""
from pathlib import Path
import hashlib, json
MOD=Path(__file__).resolve().parent.parent
GAME=MOD.parent.parent
SRC=GAME/'Editor/Enhancements/src'
DEST=MOD/'src/editor'
DEST.mkdir(exist_ok=True)
manifest={}
for name in ['NativeEntities.as','PngWriter.as','ToolButton.as','fe/loc/EditorPreviewProfile.as','EditorTools.as']:
    src=SRC/name; dst=DEST/('bridge/EditorTools.as' if name=='EditorTools.as' else 'vendor/'+name)
    if dst.exists(): raise RuntimeError(f'Already exists: {dst}')
    dst.parent.mkdir(parents=True,exist_ok=True); dst.write_bytes(src.read_bytes())
    manifest[name]=hashlib.sha256(src.read_bytes()).hexdigest()
source=SRC/'NativeRenderer.as'
text=source.read_text('utf-8')
for a,b in {
    'class NativeRenderer':'class RRReviewRenderer',
    'function NativeRenderer()':'function RRReviewRenderer()',
    'new Location(land,roomXML,false,{mirror:mirror});':'new Location(land,roomXML,false,{mirror:mirror,water:null,ramka:null,backform:0,transpFon:String(roomXML.@rrTheme)=="mane"});',
    'EditorPreviewProfile.apply(land,loc,difficulty);':'EditorPreviewProfile.apply(land,loc,difficulty);\n            if(roomXML.@rrEcology.length()) loc.tipEnemy=int(roomXML.@rrEcology);',
    'biome:loc.biom,enemyType:loc.tipEnemy,':'biome:loc.biom,enemyType:loc.tipEnemy,transpFon:loc.transpFon,simulationUnits:loc.units.length,',
    'EditorTools.log("prerender",report);':'// Review rendering never writes into the editor working document.'
}.items():
    assert text.count(a)==1,a
    text=text.replace(a,b)
target=DEST/'RRReviewRenderer.as'
if target.exists(): raise RuntimeError('Renderer already exists')
target.write_text(text,'utf-8')
manifest['NativeRenderer.as']=hashlib.sha256(source.read_bytes()).hexdigest()
for path in ['Editor.swf','Editor/Enhancements/EditorTools.swf','Editor/Enhancements/NativeScene.swf','pfe.swf','mods/RandomRooms/release/RandomRoomsMod.swf']:
    manifest[path]=hashlib.sha256((GAME/path).read_bytes()).hexdigest()
(MOD/'design/editor-runtime-20260928/baseline.json').write_text(json.dumps(manifest,indent=2)+'\n','utf-8')
print('Vendored renderer support and staged EditorTools bridge; installed files unchanged.')
