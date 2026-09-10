---
domain: knowledge-validation
type: experiments
game-version: ["1.02"]
confidence: high
verified: true
discovered-by: RandomRooms
evidence:
  - kind: game-source
    symbol: "AllData object definitions; Box.initDoor/setDoor/damage; Interact.setAct; Location.getDist; UnitPlayer.actAction"
  - kind: local-experiment
    summary: "1088 actual AS3 rooms, six native fixture cycles, six normal hatch climbs and six horizontal crossings; details below."
date-updated: 2026-09-10
---

被测技能：remains-auto-testing、remains-mod-build、remains-runtime-debug、remains-release-gate。
技能归属：D:/Program Files/Steam/steamapps/common/Remains/.agents/skills。
测试工作区：D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms。

# v7.1 门、活板门与玻璃窗

## 请求与实现

用户在 v7 实景页指出缺少门、活板门，并要求检查窗户。查实 v7.0 只有部分
房型安排 stdoor，没有活板门；背景窗不等于隔墙内的玻璃窗。此次在既定 C
建筑生成中补齐原版交互物件，保留右/下无限扩张。不重新开启设计问卷；没有
分派子代理，本轮工作为既定功能的连续实现与实测。

- 普通六房型与 connector 都有附室入口门，按 stable/plant/sewer/mane 分别用
  stdoor/door2/door1b/door1；门洞按真实两格或三格高度生成，预留门框与通路。
- 每房在一处有两侧楼板支撑的梯口放 2×1 活板门，城市/下水道用 hatch1，
  避难所/工厂用 hatch2。保持梯子信息，远离地图外边界，不拿活板门封死连接口。
- 内部隔墙有窗楣、窗台且两侧空间敞开时放 window1/window2。避难所用装甲玻璃，
  其余主题用普通玻璃；下水道少放一些。新增玻璃不承担唯一必经通路。
- 开门、开盖均沿原版交互，初始关闭且 lock=0、mine=0；玻璃使用原版材料和
  伤害规则。生成器先保留这些物件周围空间，再布置家具，背景窗也继续保留。
- XML 标识 rrGen=space-v7 保持原有 cook 保护，增加 rrRevision=7.1 和对象
  rrFixture 分类。日志与启动文字更新为 v7.1。

## 原版机制证据

参考源均位于 game-reference/decompiled/1.02/src102/scripts/，只读调查：

|原版对象|占格|材质/行为|
|---|---|---|
|stdoor|1×3|金属门，原定义可随机锁门/埋雷；本生成通路显式覆盖为零|
|door1 / door1b / door2|1×2|分别木门/金属门/重门，原版 Interact 开关|
|hatch1 / hatch2|2×1|木/铁活板门，Box 修改两格碰撞，保留 Tile.stair|
|window1 / window2|1×2|玻璃材质5、opac=0.2；HP10 / HP1000，后者伤害阈值100，无开关交互|

Box.initDoor/setDoor 负责真实 phis/opac 和 Tile.door，打开后清碰撞；关闭时恢复。
Box.damage/die 使玻璃破碎后清除阻挡。不是只画门窗贴图。

## 输出检查

真实 AS3 分两批导出；普通房每主题256，共1024，连接竖井每主题16，共64。
各自再经过真实 cookPool，生成房新增副本为零。检查脚本读取原版 AllData
对象尺寸，验证门框、窗框、梯口支撑、占位、锁雷、22口与2×2净空；玻璃按
未破坏的阻挡计入，门和盖按正常可打开计入。几何净空本身不等于真实物理可达。

|批次|房数|门|活板门|玻璃窗|检查|
|---|---:|---:|---:|---:|---|
|普通房|1024|2439|1024|1792|通过|
|connector|64|128|64|112|通过|
|两批 cook 后|1088|2567|1088|1904|通过，物件计数保持|

[检查与输入哈希](fixtures-v71-evidence/geometry-checks.json)。普通输入
generated-v71.xml 的 SHA256 为 0C3C026ED5CE480D8B6E2688063C65068F794E01117235F8BAA538A510B7523E；
connector 输入为 D9468CA298A23D36CF1A8676EBF5C255B1BB8B0A3052C7B4771F006D9C5847AB。
普通批次先于 connector 的 reserve(21..26) 调整，但普通分支未变；竖井批次及
整模组实测使用调整后的最终源码。

## 六型实机交互与穿越

隔离的独立 pferr-style 应用，原封根 pfe 副本、正常 newGame(-1)/beginMission，
固定案例去掉敌人。先拍原始图，再逐对象运行原版 setAct 开→关并断言碰撞；
逐窗调用原版 damage(100000)，断言破碎后清除碰撞。这只验证原版伤害函数，
不等于每种武器的射击结果。每房均通过。

随后角色从真实出生点走到梯子，Camera 瞄准可见表面、Ctr.keyAction 打开盖，
Ctr.keyBeUp 爬至对应楼层；这一段没有直接打开门或设置角色坐标。

|房型/主题/原房|开盖上爬帧数|成功时Y / isLaz|
|---|---:|---|
|atrium/stable/syn_120|335|319.5 / 1|
|workshop/sewer/syn_401|299|639.75 / 1|
|offices/plant/syn_513|179|639.75 / 1|
|damaged/mane/syn_832|158|319.5 / 1|
|service/stable/syn_0|391|319.5 / 1|
|warehouse/sewer/syn_257|293|639.75 / 1|

