"""Build the local review from frozen, unedited native captures."""
from collections import Counter
import json
from pathlib import Path
import xml.etree.ElementTree as ET

MOD=Path(__file__).resolve().parents[2]
ASSETS=MOD/'design/assets/v9-scenes'
records=[]
for case in ET.parse(ASSETS/'cases.xml').getroot().findall('case'):
    r=case.find('room')
    counts=Counter(o.get('rrFixture') for o in r.findall('obj') if o.get('rrFixture'))
    records.append(dict(id=case.get('id'),theme=r.get('rrTheme'),form=r.get('rrForm'),room=r.get('name'),
                        spaces=[dict(e.attrib) for e in r.findall('rrPlan/space')],fixtures=dict(counts)))
html='''<!doctype html>
<html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>RandomRooms v9 · 四种场景，四种空间</title>
<style>
:root{color-scheme:dark;font:16px/1.8 system-ui,"Microsoft YaHei",sans-serif;background:#111918;color:#e4ece6}*{box-sizing:border-box}body{margin:0}main{max-width:1480px;margin:auto;padding:36px 28px 70px}h1{font-size:clamp(28px,4vw,45px);line-height:1.3;margin:8px 0 18px}h2{font-size:25px;margin:20px 0 6px}.muted,figcaption{color:#a9bcb1}p{max-width:1020px;margin:10px 0}a{color:#b5d89c}button,select{font:inherit;border:1px solid #496354;background:#253a2e;color:inherit;border-radius:7px;padding:9px 17px;cursor:pointer}button[aria-pressed=true]{background:#92b574;color:#15231b;border-color:#c4dfa9}button:focus-visible,select:focus-visible,a:focus-visible{outline:3px solid #efce83;outline-offset:3px}nav,.tools{display:flex;gap:9px;flex-wrap:wrap;align-items:center;margin:20px 0}.tools{margin:14px 0}figure{margin:0}.frame{position:relative;background:#080e0b;border:1px solid #45614e;border-radius:9px;overflow:hidden}.frame img{display:block;width:100%;height:auto}.stage .frame{max-width:1008px;margin:auto}.stage figcaption{text-align:center}.frame svg{position:absolute;inset:0;width:100%;height:100%;pointer-events:none}.meta{color:#adc8b1;font-size:14px}.intro{padding:18px 22px;border-left:3px solid #92b574;background:#19291f}.compare{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:18px 0}.compare button{padding:0;overflow:hidden;text-align:left;background:#1c2d23}.compare img{display:block;width:100%;aspect-ratio:1.92;object-fit:cover}.compare span{display:block;padding:8px 12px}.note{border-top:1px solid #3c5143;margin-top:34px;padding-top:20px}@media(max-width:800px){main{padding:24px 14px}.compare{grid-template-columns:repeat(2,1fr)}.tools{gap:7px}button,select{padding:8px 12px}}
</style><main>
<div class="muted">RANDOMROOMS · v9</div><h1>四种场景，各有自己的空间</h1>
<p>工厂、废弃避难厩、下水道与城市废墟分别生成空间、墙面、门窗和设施。F1 选择场景后，向右、向下扩张及 F4 深入均保持该场景；回城后可以更换。</p>
<div class="compare" id="compare" aria-label="四场景概览"></div>
<nav id="scenes" aria-label="选择场景"></nav>
<div class="intro"><h2 id="title"></h2><p id="description"></p></div>
<div class="tools"><label>空间样本 <select id="sample" aria-label="空间样本"></select></label><button id="stage" aria-pressed="false">游戏画面</button><button id="room" aria-pressed="true">整房结构</button><label><input id="overlay" type="checkbox"> 空间标记</label><a id="original" target="_blank" rel="noopener">查看原图</a></div>
<p class="meta" id="meta"></p>
<figure id="figure" class="room"><div class="frame"><img id="image" alt=""><svg id="overlaySvg" viewBox="0 0 1920 1000" aria-hidden="true"></svg></div><figcaption id="caption"></figcaption></figure>
<div class="note"><p>图片均来自原版游戏实际渲染，未重绘。整房图为检查结构而关闭视野遮罩，不包含独立远景层；游戏画面保留原版光照、界面和城市远景。单房展示时，原版会封闭没有邻居的外缘；连续地图另有入口与扩张实测。</p><p>下水道使用真实污水和原版辐射效果，必经通路保留干路；进入池中属于可选探索。门和活板门可操作，玻璃窗使用原版碰撞。</p><p><a href="../knowledge/experiments/generator-v9-validation-2026-09-19.md">查看验证记录与已知边界</a> · <a href="generator-v8-review.html">上一版画面</a></p></div>
</main><script>
const data=__DATA__;
const info={plant:['工厂','宽大的工作大厅连接仓库、检修区与办公附室。混凝土墙、厂房窗、设备和锈梁形成连续的生产空间。'],stable:['废弃避难厩','金属舱室围绕居住、行政、服务设施与公共空间组合。采用避难厩专用门窗、墙板和钢梁。'],sewer:['下水道','水渠、集水池与泵房连接检修通路。管线、潮湿墙面和真实污水构成场所特点；开放入口之间保留干燥路线。'],mane:['城市废墟','楼体与街道、屋顶交错。破损楼层、建筑外墙、混凝土梁、室内残存家具与原版城市远景共同构成废墟。']};
const forms={production:'车间与附室',storage_hall:'仓储大厅',service_wing:'生产区与辅助房',quarters:'居住舱室',atrium_ring:'公共中庭',service_cluster:'服务与行政区',canal_gallery:'水渠与检修通路',cistern:'集水池',pump_chain:'泵房与渠池',courtyard:'楼间院落',broken_facade:'破损楼体',roof_passage:'屋顶通路'};
const $=id=>document.getElementById(id);let theme='plant',selected=0,mode='room';
for(const [id,[name]]of Object.entries(info)){const b=document.createElement('button');b.textContent=name;b.onclick=()=>choose(id);b.dataset.theme=id;$('scenes').append(b);const t=document.createElement('button'),img=document.createElement('img'),s=document.createElement('span');img.src='assets/v9-scenes/'+data.find(r=>r.theme===id).id+'-room.png';img.alt=name+'整房概览';s.textContent=name;t.append(img,s);t.onclick=()=>choose(id);$('compare').append(t)}
function choose(id){theme=id;selected=0;$('sample').replaceChildren();data.filter(r=>r.theme===theme).forEach((r,i)=>{const o=document.createElement('option');o.value=i;o.textContent=forms[r.form]||r.form;$('sample').append(o)});render()}
$('sample').onchange=()=>{selected=Number($('sample').value);render()};for(const m of ['stage','room'])$(m).onclick=()=>{mode=m;render()};$('overlay').onchange=render;
function render(){const r=data.filter(r=>r.theme===theme)[selected];$('title').textContent=info[theme][0]+' · '+forms[r.form];$('description').textContent=info[theme][1];for(const b of $('scenes').children)b.setAttribute('aria-pressed',b.dataset.theme===theme);for(const m of ['stage','room'])$(m).setAttribute('aria-pressed',m===mode);const src='assets/v9-scenes/'+r.id+'-'+mode+'.png';$('image').src=src;$('image').alt=info[theme][0]+'，'+forms[r.form]+'，'+(mode==='stage'?'游戏实际画面':'整房结构');$('original').href=src;$('figure').className=mode;$('meta').textContent=r.spaces.filter(s=>s.kind==='volume').length+' 个主要空间 · '+(r.fixtures.door||0)+' 扇门 · '+(r.fixtures.hatch||0)+' 个活板门 · '+(r.fixtures.window||0)+' 扇玻璃窗';$('caption').textContent=mode==='stage'?'保留原版光照和远景的游戏屏幕。':'关闭视野遮罩的整房诊断视图；空白室外的真实远景请切换游戏画面。';$('overlaySvg').replaceChildren();$('overlaySvg').style.display=mode==='room'&&$('overlay').checked?'block':'none';for(const s of r.spaces.filter(s=>s.kind==='volume')){const n=document.createElementNS('http://www.w3.org/2000/svg','rect');for(const[k,v]of Object.entries({x:s.x0*40+3,y:s.top*40+3,width:(s.x1-s.x0+1)*40-6,height:(s.floor-s.top+1)*40-6,fill:'none',stroke:'#e6d19e','stroke-width':3,'stroke-dasharray':'12 7'}))n.setAttribute(k,v);$('overlaySvg').append(n)}}choose(theme);
</script></html>'''
(MOD/'design/generator-v9-review.html').write_text(html.replace('__DATA__',json.dumps(records,ensure_ascii=False)),encoding='utf-8')
print('Scene review generated:',len(records),'native samples')
