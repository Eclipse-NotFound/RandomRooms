# RandomRooms —— 开发记忆入口

> 新会话从这里开始。协议见工作区 GOVERNANCE.md §8；本模组参数见 ../AGENT_SCOPE.md。

## 1. 这个模组是什么

在随机土地（如马哈顿废墟）中**程序化合成结构合理的房间**：干净矩形房间 + 走廊网络 + 材质带 + 物件摆放，替代原版的模板拼贴感。技术形态：AS3 模组（入口类 `RandomRoomsMod`）+ Python 离线验证脚本 + FFDec loader 部署进 pfe.swf（loader 已就位；日常部署=覆盖 release SWF+重启）。

## 2. 用户偏好与协作约定

- 实测工作流固定：改代码 → `bash build/build-m0.sh` 编译 → 用户重启游戏 → **F2 回城 → F5 进展示馆** → 读 `%APPDATA%/pfe/Local Store/RandomRooms_diag.log`（前缀 `[RR:0.0.1-M0]`，grep -a）。
- 热键已占用：F1/F2/F3/F4/F5/F7；**F8/F9 被其他模组占用，不可用**。
- 范围约定（DEC-0001）：v1 = P0+P1；种子与联机同步延后。
- 自动测试用独立 appId 实例（app_rr_test.xml，id=pferrtest；AIR appId 不许下划线），跑完杀进程+删描述符；注意其他模组 agent 会在游戏根目录并行开自己的测试实例（如 app_rvision_test_*），绝不动。

## 3. 当前状态

- 部署版本 **v5.8**——release/RandomRoomsMod.swf 已更新，**待实机（F5）复评**。
- v5.6 分层大厅范式（DEC-0003）→ v5.7 灵性工程第一轮（DEC-0004 反均匀：
  房间个性向量/视觉锚/分区纹理/墙面叙事）→ **v5.8 修复**：
  - **悬空根因修复**：safeDecor 黑名单漏西里尔 Е（横梁）→ `_Е` 格放物件悬空。
    改 SAFE_FLOOR 白名单（B C F H L M N Q T W，oForms 实证纯地板）+ isOpenCell
    白名单制 + safeDecor 白名单制。
  - 墙体形态：墙带 1-2 行随机厚、隔断 1-2 格厚、层型三档每层独立
    （大厅 0 隔断/普通 1-2/蜂窝 3-4）——修"永远一堵薄墙"的机械感。
  - 通道分化：墙带主洞 3-4 宽/次洞 2 宽；主门口 3 宽/次门口 2 宽。
- 冒烟通过（展示馆 8 房生成无异常）。

## 4. 正在进行与卡点

- 等 v5.8 实机复评（F5）：①悬空是否绝迹；②墙体厚度/大厅/蜂窝形态观感；
  ③主通道可感性；④v5.7 的方差/锚点一并看。

## 5. 已知问题

- back 装饰仍是每 rect 3-6 个；新范式 rect 是横向长条，back 密度可能偏高，待实机看。
- 竖隔断门口的"门"物件（stdoor/door1）70% 概率放置，视觉密度待实机调。
- 既有物件 used 只标锚点格（v5.2 行为）：1×1 物件可能视觉叠上多格物件覆盖格；en/锚段已全格标记，旧物件未动。
- v54 镜像脚本未同步锚阶段与个性密度（不变式由 footOk/used 机制 + 冒烟覆盖）。
- 空房率/密度区间是首版参数（6%、0.5-1.4），待实机体感调。
- 8/21 22:32 有一次游戏运行未产生模组日志（原因不明）；链路本身已实测健康。

## 6. 下一步（优先级排序）

1. v5.8 实机复评（F5）——悬空/墙体形态/通道分化/v5.7 方差锚点一起看；
2. 按体感调参数（墙带厚度概率、层型配比、主次洞宽、个性密度区间）；
3. 灵性工程后续：进深序列（入口→深处梯度）、遭遇编排（enspawn 伏击位）、稀有地标；
4. 种子/联机仍延后（DEC-0001）；构件级 WFC 远期；
5. 共享知识待办：Tile.dec 字符位置语义 + **SAFE_FLOOR 白名单实证**（本次新增）、
   ups/kolEn/tipEnemy、AllData 物件体系、房间内容统计 → 沉淀 shared-knowledge。

## 7. 深入了解

- **开发历程**：state/journal.md（v3.1→v5.8，每条=一个实机反馈闭环）
- **当前生成器 v5.8**：src/rr/RRSynth.as（分层大厅 + 个性向量 + 视觉锚 + SAFE_FLOOR）
- **设计**：design/room-soul-plan.md（灵性工程三步走+两张设计卡）；design/generator-v5.md（v5 旧范式，待更新）
- **决策**：decisions/DEC-0001（范围）、DEC-0002（敌标记）、DEC-0003（分层大厅）、DEC-0004（反均匀路线）
- **关键实证**：knowledge/discoveries/alldata-materials-room-xml.md（材质/占地格/enl 标记）、
  knowledge/discoveries/room-content-statistics.md（物件组合近随机、方差才是灵性来源）；
  SAFE_FLOOR 白名单依据 = AllData oForms ed=2 逐字符 phis/语义（见 journal v5.8 条目）
- **工具链（2026-08-27 打通，全部实测）**：
  - 编译：`bash build/build-m0.sh`（mxmlc=flexsdk 4.16.1，Java=Animate 2024 JRE，配置=build/rr-config.xml；**勿用 amxmlc 直编**，air-config 的 {airHome} 令牌已失效）
  - SDK 全套：`D:\RemainsMod\mods\Sandevistan\build\tools\`（flexsdk+airsdk+ffdec）
  - Python（离线验证）：`C:\Users\hello\Documents\_sandevistan_dev\python3\python.exe`
  - 结构诊断：`build/diag-skeleton.py`（开放率/连通/rects 量化）；物件验证 `build/synth-v54-verify.py`（用前 rm -rf build/__pycache__）
  - 语料 `Rooms/rooms_*.xml`（658 房，player 0.99/房、敌标记 3.48/房、墙占比 15-36%）
- **构建/部署/测试技能**：remains-mod-build、remains-swf-patching、remains-auto-testing
