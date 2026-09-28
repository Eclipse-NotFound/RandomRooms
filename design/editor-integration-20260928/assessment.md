# RandomRooms 与现有地图编辑器的接入调查

2026-09-28。用户请求：探查现有地图编辑器能否增强 RandomRooms 的运行效果。本轮完成源码调查、132 个历史房间的格式核对及四种地区的隔离静态预览；未实施接入功能，未改正式模组、编辑器、地图或真实存档。

**能用，而且很适合改善生成结果的观感与调试效率。建议先把编辑器接成“生成结果审查工具”，再用它设计摆设规则。** 当前 v13 从零生成建筑并持续扩张；直接修改一个编辑器地图文件，不会改变它下一次生成的房间。现有保存链还会丢失 RandomRooms 的附加信息，不能直接编辑后回灌。

预期收益主要是：更快发现空墙和重复摆设、校正灯具与家具的相对位置、检查材质接缝、把用途／危险度／价值度与实际画面对应起来。没有证据表明接入编辑器本身会提高游戏帧率或缩短生成时间。

本次核对的正式模组是 v13，`release/RandomRoomsMod.swf` 为 88,909 字节，SHA-256 `A5EB49A089835BBC7B670411BBDF32865F5110AEAE79F8BC182AF3BB4C9CBE46`。编辑器是本会话此前安装的汉化增强版，含透明避让标签与原生静态预渲染。全部组件指纹及前后不变检查见 [audit.json](audit.json) 和 [verification.json](verification.json)。

**为什么格式能接上，却不能直接影响运行**

RandomRooms 的主链路是：

`选择版本／种子／地区 → RRExpedition → RRArchitecture 建筑 → RRPopulation 内容 → RRFurnish 摆设 → 48×25 房间 XML → RRGrowth 拼接、扩张 → 原生 Location`

`RRSynth.generate()` 输出标准的地块行、物体、背景、房间选项和 22 个边界接口，另带 `rr*` 属性及 `rrPlan`。这些附加数据记载生成条件、内部空间用途、D/V、炮塔和终端布置等。[房间输出](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/src/rr/RRSynth.as:58>)、[版本与种子派生](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/src/rr/RRExpedition.as:16>)

虽然模组登记了名为 `rooms_random_rooms` 的房间池，当前主入口 `refreshLandPool()` 对 RandomRooms 会直接转入 `refreshArchitecturePool()`；后者调用生成器，`RRGrowth` 再把 XML 放进内存中的 `act.allroom`。**它目前没有“读取编辑器保存文件并替换生成房”的入口。** 修改原版 Rooms 或新增同名 XML 都不是当前 v13 的接入方法。[入口分支](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/src/RandomRoomsMod.as:919>)、[实际构建](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/src/RandomRoomsMod.as:823>)、[内存池](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/src/rr/RRGrowth.as:24>)

拼接也不只是读取单房：`RRGrowth` 按邻居接口开边界、修复梯子端点、设置镜像和城市背景参数，之后才创建真实内容。编辑器单房预览没有这套过程。[拼接与内容创建](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/src/rr/RRGrowth.as:112>)

**本次实际验证**

使用 v13 已归档的 `population-release-candidate` 四份房间池。这些是此前运行测试产生的历史 XML；本次没有重新运行正式模组的生成器，也没有把历史测试结果当作本次游戏实测。

| 地区（游戏中文名称） | 核对房间数 | 本次预览样本／地图坐标 | 应用镜像 | 画出的物体／省略的运行标记 | 图片 |
|---|---:|---|---|---:|---|
| 工厂 | 36 | `syn_2`／(0,2) | 是 | 30／17 | [预览](previews/plant.png) |
| 废弃避难厩 | 35 | `syn_2`／(0,2) | 否 | 42／18 | [预览](previews/stable.png) |
| 下水道 | 36 | `syn_28`／(3,5) | 是 | 31／14 | [预览](previews/sewer.png) |
| 马哈顿废墟 | 25 | `syn_19`／(3,4) | 否 | 58／4 | [预览](previews/mane.png) |

