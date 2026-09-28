"""Check the real probe's products and build a portable, read-only review page."""
from pathlib import Path
from collections import Counter
import hashlib
import json
import re
import struct
import xml.etree.ElementTree as ET
import zlib

HERE = Path(__file__).resolve().parent
MOD = HERE.parent.parent
ROOT = MOD.parent.parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical(node):
    return (node.tag, tuple(sorted(node.attrib.items())), (node.text or '').strip(), tuple(canonical(x) for x in node))


def bag(room, tag):
    return Counter(canonical(node) for node in room.findall(tag))


def png_check(path):
    b = path.read_bytes()
    assert b[:8] == b'\x89PNG\r\n\x1a\n'
    pos, compressed, size = 8, bytearray(), None
    while pos < len(b):
        length = struct.unpack_from('>I', b, pos)[0]
        kind, payload = b[pos+4:pos+8], b[pos+8:pos+8+length]
        assert zlib.crc32(kind + payload) & 0xffffffff == struct.unpack_from('>I', b, pos+8+length)[0]
        if kind == b'IHDR':
            w, h, depth, color, _, _, interlace = struct.unpack('>IIBBBBB', payload)
            assert (w, h, depth, color, interlace) == (1920, 1000, 8, 2, 0)
            size = (w, h)
        if kind == b'IDAT':
            compressed.extend(payload)
        pos += length + 12
    raw = zlib.decompress(compressed)
    assert len(raw) == (1920*3 + 1)*1000
    return {'sha256': sha(path), 'size': size, 'crcAndPixels': True}


def main():
    manifest = json.loads((HERE / 'manifest.json').read_text(encoding='utf-8'))
    probe = json.loads((HERE / 'results.json').read_text(encoding='utf-8-sig'))
    execution = json.loads((HERE / 'execution.json').read_text(encoding='utf-8-sig'))
    assert probe['status'] == 'passed' and execution['exitCode'] == 0
    protected = [{'path': p['path'], 'unchanged': sha(ROOT / p['path']) == p['sha256']} for p in manifest['inputs']]
    assert all(p['unchanged'] for p in protected)
    assert all(sha(ROOT / p) == h for p, h in manifest['supportSources'].items())
    # Markers follow the generator's planned footprint, not a re-guessed body width.
    sizes_text = (MOD / 'src/rr/RRPopulation.as').read_text(encoding='utf-8')
    sizes = {key.strip('"'): [int(w), int(h)] for key, w, h in re.findall(r'("?\w+"?):\[(\d+),(\d+)\]', sizes_text)}
    rows, checks = [], []
    first = json.loads((HERE / 'first-run/results.json').read_text(encoding='utf-8'))
    for fixture in manifest['cases']:
        theme = fixture['theme']
        assert sha(HERE / fixture['sample']) == fixture['sampleSha256']
        assert sha(HERE / 'probe-app' / fixture['sample']) == fixture['sampleSha256']
        pool = ET.parse(HERE / fixture['sample']).getroot()
        room = pool.find('room')
        encoded = ET.parse(HERE / 'roundtrip' / f'{theme}-snapshot.xml').getroot()
        roundtrip = next(r for r in probe['roundtrip'] if r['theme'] == theme)
        render = next(r for r in probe['render'] if r['region'] == fixture['region'])
        original_render = next(r for r in first['render'] if r['region'] == fixture['region'])
        same_native = {
            'grid': [n.text for n in room.findall('a')] == [n.text for n in encoded.findall('a')],
            'objects': bag(room, 'obj') == bag(encoded, 'obj'),
            'backgroundObjects': bag(room, 'back') == bag(encoded, 'back'),
            'options': bag(room, 'options') == bag(encoded, 'options'),
            'selectedCoordinates': roundtrip['coordinates']['original'] == roundtrip['coordinates']['selected'],
        }
        assert all(same_native.values()), (theme, same_native)
        assert roundtrip['planAfter'] == 0 and roundtrip['doorsAfter'] == 0
        assert render['sourceUnchanged'] and not render['warnings'] and render['simulationUnits'] == 0
        assert render['mirror'] == fixture['mirror'] and render['enemyType'] == fixture['ecology']
        assert render['transpFon'] == (theme == 'mane')
        assert all(p['match'] for n in fixture['neighbours'] for p in n['interfaces'])
        image = png_check(HERE / 'previews' / f'{theme}.png')
        check = {'theme': theme, 'nativeFieldsPreservedAfterSelectingRoom': same_native,
                 'roomMetadataLost': len(roundtrip['lostRoomAttributes']), 'rootMetadataLost': roundtrip['lostRootAttributes'],
                 'coordinates': roundtrip['coordinates'], 'planLost': True, 'doorsLost': True,
                 'png': image, 'repeatImageIdentical': sha(HERE / 'first-run/previews' / f'{theme}.png') == image['sha256'],
                 'repeatEntitySelectionIdentical': original_render['entityDetails'] == render['entityDetails'],
                 'staticHiddenBodies': [b for b in render['staticBodies'] if not b['visible'] or b['alpha'] <= 0]}
        checks.append(check)
        rows.append({**fixture, 'plan': {tag: [dict(n.attrib) for n in room.findall('rrPlan/'+tag)]
                                       for tag in ('space', 'zone', 'point', 'gun', 'control', 'mass', 'merge')},
                     'render': render, 'roundtrip': roundtrip, 'check': check,
                     'preview': f'previews/{theme}.png'})
    data = {'cases': rows, 'sizes': sizes, 'scope': 'archived v13 snapshots, static native images, generated-plan overlay'}
    (HERE / 'review-data.js').write_text('window.REVIEW_DATA = '+json.dumps(data, ensure_ascii=False, separators=(',', ':')).replace('</', '<\\/')+';\n', encoding='utf-8')
    output = {'status': 'passed', 'protectedInputs': protected, 'rendererSourcesUnchanged': True, 'cases': checks,
              'driverSourceSha256': sha(HERE / 'ReviewProbe.as'), 'driverSwfSha256': sha(HERE / 'probe-app/ReviewProbe.swf'),
              'limits': ['in-memory codec, not GUI Save dialog', 'static native images, not live gameplay',
                         'neighbour port contracts, not traversal', 'HTML interaction not browser-tested; file URL denied by browser tool',
                         'native random frames and unspecified variants are not fixed by the generation seed']}
    (HERE / 'validation.json').write_text(json.dumps(output, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'passed': True, 'cases': len(rows), 'protectedInputs': len(protected),
                      'entities': sum(r['render']['entities'] for r in rows),
                      'hiddenBodies': sum(len(c['staticHiddenBodies']) for c in checks),
                      'repeatPixelIdentical': sum(c['repeatImageIdentical'] for c in checks)}))


if __name__ == '__main__':
    main()
