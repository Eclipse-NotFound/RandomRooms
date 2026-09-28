# 现有编辑器与 RandomRooms v13 XML 的兼容边界

日期：2026-09-28。范围：只读源码调查、历史 XML 样本解析和独立规则重放；未启动 GUI、未保存编辑器地图、未修改编辑器或模组运行代码。本文的“规则重放”不是 AIR/GUI 往返实测。主调查随后提供了[隔离预渲染实测结果](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/design/editor-integration-20260928/preview-results.json>)，与静态调查分别标明。

## 结论

**现有编辑器适合立即用作生成结果的视觉审查器，但目前不能作为 v13 XML 的无损编辑器。** 标准 48 × 25 地形、家具、背景及房间 `options` 有可复用基础；保存链会丢生成器元数据，序列地图的编辑房间还会丢 `doors`。预渲染能辅助看材质、装饰、墙体和静态水面，不能验收 v13 的 D/V、生态、炮塔布防、终端接近路线及机关运行。

这里的结论来自当前补丁源 `Editor.as`，其九个既有读写方法已在编辑器上一轮验证中确认未改变。那轮 55 个原版房间的成功另存，不能推导出含 v13 扩展字段的房间也能无损保存。[既有验证记录](<D:/Program Files/Steam/steamapps/common/Remains/Editor/Enhancements/build/verification.json:18>)

## 1. XML 载入和保存：兼容矩阵

| 内容 | 载入到当前编辑器 | 再编码／保存后的行为 | 判断依据 |
|---|---|---|---|
| `<all>` 根属性，如 `rrVersion`、`rrSeed` | XML 原文存在 `allroom` | `encodeAll()` 新建空 `<all>`，丢所有根属性；即使没有编辑任何房间也如此 | `encodeAll` 785–797 |
| `<all>/<land>` | 仅取第一个 `land` 为 `landXML` | 原节点整体追加，属性与子节点可保留；额外 `land` 不保留 | `decodeAll` 974；`encodeAll` 789–792 |
| `<all>` 下除 `land`、`room` 的扩展节点 | 没有进入编辑模型 | 全图保存时丢失 | `decodeAll` 974–1008；`encodeAll` 788–796 |
| `<room>` 根属性 | `arrroom[name]` 暂存原 XML；编辑模型仅使用名称、坐标 | **重新编码的房间**仅重建 `name` 与按模式决定的 `x/y/z`；`rrGen/rrTheme/rrMirror/rrVersion/rrDanger/rrValue/rrSeed/...` 全部丢失 | `encode` 826–837 |
| `<rrPlan>`、其他房间扩展子节点 | 不进入画布模型，也不进入房间属性框 | **重新编码的房间**不追加这些节点，故丢失 | `decode` 1036–1090；`encode` 838–884 |
| `<obj>` / `<back>` 自定义属性和子节点 | 识别且坐标合法的对象保留整段 XML | `rrContent/rrMount/rrZone/rrD/rrV/rrFixture/uid/code/allid` 及 `<scr>` 等可随原节点保留；不是只挑标准属性 | `addObj` 1820–1827、1849–1859；`encode` 856–860 |
| 未在编辑器目录内的对象／背景，或坐标越界的对象 | `addObj()` 直接返回，不进入 `objs` | 未修改的原 `arrroom` 仍有它；当前房间被重编码后会丢它 | `addObj` 1736–1739、1752–1759 |
| `<options>` | 房间属性框拿的是第一个 `options` 整节点 | 属性及子节点整体保留；多个 `options` 只保留第一个 | `decode` 1082–1090；`encode` 878 |
| `<doors>` 22 个接口值 | 不读入原接口数组 | 随机模式从边缘地形重算；**`land serial="1"` 的序列模式不写 `doors`** | `decodeAll` 974–982；`encode` 861–875；`getDoors` 908–967 |
| 地形 `<a>` | 固定读取 25 行，每行固定读 48 格 | 从每格 `edTile.enc()` 重建 25 行；不保留每个 `<a>` 的属性、额外行列或任意自定义格码 | `decode` 1038–1058；`encode` 838–855 |

