# RandomRooms —— 项目状态（交接快照）

> 本文件记录当前开发状态，供新会话无缝接续；频繁更新。
> 游戏机制结论在 knowledge/ 与 shared-knowledge/；本文件只记"当前在哪、下一步做什么"。

## 当前版本（2026-08-21）

- 部署版本：**v5.3**（git `fe67d49`）—— 已部署进 pfe.swf，**等待实机（F5）评估**
- 工作流：每次代码更改 → `bash build/build-m0.sh` 编译 → `bash build/deploy-pfe.sh`
  部署 → 用户重启游戏按 **F2 回城 → F5 进展示馆** 实测 → 读
  `%APPDATA%/pfe/Local Store/RandomRooms_diag.log`（`[RR:0.0.1-M0]` 前缀，grep -a）
- 热键：F1=rr_test / F2=回 rbl / F3 显示房间池 / **F5=展示馆（合成房重现实测）** /
  F4=深度循环 / F7=jumpToSynth（F8/F9 被其它模组占用）
- pfe.swf 部署校验：二进制含 RandomRoomsMod 16 处引用；tag 数 84384 一致；
  回滚备份 `pfe_before_rrooms_20260821_184958.swf`

## 合成算法演进史（每条=一个实机反馈闭环）

| 版本 | 算法 | 实机反馈 → 教训 |
|---|---|---|
| v3.1 | 字段噪声+固定直线 roadWalls | 两个固定"模板"（corridor=双竖墙/hall=双横墙）→ 删直线 |
| v3.3 | 墙为底+开凿（fill-wall+carve） | 空/墙碎/通道堵 → 范式反转 |
| v3.4 | 直角规整房间+主廊折线 | 仍堵/墙多 → 学原版 |
| v3.5 | 原版分区墙（薄带+缺口） | 初步雏形但水/栅格碎片化 → 学原版物件 |
| v3.6 | 原版条带马尔可夫（48×4 条带库） | **拼贴感**（内容级复用）→ 学规律不学内容 |
| v4 | 行谱结构生成（PROFILE 逐行采样） | 混乱墙充填（谱是边际分布，勿逐行全填）→ 行二值化 |
| v4.3 | 锚点行=墙带 + 竖向墙柱 | 墙拼贴/水碎片 → AllData 材质表实证 |
| v5 | 房间-走廊骨架（显式房间+2宽L连廊） | 通道少/墙大 → 房间加大+双连接 |
| v5.1 | +物件生成（door/crates/sofa/back/player） | **物件悬空+孤立房间** → 三根因 |
| v5.3 | linkL2 下标错位修复+门朝房内+back 开放格 | **待实机评估** |

**教训线**：不要复刻内容（v3.6 条带=拼贴）；谱是边际分布不能每行全填（v4）；
物件必须校验占地格（v5.1 悬空）；走廊 linkL2 必须排除目标房间且房间/矩形下标
同步（v5.3 孤立房间）；back 元素原版 85% 放在开放格（v5.3 悬空）。

## 关键实证知识（AllData/房间 XML 反编译，勿再猜）

- **材质表**（`AllData.d.mat`，ffdec 导出 fe/AllData.as）：
  - fForms A-T 全部 phis=1 实体墙（J=Железная стенка, A=Сталь, G=Камень…）
  - **ed=2 拉丁 A-Z oForms 是真实地板纹理**（Плитка/Металл.плиты/**Сетка=K 网格
    地板=用户"框架地板"（s+space 可穿）**/Трубы…）——旧 tile-code-table.md 里
    "占位无效果"是错的，需要修订
  - ed=3/4 西里尔+`-`：А/Б 楼梯、`-`ДЕКНР 横梁(shelf)、ВГЖЗИЙЛМОПСТ 台阶、
    `*`=水、`,`/`;`/`:`=Z 层
- **房间 XML**（原版 rooms_*.xml）：`<a>`×25 网格行 + `<obj id code x y/>` +
  `<back id x y/>` + `<doors/>`（空标记）+ `<options>`