- 132 房、158,400 格均为 48×25；标准行、22 个接口、`rrPlan` 和单个玩家标记检查通过。四份源文件前后指纹一致。
- 兼容性子调查按编辑器内嵌目录与格码规则静态重放：55 种格码均可识别、重编码一致，所有样本物体／背景可识别且没有触发坐标过滤。这是独立模型核对，**不是编辑器 GUI 的保存往返测试**。[规则和完整矩阵](editor-compatibility.md)
- 四个代表房通过独立隐藏 AIR 应用，动态加载**已安装 `EditorTools.swf`、`NativeScene.swf` 及素材的原样副本**。均导出 1920×1000 PNG，无渲染警告，输入 XML 未被改变，进程正常退出。驱动器使用明确地区及样本 `rrMirror`，没有加载编辑器主界面或运行 AI。[实际结果](preview-results.json)、[退出记录](probe-execution.json)
- 目视检查了四张导出图：材质、家具、灯具、门和背景可辨，可用于观察重复摆设、长空墙、厚实体块与背景接缝。这只能证明静态图能画出来，不能证明与游戏每一帧完全一致。

最初独立驱动器在第一房已绘制后、写 PNG 前超时，未取得明确异常原因。将驱动器输出路径改为普通文件路径的父目录后，同一套原样组件通过；没有修改编辑器渲染代码。该失败及边界保留在 `verification.json`，不将它认定为编辑器导出故障。

**需要补的适配，按实际影响排列**

| 缺口 | 当前后果 | 接入时的处理 |
|---|---|---|
| 保存重建 XML | 所有全图保存都会丢 `<all>` 的版本／种子；被重编码的房间会丢全部 `rr*` 根属性和 `rrPlan`；样本 `serial=1` 模式还不写 `doors` | 先提供真正只读审查；以后支持编辑时，完整保留扩展字段与接口，并验证修改后的含义 |
| 地区与镜像不自动读取 | 原始四份样本文件名实测都推断为工厂；预览不自动取 `rrMirror` | 按原始房间的 `rrTheme/rrMirror` 设置预览，换房即更新；城市补齐 `transpFon=true` |
| 预览快照也经过 `encode()` | 虽然不写盘，快照已经缺失生成元数据 | 审查快照直接读取原房间及运行上下文，避免从简化画布反推 |
| 部分动态对象完全省略 | 不仅敌人，炮塔、地雷、部分机关、商贩／医生也可能不画 | 增加可开关的图标或规划叠层，并注明省略内容；战斗与机关仍在游戏验收 |
| 单房没有邻接语境 | 接口可见不代表相邻房能接通；城市街道／楼层关系可能判断错误 | 同时导出坐标、邻房及接口契约，支持相邻房对照；实测扩张与跨房通行 |
| 修改后旧规划过时 | 移动炮塔、终端、家具或墙后，旧路线、用途边界和布置证据未必还成立 | 区分“原始生成”“视觉草稿”“重新验证”状态；重算相关规划或明确标为失效 |

上述保存行为来自当前源码；没有在真实编辑器中执行破坏性保存来复现。仅点开“房间属性”也会将房间标为已修改，之后切房可能在内存重编码，因此普通界面操作不能等同于严格只读。逐项来源和边界见 [兼容性调查](editor-compatibility.md)。

当前静态预览保留房间 `options` 的原生读取，地形水标记也能处理，但没有 AI、探索迷雾、脚本交互或实际涉水／辐射测试。马哈顿废墟还缺运行时背景参数，所以本次城市图片尤其不能视为完整运行效果。

**推荐的接入顺序**

