# RandomRooms —— 设计愿景与方案提案

> 版本: v0.1（2026-08-17，设计初稿，待用户确认方向）
> 目标游戏: Fallout Equestria: REMAINS 1.02（可扩展 1.03/1.04）
> 一句话: 为游戏提供随机生成房间的能力，终结"视觉疲劳"。
>
> 本文是设计文档，不是实现文档。技术事实依据见
> `../knowledge/discoveries/room-system-architecture.md`（本模组静态勘察结论）。

---

## 1. 设计目标

### 1.1 玩家幻想（Player Fantasy）

> **"废墟永远是新的。"**

玩家每一次踏入废土建筑、下水道、马哈顿废墟，看到的都不再是同一批
房间排列。探索由"背板"变成"面对未知"：

- 路线不确定：这一层通往哪里？这扇门后面会是什么？
- 空间不确定：掩体、平台、走廊的布局每次不同，战斗站位随之改变；
- 内容不确定：箱子、敌人、陷阱与稀有房间的分布随种子变化；
- 但**公平可控**：难度曲线、资源节奏、通关路径始终可学习、可预期。

### 1.2 设计支柱（Pillars）

1. **可重玩性第一**：任何两个"同一地图"的体验都不应相同；
2. **手作质感**：随机 ≠ 噪声。生成结果必须保持 Remains 房间的设计
   语言（掩体节奏、视线遮挡、门位对齐）；
3. **公平性**：保证生成地图可达、可通、难度随深度平滑上升；
4. **确定性**：同样的种子 + 同样的进度 → 同样的世界（这也为联机
   世界同步铺路，见 §6）；
5. **零侵入**：不改游戏文件即可工作；不破坏其他模组；玩家可用配置
   一键回退到原版体验。

### 1.3 非目标（Non-Goals，v1 不做）

- 不做全图无缝大地图（游戏本身是房间网格制，硬改收益低）；
- 不做剧情土地重排（story/base 土地的剧情依赖固定房间，只碰 rnd）；
- 不做敌人 AI / 数值修改（那是内容数值，不是房间）。

---

## 2. 现状：Remains 的"房间"到底是什么

勘察结论（详见 knowledge/discoveries/room-system-architecture.md）：

- **房间模板** = 一个 `<room>` XML：48×24 字符网格（瓦片代码，
  首字符=地板形态 `Form.fForms`，后缀=对象形态 `Form.oForms`，`*`=水、
  `,;:`=Z 层），加上 `<options>`（tip/level/back/uniq/spawn/sky/zoom…）、
  `<doors>`（22 值字符串，含镜像交换规则）、`<obj>`（箱/陷阱/存档点/奖励）。
- **土地房间池** = `Rooms/rooms_XXX.xml`（磁盘）或 SWF 内嵌 XML。
  `World.w.roomsLoad`（public）决定加载路径；`World.w.rooms.rooms`
  是 public 数组，**运行时可整体替换**。
- **地图组装** = `Land.buildRandomLand()`：按 `LandAct.conf`（0-11 的
  土地原型）在 mx×my 网格上摆"固定 tip 房"（beg/end/pass/vert/surf/
  roof）与"随机房"（`newRandomLoc`：lvl≤阶段 门控 + kol² 加权 + 邻接
  去重 + 镜像翻转 + 每模板限次），并按深度套难度公式（enemyLevel/
  weaponLevel/locksLevel）。
- **内容散布** = `GameData.d` 中每个 `<land>` 的 `<prob>/<prob1>/<wave>`
  模板（随机遭遇、首领门、波次），由 `buildProbs/newRandomProb` 打进房间。
- **可扩展点（全部 public，模组可安全触碰）**：
  `World.w.rooms.rooms`（房间池数组）、`World.w.roomsLoad`（int）、
  `GameData.d`（static XML，可在 newGame 前追加 `<land>`）、
  `Game.lands`（newGame 时从 GameData.d 构建）、`Game.gotoLand()`（旅行 API）。

**结论**：Remains 已经拥有"模板池 + 网格组装"的成熟随机地牢引擎
（Spelunky / Dead Cells 同构）。RandomRooms 的本质机会 = **把这个
引擎的门打开**：房间池可编程、土地定义可追加、组装参数可干预。

---

## 3. 同类游戏对标（设计养分）

