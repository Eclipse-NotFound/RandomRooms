# RandomRooms —— 开发记忆入口

> 2026-09-27：危险/价值 HTML 已追加天花板炮塔、按射界和逐入口路线选点的安保终端、关闭/恢复模拟。882 次本轮模型检查通过，实际浏览器排版及游戏玩法未验。入口 design/danger-value-preview/index.html，点击“看有终端的样例”。正式仍为 09-24 的 v12.2/v12.3 对照版。

## 1. 模组是什么

- 为 Remains 1.02 从零生成建筑空间，不复制原版整房或局部地形；按用途安排原版家具、敌群和通用探索内容。
- 四类场景：工厂、废弃避难厩、下水道、城市废墟；一次探索固定场景，向右、向下无限扩张。
- 固定入口 release/RandomRoomsMod.swf，类 RandomRoomsMod，public static init(main)。本目录独立 Git 仓库，main 分支。

## 2. 用户决定与边界

- 土地＝整次旅行地图；合成房＝48×25 格；房间＝内部功能空间。采用 C 从零生成；不能改成有限 5×5 加 F4。
- 普通上下连接错开，少量特殊长井；较强探索、回环为主，少量有内容的尽头。不指定统一穿房路线或首入口；任一实际开放入口均应可进出，不要求四面全开。
- 保留门、活板门、玻璃、场景生态与用途。允许原版合理共用，禁止专属敌人/设施混入不适用场景。剧情 NPC、任务装置和首领另行设计。
- 下水道使用真实污水，必经干路、涉水可选；城市按地图坐标组织连续建筑/街巷/屋顶，不能每个合成房都塞全套室内外。
- 随机用途侧重、房间数量、大小与位置；普通空间降低净高，部分合成房采用对齐的楼层，允许显著大小反差。
- v12.3 已获准厚实体块、减少房数、矩形规划后横向拆墙为主、少量拆楼板跨层合并；这替代了最初仅矩形的限制。
- 新增 D/V 方向：合成房有整体基调，内部空间局部变化；D 先控制主要敌群概率、规模、布防，强度遵守原版场景/难度/深度。允许合理耦合，也须允许单独高危或高值。09-27 用户另要求蜘蛛地雷/地雷/无人机可偏向低危高值，地雷类偏向盲区；已授权先 HTML 实时模拟，参数尚待评估。
- 09-24 的 v12.2/v12.3 已授权并完成部署；09-27 新内容机制本轮范围为 HTML。不要将旧部署许可误读为本轮已接入或已部署新内容。
- 用户追加天花板炮塔与部分合成房中的安保终端，要求考虑选点。预览采用原版整 Location 控制范围；至少一条近似避火接近路线，不预设从左入口进入。
- 仅改本模组；正式存档、其他模组、根/DLC SWF 不改。测试用独立 pferr-style-* 应用、newGame(-1)、隐藏 ADL，不用 Ghost，不关闭用户游戏。
- 每次替换 SWF 后须完全退出重启，再回城 F1 生成新土地；旧地图不会自动更新。已决定事项不重复提问。

## 3. 当前状态

- 新预览单 HTML 内嵌模拟算法与 16 份 v12.3 AS3 布局；支持实时生成/实际布局重排内容、D/V 与特殊规则、四组引导、三层图、逐房理由和 3×3 对照。旧两页保留 DATA，只增入口。
- 顶炮/地面/混合安装对照，终端机会 0–100%，操作空间检查全部炮塔可转向射界；先预留炮塔预算和终端站位，再放敌群/地雷/奖励。关闭模拟作用于全合成房炮塔，重新生成复位。第四组引导/快捷按钮用种子 4345、D70/V65，两座炮塔和一处终端。
- 正式 release/RandomRoomsMod.swf 已为对照版，76834 B，SHA256 8E0E8A83E0DE96D0CA6F5162DD81F226B53CF8F0634F0AD073E9E3829BA292E9；与 build/RandomRooms-v12-comparison-candidate.swf 一致，日志 [RR:v12-compare]。
- F1/F5 新增 v12.2/v12.3、种子和四场景/随机选择；取消恢复暂停。每次明确新开从第 1 层开始，F4 与右下扩张保持版本/种子/场景。菜单种子更改用于下次 F1，无须为改种子重启。
- RRExpedition 将规则分区真正接进地图：场景+深度派生地图随机源，坐标派生房间种子；版本不参与种子派生，镜像/边口/城市条件可公平对照。原版掉落和 AI 仍有运行时随机。
- v12.2 七类冻结于 src/rr/v122，来源 93e7fef，只改包名/导入；当前 rr 中的 v12.3 规则保留 430d085。不要直接部署原 prototype-2/3 SWF，它们的 F1 仍走旧链。
- v12.2 以矩形数量/尺度/共层随机为主；v12.3 在此基础上减少分隔房、加入实体块和最多三个矩形合并。家具与内容目前仍按矩形子区布置。
- 原正式 v11.1 已备份：46044 B，SHA256 16F3D2BD63D19660E039F5F44B4792FD85F3E2119A59F058F8290F5746346C7F；回滚位置见第 6 节。

