# RandomRooms —— 开发日志

> 协议见 GOVERNANCE.md §8：只追加不改写，**新条目插在最上面**。

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
