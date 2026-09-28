"""Freeze four archived rooms and make an isolated editor/renderer experiment.

Only writes this directory. No installed editor, generator, map or save edits.
"""
from pathlib import Path
import hashlib
import json
import shutil
import xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parent
MOD = HERE.parent.parent
ROOT = MOD.parent.parent
CASES = [('plant', 'syn_18'), ('stable', 'syn_16'), ('sewer', 'syn_28'), ('mane', 'syn_7')]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def copy(relative, app):
    src = ROOT / relative
    dst = app / relative
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)
    assert sha(src) == sha(dst)
    return {'path': relative, 'sha256': sha(src), 'bytes': src.stat().st_size}


def world_ports(room):
    values = list(map(int, room.findtext('doors').split('.')))
    if room.get('rrMirror') == '1':
        result = [0] * 22
        for p, n in enumerate(values):
            target = p + 11 if p < 6 else 16 - p if p < 11 else p - 11 if p < 17 else 38 - p
            result[target] = n
        return result
    return values


def main():
    app = HERE / 'probe-app'
    manifest = {'purpose': 'isolated review adapter and actual editor in-memory roundtrip',
                'inputs': [], 'cases': [], 'selection': 'Fixed explicit fixtures: terminal plus ceiling turrets, mirrored terminal, sewer growth, mixed city mounts. Not a representative frequency sample.'}
    assets = ['Editor.swf', 'Editor/Enhancements/EditorTools.swf', 'Editor/Enhancements/NativeScene.swf',
              'texture.swf', 'texture1.swf', 'sprite.swf', 'sprite1.swf', 'text_zh.xml', 'text_en.xml', 'text_ru.xml',
              'Editor/Resources/langs.xml', 'Editor/Resources/text_zh.xml', 'Editor/Resources/text_en.xml', 'Editor/Resources/text_ru.xml']
    manifest['inputs'] = [copy(p, app) for p in assets]
    for theme, name in CASES:
        copy(f'Rooms/rooms_{theme}.xml', app)
        src = MOD / f'design/v13-content-runtime/population-release-candidate/rrstyle-navigation-{theme}-pool.xml'
        pool = ET.parse(src).getroot()
        room = pool.find(f"room[@name='{name}']")
        assert room is not None
        output = ET.Element('all', pool.attrib)
        output.append(ET.fromstring(ET.tostring(pool.find('land'))))
        output.append(ET.fromstring(ET.tostring(room)))
        path = HERE / 'samples' / f'rooms_{theme}_review.xml'
        path.parent.mkdir(exist_ok=True)
        ET.indent(output, space='  ')
        ET.ElementTree(output).write(path, encoding='utf-8', xml_declaration=True)
        dest = app / 'samples' / path.name
        dest.parent.mkdir(exist_ok=True)
        shutil.copyfile(path, dest)
        x, y = int(room.get('x')), int(room.get('y'))
        ports = world_ports(room)
        neighbours = []
        for direction, dx, dy, slots in [('left', -1, 0, range(11, 17)), ('right', 1, 0, range(6)),
                                          ('up', 0, -1, range(17, 22)), ('down', 0, 1, range(6, 11))]:
            other = pool.find(f"room[@x='{x+dx}'][@y='{y+dy}']")
            pairs = []
            if other is not None:
                opposite = world_ports(other)
                for p in slots:
                    q = p + 11 if p < 11 else p - 11
                    if ports[p] >= 2 or opposite[q] >= 2:
                        pairs.append({'slot': p, 'local': ports[p], 'neighbour': opposite[q], 'match': ports[p] == opposite[q]})
            neighbours.append({'direction': direction, 'room': other.get('name') if other is not None else None,
                               'x': x+dx, 'y': y+dy, 'interfaces': pairs})
        case = {'theme': theme, 'name': name, 'sample': 'samples/' + path.name, 'mirror': room.get('rrMirror') == '1',
                'region': 'random_' + theme, 'difficulty': int(room.get('rrDifficulty')),
                'ecology': int(room.get('rrEcology')), 'context': dict(room.attrib), 'worldPorts': ports, 'neighbours': neighbours,
                'source': str(src.relative_to(MOD)).replace('\\', '/'), 'sourceSha256': sha(src), 'sampleSha256': sha(path)}
        manifest['cases'].append(case)
        manifest['inputs'].append({'path': str(src.relative_to(ROOT)).replace('\\', '/'), 'sha256': sha(src), 'bytes': src.stat().st_size})
    for relative in ['pfe.swf', 'DLC/pfe.swf', 'DLC/pfeUI.swf', 'mods/RandomRooms/release/RandomRoomsMod.swf']:
        source = ROOT / relative
        manifest['inputs'].append({'path': relative, 'sha256': sha(source), 'bytes': source.stat().st_size})
    # All supporting renderer sources are read-only. This one generated adapter
    # changes just the Location context and ecology to match RRGrowth.
    native = ROOT / 'Editor/Enhancements/src/NativeRenderer.as'
    text = native.read_text(encoding='utf-8')
    replacements = {
        'class NativeRenderer': 'class RRReviewRenderer',
        'function NativeRenderer()': 'function RRReviewRenderer()',
        'new Location(land,roomXML,false,{mirror:mirror});':
            'new Location(land,roomXML,false,{mirror:mirror,water:null,ramka:null,backform:0,transpFon:String(roomXML.@rrTheme)=="mane"});',
        'EditorPreviewProfile.apply(land,loc,difficulty);':
            'EditorPreviewProfile.apply(land,loc,difficulty);\n            if(roomXML.@rrEcology.length()) loc.tipEnemy=int(roomXML.@rrEcology);',
        'biome:loc.biom,enemyType:loc.tipEnemy,':
            'biome:loc.biom,enemyType:loc.tipEnemy,transpFon:loc.transpFon,simulationUnits:loc.units.length,'
    }
    for before, after in replacements.items():
        assert text.count(before) == 1, f'Renderer API changed: {before}'
        text = text.replace(before, after)
    generated = HERE / 'generated-src'
    generated.mkdir(exist_ok=True)
    (generated / 'RRReviewRenderer.as').write_text(text, encoding='utf-8')
    manifest['rendererAdapter'] = {'base': str(native.relative_to(ROOT)).replace('\\', '/'), 'baseSha256': sha(native),
                                   'generatedSha256': sha(generated / 'RRReviewRenderer.as'), 'substitutions': replacements}
    manifest['supportSources'] = {str(p.relative_to(ROOT)).replace('\\', '/'): sha(p)
                                  for p in (ROOT / 'Editor/Enhancements/src').rglob('*.as')}
    (app / 'cases.json').write_text(json.dumps(manifest['cases'], indent=2), encoding='utf-8')
    (HERE / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'prepared': len(CASES), 'app': str(app), 'neighbourMismatches': sum(
        not p['match'] for c in manifest['cases'] for n in c['neighbours'] for p in n['interfaces'])}))


if __name__ == '__main__':
    main()
