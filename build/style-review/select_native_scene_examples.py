"""Author-room copies for native rendering; no terrain is changed."""
import copy
from pathlib import Path
import xml.etree.ElementTree as ET

MOD = Path(__file__).resolve().parents[2]
GAME = MOD.parent.parent
EXAMPLES = {'plant': [16, 10, 44], 'stable': [5, 20, 23],
            'sewer': [9, 12, 19], 'mane': [23, 45, 51]}
out = ET.Element('examples', source='external-native-1.02')
for scene, indexes in EXAMPLES.items():
    source = ET.parse(GAME/'Rooms'/f'rooms_{scene}.xml').getroot().findall('room')
    for index in indexes:
        r = copy.deepcopy(source[index])
        r.set('rrTheme', scene)
        r.set('sourceIndex', str(index))
        r.set('sourceFile', f'Rooms/rooms_{scene}.xml')
        out.append(r)
ET.indent(out)
ET.ElementTree(out).write(MOD/'build/style-review/native-scene-examples.xml', encoding='utf-8', xml_declaration=True)
print([(r.get('rrTheme'), r.get('sourceIndex'), r.get('name')) for r in out])
