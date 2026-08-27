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

- 部署版本 **v5.4**（本会话编译）——release/RandomRoomsMod.swf 已更新（旧 v5.3 备份在 release/RandomRoomsMod_v53_backup.swf），**待实机（F5）评估**。
- 测试实例冒烟通过：加载链完整、无 UNCAUGHT、展示馆 8 合成房生成无异常（enspawn 代码已执行）。
- pfe.swf 里的 loader（8/21 部署）实测健康，无需重打。

## 4. 正在进行与卡点

- 等 v5.4 实机反馈：v5.3 三修复（通道/悬空/孤立房间）+ v5.4 敌人标记与 player 修复**一起看**（F5 展示馆；敌标记本身不可见，看的是房间内敌人是否按 biome 出现、开局不贴脸）。

## 5. 已知问题

- back 装饰仍是每 rect 3-6 个（原版每房口径未查；纯视觉、风险低，未动）。
- 既有物件 used 只标锚点格（v5.2 行为）：1×1 物件可能视觉叠上 2×2 物件的覆盖格；en 标记段已做全格标记，旧物件未动。
- 8/21 22:32 有一次游戏运行未产生模组日志（原因不明，疑日志被清或未走正常启动链）；链路本身已实测健康。

## 6. 下一步（优先级排序）

1. v5.4 实机评估收尾（F5；若异常先看日志与 dumpSynthGrid 分阶段输出）；
2. 按实机体感调结构参数（房间数/间距/额外环数）；
3. 远期：v4 规划中的构件级 WFC 混合；种子/联机仍延后（DEC-0001）；
4. 共享知识待办：ups/kolEn/tipEnemy 敌人生成机制、AllData 物件体系、ed=2 拉丁 oForms 语义修订 → 沉淀 shared-knowledge。

## 7. 深入了解

- **开发历程**：state/journal.md（v3.1→v5.4，每条=一个实机反馈闭环）
- **当前生成器 v5.4**：design/generator-v5.md + src/rr/RRSynth.as en 段（房间级放置）
- **决策**：decisions/DEC-0001-scope-confirmed.md（范围）、DEC-0002-enspawn-channel.md（敌标记通道与配比）
- **关键实证**：knowledge/discoveries/alldata-materials-room-xml.md（AllData 材质/占地格/enl 标记 4931-4933 行）
- **实验**：knowledge/experiments/（M0 部署管线 / P0 注入点 / P1 种子）
- **工具链（2026-08-27 打通，全部实测）**：
  - 编译：`bash build/build-m0.sh`（mxmlc=flexsdk 4.16.1，Java=Animate 2024 JRE，配置=build/rr-config.xml；**勿用 amxmlc 直编**，air-config 的 {airHome} 令牌已失效）
  - SDK 全套：`D:\RemainsMod\mods\Sandevistan\build\tools\`（flexsdk+airsdk+ffdec）
  - Python（离线验证）：`C:\Users\hello\Documents\_sandevistan_dev\python3\python.exe`
  - 离线验证：`build/synth-v54-verify.py`（400 房不变式；用前 rm -rf build/__pycache__）
  - 语料 `Rooms/rooms_*.xml`（658 房，player 0.99/房、敌标记 3.48/房）
- **构建/部署/测试技能**：remains-mod-build、remains-swf-patching、remains-auto-testing
