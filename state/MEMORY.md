# RandomRooms —— 开发记忆入口

> 2026-09-28：v13 已实装，正式 release 仍为 88,909 B，SHA256 A5EB49A089835BBC7B670411BBDF32865F5110AEAE79F8BC182AF3BB4C9CBE46。随后完成编辑器接入调查（§8）与本次原版破碎感/噪声算法调查（§9），均尚未实施生成器适配。最新图文入口 design/fracture-study-2026-09-28/index.html。

## 1. 模组与运行入口

- Remains 1.02，从零生成建筑空间，不复制原版整房/局部模板。四场景：工厂、废弃避难厩、下水道、城市废墟；一次探索固定场景，向右、向下无限扩张。
- 本目录独立 Git 仓库，main 分支。正式入口 release/RandomRoomsMod.swf，类 RandomRoomsMod，public static init(main)。
- v13 部署轮仅替换本模组 release；根/DLC SWF、真实存档、其他模组未改。共享 registry 登记 Shift+F3 和调试显示层。
- v13 部署时 root pfe.swf = B78244657ED407D03808C90E97325509DB35F802122835F58933FFF8003305AC；后续编辑器调查只读核对的当前宿主 = C631CBF3511B6EE303F533D08D51511FE0EB702F43E5DB17F5241D8576C64867，本次未修改宿主，不覆盖旧部署证据。启动用 application.xml，不是 app.xml。加载清单 mods/loader-manifest.txt 是权威，RandomRooms|RandomRoomsMod|1|1|0；本次未写加载清单。

## 2. 用户决定与边界

- 土地＝整次旅行地图；合成房＝48×25 格；房间＝内部功能空间。采用 C 从零生成，不能用有限 5×5 加 F4 替代向右/下扩张。
- 所有实际开放入口均应可进出，不要求四面全开，不指定统一穿房路线或首入口。普通上下连接错开，少量特殊长井；较强探索，回环为主，少量有内容的尽头。
- 保留原版门、活板门、窗、生态、用途及合理共用；禁止专属敌人/设施不合理越界。剧情 NPC、任务装置与首领不入通用刷新。
- 下水道真实污水，必经干路、涉水可选。城市按地图坐标延续建筑/街巷/屋顶，不能每房都塞全套。
- 随机用途侧重、房数/尺度/位置；降低普通净高，部分共层，显著大小反差；厚实体块、横向合并为主、少量跨层合并已获准，替代早先只矩形限制。
- D/V＝合成房基调＋内部局部变化，部分耦合，允许高危低值及低危高值；D 先控制主要敌群机会、数量、布防，强度仍按原版生态/难度/深度。动物另行抽样；地雷、蜘蛛地雷、无人机偏低危高值及适当盲区。
- 顶/地炮塔按战术位置生成；部分带炮塔房安排安保终端，控制范围遵循原版整 Location，不限内部子房。至少一条候选避火接近路，不假定左边进入、不承诺每个入口均避火。
- 用户本轮明确要求“游戏内用途/D/V/生成点/枪线调试＋此前未实现机制＋实装”，已取代此前 HTML-only 限制。v12.2/v12.3 对照须保留。
- 测试使用独立 pferr-style-* AIR app、新角色和隐藏 ADL，不用 Ghost，不关用户游戏。只结束精确匹配本模组独立实例的进程。
- 每次换 SWF 须完全退出重启，再 F2 回城、F1 生成新土地；旧地图不自动升级。

## 3. 当前实现

- F1/F5：v13、v12.2、v12.3＋种子＋四场景/随机；F4 与扩张保持选择。新探索从第 1 层开始。首次读旧配置迁到 v13，之后尊重版本选择。
- v13 使用真实 v12.3 地形，未搬入 HTML 简化布局。v12.2 七文件冻结在 src/rr/v122；v12.3 厚块、少房、矩形合并仍在 rr。历史 Git SHA 曾随公开仓库清理图片而变化，核对旧源请用哈希确认的旧发布 archive，别依赖失效的 93e7fef。
- RRContentPlan：最终合并组共用 D/V 与压力预算，图库交通空间不重复给预算；按用途偏向，局部变化 32、共同因素 30%。先炮塔/终端，再主敌群、零散生态、机关、特殊威胁、奖励与服务。
- 主要敌人最多 10 / 合成房，特殊威胁最多 3，炮塔最多 3；原版 RREcology.large 抽到炮塔也须归入统一战术安排，不能绕过。
- V 独立随机来源，改变 V 不重抽地形/生态/主敌群/炮塔。保留原生掉落、黑入、拆除和容器潜伏事件。
- RRTactics：2×2 身体近似、步行/梯路、机械限角和实体遮挡；门和玻璃不当永久掩体。顶炮支撑及入口保护；62% 机会尝试终端，操作位不能含梯子或结构预留，要求两脚支撑。找不到合格位置不硬塞终端。
- RRDebugOverlay：Shift+F3，默认关闭、配置记忆；用途/D/V、生成十字、当前单位、炮塔防守虚线、终端候选青线、实际枪口朝向。随镜像/相机更新，只读 native unit/weapon/Tile，停机炮塔无活动枪线。20Hz 更新，关闭不做动态射线。
- 调试层名称 RandomRooms_DebugWorld / RandomRooms_DebugHUD；标签多行，顶炮文字下移避开 D/V。旧版显示用途和“旧版，无 D/V”。
- RandomRoomsMod 的 F2/F4 已加原生区域切换保护：t_exit > 0 或目标/实际土地不一致时等待。日志版本 [RR:v13-dv]。