以上行号均在 [当前 Editor.as](<D:/Program Files/Steam/steamapps/common/Remains/Editor/Localization/display-patch/modified/Editor.as:785>)。对象坐标限制具体是 `0 ≤ x < 47`、`0 ≤ y ≤ 24`；画布虽有第 48 列（`x=47`），对象导入过滤比格子宽度更窄。[addObj](<D:/Program Files/Steam/steamapps/common/Remains/Editor/Localization/display-patch/modified/Editor.as:1718>)

**丢失不是一加载就写回磁盘。** `decodeAll()` 把原房间节点放进 `arrroom`，`decode()` 末尾清除 `mActive`；`encodeCurrent()` 仅在 `mActive=true` 时替换该房间。未动的房间可能继续带完整元数据，但编辑过的房间不行。切换房间会调用 `encodeCurrent()`，并不必等最终保存。尤其“房间属性”按钮仅打开就设 `mActive=true`，即使用户只是想读参数，随后切换房间也会在内存里重编码；“更新列表”同样主动设为 true。[载入原文](<D:/Program Files/Steam/steamapps/common/Remains/Editor/Localization/display-patch/modified/Editor.as:1008>)、[重编码条件](<D:/Program Files/Steam/steamapps/common/Remains/Editor/Localization/display-patch/modified/Editor.as:800>)、[切换房间](<D:/Program Files/Steam/steamapps/common/Remains/Editor/Localization/display-patch/modified/Editor.as:660>)、[房间属性按钮](<D:/Program Files/Steam/steamapps/common/Remains/Editor/Localization/display-patch/modified/Editor.as:1381>)

房间属性原始 XML 框实际上只对应 `<options>`，不是完整 `<room>`。对象属性框则对应整段对象 XML；`updSelObj()` 从文本重新解析并替换该节点。这意味着不能把缺失的 `rrPlan` 或 `rrMirror` 粘到“房间属性”框就当作恢复了正确层级。[属性框](<D:/Program Files/Steam/steamapps/common/Remains/Editor/Localization/display-patch/modified/Editor.as:2025>)

## 2. 对实际 v13 样本的静态核对

选择已归档的 `design/v13-content-runtime/population-release-candidate/rrstyle-navigation-{theme}-pool.xml`，没有生成新地图或改动这些证据。四份均是 `<all rrVersion="13" rrSeed="20260818"><land serial="1"/>…`，每房都有 `doors/options/rrPlan`，因此上节根属性、房间元数据及序列模式接口丢失风险实际适用。

| 样本 | 房间数 | 地形格数 | 物体数 | 背景对象数 | 独立格码种类 | 静态格码重编码差异 |
|---|---:|---:|---:|---:|---:|---:|
| [工厂](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/design/v13-content-runtime/population-release-candidate/rrstyle-navigation-plant-pool.xml:1>) | 36 | 43,200 | 1,256 | 1,457 | 17 | 0 |
| [废弃避难厩](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/design/v13-content-runtime/population-release-candidate/rrstyle-navigation-stable-pool.xml:1>) | 35 | 42,000 | 1,258 | 1,097 | 14 | 0 |
| [下水道](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/design/v13-content-runtime/population-release-candidate/rrstyle-navigation-sewer-pool.xml:1>) | 36 | 43,200 | 718 | 3,050 | 14 | 0 |
| [城市废墟](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/design/v13-content-runtime/population-release-candidate/rrstyle-navigation-mane-pool.xml:1>) | 25 | 30,000 | 984 | 1,421 | 20 | 0 |

共 132 房、158,400 格、55 种不同格码。使用编辑器原始 XML 导出的内嵌材质／对象目录，核对 `edTile.dec/enc` 字节码：首字符为前景；其后按材质 `ed` 放入背景、梯子、梁／台阶、水这几个槽，`,`、`;`、`:` 为形状；编码按槽顺序输出。对上述样本进行独立 Python 规则重放，所有格码可识别且输出相同，`*` 水标记也保留。所有样本 `obj/back` 都能在编辑器目录匹配，且无对象触发坐标过滤。[材质槽建立](<D:/Program Files/Steam/steamapps/common/Remains/Editor/Localization/display-patch/modified/Editor.as:422>)、[材质表注册](<D:/Program Files/Steam/steamapps/common/Remains/Editor/Localization/display-patch/modified/Editor.as:1244>)、[edTile.enc 字节码](<D:/Program Files/Steam/steamapps/common/Remains/Editor/Localization/display-patch/original/Editor.xml:30689>)、[edTile.dec 字节码](<D:/Program Files/Steam/steamapps/common/Remains/Editor/Localization/display-patch/original/Editor.xml:30713>)

