# v11.1 合成房讲解：源码与验证索引

本页说明2026-09-23本地源码，基线提交 `8954613`。只增加解释材料，生产源码、release与根游戏SWF未修改。

## 阅读入口

- [图解讲解页](guide.html)：16个实际样本的图层、四场景配方、尺寸阈值实验、有效/遗留参数。
- [Archify流程图](flow.html)：工作流图，源规格见flow.workflow.json。

## 源码位置

| 文件与起始行 | 入口 | 说明 |
|---|---|---|
| [src/rr/RRSynth.as](../../src/rr/RRSynth.as) 第20行 | `genGrid / generate` | 建筑最多尝试48次；探索物在家具之前；导出XML、门锁/地雷清零、记录rrPlan。 |
| [src/rr/RRScene.as](../../src/rr/RRScene.as) 第14行 | `profile / options / background / door` | 场景构造列表、墙和灯、门窗家族、环境；列表有重复值时增加对应抽选权重。 |
| [src/rr/RRArchitecture.as](../../src/rr/RRArchitecture.as) 第38行 | `build` | seedScene→refineSpaces→边口/空间连接→局部特征→通行审查→材料。 |
| [src/rr/RRArchitecture.as](../../src/rr/RRArchitecture.as) 第155行 | `seedScene` | 16种构造的不同划分顺序；不是从原版地形片段拼接。 |
| [src/rr/RRArchitecture.as](../../src/rr/RRArchitecture.as) 第264行 | `refineSpaces` | 面积/宽/高阈值、分割预算、用途继承与附室转换；不调用旧partition。 |
| [src/rr/RRArchitecture.as](../../src/rr/RRArchitecture.as) 第364行 | `connectVolumes` | 随机相邻连边树+额外边；额外边四档；按场景选择放门概率。 |
| [src/rr/RRArchitecture.as](../../src/rr/RRArchitecture.as) 第449行 | `gallery / addSceneFeatures / addPool` | 大厅平台、城市残梁、水池/干桥与爬出水池的梯。 |
| [src/rr/RRArchitecture.as](../../src/rr/RRArchitecture.as) 第534行 | `shapeCeiling / dressMaterials` | 局部压低天花板；按场景和用途重铺背景带、实体墙细节。 |
| [src/rr/RRArchitecture.as](../../src/rr/RRArchitecture.as) 第602行 | `ladderPosition / ladderRoute` | 分离梯井；满足条件时65%尝试斜梯；长梯尝试错开但可退回直梯。 |
| [src/rr/RRArchitecture.as](../../src/rr/RRArchitecture.as) 第750行 | `addHatches / addWindows` | 活板门0–2；玻璃0–scene.windowMax；合法候选可能少于目标。 |
| [src/rr/RRMapPlan.as](../../src/rr/RRMapPlan.as) 第20行 | `parentLeft / horizontal / downward / vslot / city` | 父连接保证向起点连通；额外边62%；竖向开口4%重复；城市2–4列建筑+1列街巷，屋顶0行。 |
| [src/rr/RRGrowth.as](../../src/rr/RRGrowth.as) 第22行 | `build / update / append` | 地图难度取max(地图dif,等级−1)；传入difficulty/坐标奇偶/城市；非城市50%镜像；仅追加新房。 |
| [src/rr/RRTraversal.as](../../src/rr/RRTraversal.as) 第9行 | `check` | 两格净空的地形往返图；玻璃作实墙；有水另查干路；不是完整原版物理模拟。 |
| [src/rr/RRPopulation.as](../../src/rr/RRPopulation.as) 第33行 | `构造函数 / build` | ecology先确定；mood18/24/35/23；奖励和服务先放，按需再放安全/危险/敌群。 |
| [src/rr/RRPopulation.as](../../src/rr/RRPopulation.as) 第58行 | `fit / positions / put` | 按物体尺寸、支撑与挂载方式找位；危险物距离出生点限制、入口保留区。 |
| [src/rr/RRPopulation.as](../../src/rr/RRPopulation.as) 第106行 | `rewards / services / enemies / security / hazards` | 用途相关奖励、配套终端/机关；数量均为尝试上限而非最终保证。 |
| [src/rr/RREcology.as](../../src/rr/RREcology.as) 第13行 | `构造函数及各成员` | 使用本房原版难度选择生态，再决定大/小/飞行单位、警戒和陷阱。 |
| [src/rr/RRFurnish.as](../../src/rr/RRFurnish.as) 第42行 | `kit` | 按场景和用途的关系组合：大组合、紧凑组合；不包含复制地形。 |
| [src/rr/RRFurnish.as](../../src/rr/RRFurnish.as) 第169行 | `facilities / place / build` | 主题背景安装；1/2/3组家具预算；大组24次，紧凑组枚举位置；背景失败不撤销实体家具。 |
| [src/rr/RRPorts.as](../../src/rr/RRPorts.as) 第6行 | `22个原版边口位置` | 原版共22槽；当前地图左右各使用5档高度、上下各5档水平位置；匹配和镜像使用同一表示。 |
| [src/rr/RRSeed.as](../../src/rr/RRSeed.as) 第20行 | `fork / next` | xorshift32序列；fork(synth)隔离旧cook；并非逐房独立种子。 |
| [src/rr/RRConfig.as](../../src/rr/RRConfig.as) 第14行 | `配置字段` | seed默认20260818；seedEnabled为真；enabled保存但当前新链未消费。 |
| [src/rr/RRMenu.as](../../src/rr/RRMenu.as) 第89行 | `onToggle / onInputKey / refresh` | 设置保存，不重建synth序列；旧v10.0显示仍存在。 |
| [src/RandomRoomsMod.as](../../src/RandomRoomsMod.as) 第129行 | 初始化 | seedEnabled与fork(synth)，随机序列只在初始化创建。 |
| [src/RandomRoomsMod.as](../../src/RandomRoomsMod.as) 第769行 | refreshArchitecturePool | 场景、5×5尺寸、地图dif=8+2×深度；正式合成链交给growth.build。 |

