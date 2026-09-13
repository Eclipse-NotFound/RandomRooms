# RandomRooms —— 开发记忆入口

> 2026-09-13 用户明确“开始生成器改进”。v8已在重写与实机验证中，尚未发布；正式release仍为已验证的v7.1。


## v8 实施中（2026-09-13，不能当作已发布）

- RRArchitecture改为不等宽/不等高空间分割，先选无向连接图再开门/梯口；局部平台、错位短梯、随机数量的环与有用途的尽头。不再六套固定坐标布局。RRSynth rrGen=space-v8、rrRevision=8.0；旧space-v7仍受cook保护。
- RRPorts统一22个原版边口；RRMapPlan逐边提前定口，向原点的父连接保证地图连通，额外连接产生回环；普通上下口错位，约4%的连续纵向边允许同槽，非每4列竖井。
- RRGrowth统一初始/扩张：短暂用空池/非随机模式初始化空原版Land后同步恢复LandAct，再以原版newLoc/setDoor/mainFrame/setObjects/preStep/XP/map组装；正式rnd语义仍保留。每房生成时先反向变换镜像端口，再交原版镜像，前沿接口保持已探房XML不改。RandomRoomsMod在正常gotoLand前完成整图，并拦截原版crea重建请求。
- RRTraversal按两格净空、脚下梯格、落脚面检查有向步行/爬升/下落的双向可达，玻璃闭合。不能把下落当成返回证明；无可落脚梯顶或不可达的候选整房作废后重生，48次上限。
- 初版1024房/cook通过，但随后又改了短梯、地图哈希、窄室家具和脚下梯格判断，最终仍须重跑。最新64房generated-v8-c.xml与b同内容，SHA256 1913AF65991BB75D16402DD9D36184B6958DFBF7F203CA59CB2450215CAC3F50；c执行了最新脚下梯格检查。
- 候选build/RandomRooms-v8-candidate.swf，31789B，SHA256 6E638D2894AB940DC5158B4D89A26833D975C6834D869D5D277AD52B8E0992F4。独立实机已进入F5/F1（12/25房），升级后的全槽接口/镜像/地图连通检查零问题；不等于多入口物理往返通过。
- 新NavigationProbe.as按原版Tile读路径，正常行动键/爬梯/跳跃逐入口往返并访问各space，不写坐标/碰撞/地形；测试起点由原版旅行curCoord选择房间后正常spawn。驾驶器仍在调整：早期会在平台边缘漏掉落地转折或未落稳就横移，造成超时/意外跨房；均如实失败记录。
- 最新实机查到真正的恢复缺陷：RRGrowth.restoreOpening只Tile.dec不重做Location.buildLoc的梯顶shelf/vid，底部新短梯头失去自动落脚面。候选已补回，并重新实测中。原版Unit.checkStairs仅按脚下格，正梯X=tile.phX2-scX/2，负梯X=tile.phX1+scX/2；测试图不能把相邻两列/头部梯格都当作可爬。
- 当前持续工作：新多入口正常操作验证→扩張实机往返→结构分布/多种子→原生截图评审页→release门禁与部署→更新记忆。未通过前不替换release，不声称v8完成。

## 1. 模组与当前版本

入口 release/RandomRoomsMod.swf，public static init(main)。C/v7 从零生成建筑空间，再按用途布置家具，不复用原版整房/地形片段。
正式 release 27326B，SHA256 F4C1E36E4E9038EBCF86AFB433EDAA0854F9A8F588B5850723DA13781D3250C8。日志 [RR:v7.1]，XML rrGen=space-v7、rrRevision=7.1。
F1全生成冒险土地，初始5×5并向右/下扩张；F5为4×3四主题展示馆。F4进入新深度层。

## 2. 用户已确定的方向

