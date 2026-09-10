---
domain: knowledge-validation
type: experiments
game-version: ["1.02"]
confidence: high
verified: true
discovered-by: RandomRooms
evidence:
  - kind: game-source
    symbol: "Land.buildRandomLand/newLoc/buildProb; Location.init/mainFrame/setDoor/setObjects; Tile.dec; World.roomsLoadOk; Game constructor"
  - kind: local-experiment
    summary: "正式AS3 1024房导出、原版渲染、六型真实横穿、二维扩张与反向爬梯；证据清单在 style-v7-evidence。"
date-updated: 2026-09-10
---

被测技能：remains-auto-testing、remains-mod-build、remains-runtime-debug、remains-release-gate；grilling / game-brainstorming 作为设计流程使用，未单独评价其普适有效性。
技能归属：D:/Program Files/Steam/steamapps/common/Remains/.agents/skills；设计技能为 C:/Users/hello/.agents/skills。
测试工作区：D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms。

# RandomRooms C/v7：生成、观感、通行与扩张验证

## 结论与用户约束

用户看过 A/B/C 的真实原型对照后批准 C 正式重写；随后明确要求保留向右、向下无限扩张。实现从建筑空间关系生成地形，再按用途摆设；不复用原版整房或地形片段。初始 5×5 是扩张起点，不是地图上限。

正式生成器的 1024 个样本通过结构与家具检查；六种布局在原版物理中全部横穿；实际进入新增列、新增行，并从新增深层沿梯井回到原区域。四主题最终实景见 [正式评审页](../../design/generator-v7-review.html)。当前仍只有六种普通布局，重复结构和细节丰富度是后续内容边界，不能据此声称与手工原版房已无法区分。

发布状态与最终启动检查见文末；这里的 verified 指下述明确实验，不代表游戏全部机制、全部随机种子或所有模组联用已验证。

## 原版调查及方案比较

- 核对 120 间原版普通房：stable 32、sewer 22、plant 40、mane 26。旧统计把 beg2/beg3 纳入普通池得到 122，已修正筛选。
- 原版语义证据来自房内相邻物件及地形，而非单纯整房共现频数。桌柜、控制设施、连续管线、厨房有局部用途关系；修正旧 DEC-0004 的过强推断，见 DEC-0005。
- 旧 v6.6 真实 AS3 导出 32/32 都有固定底边 x=23/24 开孔；过去仅凭日志宣称底边全封的结论不成立。字符开孔本身不等于实际坠亡证据。
- A 只做材质去噪，巨大空腔仍在；B 严格局部拼接可保留细节，但合格组合少、改动小；C 的 32 个原型形成平台、梯井、附室关系，用户据画面选择 C。
- 原型与最终正式 AS3 分开存证。原型截图冻结在 design/assets/prototypes-2026-09-10，不被后续 harness 运行覆盖。

调查过程：build/style-review/VANILLA_FINDINGS.md、furnishing-reference.md、v7-space-audit.md。未修改公共反编译资料。

## 实现和已修问题

| 部分 | 最终行为 |
|---|---|
| RRArchitecture | 主厅、工坊、办公室、损毁厅、维修间、仓库六类，另有连接楼层的竖井；尺寸与布局参数随机 |
| RRFurnish | 按用途整组摆设，检查整块向上占位、整宽支撑、梯子与门口保留区；放不下选同用途小组或留空 |
| RRSynth | 输出 25×48、22 位连接记录和独立物件编号；普通房只有左右底层口，竖井有中心上下口 |
| 自有土地 | F1 全 C、每次统一一个主题；F5 四主题；进入时重新生成，C 不再受旧瓦片变异和重复扩池影响 |
| RRGrowth | 提前生成新列/行；每四列一条竖井，新增行延续竖井；装配对象、恢复旧边口、地图和经验记录完整更新 |

