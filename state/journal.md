# RandomRooms —— 开发日志

> 协议见 GOVERNANCE.md §8：只追加不改写，**新条目插在最上面**。

## 2026-08-28 v5.9：悬空第二根因（back 中央悬挂）+ 通道强化 + 物件谱系扩展

- 实机反馈：仍有悬空；"只有一堵墙"（同前）；房间间无通道只能 F7。
- 诊断进展：
  - **back 贴墙实证**：原版 25868 个 back 中 84% 距墙 ≤3 格（45% 贴墙 1 格内）——
    v5.7 起大空间中央撒 back = 灯/管道悬在半空，这才是"物品悬空"的主要视觉来源
    （SAFE_FLOOR 修的是另一层）。
  - **P0 变异器无罪**：F_GROUPS 全是墙材质组内互换（不改变开放状态）、边界保护、
    selfCheck 查首末行；后缀交换组（-ДЕКНР/ВГЖЗИЙЛМОПСТ）不含 SAFE_FLOOR 字符。
  - **diag v5.8 连通性**：28/1000 房缺口不可达（缺口孤立格）+ 玩家 2×2 过 2 宽洞
    是临界。层间洞加宽（主 4-5/次 3）+ GX 列对齐十字洞。
  - **仍未定案**：loc 间通行机制（gotoLoc 只查目标位置碰撞——缺口错配已由
    normalizeGaps 统一）——verifyEntry 新增**缺口贯通检查日志**（6 缺口向房内
    开放深度），下次实机日志一锤定音。
- 实施（v5.9）：
  - back 贴墙采样（距墙 ≤3 的开放格，对齐原版分布）；
  - markUsed 全格占用（消 1×1 叠多格物件的视觉穿模）；
  - 通道强化：主洞 4-5 宽/次洞 3 宽 + 60% 概率 GX1/GX2 列对齐十字洞；
  - 物件谱系：+hatch2(2×1 活板门)/wallcab/medbox/trash/bed(4×1)，objFoot 补全
    （AllData size/wid 实证）。
- 冒烟通过。待实机：悬空（back）/通道走通/新物件观感 + **缺口贯通日志**。

---

## 2026-08-28 v5.8：悬空根因修复（SAFE_FLOOR 白名单）+ 墙体形态与通道分化

- 实机反馈：物件悬空、房间间"大多只有一堵墙"、房间/通道无显著分化。
- **悬空根因**（v5.7 回归）：isOpenCell 放行一切 `_X` 纹理格，但 safeDecor 黑名单
  漏了西里尔 Е（ДЕКНР 横梁之一）→ `_Е` 格放物件=横梁上悬空。修复：
  1) SAFE_FLOOR 白名单（oForms ed=2 实证纯地板：B C F H L M N Q T W；排除墙背类
     A D E G I J P R U V X Y Z、网格 K、设施 O S）；
  2) safeDecor 改白名单制（黑名单制天然漏）；
  3) isOpenCell 的 `_X` 仅认 SAFE_FLOOR。
- **墙体形态**：层间墙带 1-2 行随机厚（动态层界）；竖隔断 1-2 格厚；
  层型三档每层独立抽（大厅 0 隔断 / 普通 1-2 / 蜂窝 3-4）→ 房间大小方差出
  "显著大厅"与"蜂窝小间"。
- **通道分化**：墙带洞分主次（主洞 3-4 宽，次洞 2 宽）；隔断门口分主次
  （主门口宽 3）。roomRects 估算适配隔断厚度。
- 冒烟通过。待实机：悬空是否绝迹、墙体厚度/大厅/蜂窝的形态观感、主通道可感性。
- 遗留：v54 镜像待同步（锚/个性/白名单）；generator-v5.md 待更新。

---

## 2026-08-28 灵性工程第一轮：反均匀（头脑风暴 → 归档 → 实施 v5.7）

- 头脑风暴（game-brainstorming 完整模式）：语料统计推翻直觉——原版物件组合近乎随机
  （共现提升度 1.2-1.5x）、同物件不成簇（最近邻≈随机期望）；**灵性在层不在点**：
  方差/分区/序列/锚点。归档 design/room-soul-plan.md + decisions/DEC-0004 +
  knowledge/discoveries/room-content-statistics.md（6e97711）。