- 中文。土地=一次旅行完整地图；合成房=25×48土地格；房间=内部功能空间；通道=内部连接。
- 用户比较A/B/C后批准C正式生成器，随后明确要求保留右/下无限扩张，不能改为有限5×5+F4。
- 本轮用户指出缺门/活板门，并要求检查窗户；已补齐原版交互物件及玻璃窗。
- 2026-09-12用户反馈横竖三段式、部分中央跨房竖井太重复，要求头脑风暴。已确认：普通房错开上下连接，少数特殊场景保留长井；允许较强探索/错层/多高度出口；回环为主、少量有内容的尽头。
- 2026-09-13用户强调不同合成房不能套近似路线，玩家可能从上下左右任一开放口进入。所有实际边口均可进出，不能预设首入口/终点或按进入方向重排房间。回环为主是总体倾向，不强制每房同一主路/环/支路配方；各房的分岔、狭窄连接点、多层连接关系也要变化。
- F1冒险/F2回城/F3旧测试/F4进深/F5展示/F7跳合成房；F8/F9留给其他模组。
- 需重启游戏，再回城进入新随机土地以生成新内容。真实存档、根/DLC游戏SWF未动。

## 3. 已完成实现

- RRArchitecture六普通布局+全高connector，RRFurnish按空间用途摆设；RRSynth负责XML与检查。梯顶、落脚、门窗周围先预留。
- v7.1每房附室入口有主题门（stable stdoor / plant door2 / sewer door1b / mane door1），真实尺寸建门洞；门与活板门初始关闭、lock=0 mine=0。
- 每房一处两侧有楼板支撑的2×1梯口活板门，hatch1或hatch2；保留Tile.stair，避开地图外连接口。
- 内部隔墙加入真实window1/window2，窗楣/窗台/双侧净空完整；避难所用装甲玻璃，下水道目标1扇、其他2扇。背景窗继续保留，玻璃不承担必经通路。
- F1池62/初始25格，每次一主题；F5池34/实际12格四主题。C池不接受旧cook变异/重复扩池；原版其他土地保留旧P0。
- RRGrowth提前一房生成行列，每4列竖井延续。完整newLoc/配对/mainFrame/setObjects/preStep/XP/map；旧边界按XML+mirror恢复两格接口stair与opac再重绘。
- 初始化等待31原版加载器loaded且allroom非空后切roomsLoad=0，v7.0已修复基地buildProb偶发#1009；本轮保持。

## 4. 本轮验证

- 真实AS3普通1024房+connector64房，cook前后均过尺寸/端口/对象占位支撑/门窗框/梯口/锁雷/2×2几何净空。总2567门、1088活板门、1904玻璃窗。玻璃按闭合阻挡检查，不假定破窗才能走。
- 六型固定实机：所有门盖原版开关碰撞、玻璃原版damage破碎清障通过；随后从自然出生点正常走至梯子、行动键开盖、爬至上方，6/6成功，最终isLaz=1。玻璃伤害测试不是逐武器射击。
- 独立六型横穿6/6，正常开门后进入邻房。对应图片及记录冻结design/assets/v7-1-fixtures，六张整房均已目检，并检查了开盖后的游戏屏幕。
- 最终候选整图自然5×5→8×8，进(5,0)新列、沿第4列逐个开活板门下到(4,5)新行、上爬回(4,4)，1909帧成功，(975,984.75)/isLaz=1。101房池、64实际格、接口零问题；新增池门窗检查也通过。
- 正式release路径隔离重启，appId pferr-style-bea52955a6fc40ffa8054811e91d81fe；F5/F1完成，34/62池全新门窗、连接零问题；实际原始日志出现v7.1，退出0，manifest complete。
- v7.0先前1024房同种子复现、固定竖井往返、扩张至8×12、四次旅行和启动屏障正反对照仍见旧报告，不冒充本轮重复测试。

## 5. 已知边界与机制