具体修复包括：梯顶断口、家具悬空/叠进墙、维修间被实心核心占满、仓库悬墙、损毁厅固定悬板、下水道管线组尺寸过大而全部落空。最终 1024 房中 75/75 个 sewer/service 样本有管线组。

通路门使用真正的 stdoor，显式 lock=0、mine=0，保留正常关门与开门交互。原版默认门可能随机上锁带雷，不适合作为唯一通路的默认值。lov 是陷阱，不是沙发；沙发使用真实 couch。未引入依赖房间脚本的终端、炉灶等对象。

## 自动与实际运行的证据

| 检查 | 结果与边界 |
|---|---|
| 正式生成器批量 | 四主题各256，总1024；尺寸、22口、梯顶净空/落脚、家具尺寸/支撑/不阻梯、玩家标记、门锁雷属性全通过 |
| 独立清隙检查 | 所有可站立地面的2×2净空与出生处连通；这是几何检查，不能代替重力、跳跃和爬梯 |
| 旧 cook 后复验 | 1024房通过，新增副本0；C房未被变异 |
| 重复种子 | 最终1024房逐 room XML 完全一致；仅导出根节点的版本标签不同，不能宣称两份完整文件哈希相同 |
| 结构变化 | 1024房有464种不同地形；含编号的整XML各异不作为布局多样性证据 |
| 辅助工具 | render_dump日志/多房/完整性检查与原型测试，共5项通过；渲染图是结构示意，不是真实游戏截图 |
| 六类横穿 | atrium261帧、workshop277、offices293、damaged297、service293、warehouse261；6/6自然进入相邻格，正常开门，无改坐标 |
| 固定上下竖井 | 原版1×2装配；下行16帧入下一格，上行29帧返回原格，2/2段通过 |
| 整图旅行/刷新 | 26498B版F5→基地→F5、F1→基地→F1全通过；F5池34/实际12格，F1池62/实际25格，刷新池哈希变化，四次连接检查无问题 |
| 二维自然扩张 | 从原5×5出生，进入第6列syn_100000，再沿第5列竖井进入第6行syn_100019；最终导出8×7/56格/93池房，接口检查无问题 |
| 扩张反向上爬 | 独立轮从新增第10行（坐标9）爬回原第5行（坐标4）rr_exit；isLaz实际变化并逐房过缝，3/3阶段通过；运行继续生成至8×12 |

六型真实截图所用正式 XML：`generated-v7-final.xml`，SHA256 `1829D54A178AEE61859422B31EBEB28AC6E867C4A12B8BA3B7A6C2D7719D2139`。
cook 后输出：`D71FC102C2C4788CCEB7560446A66567C79A3DBAC84A71CB8112C1C09D661A9F`。
复跑导出：`8CEBBAC4EE4CEFA7154749703C1538AB6005D8D8DC49AA238A9AE4A7EBFFFB1B`，根 generator 标签 space-v7 → space-v7-final。

六型图片先按“六型、尽量覆盖四主题”选取，源房依次 syn_120/stable、syn_401/sewer、syn_513/plant、syn_832/mane、syn_0/stable、syn_257/sewer。主代理人工查看全部六张整房图，确认材质连续、家具成用途组、无过场黑幕；这是有边界的视觉判断，不是统计审美评分。

## 隔离、驱动与归因边界

测试只使用本模组 build/style-review/game-harness/app 的原版副本、每轮 pferr-style-GUID 独立应用身份、新游戏 newGame(-1)。窗口隐藏，限定运行时间，仅结束本轮进程。未读写真实 pfe 存档、未修改根/DLC SWF、未复制或启用其他实际模组。

固定房模式由原有 RandomRooms loader 加载自写测试驱动，走正常 LandAct/beginMission 建造。整模组模式在隔离副本的空 TDFC loader 槽放自写薄壳，它加载原封候选 RandomRooms SWF 后调用 static init(main)。真实 TDFC 未读取或修改。实际生产 SWF 与入口确实执行，但可观察驱动的装载调用方不同；不等同于完整六模组集成验收。