| 游戏 | 借什么 | 落在 Remains 上 |
|---|---|---|
| **Spelunky** | 模板拼接 + 黄金路径保证 | 房间池注入时必须保证 beg→end 连通 |
| **Dead Cells** | 房间节点图 + 分支选择 + 难度逐层 | 用 pass/vert 门位做图论连通校验 |
| **Enter the Gungeon** | 大量小模板 + 稀有房 + 宝箱房节奏 | uniq 稀有房间、treasure 房类型 |
| **Hades** | 房间池 + 每次选择(门=祝福) | 把"门"变成信息：预览下一房类型 |
| **Noita** | 局部语法/WFC 保证邻接合法 | 瓦片级合成器（P2） |
| **Deep Rock Galactic** | 手作块 + 噪声雕刻拼接 | 模板交叉混合：同模板换 biom 材质 |
| **STALKER Anomaly** | 异常点/战利品随每次进入漂移 | 内容散布层重掷 |
| **每日挑战类**（Spelunky Daily 等） | 共享种子 + 排行榜 | 种子码系统 |
| **Minecraft 结构方块/拼图** | 拼图块(jigsaw)连接器思想 | doors 字符串就是现成的连接器 |

---

## 4. 方案提案

按四个层次组织。P0 = 最小可行、风险最低、立刻改变体验；P2 = 远期愿景。

### P0 —— 房间池重掷与模板变异（"换皮 + 换排列"）

**最小改动，最大见效。**

1. **池重掷**：在每次进入 rnd 土地前，向 `World.w.rooms.rooms[file]`
   注入"原池 + 变异副本"的扩增 XML（不改磁盘文件）。
2. **模板变异器**（对已有房间做合法变换）：
   - **镜像/旋转**：游戏原生支持 mirror（doors 自动交换）；
   - **属性重掷**：`back` 背景墙、`sky`、`zoom`、`color/light`、`kolspawn`
     出生密度、`tilespawn` 陷阱概率——在作者设定的合理区间内重 roll；
   - **瓦片级微突变**：掩体位移、走廊变宽/窄、家具互换（同语义瓦片码
     换用），保门位与边界不变；
   - **战利品/敌人重掷**：`<obj>` 的箱子内容档位、`<prob>` 权重重洗。
3. **效果**：同一土地每次进入，排列、朝向、光照、内容都不同。

### P1 —— 新土地「random_rooms」：无限废墟模式

**把随机引擎变成玩家的常驻玩法。**

1. 在 `GameData.d` 中追加自定义 `<land id='random_rooms' tip='rnd'
   rnd='1' ...>`（newGame 前注入）——配专属 rooms 池与 conf；
2. 提供入口：主菜单或 PipPage 旅行列表新增项（调用 `gotoLand`），
   或复用某块大地图的一扇门；
3. **无限深度**：rnd 土地本身每次进入重生成，配 `upStage`/landStage
   语义可实现"每清一层加深一层"的 roguelike 循环；
4. **种子系统**（本模组差异化王牌，见 §6）：可输入/复制的种子码，
   同种子同世界——解决共享知识已记录的"rnd 双实例不一致"问题，
   并天然兼容 RConnect 联机镜像的前提。

### P2 —— 程序化房间合成与稀有内容

**从"变异已有房间"到"无中生有"。**

1. **文法提取器**：离线/运行时解析全部 64k 行房间 XML 语料，提取
   设计文法（边界墙、门区、平台节奏、掩体密度、陷阱位分布）；
2. **WFC-lite 合成器**：生成全新 48×24 网格，约束 = 门位对齐 +
   可达性 + 掩体节奏，输出合法 `<room>`；
3. **稀有房间**：uniq 房（大宝藏/首领门/商人/修理台/传送门）；
4. **每日挑战**：服务器无关的本地日种子 + 结算统计。

### 拓展设想（头脑风暴，未排期）

- **房间主题日**：生物群系混搭（下水道材质 × 马哈顿布局）；
- **腐蚀地带**：深度越深，瓦片变体越"废土"（墙体破损率、积水率上升）；
- **限时房**：门后限时奖励房（风险换收益）；
- **蓝图收集**：玩家在废土拾取"房间蓝图"解锁新的生成模板；
- **记忆迷宫**：多层同构异位房间的迷宫（考验空间记忆）；
- **深度计分板**：本地无尽模式最深记录。

