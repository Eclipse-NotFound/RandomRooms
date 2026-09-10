# 原版渲染器中的房间对照

```powershell
& './mods/RandomRooms/build/style-review/game-harness/run-game-captures.ps1'
```

默认输入：原版 `Rooms/rooms_stable.xml` 首房 `13`、基线 `baseline-v66.xml`
首房 `syn_0`，以及存在时的 `prototype-a.xml` 首房与 `prototype-c.xml` 前两房。
可通过 `-PrototypeFiles @('绝对路径.xml', ...)` 覆盖额外输入。输入须为根节点下
直接含 room 子节点的 XML。工具不编译或修改模组正式 src。

## 隔离方式

- 独立应用根为本目录 `app/`；复制当前根 pfe.swf，不打补丁。
- 资源白名单为 pfe、四个纹理/精灵 SWF、三个声音 SWF、lang/en、Rooms、
  四首启动/基地/测试音乐。总计 130792993 字节（124.73 MiB）；超过 300 MiB 中止。
- AIR runtime 与 adl64 从安装根直接运行，不复制。固定房模式只存在自己的
  `mods/RandomRooms/release/RandomRoomsMod.swf`，文件是本目录的测试驱动器。
  该路径位于 build 隔离根，不是正式 release。其他模组的硬编码 loader
  会报告找不到文件，预期不加载；未读取其他模组代码或配置。
- 每次生成唯一 `pferr-style-<GUID>` appId。引擎的新档/配置属于这个测试
  appId；不读写真实 pfe 存档。显式截图与日志均写本工作区。
- 窗口隐藏、无合成按键、无前台焦点依赖。外层普通截图120秒、短程240秒、
  整模组360秒超时，只杀本次启动
  返回的 PID；完成后删除本次临时应用描述符。

## 真正执行的路径

现有宿主 loader → 测试驱动器 static init → 等待 landData、全部土地 XML、
文字和图像资源就绪 → mainMenuOff → newGame(-1, LP, {propusk:true}) →
等待基地建好 → 为各输入建立不同 id 的 1×1 LandAct → beginMission →
双重确认 game.curLandId 与 land.act.id → 2.5 秒稳定等待 → 截图。

每房强制 options.tip=beg0，以唯一候选方式从正常 Land 建造入口进入；
两侧对照均移除 en* 标记、entip=0、kolspawn=0，便于观察建筑。其他物件
属性原样保留。没有 gotoXY，没有手工改 curLandId，没有直接 enterToCurLand。
此设置只验证固定单房的装配及显示，不验证整个随机土地或跨房游玩。

## 截图与边界

- `app/captures/<case>-stage.png`：真实游戏窗口，保留游戏光照和界面。
- `app/captures/<case>-room.png`：原版渲染树整房图，1:1 坐标，1920×1000。
  为统一曝光，截取时临时关闭 `grafon.visLight` 玩家视野遮罩并立即恢复；
  这是整房诊断视图，不是玩家屏幕的原样截图。
- `app/captures/runner.log` 记录真实 land/room 名称、尺寸和曝光模式；
  `app/stdout.txt` / `stderr.txt` 收集运行时输出。

2026-09-10 最终统一批次已实际运行 5 案例，约 80 秒，正常退出 0：

| case | 运行时 Room id |
|---|---|
| rrstyle-original | 13 |
| rrstyle-baseline | syn_0 |
| rrstyle-prototype-a | syn_0 |
| rrstyle-prototype-c-0 | rule_stable_0 |
| rrstyle-prototype-c-1 | rule_stable_1 |

五者均生成 stage（1008×729）及关闭视野遮罩的 room（1920×1000）图。
runner.log 无 FAIL，记录 DONE 5 cases；进程正常退出，临时描述符已删除。
测试 pfe 副本与当前正式 pfe 的 SHA256 相同：
5300EC4874E0404D298BB58C5D2A7469E82F93B455AD29AD64DD2E29D17241E7。
当时正式 RandomRooms release 保持原哈希 5E3D611C9C38F19FEB30D0DB535BFDC6D1040FE8CF3A5B6F8EC39131E2DA4A00；
后续正式发布的验证见本文末尾。