## 4. 正在进行与验证证据

- 本轮新预览验证见 design/danger-value-preview/validation.md 追加节、turret-terminal-checks.json：882 次执行，147 顶炮/505 地面炮塔/323 终端，无所查支撑/射界/操作位置/压力违规；144 对 V 独立性、64 对终端机会不改变炮塔通过。逐入口 410 可绕开、67 经过射界、815 步行/梯路未证实，不能冒充任意入口实机可达。最小 DOM 检查新旧交互与复位，离线 SVG/PNG 查看关闭前后；浏览器 file URL 已拒绝，不绕行。
- 首版 736 次执行、144 对独立性及遮挡偏好 20/14 的历史证据仍在 simulation-checks.json，属于旧模拟器指纹，不可覆盖或混报为本轮统计。
- 原版调查 120 普通房及两版各 256 XML，来源指纹和统计在 design/danger-value-2026-09-27/native-evidence.json；不是本轮战斗实测。
- 发布检查的源代码/候选已一致冻结在 design/v12-runtime-comparison/algorithm-evidence.zip。1024 历史 HTML XML 重放一致；512 实际坐标输入结构、材料、生态均通过；256 对版本输入相同，896 对邻接口一致。
- 当前候选 UI 生命周期 8/8，174 房：两版 F1→F4、回城切换、随机种子选择、F5 展示馆、取消/暂停；ui-lifecycle 下完整证据与原生界面截图。
- 同一候选、种子 20260818，两版四场景 8/8 完整扩张往返通过；每案真实按键、5×5→8×8、新列/新行往返、旧 XML/mirror/内容实例保持，下水道 wetFrames=0。每案均核对 64 房接口和版本/主种子。详见 growth-results.json。正式文件的 release-smoke-12.2 / release-smoke-12.3 各 2 案、37 房通过，日志版本和文件哈希均正确。
- 一些成功单案保存在整体后来失败的运行目录中：driver-descending-flight-failed 的 v12.2 工厂/避难厩；driver-hanging-ladder-failed 的 v12.3 工厂。必须按单案引用，不能将父运行改报全过。
- 驾驶器失败均原样冻结：梯子 0.25 像素落脚误差、斜梯与下方地面混淆、应下降的边缘反复起跳。仅调整测试按键/选路，不移动角色、不改地图/家具；生成器与候选指纹未变。
- 六模组全组合、联机、所有种子和长期扩张未覆盖。出生房无奖励箱时 cacheStayedEmpty=false 是该项不适用；存在且领取过的箱子若补货会令整案失败。

## 5. 已知问题与机制

- D/V 接入风险：RREcology 主池也能出炮塔，不能只改 security；合并前矩形不能各分一份预算，家具已有原生 cont。容器 mine=0 不能阻止 cont 自带刷怪。公共机制见 native-container-latent-hazards / native-control-location-scope。
- 原版 UnitTurret.hack(0) 休眠，1/2 改阵营且不清已有 sleep；term1 控制全 Location 并有破解条件。顶炮 aRot=[30,150] 是待机扫描，非完整转角。HTML 核对机械可转向范围，但不模拟原版追踪、弹道、破坏；步行/梯路图不含跳跃，终端周围留 3 格不代表全路无敌人。
- 自然度仍待用户实玩：部分狭长空间/空墙，厚块偏矩形，合并房背景接缝与家具仍沿子矩形，城市屋顶顶边框；不是已等同原版的声明。
- 新分区中 sceneForm 是用途组合家族，非固定坐标；archetype 仅 connector 特例影响主体。旧 partition/profile 参数不可混作新链有效入口。XML 的 generator=space-v11 是沿用的元数据；实际版本看 rrVersion / rrMasterSeed 和日志。
- RRTraversal 只是地形图；真实通行还受单向梁、门、家具影响。普通长梯错开失败仍可能回退直梯。性能慢尾和分布偏向待进一步优化。
- 交互要满足 isLine 并持续按住；低门旁落梁只用双下，梯子没有接收平台时不能提前跳出。正常跳跃需长按数帧。
- 斜梯可读 tile.diagon/getMaxY；斜梯下的地面是独立路径。测试从坡面去下方地面应先到梯脚，再从实际落点规划；不能在半空追坡下节点。
- 必经干桥下一格脚点可能触水；干路图排除水面上一格。水下池底 stay 可能 false。
- setDoor/setNoObj 会省略 rem 物体：左右入口向内 6 格、上下 3 行；人口和家具要保留此净空。原版 Land 会改 tipEnemy，RRGrowth 已恢复。
- 测试归档已修正 PowerShell ISO DateTime 二次解析丢 UTC Kind 的问题；旧重复 PNG/XML 经 SHA256 去重，索引 duplicate-capture-index.json.gz。开始需 1 GiB 空余、每轮/归档上限 512 MiB、保留 256 MiB；不要重建巨大旧归档。

