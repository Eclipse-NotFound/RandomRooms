# RandomRooms —— 开发记忆入口

> 2026-09-20：v10.0 原版通用探索内容已完成并部署。创建、交互、机关触发、四类右下扩张、旧内容状态保持和正式产物隔离重启均通过。历史过程见 journal。

## 1. 模组是什么

- 为 Remains 1.02 从零生成建筑空间，并按用途安排原版家具与可玩的探索内容；不复制原版整房或地形片段。
- 工厂、废弃避难厩、下水道、城市废墟分别控制空间、材料、门窗、敌群和设施。一场探索固定场景，向右、向下无限扩张。
- 入口固定 release/RandomRoomsMod.swf，类 RandomRoomsMod，public static init(main)。中文说明 README.md。

## 2. 用户决定与协作边界

- 土地=一次旅行完整地图；合成房=48×25 土地格；房间=内部功能空间；通道=内部连接。
- 采用 C 从零生成；不能把无限右下扩张改成有限 5×5 加 F4。取消固定三段式、中央井和统一穿房路线；普通上下连接错开，少量特殊场景可对齐。
- 较强探索、多高度出口、错层和分支；总体回环为主，少量有内容的尽头，不给每间强制同一配方。
- 上下左右任一实际开放边口都能进入并返回，不要求每间四面全开，不指定首入口，不随进入方向重排。
- 原版门、活板门、玻璃交互保留，不要求每房必出活板门。
- 四类场景整次探索保持，扩张和 F4 不更换；F1 四类入口加随机，回城再选。下水道真实污水，必经路线有干路，涉水可选。
- 新确认：先完整接入通用探索内容；剧情 NPC、任务专属装置、首领另行设计。密度题未单独回复，已说明按推荐的疏密变化默认推进，不记成用户明确选择。
- F1 冒险选择，F2 回城，F4 新深度，F5 展示馆选择；F3/F7 保留旧诊断，F8/F9 留其他模组。
- 更新后须重启游戏、回城后进入新土地；旧已加载地图不自动转新版。已决定事项不重复问。
- 只改本模组。根/DLC SWF、真实存档、其他模组不改；独立 pferr-style 应用 newGame(-1)，不使用 Ghost，不干扰用户实例。

## 3. 当前状态

- v10.0 已部署，日志 [RR:v10.0]，XML space-v10/revision10.0。仓库 main，准确提交查 git log。
- release 与 build/RandomRooms-v10-candidate.swf 相同：41027 B，SHA256 7AC89A73D6A09C0922FD0C7F1FFE7C2C2A836EE635393BF5D32FCC503463058C。
- RRPopulation 在地形后、家具前安排内容并预留占地。敌群/炮塔/容器/终端/按钮/服务/机关按主题和深度选择；显式敌人代替会跨场景重掷的通用占位符。原版类负责 AI、型号、掉落、技能和交互。
- 终端配实际炮塔或可黑入保险箱；触发器/武器同房唯一 allid；奖励按钮只指向可选箱。出生房和展示馆无敌人与危险设施，取消容器地雷；展示馆取消锁。整房通电开关初始关闭。
- RRScene/RRArchitecture 的四场景空间、用途和材料沿用 v9。RRPorts/RRMapPlan 保持全部 22 槽共享边与镜像；RRTraversal 继续双向可返回审计，下水道另审干路。cook 保护兼容 v7–v10。
- 最终 AS3 1024 单房+128地图房独立检查通过，75 个原版内容 ID 出现。cook 前后不重复计数；批量接口地图有意混主题，实际探索地图保持单主题。
- 最终候选原版 200 房/1684 个内容实例创建核对通过：646 次领取、49 炮塔终端、49 解锁终端、27 开关、115 拆除、59 工作设施、9 NPC 服务；12 组成套机关真实碰撞触发通过。成功行动效果验证不代表黑入概率或逐件正常接近。
- 四类各完成新列/旧列、新行/旧行 4/4，5×5→8×8；原 XML/mirror 与 760 个旧内容实例保持，已搜箱仍空。下水道 wetFrames0；工厂/避难厩成功项在失败总轮中，城市/下水道各另轮通过，证据如实区分。
- 正式产物隔离实例 pferr-style-55f84356066b486bac7451ea814793bd 重启通过：v10日志、展示12房全无危险、冒险25房、接口0问题、正常退出。未替用户重启其游戏。

