# RandomRooms —— 开发记忆入口

> 2026-09-13：用户“开始生成器改进”已完成。v8.0 已部署，最终样本、正常移动、右下扩张与正式路径隔离重启验证全部通过。本页替换旧 v7.1 / v8 进行中快照；历史过程见 journal。

## 1. 模组与当前版本

- 入口固定 release/RandomRoomsMod.swf，入口类 RandomRoomsMod，public static function init(main:*):void。
- 正式文件 32035 B，SHA256 5F340D05EDDFD14488D7330D6D499849F76DE9C1B0CBFEA1E818224204C46E8F，与 build/RandomRooms-v8-candidate.swf 一致。
- 运行日志 [RR:v8.0]；XML rrGen=space-v8、rrRevision=8.0。仓库 main，准确提交查 git log。
- 用户入口说明 README.md；实景对照 design/generator-v8-review.html。

## 2. 用户已确定的方向

- 中文。土地=一次旅行完整地图；合成房=48×25 土地格；房间=内部功能空间；通道=内部连接。
- C 从零生成建筑空间，再按用途摆设，不复制原版整房或地形片段。保留向右、向下无限扩张，不能改为有限 5×5 + F4。
- 横竖结构、内部连接关系共同变化，取消三段式、固定中央井及每四列长井。普通上下连接错开，少量允许对齐；强探索、多高度出口、错层、分岔。
- 回环为总体偏好，少量有内容的尽头；不强制每间同一主路/环/支路配方。
- 上下左右任一实际开放边口均可作为入口；不要求每间四面全开，不指定首入口/终点，不按进入方向重排房间。下落可达不能冒充能够返回。
- 门、活板门、真实玻璃窗保持原版交互；不要求每房必出活板门。
- F1 冒险（初始 5×5）、F2 回城、F4 进新深度层、F5 四主题展示馆（4×3）；F3 旧测试、F7 跳合成房。F8/F9 留给其他模组。
- 用户需重启游戏，回城再进入新随机土地。上述方向已明确，无需重复提问。

## 3. 当前实现

- RRArchitecture：4–9 个不等尺寸空间，变化的空间相邻关系、楼层和回环数量；用途影响比例和家具。局部门洞平台、梯子、夹层，较长梯尝试错开分段；普通内部下降梯避开底部边口。
- RRPorts：原版全部 22 槽的坐标、镜像、对面口与采样。RRMapPlan：共享边提前、确定性生成，查询顺序不影响结果，普通上下口避开上一行位置，保留少量对齐。
- RRTraversal：两格角色净空、脚下梯格、平台、闭合玻璃的有向可达与反向可达审计；所有可站立区与实际边口必须通过。它是保守生成筛选，不替代原版物理验证。
- RRSynth：最多 48 次重试，维持既定边口；输出 rrPlan 空间/连接/梯子资料。已生成房绕过旧 cook 变异，兼容识别 space-v7。
- RRFurnish：按居住、办公室、维修、仓储等用途组合原版物件；为门窗、梯口、边口保留净空，小空间使用紧凑组合。门盖不锁不埋雷，玻璃不承担必经路。
- RRGrowth：初始与新增行列共用构造流程，保留旧 XML/mirror。空 Land 引导后恢复原版随机土地生命周期；新邻居配对开口后执行原版绘制、物件、预步进、经验与地图处理。
- 恢复旧边口同时清 opac、恢复 stair，并补原版梯首 shelf/vid；平台限制在空间和 x=1..46，生成审计防止非声明边缘漏口。
- RandomRoomsMod：生成地图池后旅行，原版 crea 重建转回自己的地图构造；其他土地保留旧 P0。完整 31 个原版加载器就绪屏障保持。

## 4. 已完成验证

