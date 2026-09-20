# RandomRooms —— 开发记忆入口

> 2026-09-20：正在进行 v11 原版场景调查与生成器改进。正式 release 仍是 v10；不要把开发验证当作已发布。Q1 已确认，城市地图组织 Q2 待答。历史过程见 journal。

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
- 本轮 Q1 明确确认：按原版生态与空间用途区分，允许合理共用。先定房间敌群，再配套机关、警报、机器人舱；不因“分离”删除合理的原版共享内容。
- 本轮 Q2 待答：是否按地图组织连续建筑、街巷、屋顶，各合成房承担不同用途（推荐）；或继续每间房都含室内外。不能把未答视为同意，仅城市地图改造依赖此题。
- F1 冒险选择，F2 回城，F4 新深度，F5 展示馆选择；F3/F7 保留旧诊断，F8/F9 留其他模组。
- 更新后须重启游戏、回城后进入新土地；旧已加载地图不自动转新版。已决定事项不重复问。
- 只改本模组。根/DLC SWF、真实存档、其他模组不改；独立 pferr-style 应用 newGame(-1)，不使用 Ghost，不干扰用户实例。

## 3. 当前状态

- 正式 v10.0 已部署，日志 [RR:v10.0]，XML space-v10/revision10.0。仓库 main，准确提交查 git log。下面 v10 结果保留作发布基线。
- v11 开发：调查外置原房192间、冻结12间原版实景。RREcology 按1.02源码与宿主难度选择同房生态，RRGrowth 恢复被 Land 改写的 tipEnemy；修正跨场景敌人/设施、按用途家具与墙面。工厂/避难厩/下水道分别重写构造顺序，增加原生斜楼梯及深池；城市结构仍旧分支，待 Q2。
- 最新开发产物 build/RandomRooms-v11-dev-8.swf，44751 B，SHA256 EFBFB2615A272BA46FD58D5AC890253833CC56F1319F0B55AA61ACFF3DA4EEA9；日志 [RR:v11-dev]，XML space-v11。只在 build，未替换 release。dev8相较dev7仅修正城市backwall/tWindows与transpFon。
- 当前批量 generated-v11-background-eighth：128单房+64地图房结构/场景通过，128单房生态通过；所有13个现有房型出现，蓄水池3/32下水道。冻结 batch-dev8.zip。与第七轮是同一固定种子，不累加成新覆盖。
- dev4 原版100房/750内容：生态/实际难度保持、创建、成功交互、碰撞触发通过，证据 population-dev4。后续改了空间/布景，不能宣称这一批是最新二进制实测。斜楼梯独立原房7/7、1085帧通过；该样本封边，不是跨房验证。
- 工厂dev7、避难厩dev7、下水道dev8均完成新列/旧列、新行/旧行4/4，5×5→8×8；分别190/208/182个旧内容对象、原XML/mirror及空箱保持。下水道wetFrames=0。工厂成功项在失败总轮内，避难厩/下水道各独立完整通过。
- 城市dev8到达新列，返回旧列屋顶目标时在断层掉落、反复寻路，1/4里程碑后失败。原房与日志冻结 growth-city-dev8-failure；不能声称四类完整移动通过。城市背景实际屏幕已看到窗带和远景。
- release 与 build/RandomRooms-v10-candidate.swf 相同：41027 B，SHA256 7AC89A73D6A09C0922FD0C7F1FFE7C2C2A836EE635393BF5D32FCC503463058C。
- RRPopulation 在地形后、家具前安排内容并预留占地。敌群/炮塔/容器/终端/按钮/服务/机关按主题和深度选择；显式敌人代替会跨场景重掷的通用占位符。原版类负责 AI、型号、掉落、技能和交互。
- 终端配实际炮塔或可黑入保险箱；触发器/武器同房唯一 allid；奖励按钮只指向可选箱。出生房和展示馆无敌人与危险设施，取消容器地雷；展示馆取消锁。
- RRPorts/RRMapPlan 保持全部22槽共享边与镜像；RRTraversal 继续双向可返回审计，下水道另审干路。cook保护兼容v7–v11。批量接口地图有意混主题，实际旅行保持单主题。
- 正式v10发布基线：1024单房+128地图、原版200房/1684内容、四类扩张均已有发布证据；详见v10报告与journal。这些不算作v11通过项，未替用户重启游戏。

## 4. 正在进行与卡点

- 用户本轮要求详细调查并实际改进场景同质化，工作尚未完成。Q2城市地图组织待答；不阻塞其余场景和生态修复。
- 三类构造、四类生态及材料改进已形成可审查阶段。城市结构仍待Q2，城市断层实测仍未通过；目前不能部署。原样16格宽/8格深池真实下水返岸2/2、487帧、154涉水帧通过（deep-water-regression）。
- 阶段页 design/generator-v11-investigation.html：12原版参考、工厂/避难厩第一轮6图、下水道修订4图。原版对照 assets/native-scenes-2026-09-20，最新深池 assets/v11-sewer-refined；不拿旧池图当最新。

## 5. 已知边界与调试线索

