# RandomRooms —— 开发记忆入口

> 2026-09-10 接手校正。权限见 ../AGENT_SCOPE.md 与工作区 GOVERNANCE.md；历史过程见 journal.md。

## 1. 这个模组是什么

给原版随机土地增加模板变异，提供随机冒险土地及程序生成的合成房。
当前生成器采用横版平台结构：分层地板、竖隔断、内部通道、材质分区和物件摆放。
AS3 入口为 RandomRoomsMod.init(main)，通过运行时房池和土地定义接入游戏。
种子系统、深度循环、展示馆已实现；完整世界确定性和联机同步尚未验证。

## 2. 用户偏好与协作约定

- 中文交流。土地 = 一次 gotoLand 进入的完整世界；合成房 = 25 行 × 48 列的 Room XML 土地格；房间 = 合成房内部被隔断切出的空间；通道 = 内部连接结构。
- 历史“房间之间没有通道”指 **合成房之间无法跨土地格**，不要误改内部隔断。
- 实机复评：重启游戏 → F2 回城 → F5 展示馆；F1 观察混有作者房的随机冒险土地。
- 热键：F1 随机冒险、F2 回 rbl、F3 rr_test、F4 下一层、F5 展示馆、F7 跳合成房；F8/F9 留给其他模组。
- 正式日志 %APPDATA%/pfe/Local Store/RandomRooms_diag.log；当前前缀 [RR:v6.6]，追加写入，单实例最多 3000 行。
- 自动测试用独立 appId pferrtest（不得含下划线），按测试技能隔离实例、存档和产物，结束只清理自己的实例。
- auto_enter.txt 只放测试实例 storage；代码只检查标记存在，没有 appId 白名单；当前自动试驾依赖 0 号存档。
- 发布走 release 门禁；游戏 SWF 补丁须明确授权。build/build-m0.sh 直接写 release，普通编译检查必须覆盖输出到临时路径。

## 3. 当前状态

- 源码 **v6.6**，接手基线提交 2187622；本模组实际分支 main，接手工作树干净。
- release 文件时间为 2026-09-07；本轮未部署、未启动游戏，不能把文件时间或编译通过当作实机通过。
- **2026-09-10 编译通过**：临时 SWF 34380 字节，4 条已有警告（3 处重复变量、RRConfig 缺显式构造函数）。
- 临时产物与 release 同大小、哈希不同，尚未确认二者内容差异；release 哈希与接手前一致。
- v6.6 已有代码：地板行伸至左右边界、顶部/底部封实；先修连通再放物件；脚下支撑检查；占位按锚点行横向宽度，wid 不向下延伸。
- 最新历史验证记录为 journal 的 2026-09-07 条目：悬空 0/366、player 14/32、门 0.88/房、hatch2 0.94/房、模拟弹回率 7%、底边穿透 0。**本轮未复跑这些指标，仍待实机复评。**
- 核验依据：../knowledge/discoveries/v66-validation-boundaries.md。

## 4. 正在进行与卡点

- 接手阅读、流程核对、隔离编译和记忆校正已完成；主线仍是 v6.6 通行与观感复评。
- render_dump.py 无法读取当前版本前缀，本轮最小数据复现失败；只处理最后一房，不能承担整批统计。
- 自动试驾、房池数量和旧离线脚本均有描述与实现不一致之处，不能直接沿用“自动闭环已全绿”。

## 5. 已知问题

- 日志脚本“脚下格”统计实际读锚点行 y，不是支撑行 y+1；物件近似画成 2×1，PNG 只有 48×25 像素。
- diag-skeleton.py 镜像 v5.8，synth-v54-verify.py 依赖 v5.2 结构；不能验证 v6.6。
- 展示馆 beg0-only 快照被后续公共循环覆盖：正常情况下保留 8 个启动合成房，再加入 8 个新房及一轮变异。旧“8 原始 + 24 变异”说明不准确。
- autoPilot 调用 newGame(0) 是读档；空白隔离实例启动未验证。源码仍有合成按键步骤，历史“弃用”不代表已删除。
- hasGround 对宽度内任一实体支撑即通过；放置函数的 used 候选检查只查起点。是否存在局部悬空/横向重叠需实测。
- 物件密度、背饰、门观感和玩家实际跨房成功率待复评；字符预检不等于玩家可达。
- 同种子只控制模组随机序列；诊断可能消耗序列，原版抽样/镜像未全部接管。

## 6. 下一步（优先级排序）

1. 修复日志工具：版本前缀、可选属性、整批完整块统计、锚点与支撑区分；先验证小样本。
2. 核实隔离实例读档前提与试驾步骤，再按测试技能复跑；分别检查生成器、变异后房池及实际游戏。
3. 复评 F5 纯合成房与 F1 混合地图的通行、出生点、门/活板门、悬空及观感。通行修改须覆盖玩家 2×2 碰撞空间。
4. 按证据修复确认的问题；新方案沿用 DEC-0003/0004 方向。新增路径与删除旧路径必须同次完成。
5. 后续候选：进深序列、遭遇编排、稀有地标；完整世界种子复现/联机不是本轮承诺功能。

## 7. 深入了解

- 入口/旅行：src/RandomRoomsMod.as；变异/敌表：src/rr/RRCook.as；生成器：src/rr/RRSynth.as。
- 结构顺序：v5Skeleton → finishStripRoom → placeRoomObjects → XML → 预检 → cookPool → Land 构造。
- DEC-0001 初始范围、0002 敌标记、0003 分层大厅、0004 反均匀；种子与 P2 后续实现已超出初始状态。
- design/room-soul-plan.md；design/generator-v5.md 为旧范式，不能替代当前源码。
- 原版参考：game-reference/decompiled/1.02/src102/scripts/；优先参照 shared-knowledge 的 2026-09-09 生成机制审计与冲突限定，旧 room-system-architecture.md 的“rnd 每次自动重建”不成立。
- 构建：Flex SDK mxmlc + build/rr-config.xml（显式引用 playerglobal/airglobal）；本机不能照搬 amxmlc 默认配置。
- 编译工具：D:\RemainsMod\mods\Sandevistan\build\tools\flexsdk\lib\mxmlc.jar；Java：D:\Program Files\Adobe Animate 2024\jre\bin\java.exe。
- Python：C:\Users\hello\Documents\_sandevistan_dev\python3\python.exe；隔离编译方法见核验详情。
- 技能：remains-mod-memory / remains-mod-build / remains-auto-testing / remains-release-gate；修改宿主另用 remains-swf-patching。