这是对**这些固定样本及既有字节码规则的静态验证**，不是点击编辑器后的文件往返验证，也没有证明将来任意格码或未知 ID 安全。未知根属性和 `rrPlan` 的丢失结论是当前保存代码的直接推导，本子调查未运行 Editor 的真实 `decode/encode` 来复现。

样本 SHA-256：

```text
plant  0f3fd90e6c01265c0706f755ee246340fb5f9f152d46571d5f404fa8a38e6b5b
stable f3f2874b64c6da7c764aaebbd4082689f531e3893e6cae0a0064d45ce10e6502
sewer  abcb7ed16fbd6c8480c093c6ccdedc98bcd3b8677a7e018c9b6ffe7eadcd051e
mane   1bc3eac41b54233f82098afcfc9a4b6886a464cb6f0f10ede0d61f18d2761ef6
```

元数据也不是无用备注：`RRSynth` 写入用途空间、实体块、合并关系、连通、梯路、水区，并附 v13 的 zone/point/gun/control；`RRDebugOverlay` 按 `rrPlan` 和根版本／D/V 画调试层。对象移动后，原 `rrPlan.point/gun/control` 会过时；仅做到“不丢字段”仍不足以保证编辑后的战术证据有效。[生成元数据](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/src/rr/RRSynth.as:105>)、[v13 元数据](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/src/rr/RRContentPlan.as:349>)、[调试层读取](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/src/rr/RRDebugOverlay.as:63>)

## 3. 预渲染：已能看见什么，哪些 v13 效果缺席

`ToolsSnapshot()` 调用现有 `encode()` 取得当前画布快照，仅临时复制对象数组以避免排序改变编辑顺序；它不写地图文件，但生成的预览快照同样没有房间 `rr*` 根属性和 `rrPlan`。它会先应用属性框中尚未提交的 XML，因此也不是彻底无副作用的只读对象接口。[ToolsSnapshot](<D:/Program Files/Steam/steamapps/common/Remains/Editor/Localization/display-patch/modified/Editor.as:363>)

`NativeRenderer` 创建隔离的原生 `LandAct → Land → Location`，保留标准 `room.options` 给 `Location` 构造处理，绘制原生材质、背景、门、箱柜和 `tip="trap"` 陷阱图形；并隐藏探索迷雾与相机边缘遮罩。[创建场景](<D:/Program Files/Steam/steamapps/common/Remains/Editor/Enhancements/src/NativeRenderer.as:128>)、[绘图与静态对象](<D:/Program Files/Steam/steamapps/common/Remains/Editor/Enhancements/src/NativeRenderer.as:163>)

缺席内容须比“不会模拟敌人”说得更具体：

- `tip=unit/spawnpoint/up/enspawn` 被跳过，**固定炮塔、地雷、部分压板／激光触发器、机关发射器，以及商贩／医生也可能完全不画**。例如工厂样本的 `damgren` 和 `trplate` 不是 `tip=trap`，同样走跳过分支；普通编辑画布仍有其标签／标记。[跳过分支](<D:/Program Files/Steam/steamapps/common/Remains/Editor/Enhancements/src/NativeRenderer.as:190>)、[样本机关](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/design/v13-content-runtime/population-release-candidate/rrstyle-navigation-plant-pool.xml:408>)
- 不载入 RandomRooms 的 `RRDebugOverlay`，不显示用途、D/V、炮塔枪线、终端候选路线；没有战斗、敌群、掉落、容器潜伏事件、黑入与开门后的变化。
- 预览 Box 的复制 XML 主动去掉 `<scr>` 和 `scr/scropen/scrclose/scrtouch/scrdie/fun`；因此 v13 的按钮解锁奖励箱之类行为不能在此验证。[去脚本](<D:/Program Files/Steam/steamapps/common/Remains/Editor/Enhancements/src/NativeRenderer.as:174>)、[v13 按钮连接](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/src/rr/RRContentPlan.as:309>)
- 不执行 `RRGrowth` 的相邻房间配对、边缘开放恢复、`mainFrame/setObjects/preStep` 流程，也不验证向右／向下扩张及进出。单房看起来有出口，不等于跨房接缝与路线成立。[运行时拼接](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/src/rr/RRGrowth.as:158>)、[开放边缘恢复](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/src/rr/RRGrowth.as:71>)