- 原版任务/首领/专用流程不在普通刷新池。结构仍偏直角；局部生活细节和内容密度可按实玩调整。
- 未穷尽随机种子、长期扩张内存、联机、真实旧存档死亡恢复、六模组集成、逐敌人战斗行为、伤害数值、全部购买及难度平衡。
- 原版 setDoor/setNoObj 会省略 rem 类物体：左右入口向内六格、上下三行。RRPopulation 同时为后续家具预留这些范围；不能关闭引擎保护来强塞对象。
- 水池对家具的预留允许水生敌人在真实水格内例外，仍避让返程梯子。机关明确 allid，避免原版自动武器生成越界。
- Mine 的 aiState 是 internal；成功拆除走 Interact.act→successRemine，普通机关走 actFun。终端/工作台/native服务已验证成功效果，技能概率未模拟。
- 原版干桥下一格虽空但脚到其高度就触水；导航驾驶器需避开水面上一格，沿真实桥面走。原失败房地形不改复测7/7、988帧、wetFrames0。
- 导航只用方向/爬梯/跳跃/行动，不改位置、碰撞、地形；跨房 controlOn 清 invulner，测试持续保护排除死亡。原版梁抬脚、梯子镜像吸附55px、空中惯性等旧经验仍有效。
- 原版行动须有到物体中心的isLine视线，光标能选中不够；行动键须按住到计时完成，逐帧松开会取消回调。侧边跨房抓梯须正常跳跃离梯。自动行走在柜顶不能继续追柜下地面坐标，需从实际顶面向下一路径点行走；下水道原失败房复测已通过。
- 水下到达池底时原版stay可能为false，测试不能强求干地站立状态；深池首轮因此误判，修正驾驶器后相同XML完成下水与返岸。失败与通过分开封存。
- 斜楼梯：后来梯子可覆盖斜面末端，已加完整阶梯检查；后放门须有底座和门头。原版上行需配合上键，下降按 Tile.getMaxY 取实际斜面高度；不能读取 UnitPlayer.diagon（internal），应读取公开原版 tile.diagon。
- 黏液地雷：显式地图对象用 slime tr="10"，不是 cid="10"；Unit.create 的 node 来自 AllData 定义。dev3真实刷新检查揭露、dev4实际 UnitSlime/levitPoss 检查通过。
- 大池先前因内部下降梯占位而被全部淘汰；已把上口接检修廊、池内通行优先靠岸并尝试多种池宽。保留每种构造拒绝原因统计，防止“批量全通过”掩盖某房型永远不出现。
- 城市整房图不含独立远景层，游戏屏幕包含。原图未重绘。评审页自动打开被 Browser URL 策略拒绝；不要换通道绕过，提供文件链接。
- AIR 独立 AppData 默认沙箱可能 #3003，走隔离测试权限审查，不能改真实存储绕行。

## 6. 下一步与回滚

- 下一步：收到Q2后改城市地图编排与室内/室外构造，复测断层和全部扩张路线；进一步打磨大面积空墙与空间细节；全部必要验证通过后才走发布门禁。保持从零生成、无限右下扩张和任意开放边口可返回。
- 用户现在重启仍运行正式 v10；开发版尚未部署，已有地图不会自动增补。
- v9 回滚备份 build/release-backups/RandomRoomsMod_before_v10_20260920.swf，37785 B，SHA256 7DC5DB91D6FCE0802EEE73BD3312C6724FB0BCF16A2B48246D00554BEFD8BC4E。复制回正式入口并重启，不覆盖备份。
- 根 pfe.swf SHA256 5300EC4874E0404D298BB58C5D2A7469E82F93B455AD29AD64DD2E29D17241E7 未变。只部署本模组文件。
- 发布遵循 release-gate；release、备份和运行目录不进 Git，源码与冻结图/XML/日志/清单进 Git。

## 7. 深入阅读与复现

- 当前设计 design/exploration-content-2026-09-20.md；实景 design/generator-v10-review.html。
- 本轮主入口 design/native-scene-audit-2026-09-20.md（含实施范围、逐批证据与失败边界）；generator-v11-investigation.html看实景。audit_native_scenes.py统计外置192房，select_generated_forms.py选择完整生成房。共享敌群旧文与当前源码冲突，采用本轮证据，不默改镜像副本。
- 报告 knowledge/experiments/generator-v10-validation-2026-09-20.md；证据 generator-v10-evidence/、design/assets/v10-content/。批量和原版结果按源码/二进制指纹识别，不混用早期轮。
- 既有空间决定 decisions/DEC-0005-architectural-generation.md、DEC-0006-scene-identity.md；v9报告和实景保留。
- 构建 build/build-v7.ps1 -OutputName RandomRooms-v11-dev-8.swf，只写build；旧build-m0.sh直写release，勿拿来验证。当前dev8已冻结，后续源码变化用新文件名。
- run-baseline.ps1 增加 -PopulationDepth；verify_population.py 核内容及原版出口清除，verify_architecture.py/verify_scenes.py 核结构和场景。
- run-game-captures.ps1：-DevelopmentSwf 指候选；-PopulationProbe -AllScenes [-PopulationDepth 6]；-NavigationProbe -GrowthProbe -AllScenes 或 -Scene；-ContentGallery -AllScenes；正式产物冒烟用 -SmokeOnly -DevelopmentSwf release/RandomRoomsMod.swf。
- freeze_captures.py 只冻结 complete 且哈希匹配的运行；失败总轮另存真实 manifest 和 evidence-index，不伪装通过。build_population_review.py 生成内容评审页。