appId pferr-style-7f0fc9cb4fcc41939aaca946663d739f，manifest complete、6/6 success。
证据：[原始清单](../../design/assets/v7-1-fixtures/manifest.json)、
[移动结果](../../design/assets/v7-1-fixtures/movement.json)，同目录含每房
fixtures.json、初始 room/stage 图与开盖后 stage 图，原始截图未修改。

独立六型横穿也全部通过，appId pferr-style-a009022e4e6b47a5834a9e7cf65d030c。
每案从起点正常行走、遇门以正常行动键开启，进入 locX=1；
[清单](fixtures-v71-evidence/crossing-manifest.json)、
[逐案结果](fixtures-v71-evidence/crossing-movement.json)。

## 测试夹具的修正与环境边界

- 早期活板门测试光标瞄中心，Location.getDist 会因对应格 visi<0.1 清空
  celObj；看到 onCursor>0 并不足以证明可以操作。修正为选择实际可见的
  物件边缘，保留原版距离与视线检查；不可见时继续上爬接近，不提前停住。
- hatch2 图像高48像素，但占一格40像素；旧测试以图像顶部+4作成功门槛，
  角色已经抵达320楼层仍被误判。改为真实Tile楼层高度。最终六案截图/坐标
  同时确认。失败轮保留于 game-harness/app/history，未当作生产缺陷抹去。
- 首次整模组扩张试跑 appId pferr-style-96e744f32d0347c8ae94dc93960408f2 在
  AIR applicationStorageDirectory 创建时 #3003，尚未加载开发模组。测试的
  独立 AppData 目录超出工作区默认写范围；经过工具权限审查后运行同一
  隔离夹具。真实 pfe 存档和其他模组没有被读取/修改。
- 浏览器工具对已打开的 file: 评审页返回 URL 策略阻止，因此没有自动点击
  页面控件；没有改用其他地址绕过。PNG 已直接人工检查，页面数据/资源引用
  与脚本语法另作本地检查。彩框仅是 HTML 叠加，不改原图。

## 整图扩张与发布

最终候选27326字节、SHA256
F4C1E36E4E9038EBCF86AFB433EDAA0854F9A8F588B5850723DA13781D3250C8。
构建零错误/零警告；实际部署的字节与该候选一致。

整图 appId pferr-style-233c1c7ee73243fe9f749460bf5b85c4：正常 F1 生成 stable
5×5，从 (0,0) 出生走入 (5,0) 的新增房 syn_100000，返回第4列梯井，正常打开
沿途 hatch2，下行进入 (4,5) 的新增房 syn_100019，再实际沿梯上爬回 (4,4)
rr_exit。全程1909帧，成功坐标 (975,984.75)、isLaz=1。导出时已为8×8/64格，
池101间；连接零问题，新增池检查也通过（258门、101活板门、202玻璃窗）。
受击保护与逐房回血只隔离战斗消耗，没有 godMode 或改玩家坐标；下行含沿梯井
落下，上行另有 isLaz=1 证据。

证据：[扩张清单](fixtures-v71-evidence/growth-manifest.json)、
[路线日志](fixtures-v71-evidence/growth-runner.log)、
[移动结果](fixtures-v71-evidence/growth-movement.json)、
[新增池检查](fixtures-v71-evidence/growth-pool-checks.json)。完整 XML/图片归档于
build/style-review/game-harness/app/history/pferr-style-233c1c7ee73243fe9f749460bf5b85c4-2f85d749/。

已备份 v7.0 并替换正式 release/RandomRoomsMod.swf，随后**从正式 release 路径**
重新启动隔离实例 pferr-style-bea52955a6fc40ffa8054811e91d81fe。F5与F1都完成：
F5池34间/实际12格/四主题，F1池62间/实际25格/plant；两份实际连接与池检查
均零问题。原始日志出现 `[RR:v7.1]` 与 `RandomRoomsMod v7.1 loaded`，31个
原版加载器就绪，进程正常退出0、manifest complete、临时描述符已清理。
[发布清单](fixtures-v71-evidence/release-manifest.json)、
[实际版本](fixtures-v71-evidence/release-production-version.json)、
[原始日志](fixtures-v71-evidence/release-production-diag.log)、
[入口池检查](fixtures-v71-evidence/release-pool-checks.json)。

此开发SWF测试仍使用本隔离根的自写TDFC薄壳载入原封RandomRooms，调用方与
正式RR loader不同；未访问实际TDFC源码/配置，不把它称为六模组集成测试。
实际游戏运行已加载的旧SWF不会热更新：需重启，再回城进入新随机土地。

回滚：将 build/release-backups/RandomRoomsMod_before_v7_1_20260910.swf 复制回
release/RandomRoomsMod.swf，再重启。备份26595字节，SHA256
9B547CF23C239DEBCCF1872D00F63CF50D138AF2AE172867C06C2458515E3583。
根 pfe.swf 保持 SHA256 5300EC4874E0404D298BB58C5D2A7469E82F93B455AD29AD64DD2E29D17241E7，
没有修改游戏本体、正式描述符或真实存档。本轮没有独立 changelog 文件，版本
记录进入 MEMORY/journal，并提交模组仓库。

## 验证范围

此次确认具体样本的尺寸、交互、显示和通行，不承诺穷尽随机种子、联机、
多模组集成、极长扩张资源上限或所有武器。通路门默认关闭但可直接开启；
不要求打碎玻璃才能完成路线。继续开发时保留这些约束。
