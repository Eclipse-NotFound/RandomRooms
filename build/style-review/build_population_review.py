"""Review native screenshots; annotations are a separate optional overlay."""
from pathlib import Path
import json,re,sys
import xml.etree.ElementTree as ET
from collections import Counter
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from verify_architecture import DEFS
MOD=Path(__file__).resolve().parents[2]
ASSETS=MOD/'design/assets/v10-content'
log=(ASSETS/'runner.log').read_text(encoding='utf-8-sig')
records=[]
for theme in ('plant','stable','sewer','mane'):
    cid='rrstyle-navigation-'+theme
    name=re.search(r'capture '+cid+r'-room .*?room=(\S+)',log).group(1)
    rooms=ET.parse(ASSETS/(cid+'-pool.xml')).getroot().findall('room')
    room=next(r for r in rooms if r.get('name')==name)
    content=[];counts=Counter()
    for obj in room.findall('obj'):
        kind=obj.get('rrContent')
        if not kind:continue
        d=DEFS['object_defs'][obj.get('id')];w=max(1,int(d.get('size',1)))
        x=int(obj.get('x'))
        if room.get('rrMirror')=='1':x=48-x-w
        content.append(dict(id=obj.get('id'),kind=kind,x=(x+w/2)*40,y=int(obj.get('y'))*40+20))
        counts[kind]+=1
    records.append(dict(id=cid,theme=theme,name=name,mood=room.get('rrPopulation'),depth=room.get('rrDepth'),counts=counts,content=content))
html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>RandomRooms v10 · 探索内容</title><style>
:root{color-scheme:dark;font:16px/1.75 system-ui,"Microsoft YaHei",sans-serif;background:#111918;color:#e4ece6}*{box-sizing:border-box}body{margin:0}main{max-width:1500px;margin:auto;padding:32px 26px 60px}h1{font-size:38px;line-height:1.3}p{max-width:1050px;color:#b6c9bd}button{font:inherit;border:1px solid #496354;background:#253a2e;color:inherit;border-radius:7px;padding:8px 17px;cursor:pointer}button[aria-pressed=true]{background:#a0c27e;color:#142116}button:focus-visible,a:focus-visible,input:focus-visible{outline:3px solid #efce83;outline-offset:3px}nav,.tools{display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin:20px 0}a{color:#c3dcaa}.frame{position:relative;border:1px solid #496354;background:#080e0b}.frame img{display:block;width:100%;height:auto}.frame svg{position:absolute;inset:0;width:100%;height:100%}svg circle{stroke:#17231c;stroke-width:2}svg text{fill:white;font:19px sans-serif;paint-order:stroke;stroke:#142019;stroke-width:4px}#stageMode .frame{max-width:1008px;margin:auto}.note{font-size:14px}#summary{padding:12px 16px;background:#1e3025;border-left:3px solid #a0c27e}#details{display:flex;gap:9px;flex-wrap:wrap;margin-top:14px}#details span{background:#213228;padding:3px 10px;border-radius:4px}h2{margin-bottom:5px}figure{margin:0}@media(max-width:650px){main{padding:18px 12px}h1{font-size:29px}}
</style><main><p>RandomRooms / v10.0</p><h1>让房间成为可探索的地方</h1><p>敌群、奖励、终端和机关按场景与深度安排。下面是四类场景中的实际原版画面，选取内容较丰富的房间方便查看；普通探索也会遇到安静房和小规模巡逻。</p><nav id="scenes" aria-label="场景"></nav><h2 id="title"></h2><p id="summary"></p><div class="tools"><button id="room" aria-pressed="true">整房画面</button><button id="stage" aria-pressed="false">游戏屏幕</button><label><input type="checkbox" id="marks"> 显示内容位置</label><a id="original" target="_blank" rel="noopener">查看原图</a></div><figure id="figure"><div class="frame"><img id="image" alt=""><svg id="overlay" viewBox="0 0 1920 1000" aria-label="生成位置标记"></svg></div></figure><div id="details"></div><p class="note">图像由原版游戏渲染，未重绘。整房图关闭视野遮罩，不含城市独立远景；游戏屏幕保留原版光照和界面。标记来自生成位置，敌人行动后可能离开标记处，隐藏机关也可能尚未被角色发现。</p><p>终端有实际控制目标，机关包含触发器与武器，奖励沿用原版物品池。出生房和展示馆保留安全布置。剧情 NPC、任务专属装置与首领未加入普通刷新。</p><p><a href="../knowledge/experiments/generator-v10-validation-2026-09-20.md">验证记录</a> · <a href="generator-v9-review.html">四类场景结构对照</a></p></main><script>
const data=__DATA__,names={plant:'工厂',stable:'废弃避难厩',sewer:'下水道',mane:'城市废墟'},labels={enemy:'敌人',security:'防御设施',loot:'物资容器',reward:'额外奖励',terminal:'终端',switch:'开关',hazard:'危险设施',trigger:'触发器',damager:'机关武器',service:'服务设施'},colors={enemy:'#e6756e',security:'#e89f68',loot:'#96d77d',reward:'#e2cd68',terminal:'#6bcede',switch:'#7fa5ec',hazard:'#ec9393',trigger:'#de90c4',damager:'#e681bb',service:'#a6bbff'};
const $=id=>document.getElementById(id);let chosen='plant',mode='room';
for(const [key,label] of Object.entries(names)){const b=document.createElement('button');b.textContent=label;b.dataset.theme=key;b.onclick=()=>{chosen=key;render()};$('scenes').append(b)}
for(const key of ['room','stage'])$(key).onclick=()=>{mode=key;render()};$('marks').onchange=render;
function render(){const r=data.find(x=>x.theme===chosen);$('title').textContent=names[chosen];$('summary').textContent=Object.entries(r.counts).map(([k,n])=>(labels[k]||k)+' '+n).join(' · ');for(const b of $('scenes').children)b.setAttribute('aria-pressed',b.dataset.theme===chosen);for(const k of ['room','stage'])$(k).setAttribute('aria-pressed',k===mode);const src='assets/v10-content/'+r.id+'-'+mode+'.png';$('image').src=src;$('image').alt=names[chosen]+'探索内容原版实景';$('original').href=src;const figure=$('figure');figure.style.maxWidth=mode==='stage'?'1008px':'none';figure.style.margin='auto';$('overlay').replaceChildren();$('overlay').style.display=mode==='room'&&$('marks').checked?'block':'none';$('details').replaceChildren();for(const [k,n] of Object.entries(r.counts)){const s=document.createElement('span');s.textContent=(labels[k]||k)+' '+n;s.style.borderBottom='2px solid '+colors[k];$('details').append(s)}for(const o of r.content){const g=document.createElementNS('http://www.w3.org/2000/svg','g'),c=document.createElementNS(g.namespaceURI,'circle'),t=document.createElementNS(g.namespaceURI,'title');c.setAttribute('cx',o.x);c.setAttribute('cy',o.y);c.setAttribute('r',13);c.setAttribute('fill',colors[o.kind]);t.textContent=(labels[o.kind]||o.kind)+' · '+o.id;g.append(c,t);$('overlay').append(g)}}render();
</script></html>'''
(MOD/'design/generator-v10-review.html').write_text(html.replace('__DATA__',json.dumps(records,ensure_ascii=False)),encoding='utf-8')
print('Built native content review:',len(records),'scenes')