- 正式 AS3 主样本 1024 + 第二组 256，cook 前后地形、物件尺寸/支撑/净空、梯顶、声明/非声明接口零错误；另两张 12×12 地图的配对、镜像、连通和乱序边口查询全部通过。cook 不是另 1280 个新房。
- 主组 4–9 空间，308 种以上忽略标号/坐标/主题/镜像的连接关系，1007 尺寸组合；711 房有环、313 无环。308 是 WL 指纹给出的下界，不是精确同构数。
- 第 16 格高度至少连续 6 格楼层：旧版 1024/1024，新版 258/1024（25.2%）；新楼层分布 5–20 格。主/次地图同时有上下口的 89/97 房中分别 5/3 对齐；不声称全部梯子都短。
- 六种空间、四种主题的原版截图与物件循环通过：10 门、5 活板门、10 玻璃窗。先截图，再原版 Interact 开关/伤害破玻璃；该轮不冒充正常移动或逐武器射击。
- F1：syn_8，起点 (1,3)，端口 4/8/14/18，5 空间；33/33 目标、7233 控制器帧。从每口离开并返回，每次重访全部内部空间。
- F5：起点 (2,1)，端口 4/6/18，7 空间；34/34 目标、8359 帧；12 个实际房覆盖四主题。
- 右下扩张：正常出生，进入新列 (5,0)→返回 (4,0)→新行 (4,5)→返回 (4,4)，四处均到内部空间。4/4 目标、4696 帧，5×5→8×8，最终 64 房全槽接口零问题，原 25 房 XML/mirror 不变。
- 上述移动使用正常方向/跳跃/爬梯/行动键；出生由正常旅行坐标选择，随后不写玩家坐标、碰撞或地形。持续受击保护仅隔离战斗。
- 部署后正式 release 路径新实例 pferr-style-c85b877cd7244f54a716299abb795d1d：F5 12/12、F1 25/25，实际 v8.0 日志、接口零问题、退出 0，清单 complete。
- 证据：knowledge/experiments/generator-v8-evidence/ 中 generated-samples.zip、multi-entry-f1、multi-entry-f5、growth、release-smoke；六图 design/assets/v8-spaces/。

## 5. 已知边界与原版机制

- 结构仍偏直角，家具与生活细节可以丰富。未穷尽所有种子、长时间扩张内存、联机、真实旧存档、六模组集成或逐武器破窗。
- 测试使用独立 pferr-style 应用和 newGame(-1)；隔离根自写 TDFC 薄壳加载原封候选，调用方与正式 loader 不同。真实其他模组未访问，真实存档未改。
- AIR 需要独立 AppData；默认沙箱 #3003 发生于模组初始化前，经工具权限审查后运行。不能改真实存储目录绕行。
- 原版 controlOn 跨房会清 invulner；驾驶器需持续受击保护。梯子按脚下 Tile 与符号吸附，目标横坐标使用原版宽度规则；空中不能凭身旁梯子假定已攀爬。
- Location.getDist 将光标坐标 round 到 visi 格；屏幕缩放、整数光标可能把半格中心取到暗格。瞄真实可见表面并保留原版距离/视线检查；活板门可在脚下，不能用面朝方向漏选。
- hatch2 图像高 48 px、碰撞高 40 px，落脚取 Tile 楼层。window2 hp1000/thre100；lov 是陷阱，沙发是 couch。
- 原版接口、镜像、梯首恢复详见共享发现 shared-knowledge/world-objects/discoveries/room-port-restoration-and-ladder-heads.md（相对游戏根）。

## 6. 构建、发布与回滚

- build/build-v7.ps1 -OutputName RandomRooms-v8-candidate.swf 只写 build；脚本名沿用，旧 build-m0.sh 会直写 release，不用于普通验证。
- v7.1 回滚备份 build/release-backups/RandomRoomsMod_before_v8_20260913.swf，27326 B，SHA256 F4C1E36E4E9038EBCF86AFB433EDAA0854F9A8F588B5850723DA13781D3250C8。复制回正式入口并重启；禁止覆盖备份。
- 根 pfe.swf SHA256 5300EC4874E0404D298BB58C5D2A7469E82F93B455AD29AD64DD2E29D17241E7 未变，根/DLC SWF 均未修改。
- 发布按 release-gate；release、备份、可再生大型运行目录不进 Git，冻结截图/XML/日志/清单与源代码进 Git。

## 7. 后续阅读与复现

- 本轮无未完成的必要工作。最终验证与边界见 knowledge/experiments/generator-v8-validation-2026-09-13.md；设计选择见 design/structure-diversity-brainstorm-2026-09-12.md，旧报告只作历史。
- 实景页可切换整房/真实屏幕和空间/预留边口标记。单房展示原版封外缘，彩点是预留口；另有 F1 实际四入口样本。PNG 原图不加标记，页面标记独立叠加。
- build/style-review/harness/run-baseline.ps1 导出正式 AS3 样本；build/verify_architecture.py 独立对照原版 AllData；measure_v8_diversity.py 统计尺寸与连接关系。
- build/style-review/game-harness/run-game-captures.ps1 使用 -DevelopmentSwf、-NavigationProbe -NavigationLand random_rooms|rr_showroom、-GrowthProbe、-SmokeOnly。六图使用 -ArchitectureKinds -FixtureProbe -FixtureCyclesOnly，不要求每样本有活板门。
- 旧 MovementProbe/CrossingProbe 的固定底层目标不适合作为 v8 多入口证据；使用 NavigationProbe。驾驶器失败记录保留在隔离 app/history，不能混入最终通过数据。
