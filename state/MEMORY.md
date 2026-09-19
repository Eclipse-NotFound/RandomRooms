# RandomRooms —— 开发记忆入口

> 2026-09-20：四类场景分离完成，v9.0 已部署。生成、场景保持、多入口、右下扩张、污水、门窗和正式路径隔离重启验证通过。本页替换 v8 与 v9 进行中快照；历史过程见 journal。

## 1. 模组是什么

- 为 Remains 1.02 从零生成建筑空间，按用途摆设原版资源；不复制原版整房或地形片段。
- 工厂、废弃避难厩、下水道、城市废墟有各自空间关系、材质、门窗、设施与原版环境。一场探索保持同一场景，地图向右、向下无限扩张。
- 固定入口 release/RandomRoomsMod.swf，入口类 RandomRoomsMod，public static function init(main:*):void；中文使用说明 README.md。

## 2. 用户决定与协作边界

- 土地=一次旅行完整地图；合成房=48×25 土地格；房间=内部功能空间；通道=内部连接。
- 已采用 C 从零生成；无限右下扩张不能改成有限 5×5 加 F4。取消固定三段式、中央井与统一穿房路线；普通上下连接错开，少量特殊场景允许对齐。
- 较强探索、多高度出口、错层和分支；总体回环为主，少量有内容的尽头，不给每间强制同一配方。
- 上下左右任一实际开放边口均可作为入口，均须能返回；不要求每间四面全开，不指定首入口，不随进入方向重排。
- 门、活板门、玻璃使用原版交互；无每房必出活板门配额。
- 本轮先完整分离四类。一次探索、扩张和 F4 固定场景，回城再换；F1 四类入口加随机。下水道真实原版污水，必经路线有干路，涉水可选。
- F1 场景选择冒险，F2 回城，F4 新深度层，F5 场景选择展示馆；F3/F7 保留旧诊断。F8/F9 留给其他模组。
- 重启游戏后回城再进入新随机土地；旧已加载地图不会自动转成新版。已决定事项不重复提问。
- 只改本模组；根/DLC 游戏 SWF、真实存档、其他模组不改。测试独立 pferr-style 应用与 newGame(-1)；不使用 Ghost。

## 3. 当前状态

- v9.0 已部署，日志 [RR:v9.0]，XML space-v9 / revision 9.0。仓库 main，准确提交查 git log。
- 正式与 build/RandomRooms-v9-candidate.swf 一致：37785 B，SHA256 7DC5DB91D6FCE0802EEE73BD3312C6724FB0BCF16A2B48246D00554BEFD8BC4E。
- RRScene 集中场景构造、用途和资源，继承原版环境但不继承地图构造 conf。城市 backwall=sky 保留原版远景；下水道局部真实池水 wtip=1、wrad=3，不按整行灌水。
- RRArchitecture 先安排场景主要空间再变化分割。RRFurnish 按场景与用途选择完整或紧凑组合，无跨主题沙发回退。避难厩钢梁、城市混凝土梁均用原版字符。
- RRPorts/RRMapPlan 仍负责全部 22 槽、共享边、镜像与错位。RRTraversal 审计两格姿态的有向可返回路线，下水道另审不触水路线。RRSynth 最多 48 次重试，cook 保护兼容 v7/v8/v9。
- 选择器支持鼠标、1–5、小键盘与 Esc，保存并恢复暂停状态；F4、扩张和重建沿用场景。未知场景报错。
- 1280 单房与 288 地图房独立检查通过，cook 前后是同批房，不能重复计数。12 种构造均出现。
- 最终候选生命周期 12 项通过；四类多入口正常移动 76/76，包含所有内部主要空间/夹层及各实际端口往返；下水道 wetFrames=0。可选涉水 2/2，20 帧真实 inWater 后返回干路。
- 四类各正常进入新增列、新增行并返回，均 4/4、5×5→8×8，最终各 64 房同场景、接口零问题、原 25 房 XML/mirror 不变。工厂/避难厩/下水道为失败总轮中的明确成功项，城市另轮通过；没有把失败清单改写为通过。
- 十二构造原版截图和 19 门、14 活板门、18 玻璃循环通过。24 原始 PNG 与评审页已冻结。
- 正式路径新实例 pferr-style-8c3f5e36bbc041d58753e21b0898cbdd：v9 日志、F5 12/12、F1 25/25、零接口问题、退出 0、complete。没有替用户重启其正在运行的游戏。

