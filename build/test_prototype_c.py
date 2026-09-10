"""Output-level checks for the defects found during prototype C review.
These check interfaces/headroom, not player movement under actual gravity.
"""
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).parent / "style-review"))
from prototype_c import generate, PALETTES
from render_dump import FOOTPRINTS, WALL


class ArchitecturalPrototypeTest(unittest.TestCase):
    def test_reviewed_navigation_and_object_invariants(self):
        for bi,theme in enumerate(PALETTES):
            for n in range(8):
                room=generate(theme,20260910+bi*1000+n,n)
                grid=[a.text.split('.') for a in room.findall('a')]
                with self.subTest(room=room.get('name')):
                    self.assertEqual((len(grid),set(map(len,grid))),(25,{48}))
                    self.assertTrue(all(c[0] in WALL for c in grid[-1]))
                    objs=room.findall('obj')
                    self.assertEqual(len({o.get('code') for o in objs}),len(objs))
                    self.assertEqual(sum(o.get('id')=='player' for o in objs),1)
                    shafts=set()
                    for y,row in enumerate(grid):
                        for x,c in enumerate(row):
                            if 'А' not in c:continue
                            shafts.update(((x-1,y),(x,y)))
                            if y and 'А' not in grid[y-1][x]:
                                self.assertGreaterEqual(y,2)
                                self.assertTrue(all(grid[yy][xx][0]=='_' for yy in (y-1,y-2) for xx in (x-1,x)))
                                self.assertTrue(any(grid[y][xx][0] in WALL or '-' in grid[y][xx] for xx in (x-2,x+1) if 0<=xx<48))
                    self.assertTrue(shafts)
                    for o in objs:
                        oid=o.get('id');x=int(o.get('x'));y=int(o.get('y'))
                        w,h=FOOTPRINTS.get(oid,(1,1))
                        occupied={(xx,yy) for xx in range(x,x+w) for yy in range(y-h+1,y+1)}
                        if oid not in ('player','hatch2'):
                            self.assertFalse(occupied & shafts, (oid,x,y))
                            self.assertTrue(all(grid[y+1][xx][0] in WALL or '-' in grid[y+1][xx] for xx in range(x,x+w)))
                    # Each downward-right ramp starts next to a real landing.
                    for y,row in enumerate(grid):
                        for x,c in enumerate(row):
                            if 'Г' not in c:continue
                            if y>0 and x>0 and 'Г' in grid[y-1][x-1]:continue
                            self.assertGreater(x,0)
                            self.assertTrue(grid[y][x-1][0] in WALL or '-' in grid[y][x-1],(x,y))


if __name__=='__main__':unittest.main()
