"""Select unchanged exported AS3 rooms for a native visual comparison."""
import argparse
import copy
import hashlib
from pathlib import Path
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser()
parser.add_argument('source', type=Path)
parser.add_argument('output', type=Path)
parser.add_argument('--scenes', nargs='+', default=['plant', 'stable', 'sewer', 'mane'])
args = parser.parse_args()
source = ET.parse(args.source).getroot()
out = ET.Element('examples', source=args.source.name,
                 sourceSha256=hashlib.sha256(args.source.read_bytes()).hexdigest())
for scene in args.scenes:
    seen = set()
    for room in source.findall('room'):
        if room.get('rrTheme') != scene or room.get('rrForm') in seen:
            continue
        seen.add(room.get('rrForm'))
        out.append(copy.deepcopy(room))
    if not seen:
        raise ValueError(f'No exported forms for {scene}')
ET.indent(out)
ET.ElementTree(out).write(args.output, encoding='utf-8', xml_declaration=True)
print([(r.get('rrTheme'), r.get('rrForm'), r.get('name')) for r in out])
