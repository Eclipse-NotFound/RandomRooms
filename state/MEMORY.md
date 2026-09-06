# RandomRooms —— 开发记忆入口

> 新会话从这里开始。协议见工作区 GOVERNANCE.md §8；本模组参数见 ../AGENT_SCOPE.md。

## 1. 这个模组是什么

在随机土地（如马哈顿废墟）中**程序化合成结构合理的房间**：干净矩形房间 + 走廊网络 + 材质带 + 物件摆放，替代原版的模板拼贴感。技术形态：AS3 模组（入口类 `RandomRoomsMod`）+ Python 离线验证脚本 + FFDec loader 部署进 pfe.swf（loader 已就位；日常部署=覆盖 release SWF+重启）。

## 2. 用户偏好与协作约定

- 实测工作流固定：改代码 → `bash build/build-m0.sh` 编译 → 用户重启游戏 → **F2 回城 → F5 进展示馆** → 读 `%APPDATA%/pfe/Local Store/RandomRooms_diag.log`（前缀 `[RR:0.0.1-M0]`，grep -a）。
- 热键已占用：F1/F2/F3/F4/F5/F7；**F8/F9 被其他模组占用，不可用**。
- 范围约定（DEC-0001）：v1 = P0+P1；种子与联机同步延后。
- **术语约定（2026-08-28 与用户对齐，一切交流/文档必须遵守）**：
  - **土地** = 一次 gotoLand 进入的完整世界（4×3 / 5×5）；
  - **合成房** = 土地格上放的 25×48 房间单元（Room XML，syn_N）——房池抽样单位；
  - **房间** = 合成房**内部**被竖隔断切出的房间结构（实现里的段/rects）；
  - **通道** = 合成房**内部**连接房间/层之间的结构（墙带洞、隔断门口）。
  - 历史反馈重映射：v5.4"通道窄/被堵"=通道；v5.8"房间分割机械/只有一堵墙"=房间
    之间的竖隔断；"房间之间没有通道"=**合成房之间**（跨土地格）无通道——
    走不到隔壁合成房。
- 自动测试用独立 appId 实例（app_rr_test.xml，id=pferrtest；AIR appId 不许下划线），跑完杀进程+删描述符；注意其他模组 agent 会在游戏根目录并行开自己的测试实例（如 app_rvision_test_*），绝不动。

## 3. 当前状态

- 部署版本 **v6.6**——SWF 已部署，待实机复评。
- **v6.6 = 横版认知革命**（六证据确认本作是横版平台游戏，结构语义全面反转：
  墙带=地板、左右边=唯一通道、"悬空"=脚下无实体）。四连锁 bug 修复（隧道旁格
  打穿底边/footOk wid 语义/物件先于修复放置/采样 off-by-one）+ hasGround 脚下
  校验 + 左右边界重做 + T/B 全实体。**32 房终检全绿**：悬空 0、player 恢复、
  门 0.88/房、弹回率 7%、底边穿透 0。日志 TAG 已版本化 [RR:v6.6]。
- **视觉自检闭环已建**（v6.5）：测试实例 auto_enter.txt 标记→自动进展示馆；
  refreshLandPool dump 全部 32 合成房 XML 到日志；build/render_dump.py 离线
  渲染+合规分析。**32 房实测：物件悬空 0、hatch2 0.63/房、结构合规**——
  bookcase 室内撒点漏网段已删（悬空主源）。
- v6.2/v6.3 教训固化：通行结构改动先过玩家 2×2 通行断言；"加新路径"与
  "删旧路径"必须同 commit 成对。
- v6.4 = 通道问题最终根因修复：**跨合成房是"像素撞边→目标房同高度进入，
  collisionUnit 碰撞即弹回"**（Unit.outLoc→Land.gotoLoc 反编译实证）；合成房
  整墙边界（左右开放率 4% vs 原版 35%）=几乎处处弹回+无可见缺口。边界改原版式
  开放段（L/R 2 段、T 2 段、B 保守 1 段）+逐位贯通隧道；离线断言开放位 8.6/25
  ≈原版 8.7。
- v6.3：门重做为原版墙顶模式（语料实证门 100% 站墙带顶部非嵌竖墙——修"孤立
  栅栏"）、wallSpot 背墙校验（修浮空）、**缺口贯通隧道**（6 缺口向内 2 宽×≤7，
  修合成房之间无通道）、缺口检查日志路径修复。离线三最坏结构断言+冒烟通过。
- v6.2 回滚根因：门洞收窄 1 格玩家 2×2 不可过 + 敞开口 wallW=1 时不执行 →
  70% 隔断死墙 → 玩家锁在首个开放层 →"房型固定为一种"。**教训：改通行结构
  必须先过玩家 2×2 通行断言**。背墙校验/墙材质统一/缺口检查路径修复待重做。
- v6.1：**修门/活板门从未生成的 bug**（per-rect 过滤跳过隔断列/墙带行上的全部
  门口洞位，自 v5.6 起）；back 距墙收紧 ≤2；**LAYER_PROFILES 层界库**（原版 23 条
  真实组合加权抽样，含通高/浮中层/蜂窝）；checkpoint 记录点入词表；列区边界多样化。
