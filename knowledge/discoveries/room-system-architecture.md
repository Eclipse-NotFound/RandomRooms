---
domain: world-objects
type: discoveries   # 模组内 discovery；尚未运行时验证，验证后可考虑贡献 shared-knowledge
game-version:
  - "1.02"
confidence: medium
verified: false
method: 静态反编译阅读（game-reference/decompiled/1.02/src102）
evidence:
  - kind: decompiled-game-code
    symbol: "fe.loc::Land.buildRandomLand / newRandomLoc / newTipLoc / newLoc / setLocDif / buildProbs / newRandomProb"
  - kind: decompiled-game-code
    symbol: "fe.loc::LandLoader（roomsLoad 双路径）/ fe.rooms::Rooms（rooms Array）/ fe::World.roomsLoad / fe.loc::Room / fe.loc::Tile.dec"
  - kind: decompiled-game-code
    symbol: "fe.loc::Game.enterToCurLand / Encounter / gotoLand；fe::GameData.d（land/prob/wave XML）"
date-updated: 2026-08-17
---

# Remains 房间系统架构（静态勘察）

> 本文件是本模组对游戏房间机制的**静态分析结论**，尚无运行时验证。
> 已验证的部分提升为 fact 后再按 shared-knowledge 规则评估是否贡献。

## 已确认（代码层）

### 1. 房间模板 = `<room>` XML
- 结构：`<room name=... x/y/z>` + 每行 `<a>` 为 **25 行 × 48 列**瓦片字符网格
  (World.cellsX=48/cellsY=25；24 行会致 buildLoc 越界 #1009)
  `<options>` + `<doors>`（22 值字符串）+ `<obj>`/`<backobj>` 若干。
- 瓦片解码 `Tile.dec(code, mirror)`：
  - 首字符（charCode>64 且非 `_`）→ 地板形态 `Form.fForms[char]`
    （A/C/K/M/T/L/H/E/S… 都是地板/地面类型）；
  - 后续字符 → 对象形态 `Form.oForms[char]`：`*`=水、`,;:`=Z 层、
    镜像感知的朝向字符会按 mirror 换形态；
  - `Tile` 有 phis（实体墙）/stair/shelf/water/front/back/zad 等语义位。
- `<options>` 属性：tip/level/back/uniq/nornd/spawn/kolspawn/tilespawn/
  items/sky/zoom/desoff/petoff/maxdy/trus/test。
- 边框 `ramka`（1-8）在 Location 构造时把边沿瓦片置 phis；靠边的
  phis 瓦片标 indestruct。
- `<doors>` 22 值：mirror 时 6↔10、7↔9、17↔21、18↔20、前 6 位与后
  11 位互换——**镜像翻转是游戏原生的合法变换**。

### 2. 房间池与加载双路径
- 池索引：`Rooms.rooms`（public Array）以文件名（"rooms_sewer"…）为键。
- `LandLoader(id)` 在**进入土地的瞬间**取 `GameData.d.land.(@id==id).@file`
  对应的 XML：
  - `World.w.roomsLoad != 0`（默认 1）→ URLLoader 读磁盘
    `Rooms/rooms_XXX.xml`；
  - `== 0` → 取 `World.w.rooms.rooms[file]`（SWF 内嵌或运行时替换的数组）。
- **注入点：`World.w.rooms.rooms` 与 `World.w.roomsLoad` 均为 public，
  模组可在土地加载前替换房间池内容。磁盘文件无需修改。**

### 3. 随机土地组装（rnd）
- `Land(gg, act, level)`：`act.rnd` 为真 → `buildRandomLand()`。
- 网格 mx×my（`act.mLocX/mLocY`，来自 land 定义 mx/my），每个格子
  一个 Location（id="locX_Y[Z]"）。
- 按 `act.conf`（0/1/2/3/4/5/7/10/11 已实现）走不同原型规则：
  固定格放 tip 房（beg0/beg/end/end1/pass/passroof/vert/surf/roof），
  其余格 `newRandomLoc(stage,x,y,flags,extraTip)`；conf 未命中 → 全
  随机分支。
- `newRandomLoc` 选房规则：
  - 池 = `allRoom` 中 `lvl <= stage` 且 `kol > 0` 且 `rnd=true`
    （或 tip==extraTip）且非左/上邻居同模板；
  - 权重 = `kol*kol`（lvl==0 且 stage>1 时 kol² 减半为 2）；
  - 选后 `--kol`（**每模板每土地限次**；conf==4 直接清零=不重复）；
  - 池空兜底：从全部 rnd 房随机。
- `mirror` 每格 50% 随机；conf 2/5 给特定行加水（water 17/21），
  conf 5 顶层 `visMult=2` + `gas=1`，conf 10 `home=true`，conf 11
  `atk=true`。
- 组装后第二循环设置 pass_r/pass_d（相邻门连接数组）。
- 难度：`setLocDif` 按 conf 深度公式（conf0= y/2、conf1= y、
  conf2= y*2.5）+ landDifLevel 派生 enemyLevel/weaponLevel/locksLevel/
  mechLevel；globalDif 修正。

### 4. 内容散布层
- `GameData.d` 每个 `<land>` 内 `<prob>`（含 `<con tip='box/unit' ...>`
  与 `<scr>` 脚本、`<wave>` 波次）在 `buildProbs/newRandomProb` 中按
  level/triggers 门控随机打进房间（createDoorProb 开门）。
- `<prob id='bossultra1' level='0' tip='2'>` 等 boss 房模板亦在此体系。
- `buildProb` 还会从 `World.w.game.probs["prob"].allroom` 找同名房间
  模板建 Location（Probation 微地牢）。

### 5. 土地与旅行
- `Game.lands` 在 newGame 时由 `GameData.d.land` 构建（Game.as:77）。
  **newGame 前向 GameData.d 追加 `<land>` 元素即可注册新土地。**
- `Encounter()` 修正入口（如 canter→way 门控）；`enterToCurLand`
  中 `curLand.land == null || crea` 才 `new Land(...)`（懒构建）。
- rnd 土地 visited 不置位 → 每次进入重建。

## 观察到（推论，待验证）

- 生成器对"未知 conf"走全随机分支 → 新土地可借默认分支（实验确认无
  副作用前不依赖）。
- 房间模板 `lvl`/`kol` 门控天然构成"阶段化内容池" → 变异器按 lvl 分桶
  扩池即可自动获得难度梯度。
- `options.@uniq` 与 tip='uniq' → kol=1，可做稀有房间机制。

## 尚未验证

- 运行时替换 rooms.rooms 的实际生效（M0 实验）；
- pass_r/pass_d 连接对 door 对齐的硬性要求；
- 生成房间不可达时游戏的行为（是否挂死）；
- 与存档（prob_* triggers、land.save/load）的兼容边界；
- 双实例同种子一致性（若做种子系统）。
