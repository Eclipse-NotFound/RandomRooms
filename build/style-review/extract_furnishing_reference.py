"""Extract manually selected local furnishing groups, with source/ID checks."""
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
GROUPS = [
    dict(key="stable_office", theme="stable", role="办公桌柜", index=5, origin=(9,15),
         obj=[("table2",11,15),("filecab",14,15),("filecab",15,15)],
         back=[("stwindow",9,13),("stlight4",10,12),("wires1",14,12),("wires1",14,14)],
         note="同一办公区域：桌、并排文件柜、窗、灯、连续线缆。柜前保留通道，别用箱子填满桌柜间隙。"),
    dict(key="stable_control", theme="stable", role="壁装控制台", index=0, origin=(13,19),
         obj=[("term3",15,18)],
         back=[("pult",13,18),("pult",16,18),("monitor",13,16),("monitor",13,17),("monitor",16,16),("monitor",16,17),("stlight3",16,14)],
         note="控制台为墙面整体：两组显示器上下对齐，台面比玩家站立锚点高一格。term3可选；它自带破解/信息/陷阱机制，纯视觉版只用back。"),
    dict(key="stable_store", theme="stable", role="金属仓储湾", index=31, origin=(22,23),
         obj=[("mcrate1",22,23),("mcrate1",24,23)],
         back=[("zavod2",26,22),("zavod2",29,22),("stlight3",23,19)],
         note="实体箱子占一侧，金属杂物留在另一侧，灯在其上。整个仓储湾旁留空，不以均匀间距填遍整层。"),
    dict(key="sewer_pipe", theme="sewer", role="低位管道带", index=1, origin=(24,17),
         obj=[],
         back=[("pipe3",24,16),("pipe3",26,16),("pipe3",28,16),("pipe3",30,16),
               ("pipe3",24,17),("pipe3",26,17),("pipe3",28,17),("pipe3",30,17),("potek",24,16)],
         note="两条连续管线，每节2格宽，步长也是2格；污渍覆盖同一片背景。是无碰撞设施带，不应在每节管子旁再抽一个箱子。potek宽10格，不能当1格斑点。"),
    dict(key="sewer_work", theme="sewer", role="维修兼医疗角", index=7, origin=(2,15),
         obj=[("bigmed",3,15),("table",6,15),("bookcase",9,15)],
         back=[("vent",2,13),("light3",6,13),("light4",6,12),("pipe4",8,12),("pipe4",8,14)],
         note="高柜、工作桌、高书柜三段高低变化，桌上方单独照明，细管沿柜侧连续向下。bookcase虽wall=1仍在原版贴地摆。"),
    dict(key="sewer_store", theme="sewer", role="工具仓储间", index=0, origin=(35,23),
         obj=[("locker",38,23),("table1",41,23),("trash",44,23),("instr1",45,23)],
         back=[("pipe4",35,20),("pipe4",35,22),("depot",36,21),("storage",40,21)],
         note="后台储物架负责密度，前景保留柜、桌与工具箱。没有复制该房其他位置的辐射桶，以免仅为观感引入辐射规则。"),
    dict(key="plant_control", theme="plant", role="机器控制区", index=16, origin=(20,23),
         obj=[("bigbox",20,23)],
         back=[("electro",20,20),("pult",23,22),("monitor",23,21),("monitor",23,20),("electro",25,20)],
         note="两侧机器框住中间两层显示器与控制台，前景只放一个大箱。原房platform2/knop3的allid联动未复制。electro会在引擎中随机左右翻转，预留完整3格宽。"),
    dict(key="plant_store", theme="plant", role="木箱仓储带", index=10, origin=(11,7),
         obj=[("box",11,7),("box",14,7),("box",18,7)],
         back=[("depot",13,5),("depot",16,5),("depot",19,5)],
         note="三箱间距3/4格，后台货架错开，三维层次靠前后关系而非堆满地板。使用原版既有箱子，不复制顶层的另一批箱子。"),
    dict(key="plant_med", theme="plant", role="医疗办公区", index=30, origin=(11,9),
         obj=[("bookcase",11,9),("table",14,9),("filecab",16,9),("cup",17,9),("medbox",19,8),("trash",20,9)],
         back=[("bwindow",12,6),("bwindow",17,6),("clock",16,6),("light4",13,5),("light4",18,5)],
         note="双窗和顶灯先定义办公段；医药箱挂高一格，地面摆桌柜。原房term2有默认hack_lock动作，doctor是NPC，均未复制。"),
    dict(key="mane_office", theme="mane", role="阅览休息角", index=52, origin=(17,23),
         obj=[("couch",17,23),("bookcase",23,23),("table",25,23),("trash",27,23)],
         back=[("stillage",20,21)],
         note="低沙发—后台架—高书柜—桌子的层次保留，留白是组合的一部分。这里的真沙发是couch；lov是陷阱标记，不能使用。"),
    dict(key="mane_food", theme="mane", role="冷藏与洗涤角", index=23, origin=(37,15),
         obj=[("table1",37,15),("ccup",40,15),("tap",41,15),("fridge",42,15),("wcup",40,13),("wcup",41,13)],
         back=[("light2",37,13),("bvent",37,9)],
         note="连续地柜/洗涤台/冰箱，上柜挂高两格；通风在高处。原房stove继承allact=stove，这个无脚本组留空不带入。tap的实际scy=45像素，比wid*40稍高，碰撞预留两行。"),
    dict(key="mane_server", theme="mane", role="电气机房与控制桌", index=28, origin=(3,15),
         obj=[("table",3,15),("bookcase",5,15),("term3",4,14)],
         back=[("light3",3,11),("light3",12,11),("poster",3,12),
               ("electro",10,12),("electro",13,12),("electro",16,12),
               ("monitor",13,13),("monitor",14,13),("wires1",19,12),("wires1",19,14),
               ("wires2",9,12),("wires2",9,14)],
         note="左侧控制桌，右侧三联电气背景，中间用线缆分区；原版两个monitor图层有重叠，保留它而不是对所有back强制互斥。term3可选；term1/allact=hack_robot未复制。"),
]