- v6.0 分层语法原版化（语料三项实证驱动）：层数按原版分布（1 层通高占 31%——
  此前从不生成）、层界非均分、40% 双列区同房混合分层、层间主洞 40% 出 hatch2
  活板门、锚池移除 locker（墙柜站中央=悬空）、obj 脚下实证放宽纹理白名单。
- 演进：v5.6 分层大厅（DEC-0003）→ v5.7 反均匀（DEC-0004）→ v5.8 SAFE_FLOOR
  白名单+墙体形态 → **v5.9**：
  - **back 贴墙采样**（原版 84% back 距墙≤3 格实证；大厅中央撒 back=悬空主源）；
  - markUsed 全格占用（消物件视觉穿模）；
  - 通道强化：主洞 4-5 宽/次洞 3 宽 + GX 列对齐十字洞（60%）；
  - 物件谱系：+hatch2(2×1)/wallcab/medbox/trash/bed(4×1)。
- 冒烟通过。**卡点：loc 间通行机制未定案**——verifyEntry 已加缺口贯通检查日志
  （`缺口贯通: L=3 R=2 T1=X ...` 格式，数字=向房内开放深度，X=被堵），
  下次实机日志可定位。

## 4. 正在进行与卡点

- 等 v6.0 实机复评（F5/F1）：①分层多样性（通高大堂/多层/双列区）；②**合成房
  之间**能否走通——**务必看日志"缺口贯通"行**（X=被堵；若全通但走不动则深挖
  gotoLoc 碰撞判定）；③门/活板门频率；④悬空残余（锚池已修）。

## 5. 已知问题

- back 装饰仍是每 rect 3-6 个；新范式 rect 是横向长条，back 密度可能偏高，待实机看。
- 竖隔断门口的"门"物件（stdoor/door1）70% 概率放置，视觉密度待实机调。
- 既有物件 used 只标锚点格（v5.2 行为）：1×1 物件可能视觉叠上多格物件覆盖格；en/锚段已全格标记，旧物件未动。
- v54 镜像脚本未同步锚阶段与个性密度（不变式由 footOk/used 机制 + 冒烟覆盖）。
- 空房率/密度区间是首版参数（6%、0.5-1.4），待实机体感调。
- 8/21 22:32 有一次游戏运行未产生模组日志（原因不明）；链路本身已实测健康。

## 6. 下一步（优先级排序）

1. v5.9 实机复评（F5/F1）——**缺口贯通日志一锤定音 loc 通行问题**；悬空（back）；
   新物件观感；
2. 视缺口贯通结果：若 X（被堵）→ 查哪个步骤堵缺口；若全通但玩家走不动 →
   深挖 gotoLoc 碰撞判定（可能需 mirror/玩家宽 2×2 语义）；
3. 灵性工程后续：进深序列、遭遇编排、稀有地标；
4. 种子/联机仍延后（DEC-0001）；构件级 WFC 远期；
5. 共享知识待办：Tile.dec 语义 + SAFE_FLOOR 白名单、ups/kolEn/tipEnemy、
   AllData 物件体系、房间内容统计、**back 贴墙 84% 实证**。

## 7. 深入了解

- **开发历程**：state/journal.md（v3.1→v5.9，每条=一个实机反馈闭环）
- **当前生成器 v6.6**：src/rr/RRSynth.as（横版语义：hasGround 脚下校验 + 单行占地 + 边界地板伸出 + 修复后放置）
- **设计**：design/room-soul-plan.md；design/generator-v5.md（v5 旧范式，待更新）
- **决策**：decisions/DEC-0001（范围）、DEC-0002（敌标记）、DEC-0003（分层大厅）、DEC-0004（反均匀路线）
- **关键实证**：knowledge/discoveries/alldata-materials-room-xml.md、
  knowledge/discoveries/room-content-statistics.md；
  SAFE_FLOOR 白名单 = AllData oForms ed=2 逐字符实证（journal v5.8 条目）；
  back 距墙分布 = 84% ≤3 格（journal v5.9 条目）
- **工具链（2026-08-27 打通，全部实测）**：
  - 编译：`bash build/build-m0.sh`（mxmlc=flexsdk 4.16.1，Java=Animate 2024 JRE，配置=build/rr-config.xml；**勿用 amxmlc 直编**，air-config 的 {airHome} 令牌已失效）
  - SDK 全套：`D:\RemainsMod\mods\Sandevistan\build\tools\`（flexsdk+airsdk+ffdec）
  - Python（离线验证）：`C:\Users\hello\Documents\_sandevistan_dev\python3\python.exe`
  - 结构诊断：`build/diag-skeleton.py`（开放率/连通/rects 量化）；物件验证 `build/synth-v54-verify.py`（用前 rm -rf build/__pycache__）
  - 语料 `Rooms/rooms_*.xml`（658 房，player 0.99/房、敌标记 3.48/房、墙占比 15-36%）
- **构建/部署/测试技能**：remains-mod-build、remains-swf-patching、remains-auto-testing