图像：stage 是 1008×729 正常界面和光照；room 是 1920×1000 原版渲染树整房诊断图，暂关玩家视野遮罩统一曝光，不冒充玩家屏幕原样。固定图移除敌人。自然扩张用 invulner 与每房 healAll 隔离战斗消耗；没有 godMode，未改玩家坐标，缺邻房的原版 die(-1) 仍有效。向下是按下键沿竖井下落；反向上爬另有实际 isLaz 和房号证据。

未验证：完整世界种子确定性、所有种子物理遍历、极长时间扩张资源上限、联机、多模组联合运行、真实旧存档兼容的完整矩阵。初始化与F1/F5重建走原版旅行路径；建议重启后回城再进入，以获得新生成的土地。

## 失败样本和改进

1. 冻结 Python C 原型边界空 doors，2×1横穿601帧失败。实际原版空节点不会得到默认22口；正式生成器显式声明后同路径261帧通过。
2. 外层加载原版 SWF 会在 MainFE 构造读 stage 时遇空；兄弟域也不能直接获取同名真实模组类。使用隔离副本既有空 loader 槽与自写薄壳解决，未给游戏打补丁。废弃 DevelopmentRunner 已删除。
3. 长程驱动先受战斗影响回出生，后又因落入高层平台仍朝高墙走、短跳惯性偏离梯井而停顿。修正驱动反馈后实际跨房通过；这些停顿不能伪称模组碰撞失败或跳过验收。
4. 首轮扩张跨界即时截图碰到过场黑幕；日志可证移动，黑图不能证观感。独立反爬轮延迟拍摄，主代理另按图片与清单核验。
5. 一次基地 newGame2 在 Land.buildProb 报 #1009，同输入立即复跑未重现。源码追到旧 finalizePreflight 无条件 roomsLoad=0；World.roomsLoadOk 此后任一回调即标全部加载完成，Game 有机会复制尚空的 prob.allroom。最终候选增加原版全部 LandLoader.loaded/allroom 屏障，并由后续帧重试；此改动不改变已验证的房间或扩张几何。最终延迟加载实验见发布节。

流程改进仅记录在本报告与模组资料；未自行修改任何正式技能。窗口/驱动接口、AIR app根 parent=null、loader可见性是环境/工具知识，不把本次失败直接归因为技能设计缺陷。

## 复现入口与保留证据

- 构建：`build/build-v7.ps1`，默认仅写 build，可覆盖 Java/Flex 路径。
- 生成：`build/style-review/harness/run-baseline.ps1 -OutputName generated-current.xml -VersionTag space-v7 -SamplesPerBiome 256 -BaseSeed 9301000 -CookCopies 1`。
- 检查：Python运行 `build/verify_architecture.py <导出XML> --output <报告JSON>`；它从只读 AllData.as 读取真实物件尺寸，不复制生产生成算法。
- 游戏：`build/style-review/game-harness/run-game-captures.ps1`；六型用 ArchitectureKinds/CrossingProbe，整模组用 DevelopmentSwf，扩张加 GrowthProbe；详情见相邻 README。
- 轻量实证清单已入 `style-v7-evidence/`，六型清单与真实图片在 `design/assets/v7-final/`。完整XML、日志和隔离副本留本地 build，未把125MiB可再生副本纳入Git。
- 两个事实调查子代理来自本轮显式 grilling 的委托指令；生产生成器及最终独立复核由主代理完成，未自动加载 parallel-delegate。

历史运行目录前缀均为 build/style-review/game-harness/app/history/：