### 地区推断、房间 options 与镜像

1. **地区不会自动认识 v13 的 `rrTheme`。** 当前推断只查 `land.@id`、文件名包含原版 `rooms_*`，再比房间名集合，默认 `random_plant`。本节四份样本都没有 land ID，路径没有原版文件名片段，房间名与原版池无交集，静态重放均回退工厂。应手选地区；后续适配宜直接映射 `rrTheme` 到 `random_plant/stable/sewer/mane`。目前 PreviewPanel 首次加载后还会保留地区选择，换房／换图并不自动重推。[infer](<D:/Program Files/Steam/steamapps/common/Remains/Editor/Enhancements/src/NativeRenderer.as:99>)、[面板首次加载逻辑](<D:/Program Files/Steam/steamapps/common/Remains/Editor/Enhancements/src/PreviewPanel.as:84>)
2. **`room.options` 并未被忽略。** 预览 wrapper 显式合并的是 `land/options`，随后把完整房间交给原生 Location；Location 再读取房间 `backwall/color/wtip/wrad/vis/entip/...`。因此选错地区后，某些墙体、水色仍可“看起来对”，远景及其他地区默认值却可能错。[原生 options 覆盖](<D:/Program Files/Steam/steamapps/common/Remains/game-reference/decompiled/1.02/src102/scripts/fe/loc/Location.as:376>)
3. **城市有明确参数差异。** RandomRooms 原运行链给城市 `transpFon=true`，当前预览只传 `{mirror:…}`。`RRScene.options` 还写房间属性 `darkness="-20"`，原生房间覆盖实际识别的是 `dark`；原运行效果依赖 `configureLand()` 从 `random_mane` 复制 `darkness` 等环境值。故不能因为房间带 `darkness` 就认为自动回退工厂也等效。[RRScene options/configureLand](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/src/rr/RRScene.as:30>)、[运行时参数](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/src/rr/RRGrowth.as:141>)、[Location 识别 dark](<D:/Program Files/Steam/steamapps/common/Remains/game-reference/decompiled/1.02/src102/scripts/fe/loc/Location.as:474>)
4. **下水道的格内静态水可绘制。** 样本使用 `*` 地块标记，原生 `Tile.dec()` 将其设为水，Grafon 根据 `tipWater` 画水；水区 `rrPlan/water` 是元数据，实际水面不靠这个节点生成。`color="green" wtip="1" wrad="3"` 则是 Location 可识别的房间选项。但辐射、实际涉水、干路可达性仍须游戏运行验证。[水区样本](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/design/v13-content-runtime/population-release-candidate/rrstyle-navigation-sewer-pool.xml:119>)、[水标记读取](<D:/Program Files/Steam/steamapps/common/Remains/game-reference/decompiled/1.02/src102/scripts/fe/loc/Tile.as:224>)、[水面绘图](<D:/Program Files/Steam/steamapps/common/Remains/game-reference/decompiled/1.02/src102/scripts/fe/graph/Grafon.as:500>)
5. **镜像不自动取 `rrMirror`。** 实际生成链写 `rrMirror` 并用相同布尔值构造 Location；当前编辑器的镜像按钮默认 false、沿用用户上次选择。工厂样本首房 `rrMirror="1"`，直接打开的朝向会与游戏不一致，应手动打开镜像，后续适配需按房间读取。[运行时镜像](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/src/rr/RRGrowth.as:123>)、[预览镜像变量](<D:/Program Files/Steam/steamapps/common/Remains/Editor/Enhancements/src/PreviewPanel.as:32>)

### 主调查提供的隔离实测

使用已安装 `EditorTools.swf/NativeScene.swf` 的逐字节副本，在独立 AIR 根目录对原始 XML 房间进行预览；以下结果均成功输出 1920 × 1000 PNG、`warnings=0`。这验证的是绘图组件接收原始房间的路径，**未经过 GUI 的 `ToolsSnapshot/encode()`，也不证明编辑后能无损保存**。[实测记录](<D:/Program Files/Steam/steamapps/common/Remains/mods/RandomRooms/design/editor-integration-20260928/preview-results.json>)