## 4. v13 部署验证与证据

统一入口 design/v13-content-runtime/validation.md、deployment.json、runtime-checks.json。

- 192 个 AS3 房间，47 炮塔/17 终端；预算、合并组、支撑、终端选点通过。32 对 V=0/100 保持主敌群/炮塔/地形/生态。
- 旧版 1024 历史 XML 重放一致；512 地图坐标、256 对版本输入、896 对邻接口通过；v12.2 七源与旧部署 archive 一致。
- 三版本原生 UI 12/12：F1/F4/回城切换/随机/F5/取消与暂停恢复，ui-lifecycle-final。
- 四场景连续原生内容及调试 4/4，共 132 Location，population-release-candidate；真实终端/机关/容器效果、镜像、D/V 完整、停机枪线消失均检查。
- 工厂终端真实移动及操作位置检查通过，terminal-approach-plant。动物/敌人仍正常行动，保护角色伤害用于几何测试，未传送完成路径。
- 四场景扩张往返 4/4：5×5→8×8，进出新列/新行并返回，旧 XML、镜像和内容实例保留；下水道 wetFrames=0，growth-final。
- 核心候选 50747C20…E261B 完成上列机制检查；最终 A5EB49A0…BE46 仅下移顶炮调试文字，逐源码精确替换核验，overlay-final 复测原生内容及显示通过。
- 正式安装文件经原有清单加载器启动，驾驶器不调模组 init；F1/F4/F2/F5 和 Shift+F3 共 3/3 通过，release-smoke。
- algorithm-evidence.zip、release-evidence.zip 保存实际源码/SWF；图像与 ZIP 按公开仓库既定规则不进 Git，本机保留。文本证据已保存哈希，不能把新结果覆盖旧指纹。

## 5. 失败、修复与限制

- terminal-ladder-failed：原终端位跨梯子，native pony 吸附后出掩体。正式选点排除梯子/结构预留并检查双脚，复测通过。
- navigation-flight-failed：自动驾驶在斜梯下追错误落点折返。改驾驶器到更远梯脚和绕家具，不改地图或人物位置；四场景通行复测通过。
- 连续人口测试早先回城失配的根因是区域到达仍 t_exit>0，不是只有重要物品提示暂停；正式保护与驾驶器等待共同修复。
- ui-clock-gap-failed：最后案发生长心跳空档后超时，原因未证；新实例 12 案通过，失败档保留。
- native-loader-readiness-failed：新检查器错误等待启动期不存在的 random_rooms LandLoader；原模组已 READY。按门禁先回滚，改检查器后同一 SWF 再安装并通过；不视为模组逻辑改动。
- 原生 term1 全 Location 控制；hack(0) 停机、hack(1/2) 改阵营。顶炮待机扫描范围不是全部机械转角，原生枪口起点有挂载偏移。
- 低 D/出生房没有初始敌群不等于绝对安全：容器 mine=0 不能阻止原版开箱潜伏事件。枪线不模拟散布/弧线/穿透或下一帧转向；门开闭/破坏会改变现场。
- 候选终端路只是地形近似；不保证从每个入口全程避火，移动敌人也会造成干扰。未穷尽种子、联机、全模组组合或长期内存。
- 自然度仍可改进：部分狭长/空墙、厚块偏矩形、合并背景接缝、家具沿子矩形、城市顶边框；不宣称等同原版。
- RRTraversal 不包含全部真实家具/跳跃影响；原生 Land 会改 tipEnemy，RRGrowth 保持其修正。生成器元数据 rrGen=space-v11 是沿用字段，正式版本看 rrVersion/rrRevision。

## 6. 接续与回滚

- v13 实现/部署完成；本次破碎感调查也已完成。后续按用户方向继续，推荐固定底图的表面/结构分层对照，尚未实现或授权本轮直接替换生成器；不擅自删 v12.2/v12.3。
- 回滚备份 build/release-backups/RandomRoomsMod_before_v13_20260928.swf = 76,834 B，SHA256 8E0E8A83E0DE96D0CA6F5162DD81F226B53CF8F0634F0AD073E9E3829BA292E9。关游戏→复制回 release/RandomRoomsMod.swf→核对→重启进新图。
- 更早 v11.1 备份/对照发布记录见 design/v12-runtime-comparison 与 journal，不覆盖现有备份。

## 7. 深入阅读与复现

