"""Build a self-contained viewer of actual, paired AS3 exports. No generator mirror."""
from pathlib import Path
from collections import Counter
import argparse
import hashlib
import json
import statistics
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
FORMS = {
    'production':'生产作业', 'storage_hall':'仓储装卸', 'service_wing':'维修与控制',
    'quarters':'生活单元', 'atrium_ring':'公共活动', 'service_cluster':'技术服务',
    'canal_gallery':'水渠检修', 'cistern':'蓄水设施', 'pump_chain':'泵管设施', 'dry_tunnels':'干燥管网',
    'apartments':'住宅楼内', 'offices':'办公楼内', 'commercial':'商业楼内', 'ruined':'坍塌建筑',
    'rooftops':'屋顶', 'street_links':'街隙',
}
SCENES = {'plant':'工厂','stable':'废弃避难厩','sewer':'下水道','mane':'城市废墟'}
SPECIAL = {'workshop','warehouse','hall','canal','roof','street'}


def read_rooms(path):
    out = {}
    for room in ET.parse(path).getroot().findall('room'):
        plan = room.find('rrPlan')
        spaces = [{k: (int(v) if k in ('x0','top','x1','floor') else v) for k,v in s.attrib.items()}
                  for s in plan.findall('space')]
        volumes = [s for s in spaces if s.get('kind') == 'volume']
        links = [{k:(int(v) if k in ('a','b','x','y') else v) for k,v in s.attrib.items()} for s in plan.findall('link')]
        areas = [(s['x1']-s['x0']+1)*(s['floor']-s['top']+1) for s in volumes]
        heights=[s['floor']-s['top']+1 for s in volumes if s['role'] not in SPECIAL]
        bands=Counter((s['top'],s['floor']) for s in volumes)
        floors=[{'top':top,'floor':floor,'rooms':count} for (top,floor),count in bands.items() if count>=2]
        occupied = {(x,y) for s in volumes for x in range(s['x0'],s['x1']+1) for y in range(s['top'],s['floor']+1)}
        seams = sum(all((x,y) not in occupied for y in range(1,24)) for x in range(2,46)) + sum(
            all((x,y) not in occupied for x in range(1,47)) for y in range(2,23))
        adjacency = [set() for _ in volumes]
        for e in links: adjacency[e['a']].add(e['b']); adjacency[e['b']].add(e['a'])
        labels = [str(len(a)) for a in adjacency]
        for _ in range(9):
            labels = [hashlib.sha256((labels[i]+':'+','.join(sorted(labels[j] for j in adjacent))).encode()).hexdigest()
                      for i,adjacent in enumerate(adjacency)]
        fingerprint = hashlib.sha256(','.join(sorted(labels)).encode()).hexdigest()
        out[int(room.get('harnessCase'))] = dict(
            attrs=dict(room.attrib), grid=[a.text.strip() for a in room.findall('a')], spaces=spaces, links=links,
            ports=list(map(int,room.findtext('doors').split('.'))),
            objects=[dict(o.attrib) for o in room.findall('obj')],
            floors=floors,
            water=[{k:int(v) for k,v in o.attrib.items()} for o in plan.findall('water')],
            stats={'spaces':len(volumes), 'cycles':len(links)-len(volumes)+1,
                   'height':round(statistics.mean(heights),1) if heights else None,
                   'heights':heights,'contrast':round(max(areas)/min(areas),1),'aligned':len(floors),
                   'largest':round(100*max(areas)/sum(areas)), 'seams':seams, 'fingerprint':fingerprint,
                   'sizeKey':str(sorted((s['x1']-s['x0']+1,s['floor']-s['top']+1) for s in volumes)),
                   'furnished':sum(int(f.get('groups'))>0 for f in plan.findall('furnish'))},
        )
    return out


