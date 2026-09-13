"""Present unedited native screenshots and the exported architectural plan."""
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET

MOD=Path(__file__).resolve().parents[2]
ASSETS=MOD/'design/assets/v8-spaces'
THEMES={'stable':'避难所','sewer':'下水道','plant':'工厂','mane':'城市'}
TITLES=['高厅与错层附室','大跨度大厅与侧间','错层附室与中间平台','通高附室与维修层','维修间与中间层','仓储与夹层']

def main():
    manifest=json.loads((ASSETS/'manifest.json').read_text(encoding='utf-8-sig'))
    if manifest['status']!='complete': raise ValueError('Incomplete captures')
    data=[]
    for case in ET.parse(ASSETS/'cases.xml').getroot().findall('case'):
        room=case.find('room')
        if room is None or room.get('rrGen')!='space-v8': continue
        spaces=[dict(r.attrib) for r in room.findall('rrPlan/space')]
        for s in spaces:
            for key in ('x0','x1','top','floor'): s[key]=int(s[key])
        ports=[]
        for p,a in enumerate(map(int,room.findtext('doors').split('.'))):
            if a<2: continue
            x,y=(47,3+4*p) if p<6 else (5+9*(p-6),24) if p<11 else (0,3+4*(p-11)) if p<17 else (5+9*(p-17),0)
            ports.append(dict(x=(x+.5)*40,y=(y+.5)*40,side='右' if p<6 else '下' if p<11 else '左' if p<17 else '上'))
        count=sum(s.get('kind','volume')=='volume' for s in spaces)
        data.append(dict(case=case.get('id'),title=TITLES[len(data)%6],theme=THEMES[room.get('rrTheme')],
                         room=room.get('name'),spaces=spaces,ports=ports,volumes=count,
                         loops=len(room.findall('rrPlan/link'))-count+1))
    if len(data)!=6: raise ValueError(f'Expected six samples, got {len(data)}')
    for row in data:
        for mode in ('stage','room'):
            if not (ASSETS/f'{row["case"]}-{mode}.png').is_file(): raise FileNotFoundError(row['case'])
    stats=json.loads((MOD/'build/style-review/v8-diversity.json').read_text())
    page=r'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>RandomRooms v8 · 不同的空间，不同的走法</title><style>
