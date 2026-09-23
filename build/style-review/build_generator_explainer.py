"""Build the v11.1 reader from frozen, actual room XML; no game execution."""
from pathlib import Path
import hashlib
import json
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'design/generator-explained-v11.1'
SOURCE = ROOT / 'design/assets/v11-density-dev12/cases.xml'
rooms = []
for case in ET.parse(SOURCE).getroot().findall('case'):
    r = case.find('room')
    plan = r.find('rrPlan')
    rooms.append({
        'case': case.get('id'), 'attrs': dict(r.attrib),
        'grid': [a.text.split('.') for a in r.findall('a')],
        'spaces': [dict(s.attrib) for s in plan.findall('space')],
        'links': [dict(s.attrib) for s in plan.findall('link')],
        'ladders': [dict(s.attrib) for s in plan.findall('ladder')],
        'stairs': [dict(s.attrib) for s in plan.findall('stairs')],
        'water': [dict(s.attrib) for s in plan.findall('water')],
        'objects': [dict(s.attrib) for s in r.findall('obj')],
        'backs': [dict(s.attrib) for s in r.findall('back')],
        'ports': [int(x) for x in r.findtext('doors').split('.')],
    })
template = Path(__file__).with_name('generator-explainer.template.html').read_text(encoding='utf-8')
html = template.replace('__ROOM_DATA__', json.dumps(rooms, ensure_ascii=False, separators=(',', ':')))
OUT.mkdir(exist_ok=True)
(OUT / 'guide.html').write_text(html, encoding='utf-8', newline='\n')
evidence = {'sourceCommit': '8954613', 'sampleSource': str(SOURCE.relative_to(ROOT)),
            'sampleSha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
            'rooms': len(rooms), 'releaseSha256': hashlib.sha256((ROOT/'release/RandomRoomsMod.swf').read_bytes()).hexdigest(),
            'sourceFiles': {p.as_posix(): hashlib.sha256((ROOT/p).read_bytes()).hexdigest()
                            for p in [Path('src/RandomRoomsMod.as'), *[Path('src/rr')/f for f in (
                                'RRScene.as','RRMapPlan.as','RRArchitecture.as','RRSynth.as','RRGrowth.as',
                                'RRPorts.as','RRTraversal.as','RRPopulation.as','RREcology.as','RRFurnish.as',
                                'RRSeed.as','RRConfig.as','RRMenu.as')]]}}
(OUT/'source-fingerprints.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f'Built {OUT / "guide.html"}; {len(rooms)} actual room samples.')