## 4. 正在进行与卡点

- 本轮四类分离、验证与发布已完成，无阻塞事项。用户可重启后直接比较四种场景。
- 未验证范围不是已承诺待办；下一轮按用户实际画面反馈定位，不自动重开方案拷问。

## 5. 已知边界与调试线索

- 结构仍偏直角，部分大墙面与生活痕迹可丰富。下水道重试使水渠多于集水池，未承诺构造均匀分布。
- 未穷尽所有种子、长期扩张内存、联机、真实旧存档重启/死亡恢复、六模组集成或逐武器破窗；未单独测原版辐射伤害数值曲线。
- 城市整房图不含独立远景层，室外为黑底；游戏屏幕有原版远景。PNG 未重绘；页面标记另层叠加。
- AS3 可返回审计和 Python 干路净空检查不替代原版物理；真实移动只发方向/爬梯/跳跃/行动键，不改坐标、碰撞或地形。跨房 controlOn 会清 invulner，测试持续保护仅排除战斗。
- 原版梁可能抬高落脚；双按下若后蹄压实体墙会拒绝穿透。梯子按脚下格吸附，抽象两格中心可能不同；侧向离梯须先到出口高度带，下降不能提前对齐远处低层梯边。
- 空中松开水平键仍有惯性，测试驾驶器需按 dx 提前反向减速，保留缺口两侧真实站立节点。原失败城市房 7/7、643 帧原样通过；避难厩失败房 10/10 原样通过。
- 活板门可在脚下，光标须瞄真实可见表面。hatch2 图高 48 px、碰撞 40 px；window2 hp1000/thre100；lov 是陷阱，沙发是 couch。
- AIR 独立 AppData 在默认沙箱可能 #3003，按工具权限审查运行隔离测试；不能改真实存储绕行。

## 6. 下一步与回滚

- 用户实测后按具体房间、场景和入口调查；优先提升场景细节，不重做已确定的探索规则。
- v8 回滚备份 build/release-backups/RandomRoomsMod_before_v9_20260920.swf，32035 B，SHA256 5F340D05EDDFD14488D7330D6D499849F76DE9C1B0CBFEA1E818224204C46E8F。复制到正式入口并重启，禁止覆盖备份。
- 根 pfe.swf SHA256 5300EC4874E0404D298BB58C5D2A7469E82F93B455AD29AD64DD2E29D17241E7 未变，根/DLC SWF 未修改。
- 发布走 release-gate；release、备份、大型运行目录不进 Git，源代码与冻结图/XML/日志/清单进 Git。

## 7. 深入阅读与复现

- 决策 decisions/DEC-0006-scene-identity.md；调查 design/scene-separation-2026-09-19.md；实景 design/generator-v9-review.html。
- 本轮报告 knowledge/experiments/generator-v9-validation-2026-09-19.md；证据 generator-v9-evidence/ 与 design/assets/v9-scenes/。完整清单用文件指纹识别运行，growth-partial 用独立 evidence-index 保留失败总轮。
- 构建 build/build-v7.ps1 -OutputName RandomRooms-v9-candidate.swf，只写 build；旧 build-m0.sh 直写 release，不用于验证。
- build/style-review/harness/run-baseline.ps1 导出正式 AS3；build/verify_architecture.py、verify_scenes.py 独立核原版 AllData、场景用途与干路。
- build/style-review/game-harness/run-game-captures.ps1：-DevelopmentSwf、-SceneLifecycle、-NavigationProbe -AllScenes、-NavigationProbe -Scene sewer -WaterProbe；扩张必须 -NavigationProbe -GrowthProbe，可配 -AllScenes 或 -Scene；-SamplesPerScene 3 -FixtureCyclesOnly 生成十二实景与门窗循环；-SmokeOnly 验正式路径。
- build/style-review/freeze_captures.py 仅接受 complete 运行并核哈希；build_scene_review.py 从冻结十二样本生成页面。旧固定底层 GrowthProbe 不适合多高度接口。
- 游戏机制公共来源：shared-knowledge/physics-collision/discoveries/collision-motion-source-audit-2026-09-09.md、world-objects/discoveries/room-port-restoration-and-ladder-heads.md（相对游戏根）。
