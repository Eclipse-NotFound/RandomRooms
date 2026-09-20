"""Build a local comparison from frozen native renders and verified XML only."""
from html import escape
import json
from pathlib import Path
import xml.etree.ElementTree as ET
import zipfile

MOD=Path(__file__).resolve().parents[2]
DESIGN=MOD/'design'
with zipfile.ZipFile(MOD/'knowledge/experiments/generator-v11-evidence/batch-density-dev13.zip') as z:
    stats=json.loads(z.read('v11-density-comparison.json'))['scenes']
    city=ET.fromstring(z.read('generated-v11-density-fifth-map.xml'))
    equivalence=json.loads(z.read('v11-density-image-equivalence.json'))
assert all(r['equal'] for r in equivalence['rooms'])
scenes=[
    ('plant','工厂','作业厅与配套附室',
     '参考原版车间、仓储与设备侧翼：保留机器作业空间，把控制、维修、存放等用途放进更小的附室。高窗与梁架集中在作业厅。',
     [(0,'原版车间'),(1,'原版仓储'),(2,'原版竖向设施')],[(0,'生产车间'),(1,'设备侧翼'),(2,'仓储厅')]),
    ('stable','废弃避难厩','公共廊与生活、技术房间',
     '参考原版办公、公共厅与技术区：公共廊连接多个生活间、厨房、办公室或医疗间；中庭仍保留较大公共空间，金属内壁与斜楼梯延续原版用途。',
     [(3,'原版办公区'),(4,'原版公共厅'),(5,'原版技术区')],[(3,'生活间与公共廊'),(4,'技术与服务房群'),(5,'中庭与附室')]),
    ('sewer','下水道','检修管网与蓄水设施',
     '参考原版干管网、泵管厅与蓄水区：缩小检修间，增加设备和储物附室；连续管线与排水口围绕真正的水体，保留干路和有用途的大池。大池不计为普通小房。',
     [(6,'原版干管网'),(7,'原版泵管厅'),(8,'原版蓄水区')],[(6,'水渠与检修廊'),(7,'干燥检修房群'),(8,'蓄水池与设备附室'),(9,'泵房与小池')]),
    ('mane','城市废墟','楼内、街巷与屋顶共同组成街区',
     '按已确认的城市方案组织整张地图：建筑横跨相邻合成房，街巷分隔建筑，顶层承担屋顶。楼内分别形成住宅、办公、商业和坍塌空间，不再要求每间都包含室内外。',
     [(9,'原版食堂'),(10,'原版坍塌空间'),(11,'原版办公室')],[(10,'坍塌楼内'),(11,'商业与储物区'),(12,'住宅与厨房'),(13,'屋顶及下方设备层'),(14,'办公楼内'),(15,'街巷与两侧建筑')])]

def picture(directory,stem,index,title):
    p=f'assets/{directory}/rrstyle-{stem}-{index}-room.png'
    assert (DESIGN/p).is_file(),p
    return f'<figure><a href="{p}" target="_blank"><img src="{p}" alt="{escape(title)}" loading="lazy" width="1920" height="1000"></a><figcaption>{escape(title)} · 点击查看原图</figcaption></figure>'

rows=[];sections=[]
for key,title,sub,note,refs,examples in scenes:
    s=stats[key];a=s['before'];b=s['after']
    rows.append(f'<tr><th>{title}</th><td>{a["meanGeneratedVolumes"]} → <strong>{b["meanGeneratedVolumes"]}</strong></td><td>{a["medianFunctionalArea"]:g} → {b["medianFunctionalArea"]:g} 格²</td></tr>')
    native=''.join(picture('native-scenes-2026-09-20','native-scene-examples',i,t) for i,t in refs)
    new=''.join(picture('v11-density-dev12','v11-density-final-forms',i,t) for i,t in examples)
    sections.append(f'<section id="{key}"><p class="eyebrow">{sub}</p><h2>{title}</h2><p>{note}</p><div class="compare"><div><h3>对应原版参考</h3>{native}</div><div><h3>本轮生成结果</h3>{new}</div></div></section>')

labels={'rooftops':'屋顶','street_links':'街巷','apartments':'住宅','offices':'办公','commercial':'商业','ruined':'坍塌楼内'}
rooms=sorted(city.findall('room'),key=lambda r:(int(r.get('y')),int(r.get('x'))))
cells=[]
for r in rooms:
    title=f'{r.get("x")},{r.get("y")} · 建筑组 {r.get("rrBlock")} · {labels[r.get("rrForm")]}'
    cells.append(f'<div class="cell {r.get("rrDistrict")}" title="{title}"><b>{labels[r.get("rrForm")]}</b><small>{r.get("x")},{r.get("y")}</small></div>')