def main():
    text=(ROOT/"game-reference/decompiled/1.02/src102/scripts/fe/AllData.as").read_text(encoding="utf-8-sig")
    data=ET.fromstring(text[text.index("<all>"):text.rindex("</all>")+6])
    defs={tag:{e.get("id"):dict(e.attrib) for e in data.findall(tag)} for tag in ("obj","back")}
    compiled=[]
    used={"obj":set(),"back":set()}
    for group in GROUPS:
        source=ET.parse(ROOT/"Rooms"/f"rooms_{group['theme']}.xml").getroot().findall("room")[group["index"]]
        result={k:group[k] for k in ("key","theme","role","note")}
        result["source"]={"file":f"Rooms/rooms_{group['theme']}.xml","index":group["index"],"name":source.get("name"),"origin_x_F":group["origin"]}
        x0,F=group["origin"]
        maxx=0;miny=0;maxy=1
        for tag in ("obj","back"):
            result[tag]=[]
            for oid,x,y in group[tag]:
                found=[e for e in source.findall(tag) if e.get("id")==oid and float(e.get("x"))==x and float(e.get("y"))==y]
                assert found,(group["key"],oid,x,y)
                assert not any(k in found[0].attrib for k in ("allid","allact","tr","uid","ph","transm"))
                definition=defs[tag][oid]
                assert not definition.get("allact"),(oid,definition)
                if tag=="obj":
                    assert definition.get("tip")=="box",(oid,definition)
                    w=int(definition.get("size",1));h=int(definition.get("wid",1))
                    if definition.get("scy"):h=max(h,(int(definition["scy"])+39)//40)
                    top=y-F-h+1;bottom=y-F+1
                    mount="wall-fixed" if int(definition.get("wall",0)) else "supported"
                else:
                    w=int(definition.get("x2",1));h=int(definition.get("y2",1));top=y-F;bottom=top+h;mount="background-top-left"
                result[tag].append([oid,x-x0,y-F])
                used[tag].add(oid);maxx=max(maxx,x-x0+w);miny=min(miny,top);maxy=max(maxy,bottom)
        result["nominal_bounds"]={"width_cells":maxx,"top_relative_F":miny,"bottom_exclusive_relative_F":maxy}
        compiled.append(result)
    package={"coordinate_system":"origin=(X,F), F is standable object anchor row; floor top is row F+1; entries are [id,dx,dy]",
             "script_dependencies":"local allid/allact/tr and inherited AllData allact excluded; optional term3 keeps its own native hack/loot/mine behavior",
             "object_defs":{k:defs['obj'][k] for k in sorted(used['obj'])},
             "back_defs":{k:defs['back'][k] for k in sorted(used['back'])},"groups":compiled}
    (OUT/"furnishing-reference.json").write_text(json.dumps(package,ensure_ascii=False,indent=2),encoding="utf-8")
    lines=["# C 建筑生成器：原版局部摆设与材质参考（2026-09-10）","",
           "仅数据参考，不改生产源码、不复制整个房。12 组均从四主题原版 XML 选取局部元素，保留组内相对位置；已程序化核对 ID、原坐标、尺寸、XML 与 AllData 两层脚本依赖。机器可读数据见 `furnishing-reference.json`。", "",
           "## 放置坐标与真正的脚点", "",
           "把组原点设为 `(X,F)`：X 是左端列，F 是地面家具的锚点行；地板顶面在 **F+1** 行。每项 `[id,dx,dy]` 写成 XML `x=X+dx, y=F+dy`。", "",
           "`Location.createObj` 对 box/door 使用 `X像素=(x+size/2)*40`、**`Y脚点=(y+1)*40-1`**。物件向上延伸，不能把 wid 向下占地；正常物件检查脚下 y+1。实际 scY 来自素材高度，AllData 的 wid 是编辑器格高；scy 显式覆盖须优先照顾（tap=45 px、couch=20 px）。", "",
           "`BackObj` 则以 XML `(x*40,y*40)` 作为背景素材的左上摆放基准；x2/y2 是名义尺寸，**不是脚点行**。如 3 格高 depot 顶边 `dy=-2`，底边正好到 F+1 地板。", "",
           "带 `wall>0` 的 Box 在 `checkStay()` 直接保持固定：壁柜可以悬挂。仍需根据角色区分——bookcase/locker 虽固定，原版常贴地；wcup、medbox、wallcab 常挂墙。不要把固定等同于可任意塞进实体墙。", "",
           "## 可直接采用的 12 个局部组", "",
           "以下是原版局部取样，不是密度目标。先选用途与可用墙面，再决定整个组是否放得下；不够就省略整组或选较小组，不逐个挤到梯井/门口。back 原本允许在不同图层重叠，不能套用家具碰撞互斥。", ""]
    for g in compiled:
        lines += [f"### {g['key']} — {g['role']}","",f"来源：`{g['source']['file']}` 第 {g['source']['index']} 号 room（从 0 数）`{g['source']['name']}`；原点 `{tuple(g['source']['origin_x_F'])}`。名义范围宽 {g['nominal_bounds']['width_cells']} 格，顶边 F{g['nominal_bounds']['top_relative_F']:+d}，底边不超过 F{g['nominal_bounds']['bottom_exclusive_relative_F']:+d}。","", "```text",f"obj  = {json.dumps(g['obj'],ensure_ascii=False)}",f"back = {json.dumps(g['back'],ensure_ascii=False)}","```","",g['note'],""]
    lines += ["## 全部采用的 obj 定义", "", "尺寸为 AllData size×wid；默认脚点均遵循前述公式。固定物件的名义底边也使用同一脚点公式，但不要求下面有实体地板。", "", "| id | size×wid | wall | 实际 scy 覆盖 | 角色/注意 |", "|---|---:|---:|---:|---|"]
    for oid in sorted(used["obj"]):
        d=defs["obj"][oid]
        note="可选原生破解/信息/陷阱交互" if oid=="term3" else ("挂墙或靠墙固定" if int(d.get("wall",0)) else "必须有支撑")
        lines.append(f"| {oid} | {d.get('size','1')}×{d.get('wid','1')} | {d.get('wall','0')} | {d.get('scy','素材高度')} | {note} |")
    lines += ["", "## 全部采用的 back 定义", "", "尺寸为 x2×y2，挂靠高度见各组 dy。s 是原版绘制图层，**不是伸缩倍率**。空值使用引擎默认层；不新增 XML w/h 缩放。", "", "| id | x2×y2 | 原版 s | 特性 |", "|---|---:|---:|---|"]
    for oid in sorted(used["back"]):
        d=defs["back"][oid];notes=[]
        if d.get("mirr")=="2":notes.append("引擎可随机翻转")
        if d.get("lon"):notes.append("开关灯帧")
        if d.get("er"):notes.append("擦除背景层")
        lines.append(f"| {oid} | {d.get('x2','1')}×{d.get('y2','1')} | {d.get('s','默认')} | {'；'.join(notes) or '普通背景'} |")
    lines += ["", "## 排除项与数量使用方式", "",
              "- `lov` 是 tip=up/tipn=5 的陷阱候选标记，绝不是沙发。真沙发用 couch；bed 是 4×1、scy=28 px。",
              "- `term1`/`term2` 在 AllData 内置 `hack_robot`/`hack_lock`，`stove` 内置 `allact=stove`。即使房 XML 没写 allact，也不属于本轮无脚本套件。",
              "- 未带入原房的 player/enl/enf、NPC、机关按钮、电梯、allid 引用、辐射桶或爆炸桶。这里的组不会凭空增加这些依赖。",
              "- term3 无跨对象 allid/allact 依赖，但含自己的破解、信息奖励与随机陷阱属性；若只做画面，去掉它，保留 pult/monitor 后台即可。",
              "- 原版 obj 约40这一数字含出生/敌人/陷阱标记，不能要求C硬放40个实体家具。更直接的丰富来源是连续管线、成组机台、货架与窗灯：上述组平均前景对象少于后台设施。",
              "- 主空间选择一个大主题组，侧室选用途相符的小组，平台只放一两个有明确用途的物件。梯井两列、门前后、出生点与跨房入口先保留；所有组之后不再随机补箱把空白填满。",
              "", "## 材质、地板边线和主题配对", "",
              "统计口径仍为120普通房；`_`是没有显式后缀的开放格，会使用所在房/土地默认背景，不表示最终画面完全没有纹理。首字符和后缀同一字母含义不同：例如实体J是金属墙，`_J`是剥落灰泥背景；实体D是破损混凝土，`_D`是砖墙背景。", "",
              "| 主题 | 实体主材实数 | 临空楼板顶面常见材质 | 开放背景主要后缀（含裸底） | 可采用的整片关系 |",
              "|---|---|---|---|---|",
              "| stable | J4551、K3287、A2982 | K2390 > A1090 > J846 | P6686、R6460、裸底5110、Q2749、N1208 | J墙体，K作为连续楼板/结构边带；房内P/R，Q做局部深色板带，N用于设施墙区 |",
              "| sewer | L6370、A2324、M524、I362 | L1889、A776、M242、I216 | 裸底8105、E3532、C907、K744、T711、D654 | L湿墙主结构；E大砌块局部衬里；M/_T锈金属检修区，I/_D砖衬区，不把I当全房统一装饰线 |",
              "| plant | C5868、G2179、D1601、B1523 | C2996、B881、D690 | 裸底21314、C2742、D1738、E1674、J1630、B1581 | C连续单层楼板、裸底大厅；D整段破损表面；背景C/J/D只在完整附室或车间区铺设，B用于少数重结构 |",
              "| mane | N4614、D375、B311 | N2397、D243、B176 | 裸底13580、C2687、D2582、J1999、A1223、H1119、I617 | N建筑墙/楼板主体；D连续受损楼板段；开放背景C/D/J/A/H/I按用途分区；不要主要使用stable式F/P/R |", "",
              "以上是实测分布，不是逐格抽签权重。尤其不要为追数量把A大量塞入C：A是不可破坏钢，B为高强混凝土；J/M hp5000，K/C/D/N hp1000，材质替换会改变破坏机制。", "",
              "原版直接可查的三层截面：", "",
              "1. stable `кабинеты2` x10..25：y15是开放站立层，y16整行K，y17在x10..20是J实体体积。适合 **开放空间 / K结构盖边 / J墙身**，不是J/K棋盘。",
              "2. plant `склад1` x8..30：y7裸底开放，y8整行C薄楼板，y9基本_C背景（其中x23/24是CC实体柱）。适合 **裸底上层 / 单行C楼板 / _C分区下层**；柱子成固定结构，不随机散点。",
              "3. mane `ко.офисы2` x14..36：y15开放，y16的x14..27整段D、x28..36整段N，y17开放。损坏是连续区段，未被随机噪点打散。",
              "4. sewer `трубы3` x23..34：y17是_D/_E/裸底的管道空间，y18是M楼板（中间x26..29开放口），y19整段_T背景。这种M/_T检修夹层很自然；主湿墙仍然使用L。", "",
              "形状负责可达，材质只在既定实体/开放区域内变换；跨层口、梯井、横梁和斜梯后缀不可为了视觉补齐而覆盖。特别要保留西里尔А/Б及shelf类后缀。", "",
              "## 来源", "",
              "- 原版组坐标：各组标明的 Rooms/rooms_*.xml。",
              "- ID/size/wid/wall/scy/x2/y2/s/allact：game-reference/decompiled/1.02/src102/scripts/fe/AllData.as。",
              "- 真实脚点与对象创建：fe/loc/Location.as:1980；实际素材高度与scy覆盖：fe/loc/Box.as:157；固定物件不落下：Box.as:943。",
              "- back左上摆放及镜像/图层：fe/graph/BackObj.as:40；首字符/后缀语义：fe/loc/Form.as与Tile.as:203。",
              "", "## 复跑", "", "`python mods/RandomRooms/build/style-review/extract_furnishing_reference.py`；输出只在本目录。ID 或原坐标不符、选中跨对象依赖、选中 AllData 自带 allact 会直接断言失败。材质统计小节为本轮只读扫描结果；未接入概率抽样。", ""]
    (OUT/"furnishing-reference.md").write_text("\n".join(lines),encoding="utf-8")
    print(f"verified {len(compiled)} groups, {len(used['obj'])} obj ids, {len(used['back'])} back ids")


if __name__=="__main__":
    main()