## 语义边界

- 讲解图按最终rrPlan重建分区；没有伪装成中间构造过程的实际录像。物体点/方块表示锚点，非原版贴图或碰撞包围盒。
- 样本来自design/assets/v11-density-dev12/cases.xml。此16房的XML与dev13语义一致性已在2026-09-20密度验证报告记录；v11.1正式源码相对dev13只变更日志标记。
- min/max/bias与旧partition未在新流程中生效；旧archetype除connector梯井特例外不选择主体构造；主要构造由sceneForm决定。
- 源码相同、种子相同仍需相同初始状态和调用顺序；不把地图边口的坐标稳定性推广成整间房的探索顺序独立性。
- 尺寸实验只演示超阈值条件，不模拟合法切口、预算或全房重试；参数中的概率不会等同最终接受样本的出现频率。
- 日常物体行为仍是原版；安静房仅说明本模块跳过危险物投放，不声称原版容器自身永无危险。

## 校验与画面检查

- Archify：`delivery-receipt.json`绑定最终规格与HTML；showcase 9/9，0错误、0警告。一次画面修订将流程按地图/合成房/交付分层，并改为准确中文图例。
- 自动浏览器：`flow.visual-check.json`，四种桌面尺寸通过，浅/深色端点截图已保存。
- 人工模型图像审阅：最终浅深两主题图、讲解首页、房间分区、污水与家具图层、尺寸实验及窄屏截图。没有把图片查看说成完整游戏回归。
- 讲解页：`guide-browser-check.json`，16样本×4图层、3种尺寸判断和1440/390宽度检查，页面脚本零错误；这是文档交互检查，不是生成器游戏实测。
- `source-fingerprints.json`记录解释时源码、样本XML与release哈希。

## 流程图省略连线文字的原因

顺序节点的动作已完整表达选场景→约出口→划分→检查→探索物→家具→XML→原版读取，未标字的箭头仅表示先后，无额外协议或条件。检查通过、结构不合格、重抽布局三类条件保留文字。

本次没有新增生成规则或调整风格参数。后续若实施改动，应重新查看源码，不将本页当作配置正本。