- 六种普通布局仍有重复规律，可继续增加用途关系、破损/生活细节。未穷尽随机种子、长时间扩张资源、联机、真实旧存档或六模组集成。
- 隔离测试newGame(-1)，独立pferr-style-GUID；整模组模式由隔离根自写TDFC薄壳载入原封RR，装载调用方与正式RR loader不同。真实其他模组未访问。
- AIR测试需独立AppData存储；默认沙箱下整模组首跑在applicationStorageDirectory创建时#3003，尚未载模组。经工具权限审查后同夹具运行通过，不能改真实pfe存档路径。
- 原版Location.getDist按round(celX/40)对应visi格决定是否清celObj。活板门测试瞄中心可能在暗格；应瞄真实可见表面并沿梯接近，保留原版距离/视线检查。
- hatch2图像高48px而碰撞格高40px。测试上爬成功高度取Tile楼层，不取图像凸缘；不能因此改生产碰撞尺寸。
- mainFrame封边清stair并设opac=1，Tile.dec不清opac；扩张恢复需同时处理。空doors不是22口默认值；普通5/16=3，connector另8/19=2，中心x23/24上下开孔。
- 装甲玻璃window2 hp1000/thre100，不能用小伤害未打碎推断失效。lov是陷阱，沙发用couch。

## 6. 构建、发布与回滚

- build/build-v7.ps1只输出build；当前候选RandomRooms-v7-fixtures-candidate.swf与release同哈希。旧build-m0.sh直接写release，普通验证不用。
- v7.1回滚备份：build/release-backups/RandomRoomsMod_before_v7_1_20260910.swf，26595B、SHA256 9B547CF23C239DEBCCF1872D00F63CF50D138AF2AE172867C06C2458515E3583。复制回release并重启。
- v6.6历史备份仍在build/release-backups/RandomRoomsMod_before_v7_20260910.swf。
- 根pfe SHA256仍5300EC4874E0404D298BB58C5D2A7469E82F93B455AD29AD64DD2E29D17241E7。
- 发布按release-gate；当前仓库main，准确提交见git log；release与大规模可再生输出不入Git，固定截图和精简证据入Git。

## 7. 后续入口

0. 最新设计草案 design/structure-diversity-brainstorm-2026-09-12.md（9月13日修订）。建筑空间和连通关系共同生成、协调邻房共享开口，取消固定入口到终点的逐房路线假设；形态例子只作变化参考。验证从每个实际开放口分别进入，覆盖其余边口与可探索区的双向可达、镜像及扩张，不要求每间四面全开。本轮用户已授权并已开始实现；当前实现/验证状态见文首v8实施中。
1. 最新报告 knowledge/experiments/fixtures-v71-validation-2026-09-10.md；精简清单fixtures-v71-evidence。
2. design/generator-v7-review.html已更新v7.1，可标出门/活板门/玻璃窗并切换开盖屏幕；原PNG不加标记。浏览器工具file策略阻止自动交互，本地脚本语法与资源检查通过。
3. 决策DEC-0005；v7.0建筑与扩张报告style-generator-validation-2026-09-10.md，调查build/style-review/VANILLA_FINDINGS.md、furnishing-reference.md、v7-space-audit.md。
4. 实际AS3输出harness/run-baseline.ps1，-RoomKind connector可强制竖井；build/verify_architecture.py独立读取AllData尺寸。
5. 游戏夹具game-harness/run-game-captures.ps1：-FixtureProbe -ArchitectureKinds六型门窗，-CrossingProbe横穿，-DevelopmentSwf结合-GrowthProbe或-SmokeOnly。详情见README。

Q1–Q3及任意入口/不同路线要求已明确，无需再问一次。设计讨论继续沿这些约束；原型需解除固定楼板高度、底层左右出口、中央上下口和每房必出活板门等内部假设，同时保持出口配对、从任一实际边口进入后的真实可达与可返回、镜像与扩张恢复。
本轮只读统计显示1024样本全部在第16行有至少连续6格楼板；原版允许上下五个横向槽、左右六个高度，跨界必须成对对齐。偏置连接的实机表现待测，不能只移动梯子坐标。完整事实与原版四例见最新草案。
