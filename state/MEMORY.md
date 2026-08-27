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

- 部署版本 **v5.6**——release/RandomRoomsMod.swf 已更新（v5.3 备份在同目录 _v53_backup.swf），**待实机（F5）复评**。
- v5.6 = **合成范式更换**：分层大厅（2-3 开放层 × 1 行墙带 × 层内竖隔断+门口）替换"独立矩形房+走廊网"——v5.4 实测墙占比 57-66%（原版 15-36%），且装箱数学上该范式天花板 ~45%，是"通道窄/被堵"的结构性根因。Python 量化：墙数 748→216（18%），全连通，rects 均 6.3/房。
- 水池改为房间矩形内完整放置（v5.4 全图随机被墙切碎、可能压走廊）；连通修复口袋阈值 16→6。
- 测试实例冒烟通过：init 正常、无 UNCAUGHT、展示馆 8 合成房构建完成。
- pfe.swf 里的 loader（8/21 部署）实测健康，无需重打。

## 4. 正在进行与卡点

- 等 v5.6 实机复评（F5）：通道应明显变宽变直（层间墙带洞 + 竖隔断门口），水体应为房间内完整片状。若房间感不足（隔断太少/太厚）或仍有异常，看日志与 build/diag-skeleton.py 量化。

## 5. 已知问题

- back 装饰仍是每 rect 3-6 个；新范式 rect 是横向长条，back 密度可能偏高，待实机看。
- 竖隔断门口的"门"物件（stdoor/door1）70% 概率放置，视觉密度待实机调。
- 既有物件 used 只标锚点格（v5.2 行为）：1×1 物件可能视觉叠上多格物件覆盖格；en 标记段已全格标记，旧物件未动。
- 8/21 22:32 有一次游戏运行未产生模组日志（原因不明）；链路本身已实测健康。

## 6. 下一步（优先级排序）

1. v5.6 实机复评收尾（F5；关注：通道宽度/连通、水体形态、门与隔断观感、敌标记）；
2. 按实机体感调分层参数（层数 2/3 配比、隔断数、门口密度、墙带洞数）；
3. 远期：构件级 WFC 混合；种子/联机仍延后（DEC-0001）；
4. 共享知识待办：ups/kolEn/tipEnemy 敌人生成机制、AllData 物件体系、**Tile.dec 字符位置语义**（首字符=fForms 墙表、后续字符=oForms/水/Z 层——`_X` 才是地板纹理，裸大写=墙）→ 沉淀 shared-knowledge。

## 7. 深入了解

- **开发历程**：state/journal.md（v3.1→v5.6，每条=一个实机反馈闭环）
- **当前生成器 v5.6**：src/rr/RRSynth.as v5Skeleton（分层大厅）+ design/generator-v5.md（v5 旧范式记录，待更新）
- **决策**：decisions/DEC-0001-scope-confirmed.md（范围）、DEC-0002-enspawn-channel.md（敌标记）、DEC-0003-layered-halls.md（范式更换）
- **关键实证**：knowledge/discoveries/alldata-materials-room-xml.md（AllData 材质/占地格/enl 标记）
- **工具链（2026-08-27 打通，全部实测）**：
  - 编译：`bash build/build-m0.sh`（mxmlc=flexsdk 4.16.1，Java=Animate 2024 JRE，配置=build/rr-config.xml；**勿用 amxmlc 直编**，air-config 的 {airHome} 令牌已失效）
  - SDK 全套：`D:\RemainsMod\mods\Sandevistan\build\tools\`（flexsdk+airsdk+ffdec）
  - Python（离线验证）：`C:\Users\hello\Documents\_sandevistan_dev\python3\python.exe`
  - 结构诊断：`build/diag-skeleton.py`（开放率/连通/rects 量化）；物件验证 `build/synth-v54-verify.py`（用前 rm -rf build/__pycache__）
  - 语料 `Rooms/rooms_*.xml`（658 房，player 0.99/房、敌标记 3.48/房、墙占比 15-36%）
- **构建/部署/测试技能**：remains-mod-build、remains-swf-patching、remains-auto-testing
