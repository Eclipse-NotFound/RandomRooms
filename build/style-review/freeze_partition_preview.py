"""Freeze the preview's actual inputs after checking source and capture attribution."""
from collections import Counter
from pathlib import Path
import argparse
import hashlib
import json
import xml.etree.ElementTree as ET
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT/'design/partition-preview-v12'


def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def semantic(e):
    return e.tag, sorted(e.attrib.items()), (e.text or '').strip(), [semantic(c) for c in e]


def main():
    global OUT
    ap=argparse.ArgumentParser();ap.add_argument('--stem',default='partition-dev3')
    ap.add_argument('--out',default='design/partition-preview-v12');ap.add_argument('--baseline')
    ap.add_argument('--history',nargs='*',default=['partition-dev2'])
    ap.add_argument('--swf',default='build/RandomRooms-v12-prototype-1.swf')
    ap.add_argument('--native-reference')
    args=ap.parse_args();stem=args.stem;OUT=ROOT/args.out
    manifest=json.loads((HERE/f'{stem}-manifest.json').read_text(encoding='utf-8-sig'))
    for name,sha in manifest['sources'].items():
        assert digest(ROOT/'src/rr'/name).lower()==sha.lower(), name
    for suffix,sha in manifest['files'].items():
        assert digest(HERE/(stem+suffix)).lower()==sha.lower(), suffix
    rooms={mode:{int(r.get('harnessCase')):r for r in ET.parse(HERE/f'{stem}-{mode}.xml').getroot()}
           for mode in ['new','old']}
    if args.baseline:
        rooms['old']={int(r.get('harnessCase')):r for r in ET.parse(HERE/f'{args.baseline}-new.xml').getroot()}
    occupied_checks=0
    coverage=Counter()
    for key,room in rooms['new'].items():
        volumes=room.findall("rrPlan/space[@kind='volume']")
        assert len(volumes)==int(room.get('rrP_count'))
        occupied=set()
        for space in volumes:
            x0,y0,x1,y1=[int(space.get(a)) for a in ['x0','top','x1','floor']]
            assert 1<=x0<=x1<=46 and 1<=y0<=y1<=23, key
            cells={(x,y) for x in range(x0,x1+1) for y in range(y0,y1+1)}
            assert not occupied & cells, key
            occupied |= cells
            occupied_checks+=1
        coverage['spaces']+=len(volumes)
        furnishing=room.findall('rrPlan/furnish')
        assert len(furnishing)==len(volumes)
        coverage['with_furniture_group']+=sum(int(f.get('groups'))>0 for f in furnishing)
        if key in rooms['old']:
            assert room.findtext('doors')==rooms['old'][key].findtext('doors'), key
    capture_dir=OUT/'native-captures'
    cap=json.loads((capture_dir/'manifest.json').read_text(encoding='utf-8-sig'))
    assert cap['status']=='complete' and cap['done'] and not cap['failed']
    for name,sha in cap['captured'].items():
        assert digest(capture_dir/name).lower()==sha.lower(), name
    assert digest(capture_dir/'cases.xml').lower()==cap['casesSha256'].lower()
    assert digest(capture_dir/'runner.log').lower()==cap['runnerLogSha256'].lower()
    cases=ET.parse(capture_dir/'cases.xml').getroot()
    native=list(ET.parse(ROOT/args.native_reference).getroot()) if args.native_reference else []
    prototype_cases=0;native_cases=0
    for case in cases:
        mode='new' if '-new-' in case.get('id') else 'old'
        captured=case.find('room')
        if captured.get('harnessCase') is not None:
            key=int(captured.get('harnessCase'));source=rooms[mode][key];prototype_cases+=1
        else:
            key=captured.get('sourceIndex')
            source=next(r for r in native if r.get('sourceIndex')==key and r.get('rrTheme')==captured.get('rrTheme'))
            native_cases+=1
        original=ET.fromstring(ET.tostring(source))
        options=original.find('options')
        for name,value in [('tip','beg0'),('entip','0'),('kolspawn','0')]:
            options.set(name,value)
        for enemy in original.findall('obj'):
            if enemy.get('id','').startswith('en'): original.remove(enemy)
        assert semantic(original)==semantic(captured), (mode,key)
    evidence=OUT/'evidence'; evidence.mkdir(exist_ok=True)
    archives={}
    for batch in args.history+[stem]:
        destination=evidence/(batch+'.zip')
        assert not destination.exists(), destination
        files=sorted(p for p in HERE.glob(batch+'-*') if p.is_file())
        if batch==stem:
            files+=list((ROOT/'src').rglob('*.as'))
            files+=[HERE/'harness/PartitionPreview.as',HERE/'harness/run-partitions.ps1',
                    HERE/'harness/partition-preview-app.xml',ROOT/args.swf]
            if args.native_reference: files.append(ROOT/args.native_reference)
        with zipfile.ZipFile(destination,'w',compression=zipfile.ZIP_DEFLATED) as z:
            for p in files: z.write(p,p.relative_to(ROOT).as_posix())
        archives[destination.name]={'sha256':digest(destination),'files':len(files)}
    report={'passed':True,'sourceHashesVerified':len(manifest['sources']),
        'rooms':len(rooms['new']),'disjointRectanglesChecked':occupied_checks,
        'pairedPortsChecked':len(rooms['new'].keys() & rooms['old'].keys()),
        'captureXmlMatched':len(cases),'verifiedImages':len(cap['captured']),
        'prototypeCaptureCases':prototype_cases,'nativeReferenceCases':native_cases,
        'furnitureCoverage':dict(coverage),'archives':archives,
        'scope':'Rectangle and artifact attribution checks; no movement or battle proof.'}
    (evidence/'integrity.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False))


if __name__=='__main__': main()