:root{color-scheme:dark;font:16px/1.8 system-ui,"Microsoft YaHei",sans-serif;background:#11191c;color:#e6eded}*{box-sizing:border-box}body{margin:0}main{max-width:1440px;margin:auto;padding:34px 24px 70px}h1{font-size:clamp(28px,4vw,46px);line-height:1.3;margin:8px 0 18px}h2{font-size:23px;margin-top:28px}p{max-width:1000px}.eyebrow,.muted,figcaption{color:#a4b9bb}.eyebrow{letter-spacing:3px}a{color:#8ad9c3}button{cursor:pointer;background:#213036;border:1px solid #43555a;color:inherit;padding:9px 15px;border-radius:8px;font:inherit}button[aria-pressed=true]{background:#3e7367;border-color:#91d8c1}nav,.toolbar{display:flex;gap:9px;flex-wrap:wrap;margin:18px 0}figure{margin:0}.frame{position:relative;background:#060a0c;border:1px solid #425052;border-radius:8px;overflow:hidden}.frame img{width:100%;display:block}.frame svg{position:absolute;inset:0;width:100%;height:100%;pointer-events:none}figcaption{font-size:14px;margin:8px 0}.stage .frame{max-width:1008px;margin:auto}.stats{display:grid;grid-template-columns:repeat(3,1fr);gap:15px;margin:25px 0}.stat{padding:18px;background:#1b282d;border-radius:10px}.stat strong{display:block;color:#b2e8d6;font-size:30px}.compare{display:grid;grid-template-columns:1fr 1fr;gap:15px}.compare img{width:100%}details{margin-top:28px;background:#19252a;padding:16px;border-radius:8px}summary{cursor:pointer}input{accent-color:#8bd6c0} @media(max-width:700px){main{padding:22px 12px}.stats,.compare{grid-template-columns:1fr}.stat strong{font-size:24px}}</style>
<main><div class="eyebrow">RANDOMROOMS · V8</div><h1>不同的空间，不同的走法</h1>
<p>房间的宽度、高度、分隔与连接一起生成。侧边出口可以位于不同楼层，上下出口通常错开；有的房间围绕大空间展开，有的分散成数个附室，有的连接密集，有的留下有用途的尽头。</p>
<p>每个开放边口都可以成为入口。生成器不会指定一条从左到右的固定路线，也不会因为玩家从另一边进来而重排房间。</p>
<nav id="samples" aria-label="选择房间"></nav><h2 id="title"></h2><p id="description"></p>
<div class="toolbar"><button id="room" aria-pressed="true">查看整间建筑</button><button id="stage" aria-pressed="false">查看游戏屏幕</button><label><input id="overlay" type="checkbox"> 标出功能空间与边口</label></div>
<figure id="figure"><div class="frame"><a id="full" target="_blank" rel="noopener"><img id="capture" alt=""></a><svg id="markers" viewBox="0 0 1920 1000" aria-hidden="true"></svg></div><figcaption id="caption"></figcaption></figure>
<div class="stats"><div class="stat"><strong>4–9 个</strong>样本中的功能空间数量，大小与层高分别变化。</div><div class="stat"><strong>__GRAPHS__ 种以上</strong>1,024 间样本中不同的连接关系；忽略换色、镜像与坐标后统计。</div><div class="stat"><strong>上下错开</strong>144 间地图中，89 间同时有上下口，只有 5 间上下口对齐。</div></div>
<h2>从重复楼层到变化的建筑</h2><p>旧版样本全部在第 16 格高度留下长楼层。新版同高度出现率约 25%，楼层分散在第 5–20 格。回环数量也会变化：有些房间以分支连接，有些包含多个回环，不给每间房套同一条游览路线。</p>
<div class="compare"><figure><img loading="lazy" src="assets/v7-1-fixtures/rrstyle-generated-v71-2-room.png" alt="旧版分层办公室"><figcaption>v7.1 · 固定布局中的分层办公室</figcaption></figure><figure><img loading="lazy" src="assets/prototypes-2026-09-10/rrstyle-original-room.png" alt="原版作者房间"><figcaption>原版作者房间 · 用于对照材质、空间与摆设</figcaption></figure></div>
<h2>向右、向下继续扩张</h2><p>相邻房间先约定同一个开口位置，再分别建造内部空间。靠近地图边缘时生成新行、新列；已生成房间保留原来的布局与镜像，新邻居接上预留接口。</p>
<p>门、活板门与玻璃窗继续使用原版物件。灯具和家具按办公室、维修间、仓储、居住等用途摆放，门口和梯口留出操作空间。</p>
<details><summary>画面来源与验证范围</summary><p>这些 PNG 来自原版 1.02 游戏实际渲染，没有重新绘制。整房图临时关闭玩家视野遮罩以统一曝光；游戏屏幕图保留原版光照和界面。彩框来自同一次生成的空间记录，可以关闭，不代表规定路线。空间结构仍偏向直角建筑，局部生活细节与破损形态仍有继续丰富的余地。</p><p><a href="assets/v8-spaces/manifest.json">截图原始清单</a> · <a href="../knowledge/experiments/generator-v8-validation-2026-09-13.md">实测结果与边界</a> · <a href="generator-v7-review.html">旧版评审页</a></p></details></main>
<script>const data=__DATA__;let selected=0,mode='room';const el=id=>document.getElementById(id),ns='http://www.w3.org/2000/svg';data.forEach((r,i)=>{const b=document.createElement('button');b.textContent=r.title;b.onclick=()=>{selected=i;render()};el('samples').append(b)});['room','stage'].forEach(m=>el(m).onclick=()=>{mode=m;render()});el('overlay').onchange=render;
function shape(tag,attrs){const n=document.createElementNS(ns,tag);for(const [k,v]of Object.entries(attrs))n.setAttribute(k,v);el('markers').append(n);return n}
function render(){const r=data[selected];[...el('samples').children].forEach((b,i)=>b.setAttribute('aria-pressed',i===selected));['room','stage'].forEach(m=>el(m).setAttribute('aria-pressed',m===mode));el('title').textContent=r.title+' · '+r.theme;el('description').textContent=r.volumes+' 个功能空间，'+r.ports.length+' 处开放边口，内部 '+r.loops+' 个独立回环。门、梯子与局部平台决定空间之间的实际通行。';const src='assets/v8-spaces/'+r.case+'-'+mode+'.png';el('capture').src=src;el('capture').alt=r.title+'，'+(mode==='room'?'整房图':'游戏屏幕');el('full').href=src;el('figure').className=mode;el('caption').textContent=mode==='room'?'1920×1000 · 统一曝光的整房诊断视图。点击查看原图。':'1008×729 · 保留原版光照与界面。';el('markers').replaceChildren();el('markers').style.display=mode==='room'&&el('overlay').checked?'block':'none';r.spaces.forEach((s,i)=>{shape('rect',{x:s.x0*40+3,y:s.top*40+3,width:(s.x1-s.x0+1)*40-6,height:(s.floor-s.top+1)*40-6,fill:'none',stroke:'#70c9c0','stroke-width':3,'stroke-dasharray':'12 8'});shape('text',{x:s.x0*40+15,y:s.top*40+34,fill:'#c2fff1','font-size':26}).textContent=String(i+1)});r.ports.forEach(p=>{shape('circle',{cx:Math.max(24,Math.min(1896,p.x)),cy:Math.max(24,Math.min(976,p.y)),r:19,fill:'#eabb69',stroke:'#302913','stroke-width':3})})}render();</script></html>'''
    output=MOD/'design/generator-v8-review.html'
    page=page.replace('处开放边口','处预留边口').replace('彩框来自同一次生成的空间记录，可以关闭，不代表规定路线。',
        '单房展示暂时封闭外边缘；金色点表示生成时预留的接口。彩框来自同一次生成的空间记录，可以关闭，不代表规定路线。')
    page=page.replace('<h2>向右、向下继续扩张</h2>',
        '<h2>从四边进入同一间房</h2><p>这间 F1 实机样本有四个实际开放边口，上下错开，左右位于不同高度。角色从四边逐一离开、返回，并在每次进入后走遍内部空间；33 个目标全部通过。</p>'
        '<figure><div class="frame"><img loading="lazy" src="../knowledge/experiments/generator-v8-evidence/multi-entry-f1/rrstyle-smoke-f1-room.png" alt="四方向边口实际开放的 F1 房间"></div><figcaption>原版游戏中的实际 F1 房间；绿色箭头为游戏自己的跨房标记。</figcaption></figure>'
        '<h2>向右、向下继续扩张</h2>')
    page=page.replace('已生成房间保留原来的布局与镜像，新邻居接上预留接口。',
        '已生成房间保留原来的布局与镜像，新邻居接上预留接口。实测从 5×5 扩张到 8×8，实际走进新列、新行并返回，原来 25 间房保持不变；64 间房的接口检查零问题。')
    output.write_text(page.replace('__DATA__',json.dumps(data,ensure_ascii=False)).replace('__GRAPHS__',str(stats['new']['connectivity_types_lower_bound'])),encoding='utf-8')
    print(output)

if __name__=='__main__': main()