page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>RandomRooms · 对应原版的房间尺度与场景设计</title><style>
:root{color-scheme:dark;font-family:system-ui,"Microsoft YaHei",sans-serif;background:#151a18;color:#e4eae5}body{margin:0}main{max-width:1540px;margin:auto;padding:44px 28px}h1{font-size:clamp(28px,4vw,44px);margin:10px 0 20px}h2{font-size:29px;margin:8px 0}h3{font-size:17px;color:#bed8b8}p{line-height:1.8;color:#bcc8c0;max-width:1100px}.eyebrow{color:#aace9a;font-size:13px;letter-spacing:.08em}.notice{border-left:3px solid #c3a16e;padding:16px 23px;background:#282c24}a{color:#c8e2b6}nav{display:flex;gap:18px;flex-wrap:wrap;margin:26px 0}.compare{display:grid;grid-template-columns:1fr 1fr;gap:22px}section{margin-top:46px;padding-top:26px;border-top:1px solid #3f4b42}figure{margin:0 0 24px;background:#222a24;border:1px solid #3f4b42;border-radius:8px;overflow:hidden}img{width:100%;height:auto;display:block}figcaption{padding:12px;font-size:13px;color:#c6d0c8}table{width:100%;max-width:920px;border-collapse:collapse;margin:24px 0}td,th{padding:13px;text-align:left;border-bottom:1px solid #3f4b42}thead{color:#aace9a}.map{display:grid;grid-template-columns:repeat(8,minmax(65px,1fr));gap:5px;min-width:560px}.scroll{overflow:auto}.cell{background:#354746;padding:15px 6px;text-align:center;border:1px solid #556968;border-radius:4px}.cell small{display:block;color:#b5c3be;margin-top:5px}.cell.roof{background:#605b3e}.cell.street{background:#242d35;border-color:#596770}.muted{font-size:13px}footer{margin-top:36px;border-top:1px solid #3f4b42;padding-top:20px}@media(max-width:760px){main{padding:25px 14px}.compare{grid-template-columns:1fr}th,td{padding:10px 5px;font-size:13px}}
</style><main><p class="eyebrow">RANDOMROOMS / v11.1 开发对照 / 2026.09.20</p><h1>每间合成房，容纳更多有用途的房间</h1>
<p>按对应原版场景调整空间尺度、功能分隔和家具组合。工厂保留作业厅，避难厩增加生活与技术房间，下水道围绕管网和水体组织，城市以完整街区分工。以下均为原版游戏渲染，没有重绘素材或复制原版地形。</p>
<p class="notice">这是 v11.1 开发成果对照，正式入口仍为 v10，尚未部署。192间生成房的结构与场景检查、四类场景扩张往返，以及100房807个探索物体的创建和交互检查已通过。通行结果对应实际测试种子；局部空墙、狭长空间及城市屋顶边框仍可继续打磨。</p>
<nav><a href="#plant">工厂</a><a href="#stable">废弃避难厩</a><a href="#sewer">下水道</a><a href="#mane">城市废墟</a><a href="#city-map">整张城市地图</a></nav>
<table><thead><tr><th>场景</th><th>每间合成房的内部空间数（平均）</th><th>普通功能房面积（中位数）</th></tr></thead><tbody>'''+''.join(rows)+'''</tbody></table>
<p class="muted">同一组种子，每类32间；比较本轮前的 v11 开发版与本轮结果。内部空间数包含走廊、作业厅等规划空间；普通功能房面积排除作业厅、仓库、公共厅、水池、街巷和屋顶。这不是原版作者的房间数量统计，也不是保证每个随机房达到同一密度。</p>
<section id="city-map"><h2>城市先组成街区，再安排楼内房间</h2><p>下图读取实际生成的8×8地图。每格是一间合成房：褐色为屋顶，深色为街巷，其余为建筑内部。相邻建筑内部延续用途，向下扩张保留原街巷位置；每格内部仍独立生成。此图表示用途分布，不是游戏截图。</p><div class="scroll"><div class="map">'''+''.join(cells)+'''</div></div></section>'''+''.join(sections)+'''<footer><p>图像来自同一轮16种完整房型。后续收紧斜楼梯通行检查后，逐项核对这16间的地形、物体、属性与布局记录仍与候选一致（忽略 XML 属性顺序与缩进）。单房整图不包含全部独立远景层；城市街巷和屋顶的实际屏幕应与整图分别判断。</p><p>原版参考来自四类场景192间外置房的调查；没有把开发规划空间数冒充原版房间数。<a href="native-scene-audit-2026-09-20.md">调查依据</a> · <a href="generator-v11-investigation.html">上一阶段实景</a> · <a href="../knowledge/experiments/generator-v11-density-validation-2026-09-20.md">本轮验证记录</a></p></footer></main></html>'''
(DESIGN/'generator-v11-density-review.html').write_text(page,encoding='utf-8')
print('Built density comparison: 12 original + 16 generated game renders, 64 map cells; all image paths checked.')