最终 C 源 XML SHA256：
B3924528DB2DC26461394414DC8F9327472D20727560A937A1D4AED72AA03CA4。
最终有效 cases.xml SHA256：
1F31A5F41A275DE5E6544DEB7535A8A45AED5EB0669693F600D5FF283B5E92F0。

人工查看：C 加入平台、长梯与附室；上一轮 rule_stable_1 的悬空楼梯已在
最终图中接上中层楼板。A 清理材质噪点后仍是巨大空腔。
纯字符检查、成功截图均不表示可达性、摆放正确性或观感已经通过。

脚本现在每次自动把上次 captures、cases.xml、stdout/stderr 复制到
app/history/<旧appId>-<随机后缀>/。当前 manifest 自动记录源 XML、有效
输入、宿主、驱动器、日志与截图的 SHA256，并验证每张图片来自本次运行；
失败时写 status=failed，不留下旧的成功 manifest 冒充本次通过。

## 已完成的真实操作采样

原版 `fe/inter/Ctr.as` 的 keyLeft/keyRight/keyBeUp/keyJump 为 public；
Ctr.step（349 行）不重置持续键。UnitPlayer 的移动代码（约 2534 行）
读取左右键，爬梯代码（约 2931 行）读取 keyBeUp 和 Tile.stair。
可从自然出生点执行三段有时间上限的动作：横移到梯脚 → 上爬 → 顶部横移；
每帧记录 gg.X/Y、isLaz、stay、实际房名，每段末 clearAll 释放输入。
这走真实物理，不需要 KeyboardEvent、setPos 或 gotoXY。

冻结 C 原型前两房已运行 `-MovementProbe -MovementOnly -PrototypeFiles
@('../prototype-c.xml')`：从自然出生点到梯脚、爬到顶、短跳落到平台，6/6段
成功。两房落脚分别 (389.35,320)、(266.05,360)。游戏退出0本身不等于
物理通过；应看 `movement.json` 每段的 success、坐标和房号。

`-CrossingProbe -PrototypeFiles @('../formal-c-current.xml')
-PrototypeSampleCount 2` 已实际运行：正式C syn_0→syn_1用261帧成功进入
locX=1；旧冻结原型因空doors，在相同驱动下601帧仍卡右边界。驱动只持续
向右、受阻时短跳，动作和失败边界记录在 runner.log。

`-ArchitectureKinds` 从输入XML选六种建筑并尽量覆盖四主题；可与
`-CrossingProbe` 配合分六个2×1案例运行。`-VerticalProbe` 选择输入池前两
个connector，正常建立1×2土地，从出生点走到梯井，按下蹲键下行、上键
返回；尚未经过本轮结果审阅的案例不应仅凭选项存在宣称通过。

实际竖井采样已成功：F5实际导出的syn_24/syn_25正常1×2装配，从出生
(81.8,960)走至中央；下行16帧进入locY=1至(975,192.5)，上行29帧回locY=0
至(975,984.75)、isLaz=1。2/2段success、manifest complete。此结论限固定
1×2原版物理路径，不能代替整图扩张验收。

## 完整开发模组模式

```powershell
& './mods/RandomRooms/build/style-review/game-harness/run-game-captures.ps1' `
  -DevelopmentSwf './mods/RandomRooms/build/RandomRooms-v7-dev.swf'
