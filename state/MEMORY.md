# RandomRooms —— 开发记忆入口

> 2026-09-10 v7.0 已部署并完成隔离重启验证；本轮实现已完成。

## 1. 模组与当前版本

入口 release/RandomRoomsMod.swf，public static init(main)。C/v7 从零生成建筑空间，再按用途布置家具；不复用原版整房或地形片段。
F1 是全生成冒险土地，初始5×5并向右/下扩张；F5 是4×3四主题展示馆。F4进入新深度层。
正式release 26595B，SHA256 9B547CF23C239DEBCCF1872D00F63CF50D138AF2AE172867C06C2458515E3583。

## 2. 用户已确定的方向

- 中文。土地=一次旅行完整地图；合成房=25×48土地格；房间=内部功能空间；通道=内部连接。
- 用户看A/B/C原型后明确批准C正式实现；随后明确要求保留右/下无限扩张。不能用有限5×5+F4替代。
- 热键F1冒险/F2回城/F3旧测试/F4进深/F5展示/F7跳合成房；F8/F9留给其他模组。
- 实际游戏须重启后回城再进入，获得新生成土地。真实存档、根/DLC游戏SWF本轮未动。

## 3. 已完成实现

- RRSynth仅负责XML与检查；RRArchitecture六种普通布局+全高连接竖井；RRFurnish按用途放原版物件组。梯顶、落脚、地板材料、门口净空预先保留。
- F1池62房/初始25格，每次一个主题；F5池34房/实际12格，四主题。自有C池不接受旧cook变异和重复扩池；其他原版土地保留旧P0路线。
- RRGrowth提前一房生成新行/列，每4列竖井延续。完整newLoc→配对→mainFrame→setObjects→preStep→XP→map流程，旧边界恢复stair与opac后重绘。
- 初始化等待原版landData所有加载器loaded且allroom就绪再切roomsLoad=0，修复偶发基地buildProb空引用。日志标签与启动文字v7.0。
- 删除旧合成器主体和自动试驾、重复异常监听、消耗随机数的诊断生成。

## 4. 实测证据

- 最终1024普通房（四主题各256）与cook后均通过尺寸、22口、家具整块占位/支撑、梯顶净空、2×2几何清隙检查；同种子逐room XML完全复现。464种不同地形；75/75 sewer/service都有管线组。
- 六种布局真实横穿6/6，正常开门；固定1×2竖井下行/返回2/2。几何检查本身不代表真实物理，移动另行验证。
- 26498B同几何候选自然从5×5进入新列和新行，导出8×7/56格；独立反爬轮继续至8×12，实际沿梯井返回原区域，3/3阶段通过。
- 最终26595B四次旅行F5/回城/F5、F1/回城/F1通过，31个原版加载器全就绪；启动延迟正对照42帧持续未ready、恢复后成功，旧候选同夹具提前ready被断言截停。
- 正式release路径重新启动隔离实例，F5/F1入口、两份连接检查、延迟启动均通过，appId pferr-style-81a0848eed1344ad8dbbc4c5509bc6e2，manifest complete。
- 最终图片六型/四主题均人工看过，冻结于design/assets/v7-final；正式页design/generator-v7-review.html。room图关闭玩家视野罩统一曝光；stage图保留正常光照，不能混称原样屏幕。

## 5. 已知边界与机制要点

- 当前六类普通布局仍有重复规律，破损/生活痕迹和独特空间还可增加。未承诺全部随机种子物理遍历、极长扩张资源上限、联机、旧存档完整矩阵或六模组集成验证。
- 测试全部在本模组build独立pferr-style-GUID app、新游戏newGame(-1)。整模组测试借隔离副本的空TDFC loader槽放自写薄壳载入原封release，真实TDFC未访问；装载调用方差异见报告。
- 扩张移动用受击保护/每房回血隔离战斗，未改坐标或开启godMode；向下沿梯井落下，上爬另有isLaz实证。
- 空<doors/>不等于原版22口默认值；普通房5/16=3，connector另8/19=2，只有connector中心x23/24上下开孔。
- mainFrame封边会清stair并设opac=1；Tile.dec不清opac。扩张须按xml+mirror恢复两格厚接口、清opac再setDoor，仅hole无效。
- stdDoor默认可能锁/雷；生成通路门lock=0 mine=0，正常关闭可开。lov是陷阱，沙发用couch。
- conf4需足量不重复vert，end需nornd；左上beg0受mbase_visited影响可抽普通房，右侧竖井仍保全图连通。

## 6. 构建、部署与回滚

- build/build-v7.ps1默认只输出build，Java/Flex可传参；旧build-m0.sh直接写release，普通验证不用。
- 源码继续修改前按实际需求验证，不需重复全部无关实验。正式部署遵循release-gate。
- 回滚备份：build/release-backups/RandomRoomsMod_before_v7_20260910.swf；旧SHA256 5E3D611C9C38F19FEB30D0DB535BFDC6D1040FE8CF3A5B6F8EC39131E2DA4A00。复制回release后重启。
- 根pfe仍SHA256 5300EC4874E0404D298BB58C5D2A7469E82F93B455AD29AD64DD2E29D17241E7；本轮未改游戏SWF或正式描述符。
- 本轮提交在main，精确提交见git log；release/隔离副本/可再生大输出不入Git。

## 7. 后续接手入口

1. 决策 decisions/DEC-0005-architectural-generation.md；旧DEC-0004局部语义推断已被限定。
2. 完整报告 knowledge/experiments/style-generator-validation-2026-09-10.md；轻量可核对清单style-v7-evidence/。
3. 调查 build/style-review/VANILLA_FINDINGS.md、furnishing-reference.md、v7-space-audit.md。
4. 真实AS3导出 harness/run-baseline.ps1；实机 game-harness/run-game-captures.ps1，六型/扩张/启动延迟参数见README。
5. 独立检查 build/verify_architecture.py 读原版AllData尺寸；build/render_dump.py支持当前日志和完整多房，5个辅助测试通过。

没有待用户批准的设计分支。下一轮若继续丰富观感，先对照已冻结实景与原版局部用途关系，扩充空间规则/内容；不要退回逐格随机撒材料或整房换名。