- **物件占地格**（放置必须全开放校验）：mcrate2/box/woodbox 2×2、
  couch/table/chest 2×1、locker/bookcase 2×3、stdoor 1×3、door1 1×2、
  hatch2 2×1、radbarrel/filecab 1×2、player 2×2、ammobox/explbox/lov 1×1
- **摆放规律**（原版实测）：箱子贴墙 46-52%、沙发室内、桌子居中、门在门洞；
  back 85%+ 在开放格
- **enl1/enl2/enf1 = 敌人出生标记**（tip=enspawn）；`player` obj=出生点
  （tip=spawnpoint）→ **敌人生成待做**：biome 规则（sewer 只尸鬼；mane 有
  天角兽/狮鹫/掠夺者/斑马/尸鬼，无英克雷）
- Location 构造 `for each(obj in nroom.obj)`；`noHolesPlace`+`space[].place`
  决定移除类物件落位；ramka(1-8) 控制房间边沿 phis；setNoObj 标 place=false

## 当前生成器（v5.3，src/rr/RRSynth.as）

整图填墙 → 干净矩形房间 6-11 个（8-13×6-10，三带轮换，间距 2，互不粘连）→
走廊网络（linkL2 2宽L连廊：排除本房矩形+order下标同步；6 缺口连入；
2-4 条额外环连接）→ 材质带（2×4 区 90% 主字符）→ 边界 0/24 行 0/47 列整墙
+6 缺口 → 装饰排（安全后缀：排除 `*`水/K网格/`-`横梁/西里尔台阶）→ 水池成片
（sewer/plant）→ 物件（门朝房内偏移/贴墙箱子 2-4/biome 池/沙发/桌/书架/出生点，
全部 footOk 占地校验；back 3-6 放房间内开放格）→ finishStripRoom：缺口强制 +
repairConnectivity（小口袋<16 填墙、大口袋 2 宽 L 连廊=孤立房间兜底）

## 工具链

- 编译 `build/build-m0.sh`（amxmlc target-player 32.0；AIR_HOME=
  `C:/Users/micha/Documents/_sandevistan_dev/flexsdk`）
- 部署 `build/deploy-pfe.sh`（ffdec 单脚本定向补丁 MainFE loader；备份/校验/回滚）
- 离线验证：`build/synth-proto3.py`（300 房不变量）、`build/synth-v52-verify.py`
  （物件占地格+房间可达性镜像，注意需 rm -rf build/__pycache__ 防旧字节码）、
  `build/corpus-analysis.py`（原版语料统计）
- 语料：`Remains/Rooms/rooms_*.xml`（525 个 25×48）；ffdec 导出脚本在
  `/tmp/matdump/scripts/`（fe/AllData.as、fe/loc/Location.as、fe/loc/Form.as、
  fe/loc/Tile.as、fe/Obj.as）
- 内置诊断：dumpSynthGrid（对照 genGrid+debugStages 分阶段）、precheckSynth
  （`new fe.loc.Location` 构造预检）

## 下一步（按优先级）

1. **等 v5.3 实机反馈**（F5）—— 若通道/悬空仍有问题，先看日志与 dump
2. **敌人出生标记**：每房 1-3 个 enl1/enl2/enf1（按 biome 规则、tip=enspawn
   走 addEnSpawn 通道，安全）
3. 通道可见性/房间比例按实机体感调结构参数（房间数/间距/额外环数）
4. 远期：v4 规划 M10 构件级 WFC 混合；种子/联机同步仍延后（DEC-0001）
5. 共享知识待办：tile-code-table.md 修订 ed=2 拉丁 oForms 语义；AllData 物件
   体系（obj/back/doors/占地格/enl 敌人标记）沉淀为发现文档

## 回滚

- 游戏 SWF：`pfe_before_rrooms_20260821_184958.swf` → 改回 pfe.swf
- 算法：git 每版本独立提交（v3.3→v5.3 可回退）；`src/rr/RRStripData.as` 保留
  v3.6 条带数据（未引用，可复活）