def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--stem',required=True); ap.add_argument('--out',default='design/partition-preview-v12-2')
    ap.add_argument('--baseline',help='Compare the new.xml from this earlier batch instead of the legacy control')
    args=ap.parse_args(); out=ROOT/args.out; out.mkdir(parents=True,exist_ok=True)
    new=read_rooms(HERE/(args.stem+'-new.xml')); old=read_rooms(HERE/(args.stem+'-old.xml'))
    report=json.loads((HERE/(args.stem+'-results.json')).read_text(encoding='utf-8-sig'))
    baseline_label='v11.1'
    if args.baseline:
        old=read_rooms(HERE/(args.baseline+'-new.xml'))
        baseline_report=json.loads((HERE/(args.baseline+'-results.json')).read_text(encoding='utf-8-sig'))
        previous={c['index']:c for c in baseline_report['cases']}
        for c in report['cases']:
            before=previous[c['index']]
            assert all(c[key]==before[key] for key in ('seed','scene','form','port','sample'))
            c['old']=before['new']
        baseline_label='上一版 v12'
    aggregate=[]
    for scene,name in SCENES.items():
        paired={key for key in new.keys() & old.keys() if new[key]['attrs']['rrTheme']==scene}
        row={'scene':scene,'name':name,'paired':len(paired)}
        for mode,rooms in [('new',new),('old',old)]:
            selected=[rooms[key] for key in paired]
            row[mode]={'count':sum(r['attrs']['rrTheme']==scene for r in rooms.values()),
                'spaces':round(statistics.mean(r['stats']['spaces'] for r in selected),2),
                'graphs':len({r['stats']['fingerprint'] for r in selected}),
                'sizeCombinations':len({r['stats']['sizeKey'] for r in selected}),
                'withoutSeam':sum(r['stats']['seams']==0 for r in selected),
                'height':round(statistics.mean(h for r in selected for h in r['stats']['heights']),2),
                'countRange':[min(r['stats']['spaces'] for r in selected),max(r['stats']['spaces'] for r in selected)],
                'maxContrast':max(r['stats']['contrast'] for r in selected),
                'layouts':dict(Counter(r['attrs'].get('rrP_layout','legacy') for r in selected)),
                'maxMs':max(c[mode]['ms'] for c in report['cases'] if c['scene']==scene),
                'medianMs':round(statistics.median(c[mode]['ms'] for c in report['cases'] if c['scene']==scene)),
                'requested':sum(c['scene']==scene for c in report['cases'])}
        aggregate.append(row)
    photo_file=out/'native-photos.json'
    photos=json.loads(photo_file.read_text(encoding='utf-8')) if photo_file.exists() else []
    reference_file=out/'native-references.json'
    references=json.loads(reference_file.read_text(encoding='utf-8')) if reference_file.exists() else []
    data=dict(new=new,old=old,cases=report['cases'],forms=FORMS,scenes=SCENES,aggregate=aggregate,baselineLabel=baseline_label,
              repeatChecks=report['repeatChecks'],photos=photos,references=references,
              rejections=sorted(report['rejections'].items(),key=lambda v:-v[1])[:16])
    encoded=json.dumps(data,ensure_ascii=False,separators=(',',':')).replace('</','<\\/')
    template=(HERE/'partition-preview.template.html').read_text(encoding='utf-8')
    (out/'index.html').write_text(template.replace('__PARTITION_DATA__',encoded),encoding='utf-8',newline='\n')
    (out/'summary.json').write_text(json.dumps({'aggregate':aggregate,'requested':report['requested'],
        'newSuccess':len(new),'oldSuccess':len(old),'repeatChecks':report['repeatChecks'],
        'newFailures':[c for c in report['cases'] if not c['new']['ok']],
        'oldFailures':[c for c in report['cases'] if not c['old']['ok']]},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    # Deterministic first complete pair for each use; no selection by appearance.
    selected_new=ET.Element('baseline'); selected_old=ET.Element('baseline'); ids=[]
    xml_new={int(r.get('harnessCase')):r for r in ET.parse(HERE/(args.stem+'-new.xml')).getroot()}
    xml_old={int(r.get('harnessCase')):r for r in ET.parse(HERE/((args.baseline+'-new.xml') if args.baseline else (args.stem+'-old.xml'))).getroot()}
    # Select by declared structural feature, never by visual attractiveness.
    filters={'production':('rrP_density','sparse'),'storage_hall':('rrP_density','dense'),
             'quarters':('rrP_layout','storeys'),'atrium_ring':('rrP_density','sparse'),
             'canal_gallery':('rrP_density','sparse'),'dry_tunnels':('rrP_layout','storeys'),
             'apartments':('rrP_layout','storeys'),'rooftops':('rrP_density','standard')}
    for form,condition in filters.items():
        candidates=[c for c in report['cases'] if c['form']==form and c['new']['ok'] and c['old']['ok']]
        chosen=next((c for c in candidates if xml_new[c['index']].get(condition[0])==condition[1]),candidates[0])
        idx=chosen['index']; ids.append(idx); selected_new.append(xml_new[idx]); selected_old.append(xml_old[idx])
    for mode,xml in [('new',selected_new),('old',selected_old)]:
        ET.indent(xml); ET.ElementTree(xml).write(HERE/f'partition-native-{mode}.xml',encoding='utf-8',xml_declaration=True)
    (out/'native-selection.json').write_text(json.dumps({'caseIds':ids,'selection':'First successful pair matching each declared structural feature, or first success if none match. Not selected by appearance.','filters':filters},indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'file':str(out/'index.html'),'new':len(new),'old':len(old),'photos':len(photos)}))

if __name__=='__main__': main()