1. **生成结果审查，最先做。** 从实际生成器或运行中的内存池导出完整 XML，同时记录版本、主种子、深度、难度、坐标、镜像和邻接接口。编辑器提供只读入口、正确地区预览及图片导出。固定条件比较修改前后，改善问题应落实回生成规则，让后续新种子受益。现有测试驾驶器与导出的 `*-pool.xml` 已能复用，无须先更换生成算法。
2. **把规划叠到画面上。** 加入内部用途、危险度 D、价值度 V、生成点、炮塔规划和终端候选路线；可以利用现有标签避让。展示的是生成计划，与游戏中 `Shift+F3` 的实时单位／枪线分开标明。这样能对照“计划是什么”和“画出来像什么”。
3. **用编辑器设计摆设关系，再转成规则。** `RRFurnish.kit(role, compact)` 目前在代码里列出主题／用途对应的家具与背景组合，`build()` 再按空间尺寸、占用、支撑和预留区域尝试安放。可让编辑器选中一组摆设，导出相对位置、占地、适用用途、尺寸条件和变体，再由生成器按原有检查放置。这有望减少重复组合、让床／柜／灯／控制台等关系更自然；沿用从零生成墙体和交通空间的既定方案。[组合定义](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/src/rr/RRFurnish.as:38>)、[放置检查](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/src/rr/RRFurnish.as:245>)
4. **手改房间回放，作为后续调试功能。** 若需要精确比较某处墙或炮塔移动前后，可增加限定版本／种子／坐标的实验替换入口。接入点在生成 XML 后、校验与 `newLoc` 前；必须检查边界接口、镜像、对象标识、规划失效及确定性，不应直接修改正在运行的 Location。这项改动较大，应排在前面三项之后。[适配位置](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/src/rr/RRGrowth.as:126>)

摆设组合若接入正式生成器，仍应保持其独立随机来源，避免单纯装饰调整连带重抽地形或主敌群。内容生成先于家具放置，保留的炮塔／终端位置不能被摆设覆盖。[生成阶段与随机来源](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/src/rr/RRSynth.as:30>)

这四项是调查建议，尚未实施，也不代表用户已选择手工定制房间进入正式探索。优先完成第 1、2 项即可获得有用的开发闭环：生成 → 审查 → 改规则 → 同条件复查 → 游戏验证。

**现在可以看的样本与复现方法**

本目录 `samples/` 有四份单房工作副本，保留源房完整元数据；文件名含原版地区名，探针实测地区推断正确。若在编辑器中查看，文件名栏填以下相对路径，省略 `.xml`，按住 Ctrl 点击“载入”即可走直接加载分支。操作步骤依据编辑器源码，本轮未重跑 GUI：

```text
mods/RandomRooms/design/editor-integration-20260928/samples/rooms_plant_rr_v13
```

其余分别替换末尾为 `rooms_stable_rr_v13`、`rooms_sewer_rr_v13`、`rooms_mane_rr_v13`。打开预渲染后仍应核对地区；工厂、下水道样本打开镜像，另两份关闭。现有面板会保留先前选择，换图后不要只依赖首次推断。样本用于查看或一次性视觉草稿，不回写历史源文件；当前保存结果也不能作为完整 v13 数据使用。

可重复执行本目录 `audit.py`，它从固定历史池重新提取样本并复制预览所需资源；`run-probe.ps1 -Run` 编译独立驱动器、以唯一 AIR ID 隐藏启动并输出四张图和结果。资源副本与编译产物位于已忽略的 `probe-app/`；PNG 按本仓既有规则留本机，文本证据与源码入库。脚本不运行正式模组、不加载真实存档。未来组件或样本有变化时，应新建调查目录保留本次指纹，不覆盖本次证据。

复现需要本机 Flex／AIR 工具链及 Adobe Animate 的 Java，路径在脚本中明确给出。当前根 `pfe.swf` 指纹为 `C631CBF3511B6EE303F533D08D51511FE0EB702F43E5DB17F5241D8576C64867`，与旧 v13 部署记录的宿主指纹不同；本轮只记录当前状态，没有改宿主或重做全模组验证。
