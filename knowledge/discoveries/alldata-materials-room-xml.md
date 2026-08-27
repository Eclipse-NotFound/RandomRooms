# AllData 材质表 / 房间 XML / 物件占地格（反编译实证，勿再猜）

> 来源：ffdec 导出 fe/AllData.as（mat 表）、fe/loc/Location.as、fe/loc/Form.as、fe/loc/Tile.as、fe/Obj.as 与原版 rooms_*.xml 语料统计。
> 2026-08-27 自 state/current-status.md 迁入（原文在 git 历史）。
> 待办：按 GOVERNANCE §4 提炼进 shared-knowledge（tile-code-table.md 的 ed=2 语义需修订；物件体系可沉淀为发现文档）。

## 材质表（`AllData.d.mat`）

- fForms A-T 全部 phis=1 实体墙（J=Железная стенка, A=Сталь, G=Камень…）
- **ed=2 拉丁 A-Z oForms 是真实地板纹理**（Плитка/Металл.плиты/**Сетка=K 网格地板=用户"框架地板"（s+space 可穿）**/Трубы…）——旧 shared-knowledge tile-code-table.md 里"占位无效果"是**错的**，需要修订
- ed=3/4 西里尔+`-`：А/Б 楼梯、`-`ДЕКНР 横梁(shelf)、ВГЖЗИЙЛМОПСТ 台阶、`*`=水、`,`/`;`/`:`=Z 层

## 房间 XML 结构（原版 rooms_*.xml）

- `<a>`×25 网格行 + `<obj id code x y/>` + `<back id x y/>` + `<doors/>`（空标记）+ `<options>`

## 物件占地格（放置必须全开放校验）

- mcrate2/box/woodbox 2×2、couch/table/chest 2×1、locker/bookcase 2×3、stdoor 1×3、door1 1×2、hatch2 2×1、radbarrel/filecab 1×2、player 2×2、ammobox/explbox/lov 1×1

## 摆放规律（原版语料实测）

- 箱子贴墙 46-52%、沙发室内、桌子居中、门在门洞；back 85%+ 在开放格
- enl1/enl2/enf1 = 敌人出生标记（tip=enspawn）；`player` obj = 出生点（tip=spawnpoint）→ 敌人生成待做：biome 规则（sewer 只尸鬼；mane 有天角兽/狮鹫/掠夺者/斑马/尸鬼，无英克雷）

## Location 构造相关

- `for each(obj in nroom.obj)`；`noHolesPlace`+`space[].place` 决定移除类物件落位；ramka(1-8) 控制房间边沿 phis；setNoObj 标 place=false
