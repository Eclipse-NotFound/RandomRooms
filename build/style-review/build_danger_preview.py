"""Build a portable browser-only design simulator with frozen v12.3 geometry."""
import hashlib
import json
from pathlib import Path

MOD = Path(__file__).resolve().parents[2]
SOURCE = MOD / 'design/partition-preview-v12-3/index.html'
TEMPLATE = Path(__file__).with_name('danger-value-preview.template.html')
OUT = MOD / 'design/danger-value-preview/index.html'


def main():
    raw = SOURCE.read_text(encoding='utf-8')
    data, _ = json.JSONDecoder().raw_decode(raw.split('const DATA=', 1)[1])
    selected = []
    for scene in ('plant', 'stable', 'sewer', 'mane'):
        cases = [c for c in data['cases'] if c['scene'] == scene and str(c['index']) in data['new']]
        choices = []
        for form in dict.fromkeys(c['form'] for c in cases):
            family = [c for c in cases if c['form'] == form]
            choices.append(next((c for c in family if data['new'][str(c['index'])]['merges']), family[0]))
        for case in choices:
            room = data['new'][str(case['index'])]
            selected.append({'scene': scene, 'sourceCase': case['index'], 'sourceSeed': case['seed'],
                             'form': case['form'], 'formName': data['forms'][case['form']],
                             'fixtures': [o for o in room['objects'] if o.get('rrFixture')],
                             **{k: room[k] for k in ('grid', 'spaces', 'links', 'ports')}})
    payload = json.dumps({'sourceHash': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                          'samples': selected}, ensure_ascii=False, separators=(',', ':'))
    html = TEMPLATE.read_text(encoding='utf-8').replace('/* FROZEN_LAYOUTS */ null', payload)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(html, encoding='utf-8')
    print(json.dumps({'samples': len(selected), 'bytes': OUT.stat().st_size, 'output': str(OUT)}, ensure_ascii=True))


if __name__ == '__main__':
    main()
