"""Build the review from frozen, hash-verified engine captures; no drawn mockups."""
import json
from pathlib import Path

MOD = Path(__file__).resolve().parents[2]
ASSETS = MOD / 'design/assets/v7-1-fixtures'

def main():
    kinds = [
        ('atrium', '主厅与附室', '避难所', 'syn_120', '两侧附室围绕主厅，平台连接上下用途区。'),
        ('workshop', '工坊与斜坡', '下水道', 'syn_401', '高厅、斜坡和低层仓储连在一起，工作台与工具柜成组放置。'),
        ('offices', '分层办公室', '工厂', 'syn_513', '中央梯井连接三层，办公、休息和仓储各有自己的空间。'),
        ('damaged', '损毁大厅', '城市', 'syn_832', '连续墙体中留下破损空间，以平台和斜坡保留通行路线。'),
        ('service', '维修与控制室', '避难所', 'syn_0', '两侧梯子连接维修层，中间控制设施位于完整的工作间内。'),
        ('warehouse', '仓库与夹层', '下水道', 'syn_257', '货架成列放置，上层仓储与侧边管理间由梯子连接。'),
    ]
    data = [dict(kind=k, title=t, theme=b, room=r, text=s) for k,t,b,r,s in kinds]
    for i,row in enumerate(data):
        row['case'] = f'rrstyle-generated-v71-{i}'
        fixture = json.loads((ASSETS / f'{row["case"]}-fixtures.json').read_text(encoding='utf-8-sig'))
        if not fixture['passed']: raise ValueError(row['case'])
        row['fixtures'] = fixture['records']
        for mode in ('room','stage','hatch-open-stage'):
            path = ASSETS / f'{row["case"]}-{mode}.png'
            if not path.is_file(): raise FileNotFoundError(path)
    page = r'''<!doctype html>
<html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>RandomRooms v7.1 · 门、活板门与玻璃窗</title>
<style>
:root{color-scheme:dark;font:16px/1.7 system-ui,"Microsoft YaHei",sans-serif;background:#111713;color:#e0e9df}
*{box-sizing:border-box}body{margin:0}main{max-width:1480px;margin:auto;padding:36px 24px 60px}
h1{font-size:clamp(27px,4vw,44px);line-height:1.2;margin:12px 0}h2{font-size:23px;margin:28px 0 8px}
p{max-width:960px;margin:8px 0 18px}.muted,figcaption{color:#a8b8a6;font-size:14px}.eyebrow{color:#b6d59a;letter-spacing:2px}
nav,.modes{display:flex;gap:8px;flex-wrap:wrap;margin:16px 0}button{font:inherit;padding:8px 16px;border:1px solid #42513d;border-radius:6px;background:#1c261f;color:inherit;cursor:pointer}
button[aria-pressed=true]{background:#c0d6a5;color:#152012;border-color:#c0d6a5}button:focus-visible,a:focus-visible{outline:3px solid #ebbd6e;outline-offset:3px}
figure{margin:0;padding:10px;border:1px solid #3a4938;border-radius:9px;background:#080d09}figure img{width:100%;display:block;border-radius:3px}figure.stage img{max-width:1008px;margin:auto}
.frame{position:relative}.markers{position:absolute;inset:0;pointer-events:none}.marker{position:absolute;border:2px solid #f3c779;box-shadow:0 0 0 1px #111}.marker span{position:absolute;left:0;bottom:100%;white-space:nowrap;background:#171d16ed;color:#f3c779;font-size:12px;padding:0 4px}.marker.window{border-color:#87d9e6}.marker.window span{color:#87d9e6}.marker.hatch{border-color:#c2a2fc}.marker.hatch span{color:#c2a2fc}.legend{display:flex;align-items:center;gap:8px;margin-bottom:12px}.legend input{width:18px;height:18px}.stage .markers{display:none}
figcaption{padding:10px 4px 2px}a{color:#c6dea9}.facts{display:flex;gap:12px;flex-wrap:wrap;margin:24px 0}.fact{flex:1;min-width:190px;background:#1a251d;padding:14px 18px;border-left:3px solid #94b179}
.fact strong{display:block;font-size:26px;color:#d3e5bb}.comparison{display:grid;grid-template-columns:1fr 1fr;gap:12px}.comparison img{width:100%}details{margin-top:28px;border-top:1px solid #3a4938;padding-top:12px}summary{cursor:pointer}
@media(max-width:720px){main{padding:20px 12px}.comparison{grid-template-columns:1fr}}
</style>
<main><div class="eyebrow">RANDOMROOMS / SPACE v7.1 / 2026.09.10</div>
<h1>门、活板门与玻璃窗，接入建筑空间</h1>
<p>附室入口加入原版门，梯子穿过楼层的位置加入活板门，隔墙加入真正有玻璃的窗户。按主题选用金属门、木门和装甲玻璃；通行用的门与活板门都可直接打开。以下六间是更新后在原版游戏中的真实画面。</p>
<nav id="kinds" aria-label="选择房型"></nav><h2 id="title"></h2><p id="description"></p>
<div class="modes" aria-label="选择查看方式"><button id="room" aria-pressed="true">查看整间建筑</button><button id="stage" aria-pressed="false">查看游戏屏幕</button><button id="hatch-open-stage" aria-pressed="false">查看掀开活板门后</button></div>
<label class="legend"><input type="checkbox" id="show-markers" checked>标出门、活板门与玻璃窗的位置（整房图）</label>
<figure id="figure"><div class="frame"><a id="full" target="_blank" rel="noopener"><img id="capture" alt=""></a><div id="markers" class="markers"></div></div><figcaption id="caption"></figcaption></figure>
<div class="facts"><div class="fact"><strong>1,088 间</strong>1,024 普通房 + 64 连接竖井，均有门、活板门和玻璃窗，通过尺寸、支撑与通路检查。</div><div class="fact"><strong>6 / 6 房型</strong>角色从出生点走到梯子，用行动键掀开活板门，实际爬上对应楼层。</div><div class="fact"><strong>原版交互</strong>实测开关改变碰撞；玻璃受损破碎后清除碰撞。背景窗装饰也继续保留。</div></div>
<h2>扩张也遵循同一套建筑连接</h2><p>靠近边缘时提前生成下一列或下一行；竖井定期出现并向下延续。原来封住的地图边缘会恢复梯子和开口，新增房间拥有完整物件与地图记录。F4 仍可进入新的深度层。</p>
<h2>与原版、旧版放在一起看</h2><div class="comparison"><figure><img loading="lazy" src="assets/prototypes-2026-09-10/rrstyle-original-room.png" alt="原版13号房"><figcaption>原版 13 号房 · 整房诊断视图</figcaption></figure><figure><img loading="lazy" src="assets/prototypes-2026-09-10/rrstyle-baseline-room.png" alt="旧v6.6随机房样本"><figcaption>旧 v6.6 样本 · 整房诊断视图</figcaption></figure></div>
<p class="muted">当前仍只有六类普通布局，部分结构会反复出现。材质与用途已经连贯；更多独特空间和更细的破损、生活痕迹仍可继续扩充。</p>
<details><summary>画面来源与验证范围</summary><p>原版 1.02 游戏渲染；固定案例移除了敌人，用正常出生和旅行建立房间。整房图暂时关闭玩家视野遮罩以统一曝光，游戏屏幕图保留正常光照与界面。彩框来自运行中物件的实际坐标，可以关闭；原始 PNG 没有添加标记。</p><p>六房覆盖六房型与四主题。初始截图在测试开关、破坏玻璃之前保存；活板门打开后的截图来自随后真实移动。玻璃破碎采用原版伤害函数，未做逐种武器射击测试。扩张测试使用受击保护隔离战斗消耗，未改玩家坐标；目前未验证极长时间扩张的资源上限或联机。</p><p><a href="assets/v7-1-fixtures/manifest.json">本轮六型原始清单</a> · <a href="../knowledge/experiments/fixtures-v71-validation-2026-09-10.md">门窗测试与发布记录</a> · <a href="../knowledge/experiments/style-generator-validation-2026-09-10.md">v7.0 建筑与扩张记录</a> · <a href="style-review-2026-09-10.html">先前 A/B/C 原型对照</a></p></details></main>
<script>
const data=__DATA__;let selected=0,mode='room';
const byId=id=>document.getElementById(id);
data.forEach((row,i)=>{const b=document.createElement('button');b.textContent=row.title;b.onclick=()=>{selected=i;render()};byId('kinds').appendChild(b)});
const modes=['room','stage','hatch-open-stage'];modes.forEach(m=>byId(m).onclick=()=>{mode=m;render()});byId('show-markers').onchange=render;
function render(){const row=data[selected];Array.from(byId('kinds').children).forEach((b,i)=>b.setAttribute('aria-pressed',i===selected));modes.forEach(m=>byId(m).setAttribute('aria-pressed',m===mode));byId('title').textContent=row.title+' · '+row.theme;byId('description').textContent=row.text;const src='assets/v7-1-fixtures/'+row.case+'-'+mode+'.png';byId('capture').src=src;byId('capture').alt=row.title+'，'+(mode==='room'?'整房诊断图':'真实游戏屏幕');byId('full').href=src;byId('figure').className=mode==='room'?'room':'stage';byId('caption').textContent=row.room+' · '+(mode==='room'?'1920×1000，统一曝光的整房诊断视图。点击查看无标记的原图。':mode==='stage'?'1008×729，保留原版光照和界面。':'用行动键打开梯口活板门并爬至上方，保留原版光照与界面。');const markers=byId('markers');markers.replaceChildren();markers.hidden=!byId('show-markers').checked;for(const f of row.fixtures){const e=document.createElement('div');e.className='marker '+f.role;e.style.cssText=`left:${(f.x-f.width/2)/1920*100}%;top:${(f.y-f.height)/1000*100}%;width:${f.width/1920*100}%;height:${f.height/1000*100}%`;const label=document.createElement('span');label.textContent={door:'门',hatch:'活板门',window:'玻璃窗'}[f.role];e.appendChild(label);markers.appendChild(e)}}
render();
</script></html>'''
    output = MOD / 'design/generator-v7-review.html'
    output.write_text(page.replace('__DATA__',json.dumps(data,ensure_ascii=False)),encoding='utf-8')
    print(output)

if __name__ == '__main__': main()