| 运行 | 子目录 |
|---|---|
| 六型与最终图 | pferr-style-783a3a5e48bf4311b7f421c756a37cbf-5469a149 |
| 首次完整二维扩张 | pferr-style-033d8c43c8fe40d7bf27ad16dce0fb0d-8406c8e3 |
| 扩张反爬与可见图 | pferr-style-0e1fb96f2a2b47f0b856d21fe9c8f00c-c86a222e |
| 26498B四次旅行 | pferr-style-0cfa805ae614428d9b1921ffba58c9b6-11e6ffa0 |
| 偶发启动失败 | pferr-style-eecb92b1bbc84838b602486e4da16832-99563007 |

## 发布门禁与回滚

最终候选为26595B，SHA256 `9B547CF23C239DEBCCF1872D00F63CF50D138AF2AE172867C06C2458515E3583`；零警告编译，启动及日志标签v7.0。相对于26498B（SHA256 `DC7D207B3F537A298E17CC74BDF6DD01C7CE7D65C0AE3AC724E2DD13D3683F75`）只改启动屏障与版本文字；RRSynth/RRArchitecture/RRFurnish/RRGrowth未变。

2026-09-10 已部署正式 release/RandomRoomsMod.swf，与上述26595B候选哈希相同。部署前核对旧release未变并备份到 `build/release-backups/RandomRoomsMod_before_v7_20260910.swf`；备份哈希仍为下面的旧release基线。根pfe哈希复核不变。

最终候选先完成四次旅行：F5/回城/F5及F1/回城/F1，四份连接检查零问题；debugReady当刻31个原版加载器全部loaded且房池非空。证据 `style-v7-evidence/release_candidate_travel-*`，完整运行 `pferr-style-30146cb7fe53401aaf35c5b2f6674928-39752199`。

启动屏障正反对照：新候选将 prob.loaded 暂扣1531ms，42次逐帧确认debugReady=false；恢复后约241ms正常ready，开档及F5/F1成功。旧26498B在相同夹具约521ms就提前ready，被断言截停，未开档；证明断言能检测原缺陷。正例见 `startup_delay-*`，负例见 `startup-negative-manifest.json` 及历史目录 `pferr-style-1cd04c8532e74111b115d7c114c124aa-0662b404`。

部署后以**正式release路径**启动新的隔离游戏，appId `pferr-style-81a0848eed1344ad8dbbc4c5509bc6e2`，再次暂扣1502ms/40次保持未ready；恢复后31份资料全就绪，正常开档，F5池34/12格、F1池62/25格，两次连接检查零问题、四张截图齐全，进程退出0。`style-v7-evidence/release-smoke-*` 保留源哈希、运行结果和启动断言。重启针对隔离验证实例；未结束用户实际游玩进程，实际游戏须由用户重启加载新版。

回滚：将上述备份复制回 `release/RandomRoomsMod.swf`，核对旧release哈希，再重启。只换本模组文件。MEMORY快照、journal顶部新条目与本报告同步收尾；本模组没有既有changelog，版本变化记在journal。Git提交包含源代码、可复现验证工具、决策与固定实景，release和隔离副本按既有规则不纳入Git。

最终一轮从实际运行实例复制了原始 production-diag.log，包含 `[RR:v7.0] [RR] RandomRoomsMod v7.0 loaded` 和两个实际 C-POOL/旅行入口。原始日志SHA256 `B3720881FB591452EE32CA34640E570BDD15679D07500DC070FDF6E722CA9543`，清晰版本摘录与源SWF关联保存在 `style-v7-evidence/release-runtime-version.json`。这不是仅从源码推断版本；测试驱动还从实际候选域读取TAG作交叉核对。

根游戏pfe基线 `5300EC4874E0404D298BB58C5D2A7469E82F93B455AD29AD64DD2E29D17241E7`。旧release基线 `5E3D611C9C38F19FEB30D0DB535BFDC6D1040FE8CF3A5B6F8EC39131E2DA4A00`。本轮授权是实现正式模组，部署仅替换自己的release；游戏SWF与描述符不改，原游戏loader补丁门项不适用。
