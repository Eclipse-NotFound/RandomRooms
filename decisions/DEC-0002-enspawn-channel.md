# DEC-0002 —— 敌人出生标记的通道与配比（2026-08-27）

状态: **已实施**（v5.4，离线 400 房验证 + 冒烟通过，待实机确认）

## 决策

1. **敌人出生标记走 ups 通道，不用 enspawn 通道**
   - 合成房 XML 放 `<obj id="enl1|enl2|enf1" code x y/>`（AllData 4931-4933：
     tip='up'，tipn=1/2/3，占地 1×1/2×2/1×1）。
   - 消费链（game-reference 1.02 fe/loc/Location.as）：解析 tip=up → `ups[n]` 桶
     （681-688）→ 生成期 kolEn 配额 + `space[].place` 过滤 + 随机
     `createUnit(tipEn[i])`（1060-1084）。
   - **不选 enspawn 标记**（tip=enspawn → addEnSpawn，914-934）：那条通道服务
     kolEnSpawn/kolEnHid（Land.as 1061-1126）的进入时/隐藏敌人语义，且房池语料
     显示它主要用于固定脚本房（prob/hql/post 等）；enl 标记才是随机战斗房的
     主通道（mane 270 个 / sewer 247 个 / stable 368 个）。
2. **生成数量/敌人类型不自行实现**——由 `Location.kolEn=[0,6,4,6,4,6]` 配额与
   `Land.tipEnemy`（按 land biom，Land.as 998-1022）按原版规则决定；
   random_rooms land 注入 biom=1、rr_showroom biom=0 已存在（RandomRoomsMod 1245/1311）。
   模组只负责按语料配比放标记。
3. **配比按语料分层名额（quota），不做采样权重**
   - 语料实测（658 房）：mane=31/52/17、sewer=21/36/43、plant=35/50/15、
     stable=28/49/23（enl1/enl2/enf1）。
   - 首版采样权重失败：enl2（2×2）找位失败率 ~40%，实际分布偏差达 30%；
     补偿权重收敛慢。改 quota 分层（随机舍入、失败名额不跨桶转移）后
     400 房最大偏差 2.4%。
4. **每房标记 3-4 基准**（quota 舍入后实际 2-5，均值≈3.5）——对齐语料均值 3.48。
5. **顺手修复 v5.1 遗留**：player 出生点从每-rect 一个改为房间级一个
   （语料实测每房 0.99 个 player）；player 与敌标记同用 rectUsed 全格占用表。

## 理由

- ups 通道让"什么怪、几只"完全复用原版 biome 逻辑，合成房无需敌人表，
  与"学规律不学内容"的教训线一致。
- 语料配比是"原版手感"的最直接代理指标；分层分配把配比变成结构保证而非概率期望。
- 距 player >=3 格（曼哈顿）：player 2×2 出生点旁不放标记，防开局即战。

## 影响

- RRSynth.placeRoomObjects 增加房间级放置段（rectUsed 数组平移占用表）；
- objFoot 显式登记 enl1/enf1（enl2 原有）；
- 离线校验 `build/synth-v54-verify.py`（数量/占地/距离/重叠/比例五不变式）。
- 展示馆（biom=0）敌人按 stable 组生成；dif=0 是否出怪由原版规则决定，不干预。