| 场景／房间 | 绘制对象 | 略过动态／生成点 | 传入镜像 |
|---|---:|---:|---|
| 工厂 `syn_2` | 30 | 17 | true |
| 废弃避难厩 `syn_2` | 42 | 18 | false |
| 下水道 `syn_28` | 31 | 14 | true |
| 城市废墟 `syn_19` | 58 | 4 | false |

实测还确认：原始样本文件名全部被 `infer()` 判为 `random_plant`；隔离副本改为 `samples/rooms_<theme>_rr_v13` 后才通过文件名识别到各自地区。这为上文的推断风险补充了真实 AIR 证据；没有改变历史样本名。UI 操作、裸 Windows 绝对路径及地图写回不在本轮隔离实测范围内。

## 4. 现在即可使用的安全查看路线

文件名栏填游戏根目录下的相对路径（省略 `.xml`），例如：

```text
mods/RandomRooms/design/v13-content-runtime/population-release-candidate/rrstyle-navigation-plant-pool
```

按住 Ctrl 点击“载入”，选房，再打开预渲染；依据 `rrTheme` 手选地区，依据 `rrMirror` 手选镜像。**只查看，不保存回历史证据文件。** 编辑器没有真正的只读模式；如需试改，应先使用另存的工作副本，并把其视为一次性的视觉草稿，当前不能直接用于 v13 运行数据。

这是按源码确认的载入路线，本文未启动 GUI 重做操作。`filePath` 为空，`loadClick()` 直接向 `URLRequest` 传入输入路径，去掉一次 `.xml` 后补回；没有调用 `File.nativePath` 或做 Windows 反斜杠／盘符规范化。因此能确认相对路径的设计支持，**裸 `D:\…` 绝对路径的运行兼容性未在本子调查实测，不应承诺**；`file:///D:/…` 形式可作为绝对 URL 候选，由隔离 AIR 载入测试确认。使用相对路径已能打开这些根目录内的样本，没必要复制进原版 Rooms。[filePath](<D:/Program Files/Steam/steamapps/common/Remains/Editor/Localization/display-patch/modified/Editor.as:46>)、[载入实现](<D:/Program Files/Steam/steamapps/common/Remains/Editor/Localization/display-patch/modified/Editor.as:559>)

应加载 `*-pool.xml` 这样的 `<all><room>…` 文件；`*-layout.xml` 是 `<layout><loc>` 汇总，不能作为房间画布，单独裸 `<room>` 同样不符合 `allroom.room` 的读取层级。[decodeAll 的遍历](<D:/Program Files/Steam/steamapps/common/Remains/Editor/Localization/display-patch/modified/Editor.as:989>)

## 5. 若接入开发闭环，编辑器侧的最小改造顺序

1. **先做只读审查入口**：载入实际生成结果，锁定保存／修改，对照种子、版本、地图坐标，按 `rrTheme/rrMirror` 设预渲染；补城市 `transpFon`，注明动态对象的省略数量与类别。元数据快照直接保留原 room；仍允许开关标记和导出图片。
2. **再补审查层**：按 `rrPlan/space/zone/point/gun/control` 叠加用途、D/V、生成点、枪线目标和候选路线。明确这是生成计划，不把静态线当成正在游戏中运行的枪线。运行实况仍由原游戏 `Shift+F3` 调试层提供。
3. **若要支持真正编辑再导回**：保存需保留 `<all>` 属性与未知节点、完整 room 扩展属性／节点和序列模式 `doors`；拒绝静默丢对象。地形或物体改动后需重新计算或明确标记失效的 `rrPlan`、接口与战术验证结果，不能只把旧元数据原样粘回。最后以四场景样本做真实 Editor 载入—编辑—保存—重载及模组校验，再考虑接入运行路径。

以上是源码支撑的适配建议，尚未实施。它让编辑器服务于“发现问题—修改生成规则—同种子重生成—原生检查”的过程；是否接受手工定制房间进入运行池，还需要模组侧明确的输入契约，不能由一次普通编辑器保存隐式改变。