---

## 5. 技术架构草图（供后续 decisions/ 展开）

```text
RRConfig    种子/难度/开关配置（SharedObject config，F9 式面板或主菜单项）
RRSeed      确定性 PRNG（mulberry32/xorshift），全程替代 Math.random 影响域
RRCook      模板变异器 + 属性重掷（纯 XML 变换，可离线单测）
RRSynth     文法提取 + WFC-lite 合成（P2）
RRPool      房间池装配：原池 + 变异副本 → 组装 rooms XML
RRInjector  注入：rooms.rooms[file] 替换 + GameData.d land 追加
RRTravel    入口：gotoLand 调用 + dopusk() 门控探测（复用 land-travel-api）
RRDiag      诊断：生成日志、连通性自检、双实例一致性比对
```

注入时机（关键时序）：

```text
mod init(main)
  → 等待主菜单/World 就绪
  → 注册 RRTravel 入口
  → 玩家触发旅行/进入土地之前：
      RRInjector 替换 rooms.rooms[file] 并设 roomsLoad=0
      （LandLoader 在进入土地的瞬间读取该数组 → 新池生效）
```

遵守 modding-interop 约束：只碰 public 成员、密封类先探测、
KEY_DOWN 先于游戏、帧代码晚于游戏 step。

---

## 6. 种子与确定性（重要设计决策）

共享知识已确认：rnd 土地按 `Math.random` 生成 → 两个实例内容不一致，
单位 id 匹配失败（RConnect 联机同步的硬伤）。

RandomRooms 的种子系统若采用**确定性 PRNG 且注入点为单点**，则：

- 同模板新档 + 同种子 → 两个实例生成同一房间排列（连 `Land.locN`
  编号都能对齐）；
- 这使 RandomRooms 从"单机变奏工具"升级为"联机世界生成器"——与
  RConnect 的宿主权威镜像模式互补（镜像前提 = 同模板同世界）。

风险：游戏内部大量 `Math.random()` 不在注入点控制范围内（敌人 AI、
战利品 roll）。v1 只承诺"房间排列与内容散布确定性"，其余漂移仍由
RConnect 的镜像机制兜底。需实验验证。

## 7. 风险与未知（实验清单）

1. **门位不变量**：buildRandomLand 第二循环里 pass_r/pass_d 连接逻辑
   对相邻房间 door 的对齐要求——变异器必须保门位，否则穿墙/断路；
2. **conf 未处理值**：buildRandomLand 的 if/else 对未知 conf 走"全随机"
   分支——新土地可借这个默认分支，但要实验确认 no bug；
3. **可达性兜底**：生成的房间若不可通，游戏是否卡死（已知 gotoXY 到
   非预期房间会挂死——合成器必须有连通性自检）；
4. **存档兼容**：prob_* triggers、land save/load 与注入池的交互；
5. **重复进入**：rnd 土地 visited 不置位 → 每次进入重生成，注意
   `crea`/`upStage` 语义与玩家进度一致性；
6. **联机种子同步**：种子随宿主广播的通道（若与 RConnect 联动，
   需读其协议——跨模组问题，届时申请授权）；
7. **性能**：运行时 XML 组装 + 变异的开销（预计可忽略，仍要测）。

## 8. 路线图

```text
M0  骨架 + 诊断框架（RRDiag），验证注入点猜想（实验：替换 rooms.rooms
     观察土地是否使用新池）
M1  P0 落地：池重掷 + 模板变异器 + 属性重掷
M2  P1 落地：random_rooms 土地 + 种子系统 + 配置面板
M3  P2 起步：文法提取器（离线语料分析）
M4  P2 合成器 + 稀有房间
```

## 9. 待用户确认的问题

1. **范围**：v1 只做 rnd 土地增强，还是直接上「random_rooms」新模式？
2. **联机**：种子确定性与 RConnect 联动是否要作为核心卖点提前做？
3. **入口形式**：主菜单按钮 / PipPage 旅行列表 / 复用某地图中的门？
4. **配置 UI**：F9 面板式（同 Sandevistan 习惯）还是主菜单集成？
5. **部署授权**：模组上线需要给 pfe.swf 追加 loader（游戏文件修改），
   需要用户明确授权后执行。