```

此模式仍以原封pfe副本为AIR入口。只在本harness的app根使用空的TDFC loader
槽位载入自写TDFCMod薄壳；没有读取、复制或修改真实TDFC。薄壳让StyleDriver
将原封开发RandomRooms SWF载入自己的子域，取得入口类后调用static init(main)。
因此实际执行的是开发SWF，调用装载器与正式RR loader不同，须分开声明。
固定房模式恢复自写RR薄壳，并删除隔离根的TDFC测试薄壳，防止重复驱动。

前两种失败路线已保留日志：同名RR驱动遮蔽实际类；外层Loader加载pfe会在
MainFE构造访问stage时遇null。失败的DevelopmentRunner源码已删除，避免误用。
单独已有原RR loader的complete/class/init returned证据；由于兄弟域不共享
定义，测试驱动无法直接取得其静态调试接口，故采用上述可观察的装载方式。

调试接口仅在pferr-style应用使用。流程为F5→回基地→F5、F1→回基地→F1，
用模组同一debugTravel路径触发刷新；不在目标土地内强制重入。每次导出
pool.xml、layout.xml和topology.json，按rrGen/rrTheme/rrKind记录生成池和真实
装配Tile端口。拓扑检查只证明边口，不代表屋内通行。外围封边会清除梯井的
外侧末格stair；已配对端口应保留相应末格，不能把每房25行梯当通用判据。

2026-09-10 首次完整运行：四次旅行全完成且游戏exit0；F5为34房池、12格，
F1为62房池、25格，池全部有rrGen；F5四主题，F1本次sewer→stable且池哈希
不同。后处理曾因普通房空tip键转JSON报错，已改用ordinary键；该轮保存的
failed manifest指后处理失败，不能误解为引擎失败。最终验收以新一轮manifest为准。

26485字节growth开发SWF再次完整运行四次旅行、八张图全部完成，四份真实
topology无问题，manifest complete。对应原始证据已自动归档于app/history/
pferr-style-b88fc6100adc4cb18addcc85052ad312-b2e169ff/。

`-DevelopmentSwf <候选路径> -GrowthProbe` 从正常F1出生点出发，目标为走进
原5列以外→返回列编号4的中央梯井→下行到原5行以外（行列编号均从0开始）。它使用公开Ctr持续输入，
遇闭门时把公开Camera光标坐标指向门，再用keyAction走原版距离/视线/解锁
检查；没有直接改门open，没有改玩家坐标。受击保护invulner=true、每房
healAll只用于隔离战斗消耗；没有godMode，原版缺少下邻房的die(-1)仍有效。
不要把这个模式的存在或process exit0当成扩张已通过，应核对movement.json。

六型正式XML实际横穿记录（输入generated-v7-final.xml，SHA256
1829D54A178AEE61859422B31EBEB28AC6E867C4A12B8BA3B7A6C2D7719D2139）：

|起点房|主题/建筑|进入下一房所用帧|
|---|---|---:|
|syn_120|stable/atrium|261|
|syn_401|sewer/workshop|277|
|syn_513|plant/offices|293|
|syn_832|mane/damaged|297|
|syn_0|stable/service|293|
|syn_257|sewer/warehouse|261|

6/6 success、12张真实stage/room图、manifest physicalPass=true。闭门通过
真实光标选中后按E打开，日志记录lock=0/mine=0及交互倒计时。证据在
app/history/pferr-style-783a3a5e48bf4311b7f421c756a37cbf-5469a149/。

候选26498字节首次完整扩张采样已从5×5走进locX=5的新房syn_100000，
再沿列编号4下行进入locY=5的新房syn_100019；最终8×7共56个实际房、池93房。
边口、梯链和开口透明度检查无问题；manifest complete且physicalPass=true。
证据在app/history/pferr-style-033d8c43c8fe40d7bf27ad16dce0fb0d-8406c8e3/。
该轮下行isLaz=0，属于沿梯井落下，不应描述为攀爬；即时跨界stage截图碰到
过场黑幕，不能用于观感评审。之后的夹具会延迟截图并追加反向上爬采样。

另有一次候选启动在基地newGame2→Land.buildProb出现#1009，立即退出且保留
history/pferr-style-eecb92b1bbc84838b602486e4da16832-99563007/；同输入复跑未重现。
这是当时尚未定位的启动失败，下文记录了后续定位及对照验证；不以之后的成功覆盖，
也不归因于未执行的扩张路径。

后续已由生产侧定位启动屏障：旧finalizePreflight过早将roomsLoad置0，使原版
任意一个加载回调即可报告allLandsLoaded。修复候选26595字节（SHA256
9B547CF23C239DEBCCF1872D00F63CF50D138AF2AE172867C06C2458515E3583）
已完成四旅行，debugReady当刻31个hostLoader均loaded且房池非空，四次拓扑
零问题。证据在app/history/pferr-style-30146cb7fe53401aaf35c5b2f6674928-39752199/。

`-SmokeOnly` 只运行F5和F1两次旅行；`-StartupDelay` 在prob原版加载完成后
暂扣其公开loaded标记，再初始化开发模组。保持约1.5秒逐帧断言debugReady
为false，恢复标记后沿正常帧回调等待ready并开档；保存startup-delay.json与
startup-readiness.json。XML不改，模组源码不改，仅这个隔离实例的标记暂改。

扩展反向攀爬补充已通过，证据在app/history/
pferr-style-0e1fb96f2a2b47f0b856d21fe9c8f00c-c86a222e/：3/3段success，进入新列、
新行后继续下行至行编号9，再真实沿梯上爬9→8→7→6→5→原行编号4，终点
isLaz=1、(975,984.75)。当时导出8×8共64实际房/101池房、接口检查无问题，
随后下行阶段继续扩至8×12。以上行列编号均从0开始；延迟截图已显示实际右扩与下扩房间，可用于评审。

启动屏障的正、负对照均已实际运行：

- 26595字节修复候选暂扣prob.loaded共1531毫秒，42次检查均debugReady=false；
  恢复后31个原版房池全部就绪，F5/F1两入口完成。原始证据：
  `app/history/pferr-style-653d8261ad904445924481895151cc63-7369ddc3/`。
- 26498字节旧候选在暂扣期间约521毫秒即debugReady=true，夹具按预期报错，
  尚未开档便退出；这是用于证明测试能捕获旧缺陷的负对照。原始证据：
  `app/history/pferr-style-1cd04c8532e74111b115d7c114c124aa-0662b404/`。

正式release路径的首轮延迟冒烟也已通过：暂扣1534毫秒、42次检查，F5/F1正常
进入且接口检查零问题。原始证据归档：
`app/history/pferr-style-4dbae1255fe9434a8cb447f2f6bc2933-d8ec0a2f/`。
该轮未取得RRDiag原始日志，所以不把源文件中的版本文字称为运行时日志。
最后一轮夹具在模组初始化前创建本测试appId的存储目录，完成后仅将该实例的
RandomRooms_diag.log复制到captures，并从实际加载域读取RRDiag.TAG写入
production-version.json；不读取真实pfe存档或其他模组日志。

2026-09-10 最终正式release复跑已完成，命令为：

```powershell
& './mods/RandomRooms/build/style-review/game-harness/run-game-captures.ps1' `
  -DevelopmentSwf './mods/RandomRooms/release/RandomRoomsMod.swf' -SmokeOnly -StartupDelay
```

本轮appId为`pferr-style-81a0848eed1344ad8dbbc4c5509bc6e2`，产物在当前
`app/captures/`。源release为26595字节，SHA256为
`9B547CF23C239DEBCCF1872D00F63CF50D138AF2AE172867C06C2458515E3583`。
暂扣1502毫秒、40次ready=false，恢复后31个原版房池就绪；F5进入syn_12，
F1进入syn_14，两份接口检查均零问题，共4张真实截图，退出0且临时描述符删除。
`production-diag.log`第11行有`[RR:v7.0]`及`RandomRoomsMod v7.0 loaded`，
第61行记录F1/F5就绪，第62/295行记录两个入口的实际gotoLand；
`production-version.json`另记录实际加载域的TAG和日志存在。manifest包含原始
日志、版本JSON与所有本轮产物的SHA256。该轮验证启动及入口，六型物理通行
和扩张反爬证据仍为上文相应批次，不把两入口冒烟扩大为重复全物理测试。

生成的 app/ 全部为可再生产物，不应提交到 git。
