from pathlib import Path
import argparse,hashlib,json,shutil
parser=argparse.ArgumentParser();parser.add_argument('--installed',action='store_true');args=parser.parse_args()
HERE=Path(__file__).resolve().parent; MOD=HERE.parent.parent; GAME=MOD.parent.parent; APP=HERE/'probe-app'
manifest={}
def copy(src,dst):
    dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
    h=hashlib.sha256(src.read_bytes()).hexdigest();assert h==hashlib.sha256(dst.read_bytes()).hexdigest()
    manifest[str(src)]=dict(sha256=h,destination=str(dst.relative_to(APP)),bytes=src.stat().st_size)
for file in ['Editor.swf','Editor/Enhancements/NativeScene.swf','texture.swf','texture1.swf','sprite.swf','sprite1.swf','text_zh.xml','text_en.xml','text_ru.xml','Editor/Resources/langs.xml','Editor/Resources/text_zh.xml','Editor/Resources/text_en.xml','Editor/Resources/text_ru.xml']:
    copy(GAME/file,APP/file)
for scene in ['plant','stable','sewer','mane']:
    copy(GAME/'Rooms'/f'rooms_{scene}.xml',APP/'Rooms'/f'rooms_{scene}.xml')
    src=HERE/'population'/f'rrstyle-navigation-{scene}-review.xml'
    copy(src,APP/'samples'/f'{scene}.xml')
copy(APP/'samples/plant.xml',APP/'mods/RandomRooms/exports/review/latest.xml')
copy(GAME/'Editor/Enhancements/EditorTools.swf' if args.installed else MOD/'build/editor/EditorTools.swf',APP/'Editor/Enhancements/EditorTools.swf')
copy(MOD/'release/RandomRoomsEditor.swf' if args.installed else MOD/'build/editor/RandomRoomsEditor.swf',APP/'mods/RandomRooms/release/RandomRoomsEditor.swf')
(HERE/'probe-inputs.json').write_text(json.dumps(manifest,indent=2)+'\n','utf-8')
print('Isolated original editor + exact candidate modules + four game exports prepared.')
