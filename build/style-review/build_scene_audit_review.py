"""Readable native-image comparison. Image bytes are never modified."""
from html import escape
from pathlib import Path

MOD = Path(__file__).resolve().parents[2]
DESIGN = MOD / 'design'
sections = [
    ('plant', '工厂', '生产大腔、装卸仓库、设备侧翼',
     '高窗和承重梁围绕作业空间，机器与控制附室分工。仍有过大的空白墙面，需要继续优化设备与楼板关系。',
     [(0, '原版车间'), (1, '原版仓库'), (2, '原版专用竖向设施')],
     [('v11-three-scenes-first', 'v11-three-scene-forms', 0, '开发：生产车间'),
      ('v11-three-scenes-first', 'v11-three-scene-forms', 1, '开发：装卸仓储'),
      ('v11-three-scenes-first', 'v11-three-scene-forms', 2, '开发：设备侧翼')]),
    ('stable', '废弃避难厩', '生活舱、公共中庭、技术区',
     '金属内壁按用途分带，生活与医疗设施集中；公共廊服务多个小空间。斜楼梯采用原版金属型式。',
     [(3, '原版办公区'), (4, '原版公共厅'), (5, '原版技术区')],
     [('v11-three-scenes-first', 'v11-three-scene-forms', 3, '开发：生活舱与公共廊'),
      ('v11-three-scenes-first', 'v11-three-scene-forms', 5, '开发：中庭与侧翼'),
      ('v11-three-scenes-first', 'v11-three-scene-forms', 4, '开发：维修与服务区')]),
    ('sewer', '下水道', '干管网、泵房、真实蓄水区',
     '允许没有水的检修房；大池上方保留干路，管线、排水口和池岸关联。深池已调整，部分干房和泵房仍偏空旷。',
     [(6, '原版干管网'), (7, '原版泵管厅'), (8, '原版蓄水池')],
     [('v11-sewer-refined', 'v11-sewer-refined', 1, '开发：干燥检修区'),
      ('v11-sewer-refined', 'v11-sewer-refined', 3, '开发：泵房与小池'),
      ('v11-sewer-refined', 'v11-sewer-refined', 2, '开发：深蓄水池'),
      ('v11-sewer-refined', 'v11-sewer-refined', 0, '开发：沟渠与上方检修廊')]),
    ('mane', '城市废墟', '原版参考；地图组织待决定',
     '原版把完整楼内、街巷与屋顶放到整张地图上组织。城市生态已经修正；空间分支仍待 Q2，下面只展示原版，不能视为新城市效果。',
     [(9, '原版食堂'), (10, '原版坍塌空间'), (11, '原版办公室')], [])]

def picture(directory, stem, index, title):
    relative = f'assets/{directory}/rrstyle-{stem}-{index}-room.png'
    assert (DESIGN / relative).is_file(), relative
    return f'<figure><a href="{relative}" target="_blank" rel="noopener"><img src="{relative}" alt="{escape(title)}" loading="lazy" width="1920" height="1000"></a><figcaption>{escape(title)} · 点击查看原图</figcaption></figure>'

parts = []
for key, title, sub, note, natives, generated in sections:
    refs = ''.join(picture('native-scenes-2026-09-20', 'native-scene-examples', n, t) for n, t in natives)
    samples = ''.join(picture(d, s, n, t) for d, s, n, t in generated)
    parts.append(f'<section id="{key}"><p class="eyebrow">{escape(sub)}</p><h2>{title}</h2><p>{note}</p>'
                 f'<div class="compare"><div><h3>原版空间</h3>{refs}</div><div><h3>开发版空间</h3>'
                 f'{samples or "<p class=notice>城市地图组织尚未修改。本轮不展示旧城市图冒充改进。</p>"}</div></div></section>')

page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>RandomRooms · 原版场景调查与开发样本</title><style>
:root{color-scheme:dark;font-family:system-ui,"Microsoft YaHei",sans-serif;background:#141817;color:#e3e9e4}body{margin:0}main{max-width:1540px;margin:auto;padding:48px 32px}h1{font-size:clamp(28px,4vw,46px);line-height:1.2;margin:12px 0 22px}h2{font-size:30px;margin:8px 0}h3{font-size:16px;color:#9ec7a6;margin:20px 0}p{line-height:1.8;max-width:1000px;color:#b9c5bc}.eyebrow{color:#afd99c;font-size:13px;letter-spacing:.1em}.notice{padding:18px 24px;border-left:3px solid #c4a268;background:#232820}nav{display:flex;flex-wrap:wrap;gap:12px;margin:26px 0}nav a{padding:9px 18px;border:1px solid #4b604c;border-radius:7px}a{color:#c1e7b1;text-decoration:none}a:hover{text-decoration:underline}section{border-top:1px solid #38463c;margin-top:48px;padding-top:30px;scroll-margin-top:20px}.compare{display:grid;grid-template-columns:1fr 1fr;gap:22px}figure{margin:0 0 26px;background:#202723;border:1px solid #3b493e;border-radius:8px;overflow:hidden}img{display:block;width:100%;height:auto}figcaption{padding:12px 15px;font-size:13px;color:#bdcdbf}footer{border-top:1px solid #38463c;margin-top:32px;padding-top:18px;font-size:13px}@media(max-width:760px){main{padding:28px 15px}.compare{grid-template-columns:1fr}}
</style><main><p class="eyebrow">RANDOMROOMS / 2026.09.20 / 开发中</p><h1>让不同场景拥有自己的空间逻辑</h1>
<p>本轮核对了四类场景的192间外置原房、原版敌群解析与材质定义，并用原版游戏渲染参考和生成样本。普通共享素材保留，专属生态与用途分开。地形继续从零生成。</p>
<p class="notice">这是开发对照，尚未替换正式版。四类生态已修正；工厂、避难厩、下水道已有构造改进，并完成向右、向下扩张往返的实际行走测试。下水道必经路保持干燥，八格深池也已实测下水并返回干岸。城市地图组织等待选择，旧城市断层路线复测尚未通过；空旷区域仍需打磨，不能把本页视为风格验收完成。</p>
<nav><a href="#plant">工厂</a><a href="#stable">废弃避难厩</a><a href="#sewer">下水道</a><a href="#mane">城市废墟</a></nav>
''' + ''.join(parts) + '''<footer><p>这些是未重绘的原版渲染图。参考房与开发房并非一一复刻；独立展示时边口可能被游戏封闭。原版参考移除了通用敌人占位符，因此用来比较建筑与环境，不用于比较战斗密度。工厂与避难厩取第一轮完整房型；下水道取后续深池修订。</p><p><a href="native-scene-audit-2026-09-20.md">阅读原版调查依据</a> · 图像、房XML和运行清单保存在各自 assets 目录。</p></footer></main></html>'''
(DESIGN/'generator-v11-investigation.html').write_text(page, encoding='utf-8')
print('Written generator-v11-investigation.html; all 22 image paths exist.')
