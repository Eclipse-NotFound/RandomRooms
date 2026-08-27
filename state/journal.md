# RandomRooms —— 开发日志

> 协议见 GOVERNANCE.md §8：只追加不改写，**新条目插在最上面**。

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
