# 调查证据与核验边界

2026-09-28。调查原版破碎构造与候选算法；没有开发或部署新生成算法。

## 已完成

- `build/style-review/audit_native_fracture.py` 扫描四个外置原版 XML 共192条房间记录，普通池120条；生成逐房计数、16例原网格/后景布置与文件 SHA256。再次读取原文件，四个指纹及16例网格/后景属性全部一致。
- 原生捕获第一轮9例完成：`native-captures/manifest.json` 为 complete、无 failed，18张 PNG 与 runner/cases 文件哈希全部通过；`native-captures/cases.xml` 的所有地形行和 back 属性再次与原版逐项一致。
- 屋顶46在单房 beg0 环境缺少原生 `ramka=6→backform=2` 条件，第一轮第8例背景不作为屋顶证据。单独复制 fixture 的 options，增加 backform=2 / transpfon=1，第二轮1例完成，2张PNG和日志/输入哈希通过，几何与 back 属性保持原版。
- 实际查看9个新参考房、修正后的屋顶及7个既有原生全房图。主要结论由 XML、1.02 反编译源码和原生图交叉核对；没有用 AI 生成图片冒充游戏实景。
- 页面 JS 两个文件通过 Node 语法检查；HTML 静态资源和锚点均检查，16例图像存在。页面数据来自同一 evidence 文件，不使用网络请求加载本地 JSON。
- 已查一手 Perlin、CA、WFC、FastNoiseLite 等作者/出版方资料；算法事实与本项目适配推断分开。不是原版算法逆向发现。

## 页面验证限制

尝试用浏览器自动化打开本地调查页，被浏览器安全策略拒绝：该接口仅允许 http/https，不允许 file 协议。没有改用本地代理、其他浏览器接口或间接执行绕行。**本轮未完成浏览器实点与页面截图检查**，仅静态检查代码、数据和文件路径。原游戏参考图片的实测与人工视觉核对已完成，不能与 HTML 排版实测混称。

## 实例与版本

- 第一轮 AIR ID：`pferr-style-99af88f001e140d7a42a00eaeceec124`；第二轮 ID 见 `roof-context/manifest.json`。均为独立新角色/存储；捕获进程正常退出，未使用真实 pfe 存档。
- 当前宿主与隔离副本 `pfe.swf` 都是 `C631CBF3511B6EE303F533D08D51511FE0EB702F43E5DB17F5241D8576C64867`。该值已在同日编辑器调查记录，区别于较早 v13 发布时的 B782…；本轮没有修改宿主，也不回写旧发布证据。
- 正式 `release/RandomRoomsMod.swf` 仍为 `A5EB49A089835BBC7B670411BBDF32865F5110AEAE79F8BC182AF3BB4C9CBE46`，88,909字节。
- 图像和 ZIP 延用仓库已有忽略规则，本机保留；文字清单及图像指纹入库。两个冻结捕获目录保持原始字节，避免换行归一化破坏哈希。

## 实景的边界

展示改变入口 options 和自动敌群，不改变原网格/back布置；单房接口会封边。原生渲染仍可能随机选装饰帧、残留具名生物也可能行动。全房图关闭玩家视野遮罩、未绘制全局远景，因此透明洞显示为深色。不能用这些图证明正常游戏光照、实际敌群密度、邻房接口、玩家通行、炮塔/终端或候选算法效果。

本轮没修改候选生成器，自然也没有为候选算法执行移动或战斗验收；下一阶段需要按最终地形重新检查，详见 native-study.md / algorithm-sources.md。

## 复现

使用既有隔离原生捕获流程：先运行 `build/style-review/audit_native_fracture.py`，再对 `fracture-native-reference.xml` 取9例，`fracture-roof-context.xml` 取1例，均配 `-MovementOnly -SessionDirectory visual-app`。此处 MovementOnly 仅筛选参考输入，不表示运行移动测试。使用 `freeze_captures.py` 冻结到新的目录，不覆盖当前证据。

## 归档与纠正

按照 remains-knowledge-contribution 规则，原版渲染机制写入公共 `rendering/discoveries/native-fracture-layers.md`；模组差距和算法建议留在本目录。显式更正已有 `world-objects/discoveries/tile-code-table.md`：ed=2 是背景材质、rear 斜梯仍有运动作用、部分高度编码、F 不是玻璃，保留旧有限实测记录并收窄其含义。F 的先前纠正来自同目录 window-identity-and-break-collision.md，未把这点当本轮首创。

使用 KB-000045 r2 的窄范围提醒：后续算法对照需冻结底图，不能仅保证种子相同。知识检索先前返回 partial/0命中，不当作无相关经验的完整证明。
