---
domain: knowledge-validation
type: discoveries
game-version:
  - "1.02"
confidence: high
verified: false
discovered-by: RandomRooms
evidence:
  - kind: mod-source
    symbol: "RandomRoomsMod.finalizePreflight/refreshLandPool/autoPilot; RRSynth.genGrid/hasGround/footOk; RRCook.cookPool; RRDiag.log"
  - kind: local-experiment
    summary: "2026-09-10 基线 2187622 隔离编译通过；同样的合成日志旧前缀解析成功、v6.6 前缀失败。未运行游戏。"
date-updated: 2026-09-10
---

# v6.6 接手核验：验证工具与现有证据的边界

针对 RandomRooms 提交 2187622；保留历史实验记录，不把本轮编译当作实机验证。

## 已确认

### 构建与部署文件

本模组分支 main，接手工作树干净，身份 eclipse。源码日志标签为 [RR:v6.6]。
当前配置、Java 和 mxmlc 编译得到 34380 字节临时 SWF，工具退出码 0。
4 条警告：RRSynth.as 的 dz（431 行）、zl（1560 行），RandomRoomsMod.as 的 uce（170 行）重复变量定义，以及 RRConfig 缺显式构造函数。

| 文件 | SHA256 |
|---|---|
| release/RandomRoomsMod.swf | `5E3D611C9C38F19FEB30D0DB535BFDC6D1040FE8CF3A5B6F8EC39131E2DA4A00` |
| 临时编译 SWF | `854660B0C80D10160F0EC6133B69DA71EDCC4E3BB8B515F8730CB5BFFB846E7D` |

二者同为 34380 字节、哈希不同；未做 SWF 代码差异分析，不宣称内容一致。release 未写入，哈希与接手前一致。

隔离编译复现（PowerShell，工作目录 mods/RandomRooms）：

```powershell
$rrOutput = Join-Path $env:TEMP ('RandomRooms-check-' + [guid]::NewGuid().ToString('N') + '.swf')
& 'D:\Program Files\Adobe Animate 2024\jre\bin\java.exe' `
  '-Xmx384m' '-Dsun.io.useCanonCaches=false' '-Djava.util.Arrays.useLegacyMergeSort=true' `
  '-jar' 'D:\RemainsMod\mods\Sandevistan\build\tools\flexsdk\lib\mxmlc.jar' `
  '+flexlib=D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk/frameworks' `
  '-load-config=build/rr-config.xml' '-swf-version=32' '-use-network=false' `
  '-static-link-runtime-shared-libraries=true' ('-output=' + $rrOutput) 'src/RandomRoomsMod.as'
```

### 日志分析工具

build/render_dump.py 只去掉旧前缀，正则要求 DUMP 行相邻且没有每行前缀。
本轮使用相同 25×48 网格、1 个 player、BEGIN/END 的临时数据调用原脚本：

| 每行前缀 | 退出码 | 生成 PNG |
|---|---:|---|
| [RR:0.0.1-M0] | 0 | 是 |
| [RR:v6.6] | 1 | 否 |

临时数据和图片随后清除，没有读取或修改玩家日志。静态检查还确认：

- blocks[-1] 只处理最后一个完整块，不能重现整批 32 房统计。
- BEGIN 正则仅接受名字，不接受当前可选的 b24 属性。
- 图片为 W×H，即 48×25；S=16 未用于缩放，物件统一近似 2 格宽。
- “脚下格分布”读取 grid[y][x]，是锚点格，不能判定 y+1 支撑。
- RRDiag 追加日志并在 3000 行封顶；批量分析还须区分会话与截断。
- diag-skeleton.py 针对 v5.8；synth-v54-verify.py 针对 v5.4 并依赖 v5.2 结构，均不能作为当前生成器的完整验证。

### 展示馆数量与生成顺序

finalizePreflight 先建立 beg0 + 8 个启动合成房，并将 beg0-only 的 showBase 写入 origPools。
随后 tip=rnd 公共循环用 origPools[f2] = pool.copy() 覆盖该快照。
进入展示馆时复制快照，追加最多 8 个新合成房，再由 cookPool(showFresh, 1) 为每个普通房追加最多一个变异副本。
全部生成与变异成功时，32 个 syn 房来自 **8 个启动房 + 8 个新房 + 16 个变异副本**，不是历史描述的 8 + 24。
预检丢弃或变异失败会降低数量；预检保留数不等于最终房池数量。

正常新房路径：骨架 → 连通修复 → 物件放置 → XML → 字符/构造预检 → 房池变异。
生成器出口、变异后副本需要分别检查；玩家可达还受实际 Land/Location 构造和相邻房碰撞影响。

### 自动试驾与物件检查

autoPilot 只检查 applicationStorageDirectory 的 auto_enter.txt，没有 appId 白名单。
其 newGame(0, "LP", null) 调用是读档：原版 scripts/fe/World.as:823 用 ng = nload < 0 判定新档，0 读取 saveArr[0]。
后续代码仍有 autoKey、gotoXY、设置玩家位置和 outLoc(2)，历史“多步试驾弃用”不表示代码已删除。

RRSynth 的 footOk/markUsed 按锚点行横向宽度处理；hasGround 对宽度内任一实体支撑即返回 true，不是全宽支撑。
wallSpot/interiorSpot 的 used 检查只读取候选起点。这是检查覆盖范围的事实，不等于已观测到悬空或重叠故障。

## 观察到

- 旧记忆混有 v5.9/v6.0 待办和 v6.6 状态，本次重写入口；journal 历史条目保留。
- 最新历史记录为 2026-09-07 的 32 房指标和 300 次模拟跨房，不是本次实测。
- 早期 room-system-architecture.md 的“rnd 每次重建”与最新源码审计冲突；应以 land 为空或 crea 为重建条件，参照公共库 world-generation-source-audit-2026-09-09.md。

## 推测

- 旧脚本可能曾配合临时程序或手工统计使用，本轮未找到并验证完整的历史统计流程。
- 没有 0 号存档的全新隔离实例可能走不通现有试驾启动，须实测确认。
- SWF 哈希差异可能来自构建元数据或构建条件，原因尚未定位。

## 尚未验证

本轮没有运行游戏、部署或修改源码。后续依次补齐日志工具、核实隔离试驾前提、复评 v6.6。
门/活板门频率、出生点、整批悬空、实际跨房弹回及支撑/重叠边界均需新证据。
种子只接管模组随机源，未证明原版抽样、镜像和完整世界一致；诊断调用可能消耗同一序列。
