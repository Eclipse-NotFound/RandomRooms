"""Build a standalone, source-labelled comparison. Images are structural maps."""
import base64
import html
import json
import random
import statistics
import sys
from pathlib import Path
import xml.etree.ElementTree as ET
sys.path.insert(0,str(Path(__file__).resolve().parent.parent))
from render_dump import read_rooms, from_xml, metrics, raster, write_png

HERE=Path(__file__).resolve().parent
MOD=HERE.parent.parent
GAME=MOD.parent.parent
THEMES=("stable","sewer","plant","mane")
SPECIAL={"beg0","beg","beg1","end","end1","pass","passroof","roofpass","vert","surf","roof","back","uniq"}

def encode(room):
    tmp=HERE/"preview-temp.png"
    write_png(tmp,raster(room,12))
    data=base64.b64encode(tmp.read_bytes()).decode()
    tmp.unlink()
    return {"name":room["name"],"image":"data:image/png;base64,"+data,
            "metrics":metrics(room),"attributes":room["attributes"]}

def main():
    baseline,_=read_rooms(HERE/"baseline-v66.xml")
    clean,_=read_rooms(HERE/"prototype-a.xml")
    original={}
    roots={}
    for theme in THEMES:
        roots[theme]=ET.parse(GAME/"Rooms"/("rooms_"+theme+".xml")).getroot()
        original[theme]=[from_xml(r) for r in roots[theme].findall("room")
            if r.find("options") is not None and r.find("options").get("tip","") == ""]
    rules,_=read_rooms(HERE/"prototype-c.xml")
    data={"a":[],"b":[],"c":[encode(r) for r in rules],"screens":[]}
    captures=HERE.parent.parent/"design"/"assets"/"prototypes-2026-09-10"
    for name,label in [("original","原版 13"),("baseline","v6.6 当前样本"),
                       ("prototype-a","A · 材质去噪"),("prototype-c-0","C · 主厅与附室"),
                       ("prototype-c-1","C · 工坊与夹层")]:
        path=captures/("rrstyle-"+name+"-room.png")
        if path.exists():
            data["screens"].append({"label":label,"name":name,"image":"assets/prototypes-2026-09-10/"+path.name})
    for theme in THEMES:
        old=[r for r in baseline if r["attributes"].get("harnessBiome")==theme]
        new=[r for r in clean if r["attributes"].get("harnessBiome")==theme]
        refs=random.Random(20260910).sample(original[theme],min(8,len(original[theme])))
        for i,(before,after,ref) in enumerate(zip(old,new,refs)):
            data["a"].append({"theme":theme,"index":i,"seed":before["attributes"].get("harnessSeed"),
                             "reference":encode(ref),"baseline":encode(before),"after":encode(after)})
    manifest_path=HERE/"local"/"manifest.json"
    composites=[]
    if manifest_path.exists():
        manifest=json.loads(manifest_path.read_text(encoding="utf-8"))
        composites,_=read_rooms(HERE/"local"/"rooms_local.xml")
        for entry in manifest["manifest"]:
            room=next(r for r in composites if r["name"]==entry["name"])
            sources=[]
            for origin in (entry["host"],entry["donor"]):
                key=(entry["biome"],origin["index"])
                if key in [s["key"] for s in sources]:continue
                xml=roots[entry["biome"]].findall("room")[origin["index"]]
                sources.append({"key":key,"room":encode(from_xml(xml))})
            data["b"].append({"after":encode(room),"sources":sources,"entry":entry})
        data["search"]=manifest["search"]
    groups={"原版普通房":sum(original.values(),[]),"v6.6 新样本":baseline,"A 连续材质":clean,"B 局部重组":composites,"C 空间规则":rules}
    summary={}
    for name,rooms in groups.items():
        if not rooms:continue
        values=[metrics(r) for r in rooms]
        summary[name]={"n":len(rooms)}
        for key in ("wall_fraction","wall_material_change_rate","open_texture_change_rate","objects","backs"):
            summary[name][key]=statistics.mean(v[key] for v in values)
    data["summary"]=summary
    (HERE/"comparison-statistics.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding="utf-8")
    template=HTML.replace("__DATA__",json.dumps(data,ensure_ascii=False).replace("<","\\u003c"))
    output=MOD/"design"/"style-review-2026-09-10.html"
    output.write_text(template,encoding="utf-8")
    print(json.dumps({"output":str(output),"A_pairs":len(data["a"]),"B_samples":len(data["b"]),"summary":summary},ensure_ascii=False))

HTML = r'''<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>RandomRooms · 风格原型对照</title>
<style>
:root{color-scheme:dark;--bg:#11191e;--card:#1c282f;--muted:#a7b5bc;--text:#e4ecea;--accent:#a6d5bd}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:16px/1.65 "Microsoft YaHei","Segoe UI",sans-serif}
main{max-width:1600px;margin:auto;padding:32px 24px 80px}h1{font-size:clamp(25px,3vw,40px);line-height:1.3;margin:8px 0 14px;font-weight:600}
h2{font-size:23px;margin:0 0 12px}.eyebrow{font-size:13px;color:var(--accent);letter-spacing:2px}p{max-width:1050px}
.muted,small{color:var(--muted)}.notice{padding:16px 20px;background:#22342f;border-left:3px solid var(--accent);margin:24px 0}
.controls{display:flex;gap:12px;align-items:center;flex-wrap:wrap;margin:20px 0}
button,select{font:inherit;border:1px solid #53646c;background:#243139;color:var(--text);padding:8px 14px;border-radius:6px;cursor:pointer}
button:hover,button.active{border-color:var(--accent);background:#344b43}input{accent-color:var(--accent)}
section{margin-top:32px;padding-top:24px;border-top:1px solid #33424a}
.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px}
figure{margin:0;background:var(--card);padding:14px;border-radius:8px}figure img{width:100%;display:block;cursor:zoom-in;image-rendering:pixelated}
figcaption{font-size:13px;color:var(--muted);overflow-wrap:anywhere;margin-top:8px}.label{font-size:15px;font-weight:600;margin-bottom:10px}
.legend{display:flex;gap:22px;flex-wrap:wrap;font-size:13px;color:var(--muted)}.dot{display:inline-block;width:12px;height:12px;margin-right:6px}
table{border-collapse:collapse;width:100%;font-size:14px}td,th{text-align:left;padding:12px;border-bottom:1px solid #33424a}th{color:var(--muted)}
.scroll{overflow-x:auto}details{margin-top:12px}pre{white-space:pre-wrap;font-size:12px;max-height:320px;overflow:auto}
dialog{width:min(1300px,95vw);background:#11191e;color:var(--text);border:1px solid #50635c}dialog img{width:100%;image-rendering:pixelated}dialog::backdrop{background:#000d}
@media(max-width:900px){.grid{grid-template-columns:1fr}main{padding:20px 14px}figure img{max-height:420px;object-fit:contain}}
</style><main>
<div class="eyebrow">RANDOMROOMS / 2026-09-10 / 待选路线</div>
<h1>让随机房间更像原版</h1>
<p>先看真实游戏渲染，再对照空间轮廓与固定种子样本。A 检验材质去噪，B 检验局部复用，C 检验新的空间组织规则。</p>
<div class="notice"><strong>原型尚未发布。</strong> 上方实际画面由独立测试实例按相同整房尺度渲染，关闭光照遮罩以方便比较；下方结构图来自 XML，物件尺寸为近似。画面正常不代表移动、战斗与全部种子已通过。</div>
<section><h2>真实游戏渲染 · 相同尺度与曝光</h2><div class="controls"><select id="screen-select" aria-label="真实渲染样本"></select></div><figure id="screen"></figure><p class="muted">可以切换原版、现状和原型，点击图片放大。正常光照的 stage 截图另存于同一测试输出目录。</p></section>
<div class="legend"><span><i class="dot" style="background:#b7bdbc"></i>实体结构</span><span><i class="dot" style="background:#4b5e66"></i>开放空间 / 背景纹理</span><span><i class="dot" style="background:#ccae6e"></i>物件与背饰</span><span><i class="dot" style="background:#73cf8c"></i>玩家起点</span><span><i class="dot" style="background:#e3756a"></i>敌人标记</span></div>
<section><h2>A · 延续从零生成，先验证材质连续性</h2>
<p class="muted">保持同一房间的几何、物件坐标和水 / 楼梯 / 横梁后缀，只将零碎材质改成连续区域。它能单独检验“碎花感”来自哪里；尚未解决楼层骨架、物件用途或实际移动问题，材质改变也未做游戏验证。</p>
<div class="controls"><label>主题 <select id="theme"><option value="stable">避难所</option><option value="sewer">下水道</option><option value="plant">工厂</option><option value="mane">马哈顿</option></select></label><button id="prev">上一组</button><input id="sample" type="range" min="0" max="7" value="0" aria-label="样本编号"><button id="next">下一组</button><span id="counter"></span></div>
<div class="grid" id="a"></div><p id="seed" class="muted"></p>
</section>
<section><h2>C · 从空间用途生成建筑结构</h2><p class="muted">不复制原版整房或区块网格。先确定主厅、工坊、附室、梯井和落脚平台，再铺连续背墙、放用途相关的家具。当前仅有四个原型类型，主要检验方向；稀疏度、同类重复和全部主题表现仍需继续迭代。</p><div class="controls"><select id="ctheme" aria-label="C 原型主题"><option value="stable">避难所</option><option value="sewer">下水道</option><option value="plant">工厂</option><option value="mane">马哈顿</option></select><select id="csample" aria-label="C 原型样本"></select></div><div class="grid" id="c"></div></section>
<section><h2>B · 保留局部空间，再重组</h2>
<p class="muted">原版的平台、房间轮廓及相关物件一起保留，替换宿主的内部区块。每个输出记录来源、切口和结构改变量；接口检查不等于实际可达或视觉验收通过。下方展示当前搜索确实找到的样本，缺少的主题不补造结果。</p>
<div class="controls"><label>重组样本 <select id="bselect" aria-label="重组样本"></select></label></div>
<div class="grid" id="b"></div><p id="bnote"></p><details><summary>来源与接口检查记录</summary><pre id="provenance"></pre></details>
<details><summary>各主题当前可用数量与搜索限制</summary><pre id="search"></pre></details>
</section>
<section><h2>批量对照</h2><p class="muted">“相邻变化率”表示相邻同类格子的字符是否不同，用于衡量碎片化，不是美感评分。越低不一定越好；整房同色也可能单调。原版与原型 B 的主题、样本量不同，不能直接当成同条件胜负。</p><div class="scroll"><table id="stats"></table></div></section>
<section><h2>这轮已经回答与还没回答的事</h2><p>可确认：逐格材质变换破坏了原版的连续图案；去噪仍保留机械骨架。原版的梯井、平台和功能区关系需要进入生成规则。局部片段能保留细节，但接口、脚本依赖和大件跨缝限制了可选素材。</p><p class="muted">待验证：跨房与垂直通行、战斗与摆设阻挡、更多主题与种子的重复率。当前 C 仅通过样本生成和局部实际渲染，不能作为可玩版本发布。</p></section>
</main><dialog id="zoom"><button onclick="this.parentElement.close()">关闭</button><p id="zoomtitle"></p><img id="zoomimg" alt="放大的房间结构图"></dialog>
<script>const DATA=__DATA__;
const $=id=>document.getElementById(id);let index=0;
function figure(label,room){const f=document.createElement('figure'),h=document.createElement('div'),img=document.createElement('img'),c=document.createElement('figcaption');h.className='label';h.textContent=label;img.src=room.image;img.alt=label+' '+room.name;img.onclick=()=>{$('zoomtitle').textContent=label+' · '+room.name;$('zoomimg').src=room.image;$('zoom').showModal()};c.textContent=room.name+' · 物件 '+room.metrics.objects+' / 背饰 '+room.metrics.backs;f.append(h,img,c);return f}
function renderA(){const rows=DATA.a.filter(r=>r.theme===$('theme').value),r=rows[index];$('a').replaceChildren(figure('原版参考（同主题独立样本）',r.reference),figure('当前 v6.6',r.baseline),figure('A · 相同几何的材质去噪',r.after));$('counter').textContent=(index+1)+' / '+rows.length;$('sample').value=index;$('seed').textContent='生成种子 '+r.seed+' · A 保持这一样本的结构，左侧原版仅供风格参考。'}
$('theme').onchange=renderA;$('sample').oninput=e=>{index=+e.target.value;renderA()};$('prev').onclick=()=>{index=(index+7)%8;renderA()};$('next').onclick=()=>{index=(index+1)%8;renderA()};
for(let i=0;i<8;i++)$('csample').add(new Option('样本 '+(i+1),i));
function renderC(){const theme=$('ctheme').value,i=+$('csample').value,room=DATA.c.filter(r=>r.attributes.harnessBiome===theme)[i],a=DATA.a.find(r=>r.theme===theme&&r.index===i);$('c').replaceChildren(figure('原版参考',a.reference),figure('v6.6 当前生成器',a.baseline),figure('C · '+room.attributes.archetype,room))}
$('ctheme').onchange=renderC;$('csample').onchange=renderC;
DATA.screens.forEach((s,i)=>$('screen-select').add(new Option(s.label,i)));
function renderScreen(){const s=DATA.screens[+$('screen-select').value||0];if(!s)return;const img=document.createElement('img');img.src=s.image;img.alt=s.label;img.onclick=()=>{$('zoomtitle').textContent=s.label;$('zoomimg').src=s.image;$('zoom').showModal()};$('screen').replaceChildren(img)}$('screen-select').onchange=renderScreen;
DATA.b.forEach((r,i)=>{const op=new Option(r.after.name,i);$('bselect').add(op)});
function renderB(){if(!DATA.b.length){$('bnote').textContent='当前约束下没有合格候选；不能用强行挖通伪装成功。';return}const r=DATA.b[+$('bselect').value||0];$('b').replaceChildren(...r.sources.slice(0,2).map((s,i)=>figure(i?'原版 · 供体':'原版 · 宿主',s.room)),figure('B · 局部重组',r.after));$('bnote').textContent='两份来源都在上方，可直接比较重组后留下了什么、改变了什么。';$('provenance').textContent=JSON.stringify(r.entry,null,2)}
$('bselect').onchange=renderB;$('search').textContent=JSON.stringify(DATA.search||{},null,2);
const columns=[['n','样本数'],['wall_fraction','实体结构占比'],['wall_material_change_rate','实体材质相邻变化率'],['open_texture_change_rate','开放区纹理相邻变化率'],['objects','平均物件'],['backs','平均背饰']];
const table=$('stats'),head=document.createElement('tr');for(const text of ['样本组',...columns.map(x=>x[1])]){let cell=document.createElement('th');cell.textContent=text;head.append(cell)}table.append(head);
for(const [name,row] of Object.entries(DATA.summary)){const tr=document.createElement('tr');for(const [i,text] of [name,...columns.map(([key])=>key==='n'?row[key]:key.endsWith('rate')||key==='wall_fraction'?(row[key]*100).toFixed(1)+'%':row[key].toFixed(1))].entries()){const cell=document.createElement('td');cell.textContent=text;tr.append(cell)}table.append(tr)}
renderA();renderB();renderC();renderScreen();</script></html>'''
if __name__=="__main__":main()
