"""Prototype C: generate rooms from architectural rules, not copied room grids.
Main volume + annexes + landings + complete ladder wells + connected door frames.
This is a design prototype; engine traversal/seed coverage still require testing.
"""
from collections import Counter, deque
from pathlib import Path
import random
import xml.etree.ElementTree as ET

W,H=48,25
PALETTES={
"stable":("J","K",["R","P","F"]),
"sewer":("L","I",["E","D","T"]),
"plant":("C","B",["J","D","E"]),
"mane":("N","D",["F","P","R"]),
}

def generate(theme,seed,n):
    rng=random.Random(seed)
    wall,trim,bgs=PALETTES[theme]
    grid=[[wall]*W for _ in range(H)]
    objects=[];backs=[];regions=[];used=set();ladders=[];doors=[];reserved=set()
    def openrect(x0,y0,x1,y1,bg):
        for y in range(max(0,y0),min(H,y1+1)):
            for x in range(max(0,x0),min(W,x1+1)):grid[y][x]="_"+bg
    def region(x0,y0,x1,floor,bg,role):
        openrect(x0,y0,x1,floor,bg)
        regions.append((x0,y0,x1,floor,bg,role))
    def platform(x0,x1,y,bg,solid=False):
        for x in range(max(0,x0),min(W,x1+1)):
            grid[y][x]=trim if solid else "_"+bg+"-"
    def ladder(x,top,bottom,bg):
        for y in range(top,bottom+1):
            grid[y][x]="_"+bg;grid[y][x+1]="_"+bg+"А"
        ladders.append((x,top,bottom))
        reserved.update((xx,y) for xx in (x,x+1) for y in range(top,bottom+1))
        reserved.update((xx,y) for xx in range(max(0,x-1),min(W,x+3))
                        for y in range(max(top,bottom-1),bottom+1))
    def obj(oid,x,y,w=1,h=1):
        if x<0 or x+w>W or y-h+1<0 or y>=H:return False
        cells={(xx,yy) for xx in range(x,x+w) for yy in range(y-h+1,y+1)}
        if cells & used:return False
        if oid not in ("player","hatch2") and cells & reserved:return False
        if any(grid[yy][xx][0]!="_" for xx,yy in cells):return False
        # Furniture must have full-width support. Hatches intentionally bridge ladder mouths.
        if oid!="hatch2" and (y+1>=H or not all(grid[y+1][xx][0]!="_" or "-" in grid[y+1][xx] for xx in range(x,x+w))):return False
        objects.append((oid,x,y));used.update(cells);return True
    def doorway(x,floor,bg):
        # A door belongs to a separating wall, with a lintel above its height.
        for y in range(floor-3,floor+1):grid[y][x]=wall
        openrect(x,floor-2,x,floor,bg)
        doors.append((x,floor))
    kind=n%4
    left=rng.randint(8,12);right=rng.randint(34,38)
    main_top=rng.choice([2,3,4,5])
    role=["atrium","workshop","stacked-offices","damaged-hall"][kind]
    if kind==0:
        region(left,main_top,right,23,bgs[0],"hall")
        for top,floor in ((1,7),(9,15),(17,23)):
            region(0,top,left-2,floor,bgs[1],"storage")
            openrect(left-1,floor-2,left+1,floor,bgs[1])
        for top,floor in ((3,11),(13,23)):
            region(right+2,top,47,floor,bgs[2],"service")
            openrect(right-1,floor-2,right+1,floor,bgs[2])
        platform(left,right-8,16,bgs[0])
        platform(left+9,right,8,bgs[0])
        platform(right-8,right+1,12,bgs[0])
        platform(left,left+3,8,bgs[0])
        ladder(left+2,8,23,bgs[0]);ladder(right-3,8,23,bgs[0])
    elif kind==1:
        split=rng.randint(21,27)
        region(0,6,split-1,23,bgs[0],"workshop")
        region(split+1,2,47,15,bgs[1],"office")
        region(split+1,17,47,23,bgs[2],"store")
        openrect(split,21,split,23,bgs[2]);doorway(split,23,bgs[2])
        openrect(split,12,split,15,bgs[1])
        platform(3,split-1,16,bgs[0])
        platform(6,split-6,9,bgs[0])
        ladder(4,9,23,bgs[0]);ladder(42,16,23,bgs[1])
        # A short sloped stair transitions onto the first mezzanine.
        for step in range(8):
            x=split-10+step;y=16+step
            if grid[y][x][0]=="_":grid[y][x]="_"+bgs[0]+"Г"
    elif kind==2:
        shaft=rng.randint(19,25)
        region(shaft-3,1,shaft+3,23,bgs[2],"shaft")
        for level,(top,floor) in enumerate(((1,7),(9,15),(17,23))):
            region(0,top,shaft-5,floor,bgs[level%3],"office" if level%2==0 else "store")
            region(shaft+5,top,47,floor,bgs[(level+1)%3],"service")
            for x in (shaft-4,shaft+4):
                openrect(x,floor-2,x,floor,bgs[2])
                if level==2:doorway(x,floor,bgs[2])
            platform(shaft-3,shaft+3,floor+1,bgs[2],solid=True)
        ladder(shaft-1,8,23,bgs[2])
        # One larger upper room changes the silhouette without sprinkling walls.
        openrect(6,5,14,15,bgs[0])
        platform(5,14,16,bgs[0],solid=True)
    else:
        region(0,2,47,23,bgs[0],"hall")
        # Retained building shell and incomplete upper floors, with stair access.
        for x0,x1 in ((0,13),(32,47)):
            platform(x0,x1,8,bgs[1],solid=True)
            platform(x0,x1,16,bgs[1],solid=True)
            openrect(x0,1,x1,7,bgs[1])
        for x in (13,32):
            for y in range(1,16):
                if y not in (5,6,7,13,14,15):grid[y][x]=wall
        platform(17,28,12,bgs[0])
        platform(23,36,20,bgs[0])
        ladder(7,8,23,bgs[1]);ladder(39,8,23,bgs[1])
        platform(14,17,16,bgs[0])
        for step in range(5):
            x=18+step;y=16+step;grid[y][x]="_"+bgs[0]+"Г"
        # Masonry remains form a contiguous stepped mass in one place.
        rubble_start=rng.randint(27,30)
        for x in range(rubble_start,rubble_start+5):
            height=max(1,4-abs(x-rubble_start-2))
            for y in range(24-height,24):grid[y][x]=wall
    # Explicit ground-level cross-room contract. No top/bottom portal excavation.
    for x in range(W):grid[24][x]=wall
    for x in (0,1,46,47):
        for y in range(21,24):grid[y][x]="_"+bgs[0]
    # Main spawn is deliberate and supported.
    obj("player",1,23,2,2)
    for x,y in doors:obj("stdoor",x,y,1,3)
    # One furnishing group per usable room region, fitted to the space.
    for idx,(x0,top,x1,floor,bg,usage) in enumerate(regions):
        width=x1-x0+1
        if width<5:continue
        x=x0+2
        if usage in ("office","service"):
            obj("table",x,floor,2,1)
            obj("filecab",min(x+4,x1-1),floor,1,2)
            if width>=10:obj("case",min(x+7,x1-1),floor)
        elif usage in ("storage","store"):
            for dx in (0,3,5):
                if x+dx+1<x1:obj("mcrate2",x+dx,floor,2,2)
        elif usage=="workshop":
            obj("table2",x+5,floor,2,1);obj("mcrate2",x+8,floor,2,2)
            obj("ammobox",x+10,floor);obj("box",x+13,floor,2,2)
        # Fixtures are attached to the ceiling band, not scattered across the floor.
        if floor-top>=4 and width>=7:
            backs.append(("vents",x0+2,top+2))
            if width>=16:backs.append(("stlight1",x1-3,top+2))
    # Furnish supported landings in large rooms sparsely, keep ladder corridors clear.
    for y in range(5,24):
        for x in range(5,44,7):
            if grid[y][x][0]=="_" and grid[y+1][x][0]!="_" and rng.random()<0.25:
                obj("case",x,y)
    room=ET.Element("room",name=f"rule_{theme}_{n}",prototype="C-space-grammar",
                    harnessBiome=theme,harnessSeed=str(seed),archetype=role)
    for row in grid:ET.SubElement(room,"a").text=".".join(row)
    for oi,(oid,x,y) in enumerate(objects):
        ET.SubElement(room,"obj",id=oid,code=f"rule_{theme}_{n}_o{oi}",x=str(x),y=str(y))
    for oid,x,y in backs:ET.SubElement(room,"back",id=oid,x=str(x),y=str(y))
    ET.SubElement(room,"doors")
    ET.SubElement(room,"options",entip="0",kolspawn="0")
    assert len(grid)==25 and all(len(row)==48 for row in grid)
    assert all(c[0]!="_" for c in grid[-1])
    assert sum(o[0]=="player" for o in objects)==1
    assert len(ladders)>=1
    return room

def main():
    root=ET.Element("all",prototype="C-from-scratch-space-grammar",seed="20260910")
    for bi,theme in enumerate(PALETTES):
        for n in range(8):root.append(generate(theme,20260910+bi*1000+n,n))
    ET.indent(root)
    out=Path(__file__).with_name("prototype-c.xml")
    ET.ElementTree(root).write(out,encoding="utf-8",xml_declaration=True)
    print(f"{out}: 32 rooms, closed lower boundary, player and ladder assertions passed; traversal not yet verified")

if __name__=="__main__":main()