- 实施 v5.7（第一刀全部 + 卡1 MVP + 卡2 MVP）：
  - 房间个性向量：空房率 6%（语料 1.5% 放宽）+ 密度系数 0.5-1.4；
  - 空房美学：仅结构+出生点（无物件/back/敌标记，安静房）；
  - 视觉锚：50% 房间先放锚池大件群（locker×3/mcrate2×4/table×2），其余物件退让；
  - 分区纹理：materialBands 按层主材质 + 每层 60% 出对比补丁区；
  - 墙面叙事：back 分 3 组（结构/设施/照明），60% 出主导组；
  - 装饰排/敌标记数量联动密度；isOpenCell 语义修复（物件/敌标记可放纹理格 `_X`，水面 `_*` 除外）。
  - 氛围 options：查明 Land 级已有（房级空=原版保真），无需改动。
- 冒烟通过（init/展示馆池 8 房/无 UNCAUGHT）。**待实机复评**：房间间方差是否可感知
  （空 vs 密对比）、锚点是否"记得住"、back 主导组观感。
- 遗留：v54 镜像脚本未同步锚阶段（不变式由 footOk/used 机制保证+冒烟覆盖）；
  进深序列/遭遇编排待下一轮；design/generator-v5.md 仍记 v5 旧范式。

---

## 2026-08-28 v5.6 范式更换：分层大厅（实机反馈：通道窄/被堵/水体怪）

- 实机证据：dump 墙数 685-788（57-66% 墙占比；原版语料 15-36%）。Python 镜像（build/diag-skeleton.py）复现并定位：
  1) 房间放置成功率低（三带+间距 2 挤压，placed 均值 5.4/目标 6-8）；
  2) 走廊网络退化（房间间距 ≤2 时"最近开放格"就是邻房，走廊净增量均值仅 19 格）；
  3) **装箱数学**：1200 格网格放 6-8 个中房+走廊，开放率天花板 ~45%——范式性缺陷，参数调不出来。
  大房方案试过更差（placed 暴跌 3.5）。原版真范式（语料行结构实证）：整层开放纹理带 × 1-2 行墙带交替 × 层内隔断。
- 做了什么（v5.6）：
  - **范式更换**：v5Skeleton 步骤 2-3 重写为分层大厅——2-3 开放层（1-11/13-23 或 1-7/9-15/17-23）× 层间 1 行墙带（2-3 个 2-3 宽洞，GY 行两端对齐缺口）× 层内竖隔断（1 格厚全层高，每道 1-2 个 3 高门口）。rtype 偏置层数（corridor/split 偏 3 层，hall 偏 2 层）。linkL2 走廊网络整体退役（函数保留未删）。
  - 量化：墙数 748→**216**（18%，入原版区间），全连通 100%，rects 均 6.3/房。
  - 水池改房间矩形内完整放置（v5.4 全图随机被墙切碎/压走廊）；口袋填墙阈值 16→6（防封通道残段）。
  - 门物件适配：门口高 3 容 stdoor/door1，lastDoorSpots 传递给 placeRoomObjects（70% 放置）。
  - Tile.dec 语义查明（本次最重要实证）：**格首字符只查 fForms（ed=1 拉丁 A-T 全是墙）；后续字符才走 oForms/`*`水/`,`;`:`Z 层**——`_X` 才是地板纹理，裸大写字符=墙；`K` 位置双语义（首字符=墙，后字符=网格地板）。
- 遗留/下一步：实机复评（通道/水体/门观感）；分层参数待体感调；Tile.dec 语义待沉淀 shared-knowledge；design/generator-v5.md 记的还是 v5 旧范式，待更新。

---

## 2026-08-27 v5.4 敌人出生标记 + player 房间级修复；本机工具链打通

