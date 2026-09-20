"""Check city relationships and native shared sockets in an exported whole map."""
import argparse
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET


def audit(path):
    root = ET.parse(path).getroot()
    rooms = {(int(r.get('x')), int(r.get('y'))): r for r in root.findall('room')}
    errors = []
    def require(ok, message):
        if not ok: errors.append(message)
    require(len(rooms) == int(root.get('width')) * int(root.get('height')), 'Incomplete rectangle')
    require(root.get('orderIndependent') == 'true', 'Missing generator order check')
    edges = 0
    for (x, y), room in rooms.items():
        label = f'{x},{y}'
        require(room.get('rrTheme') == 'mane' and room.get('rrMirror') == '0', label+' scene/orientation')
        zone, form = room.get('rrDistrict'), room.get('rrForm')
        require(zone in ('roof', 'street', 'building'), label+' missing district')
        require((zone == 'street') == (form == 'street_links'), label+' street form')
        require((zone == 'roof') == (form == 'rooftops'), label+' roof form')
        require(zone == 'street' or (zone == 'roof') == (y == 0), label+' roof elevation')
        above = rooms.get((x, 0))
        require(above is not None and (above.get('rrDistrict') == 'street') == (zone == 'street'), label+' alley continuity')
        require(above is not None and above.get('rrBlock') == room.get('rrBlock'), label+' block continuity')
        ports = list(map(int, room.findtext('doors').split('.')))
        for dx, dy, indices in ((1, 0, range(6)), (0, 1, range(6, 11))):
            neighbor = rooms.get((x+dx, y+dy))
            if neighbor is None: continue
            other = list(map(int, neighbor.findtext('doors').split('.')))
            require(all(ports[p] == other[p+11] for p in indices), label+' shared socket')
            edges += 1
            if dx and zone == 'building' and neighbor.get('rrDistrict') == 'building' and room.get('rrBlock') == neighbor.get('rrBlock'):
                require(form == neighbor.get('rrForm'), label+' building use continuity')
    require(any(r.get('rrDistrict') == 'street' for r in rooms.values()), 'No street coverage')
    require(any(r.get('rrDistrict') == 'building' for r in rooms.values()), 'No interior coverage')
    return dict(file=str(path), sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                rooms=len(rooms), neighborEdges=edges, passed=not errors, errors=errors)


if __name__ == '__main__':
    ap=argparse.ArgumentParser(); ap.add_argument('map', type=Path); ap.add_argument('--output', type=Path)
    args=ap.parse_args(); result=audit(args.map)
    text=json.dumps(result, ensure_ascii=False, indent=2)
    if args.output: args.output.write_text(text+'\n', encoding='utf-8')
    print(text)
    raise SystemExit(not result['passed'])