## 4. 正在进行与卡点

- 本轮通用探索内容、验证和发布完成，无阻塞。后续按用户实际游玩反馈处理密度、平衡或具体物体。
- 不自动把未测范围变成待办，不重开已决定的生成方向。

## 5. 已知边界与调试线索

- 原版任务/首领/专用流程不在普通刷新池。结构仍偏直角；局部生活细节和内容密度可按实玩调整。
- 未穷尽随机种子、长期扩张内存、联机、真实旧存档死亡恢复、六模组集成、逐敌人战斗行为、伤害数值、全部购买及难度平衡。
- 原版 setDoor/setNoObj 会省略 rem 类物体：左右入口向内六格、上下三行。RRPopulation 同时为后续家具预留这些范围；不能关闭引擎保护来强塞对象。
- 水池对家具的预留允许水生敌人在真实水格内例外，仍避让返程梯子。机关明确 allid，避免原版自动武器生成越界。
- Mine 的 aiState 是 internal；成功拆除走 Interact.act→successRemine，普通机关走 actFun。终端/工作台/native服务已验证成功效果，技能概率未模拟。
- 原版干桥下一格虽空但脚到其高度就触水；导航驾驶器需避开水面上一格，沿真实桥面走。原失败房地形不改复测7/7、988帧、wetFrames0。
- 导航只用方向/爬梯/跳跃/行动，不改位置、碰撞、地形；跨房 controlOn 清 invulner，测试持续保护排除死亡。原版梁抬脚、梯子镜像吸附55px、空中惯性等旧经验仍有效。
- 城市整房图不含独立远景层，游戏屏幕包含。原图未重绘。评审页自动打开被 Browser URL 策略拒绝；不要换通道绕过，提供文件链接。
- AIR 独立 AppData 默认沙箱可能 #3003，走隔离测试权限审查，不能改真实存储绕行。

## 6. 下一步与回滚

- 用户重启、F2回城、F1选场景可体验新内容；已有地图不会自动增补。
- v9 回滚备份 build/release-backups/RandomRoomsMod_before_v10_20260920.swf，37785 B，SHA256 7DC5DB91D6FCE0802EEE73BD3312C6724FB0BCF16A2B48246D00554BEFD8BC4E。复制回正式入口并重启，不覆盖备份。
- 根 pfe.swf SHA256 5300EC4874E0404D298BB58C5D2A7469E82F93B455AD29AD64DD2E29D17241E7 未变。只部署本模组文件。
- 发布遵循 release-gate；release、备份和运行目录不进 Git，源码与冻结图/XML/日志/清单进 Git。

## 7. 深入阅读与复现

- 当前设计 design/exploration-content-2026-09-20.md；实景 design/generator-v10-review.html。
- 报告 knowledge/experiments/generator-v10-validation-2026-09-20.md；证据 generator-v10-evidence/、design/assets/v10-content/。批量和原版结果按源码/二进制指纹识别，不混用早期轮。
- 既有空间决定 decisions/DEC-0005-architectural-generation.md、DEC-0006-scene-identity.md；v9报告和实景保留。
- 构建 build/build-v7.ps1 -OutputName RandomRooms-v10-candidate.swf，只写 build；旧 build-m0.sh 直写 release，勿拿来验证。
- run-baseline.ps1 增加 -PopulationDepth；verify_population.py 核内容及原版出口清除，verify_architecture.py/verify_scenes.py 核结构和场景。
- run-game-captures.ps1：-DevelopmentSwf 指候选；-PopulationProbe -AllScenes [-PopulationDepth 6]；-NavigationProbe -GrowthProbe -AllScenes 或 -Scene；-ContentGallery -AllScenes；正式产物冒烟用 -SmokeOnly -DevelopmentSwf release/RandomRoomsMod.swf。
- freeze_captures.py 只冻结 complete 且哈希匹配的运行；失败总轮另存真实 manifest 和 evidence-index，不伪装通过。build_population_review.py 生成内容评审页。