## 6. 下一步与回滚

- 新内容先在 design/danger-value-preview/index.html 比较；正式迁移须按最终合并房规划、分离随机来源，并测试真实入口/射界/特殊威胁与开箱事件。当前 JS 模拟不能直接当正式生成器；不得用其连通图检查替代原版通行和战斗。
- 当前部署里程碑已完成，等待用户实玩 v12.2 与 v12.3 的对照反馈；F2 回城后 F1 切版本，保持相同种子/场景，每次从第 1 层开始。F4 与右下扩张保持此次选择。
- 已验证备份 build/release-backups/RandomRoomsMod_before_v12_compare_20260924.swf。回滚时完全退出游戏，复制回 release/RandomRoomsMod.swf，核对 v11.1 指纹 16F3D2BD…6346C7F，再重启并进入新地图。部署时间/完整哈希在 design/v12-runtime-comparison/deployment.json。
- 根 pfe.swf SHA256 B78244657ED407D03808C90E97325509DB35F802122835F58933FFF8003305AC，ModLoader v2 读 mods/loader-manifest.txt。本轮读取发现加载名单发生外部更新，RandomRooms|RandomRoomsMod|1|1|0 仍正确，不覆盖它。
- 待用户实玩比较后继续完善合并房整体装饰/交通及性能；保持两个可比较版本，未经决定不要删掉 v12.2。

## 7. 深入阅读与复现

- 新预览：design/danger-value-preview/index.html、model-notes.md、validation.md；重新打包 build/style-review/build_danger_preview.py（模板同目录 danger-value-preview.template.html）。设计与原版证据：design/danger-value-2026-09-27/assessment.md、native-evidence.json；静态复现 audit_danger_value.py。
- 部署证据：design/v12-runtime-comparison/validation.md；两个 HTML 入口 design/partition-preview-v12-2/index.html 与 partition-preview-v12-3/index.html，各自 native-study/validation/evidence 保留对应原版调查和历史失败。
- 调查：design/native-scene-audit-2026-09-20.md；decisions/DEC-0005-architectural-generation.md、DEC-0006-scene-identity.md。
- 旧正式版实证：knowledge/experiments/generator-v11-density-validation-2026-09-20.md。教程：design/generator-explained-v11.1/guide.html，仅解释旧链，不能当当前新分区文档。
- 构建：build/build-v7.ps1 -OutputName RandomRooms-v12-comparison-next.swf。仅写 build；旧 build-m0.sh 直写 release，勿用于验证。
- 比对：build/style-review/harness/run-comparison.ps1；verify_comparison.py。汇总完整实际扩张：summarize_comparison_growth.py。
- 实机：build/style-review/game-harness/run-game-captures.ps1 -DevelopmentSwf <SWF> -GeneratorVersion 12.2 或 12.3；-ComparisonLifecycle；-AllScenes -Scenes @('plant','stable','sewer','mane') -NavigationProbe -GrowthProbe；-SmokeOnly -Scene plant。
- 隔离 SessionDirectory 为 app / visual-app / comparison-app；只通过独立 AIR 存储权限运行，不能借真实存储绕行。freeze_captures.py 只收完整成功且哈希匹配结果；失败用 freeze_failed_run.py 按新鲜时间窗口冻结。
- 正式 SWF 与运行目录不进 Git，冻结证据保持 Git 字节哈希。回滚历史见 journal 和既有验证报告。
