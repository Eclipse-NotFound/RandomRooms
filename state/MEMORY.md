# RandomRooms —— 开发记忆入口

> 新会话从这里开始。协议见工作区 GOVERNANCE.md §8；本模组参数见 ../AGENT_SCOPE.md。

## 1. 这个模组是什么

在随机土地（如马哈顿废墟）中**程序化合成结构合理的房间**：干净矩形房间 + 走廊网络 + 材质带 + 物件摆放，替代原版的模板拼贴感。技术形态：AS3 模组（入口类 `RandomRoomsMod`）+ Python 离线验证脚本 + FFDec loader 部署进 pfe.swf。

## 2. 用户偏好与协作约定

- 实测工作流固定：改代码 → `build/build-m0.sh` 编译 → `build/deploy-pfe.sh` 部署 → 用户重启游戏 → **F2 回城 → F5 进展示馆** → 读 `%APPDATA%/pfe/Local Store/RandomRooms_diag.log`（前缀 `[RR:0.0.1-M0]`，grep -a）。
- 热键已占用：F1/F2/F3/F4/F5/F7；**F8/F9 被其他模组占用，不可用**。
- 范围约定（DEC-0001）：v1 = P0+P1；种子与联机同步延后。

## 3. 当前状态

- 部署版本 **v5.3**（git `fe67d49`，2026-08-21）——已进 pfe.swf，**等待实机（F5）评估**。
- 部署校验：二进制含 RandomRoomsMod 16 处引用、tag 数 84384 一致；回滚备份 `pfe_before_rrooms_20260821_184958.swf`。

## 4. 正在进行与卡点

- 等 v5.3 实机反馈——若通道/悬空仍有问题，先看日志与 dumpSynthGrid 分阶段输出。

## 5. 已知问题

- v5.1 的三根因（物件悬空 / 孤立房间 / back 落位）在 v5.3 已修，**待实机确认**。

## 6. 下一步（优先级排序）

1. v5.3 实机评估收尾；
2. 敌人出生标记：每房 1-3 个 enl1/enl2/enf1（biome 规则、tip=enspawn 走 addEnSpawn 通道）；
3. 按实机体感调结构参数（房间数/间距/额外环数）；
4. 远期：v4 规划中的构件级 WFC 混合；种子/联机仍延后（DEC-0001）；
5. 共享知识待办：修订 shared-knowledge 的 tile-code-table.md（ed=2 拉丁 oForms 语义）；把 AllData 物件体系沉淀为 shared-knowledge 发现文档。

## 7. 深入了解

- **开发历程**：state/journal.md（v3.1→v5.3 合成算法演进史，每条=一个实机反馈闭环）
- **关键实证**（AllData 材质表/房间 XML/物件占地格，勿再猜）：knowledge/discoveries/alldata-materials-room-xml.md
- **当前生成器 v5.3 流程**：design/generator-v5.md
- **决策**：decisions/DEC-0001-scope-confirmed.md（范围）
- **设计**：design/ 下 random-room-synthesis-v3/v4、room-synthesis-plan、vision-and-proposals
- **实验**：knowledge/experiments/（M0 部署管线验证 / P0 注入点 / P1 种子与随机房 / rsynth 验证）
- **工具链**：build/build-m0.sh（编译，amxmlc）、deploy-pfe.sh（部署，注意 DEFAULT_TARGET 硬编码旧 C 盘路径须传参）、离线验证 synth-proto3.py / synth-v52-verify.py（用前 rm -rf build/__pycache__）、corpus-analysis.py；语料 `Rooms/rooms_*.xml`（525 个 25×48）
- **构建/部署/测试技能**：remains-mod-build、remains-swf-patching、remains-auto-testing