- 做了什么：
  - 排查"v5.3 部署后无日志"疑团：测试实例（appId=pferrtest）实测**加载链健康**——loader/8.26 release SWF 均正常，疑当时日志被清或未走正常启动链；pfe.swf 无需重打。
  - v5.4 功能：合成房 XML 放 enl1/enl2/enf1 敌人出生标记，走原版 ups 通道；比例按语料配比 quota 分层；距 player>=3 格；同时修复 v5.1 遗留的 player 每-rect 重复（改为房间级 1 个）。
  - 离线验证 `build/synth-v54-verify.py` 400 房全过：每房 2-5 个（原版均值 3.48）、占地/重叠/距离零违规、桶比例与语料最大偏差 2.4%。
  - 编译部署 release/RandomRoomsMod.swf（v5.3 备份在同目录 _v53_backup.swf）；测试实例冒烟通过（展示馆 8 合成房生成无异常）。
  - **本机工具链打通**：SDK 全套在 `D:\RemainsMod\mods\Sandevistan\build\tools\`（flexsdk+airsdk+ffdec），Java 用 Animate 2024 JRE；`build/rr-config.xml` 显式 SWC 路径绕过 air-config {airHome} 令牌失效；build-m0.sh / deploy-pfe.sh 已更新为新路径；便携 Python 在 `C:\Users\hello\Documents\_sandevistan_dev\python3`。
- 关键决定/发现：（DEC-0002）
  - enl 标记走 **ups 通道**而非 enspawn 通道：Location.as tip=up 进 ups[tipn]（4931-4933：enl1/enl2/enf1=桶1/2/3，占地 1×1/2×2/1×1），消费在 1060-1084（kolEn 配额 + place 过滤 + createUnit(tipEn[i])）——生成数量与敌人类型由 kolEn/Land.tipEnemy 按 land biom **自动**决定，模组只放标记。
  - 采样权重法会比例失真（2×2 找位失败率约 40%），改 **quota 分层分配**（失败名额不跨桶转移）。
  - 语料实测：每房 player 0.99（v5.1 每 rect 放是 bug）、敌标记 3.48。
- 遗留/下一步：v5.4 实机评估（F5，与 v5.3 三修复一起看）；back 每-rect 口径未查；ups/kolEn/tipEnemy 机制待沉淀 shared-knowledge（并入既有 AllData 待办）。

---

## 2026-08-27 外置记忆迁移

- 由 current-status.md（交接快照，原文在 git 历史）拆分迁移：现行状态 → state\MEMORY.md；AllData 实证 → knowledge/discoveries/alldata-materials-room-xml.md；生成器流程 → design/generator-v5.md；演进史留在本文件下方历史块。
- 遗留：shared-knowledge 待办（tile-code-table.md 修订、AllData 物件体系沉淀）仍开放，见 MEMORY §6。

---

## 历史块：合成算法演进史（2026-08-21 快照时点，每条=一个实机反馈闭环）

| 版本 | 算法 | 实机反馈 → 教训 |
|---|---|---|
| v3.1 | 字段噪声+固定直线 roadWalls | 两个固定"模板"（corridor=双竖墙/hall=双横墙）→ 删直线 |
| v3.3 | 墙为底+开凿（fill-wall+carve） | 空/墙碎/通道堵 → 范式反转 |
| v3.4 | 直角规整房间+主廊折线 | 仍堵/墙多 → 学原版 |
| v3.5 | 原版分区墙（薄带+缺口） | 初步雏形但水/栅格碎片化 → 学原版物件 |
| v3.6 | 原版条带马尔可夫（48×4 条带库） | **拼贴感**（内容级复用）→ 学规律不学内容 |
| v4 | 行谱结构生成（PROFILE 逐行采样） | 混乱墙充填（谱是边际分布，勿逐行全填）→ 行二值化 |
| v4.3 | 锚点行=墙带 + 竖向墙柱 | 墙拼贴/水碎片 → AllData 材质表实证 |
| v5 | 房间-走廊骨架（显式房间+2宽L连廊） | 通道少/墙大 → 房间加大+双连接 |
| v5.1 | +物件生成（door/crates/sofa/back/player） | **物件悬空+孤立房间** → 三根因 |
| v5.3 | linkL2 下标错位修复+门朝房内+back 开放格 | **待实机评估** |

**教训线**：不要复刻内容（v3.6 条带=拼贴）；谱是边际分布不能每行全填（v4）；物件必须校验占地格（v5.1 悬空）；走廊 linkL2 必须排除目标房间且房间/矩形下标同步（v5.3 孤立房间）；back 元素原版 85% 放在开放格（v5.3 悬空）。

## 更早期（M0/P0/P1 阶段，2026-08-17~18）

- 部署管线与注入点验证（M0）、P0 变体注入刷新、P1 种子与随机房——实验记录见 knowledge/experiments/（m0-deploy-pipeline-validation、m0-injection-points-verified、p0-mutation-entry-refresh-verified、p1-seed-and-random-rooms-verified）。
- 算法演进从 v3.1 起有记录；v1-v2 原型期（日期不详）细节见 git 历史与 design/random-room-synthesis-v3.md。