- 日常构建 build/build-v7.ps1 -OutputName RandomRooms-v13-next.swf 只写 build；旧 build-m0.sh 直写 release，勿用于开发验证。
- 批量：build/style-review/harness/run-comparison.ps1 -Content；旧版省略 -Content。freeze_v13_algorithm.py / finalize_v13_evidence.py 为本轮固定指纹归档，不可直接覆盖下一轮。
- 原生：run-game-captures.ps1 -DevelopmentSwf <SWF> -GeneratorVersion 13；可配 PopulationProbe/ContentGallery、NavigationProbe/GrowthProbe、TerminalApproach、ComparisonLifecycle。NativeLoaderSmoke 只走原生 UI。
- app / visual-app / comparison-app 三个隔离目录；成功用 freeze_captures.py，失败用 freeze_failed_run.py。AIR app: 不可写，使用 new File(File.applicationDirectory.nativePath)；存储权限需独立实例审批，不能借真实 pfe 存储绕行。
- 设计背景 design/danger-value-2026-09-27；HTML design/danger-value-preview。较早教程 generator-explained-v11.1 只解释旧链。

## 8. 编辑器接入调查（2026-09-28）

- 用户本次只要求探查能否借现有编辑器改善模组。结论与建议见 `design/editor-integration-20260928/assessment.md`，逐字段兼容性见同目录 `editor-compatibility.md`；未改正式源码、release、编辑器、地图或存档。
- 主 v13 走 RRExpedition/RRSynth/RRGrowth 动态生成、内存池与持续扩张；没有读取编辑器文件替换生成房的入口。优先建议只读固定种子审查、用途/D/V/规划叠层，再把编辑器摆设组合转为 RRFurnish 规则；保留从零生成方案。建议尚未获用户实施选择。
- 现有编辑器保存会丢 all 根版本/种子；重编码房间丢 rr* 属性和 rrPlan，serial=1 还丢 doors。物体自定义 XML/options 大体可保留，但修改后旧规划会过时，不能仅保留字段就直接回灌。
- 132 历史房/158400 格、55 种格码独立静态核对通过；不是 GUI 保存往返。原样已装 EditorTools/NativeScene 的隔离副本实画四房，4/4 输出 1920×1000 PNG，0 警告、输入与正式文件哈希不变；不是本次重新运行 v13 游戏验收。
- 原始池文件均误推工厂，rrMirror 不自动应用；城市预览还缺 transpFon。当前预览跳过炮塔、地雷、部分机关/商贩，不验 AI/枪线/相邻接口/涉水；运行验证仍用原生游戏。
- 同目录 samples/ 为四份单房工作副本，previews/ 为本机图像，audit.py/run-probe.ps1 可复现隔离预览。首次驱动器写图前超时，改驱动器输出路径后同一组件通过，未确证初次原因；记录保留在 verification.json。

## 9. 原版破碎感调查（2026-09-28）

- 用户要求调查更强随机/噪声算法，重点是原版破碎感如何形成；本轮仅调查、参考渲染与图文页，生产源码/release不改。入口 `design/fracture-study-2026-09-28/index.html`，原版结论 `native-study.md`，算法来源 `algorithm-sources.md`。
- 四个外置池192条（普通120条），精读16例；新捕获9例加屋顶背景修正1例，复用7张既有图。普通城市26间里25有hole、20有heap；工厂40间13有chole、0有heap；避难厩32/下水道22均没有这两组，不能把计数当概率。
- 关键区分：真实地形缺失、E裂纹实体（hp150/thre10）、后墙擦除是不同机制。D仍与C同为hp1000/thre100；城市45内框只有14实体格，y8/y16大量旧楼层是_A背景。岩洞G/H与金属设施交错，苔墙L的粗边不等于高频删格。
- 当前限制：城市1–3处2–4格缺口全留薄梁；hole要求单子矩形宽/高>=10且不跨实体，低层高房被筛掉；材料旧损按坐标分块；避难厩缺自然洞穴空间体系。
- 推荐但未实施：建筑/自然区域基底→少量有方向破坏事件→连片侵蚀→小幅多尺度噪声修边→背景/残留；CA局部岩体、WFC后续修边。破损面积、事件尺度、边缘细碎、残留、易碎与表面破旧分参数，独立于D/V。
- 新结构需同步用途/可站立面、门梯、全入口往返、污水干路、炮塔支撑/枪线、终端接近与开墙后敌群支援预算，不能只删grid；不能为修复通行重新加统一底层横路。
- 9+1捕获及全部哈希/原网格/back比对通过。页面JS语法/静态资源核对通过，浏览器工具拒绝file协议，本轮未实点HTML或截图，也未绕行。城市屋顶需Land的backform=2条件，首轮屋顶图不用于背景结论，已单独复拍。
- 公共知识：新增 rendering/discoveries/native-fracture-layers.md；显式纠正 tile-code-table.md 的ed=2/斜梯/F/部分高度解释。KB-000045 r2仅用于冻结底图对照提醒。完整边界与复现见 validation.md。
