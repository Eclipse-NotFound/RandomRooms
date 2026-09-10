# 真实 AS3 生成器基线

本工具直接编译并执行当前 `src/rr/RRSynth.as` 及其依赖；可调用 `RRCook`。
不加载游戏 SWF，不调用 RandomRoomsMod.init，不修改 release 或真实存档。

在游戏根目录执行：

```powershell
& './mods/RandomRooms/build/style-review/harness/run-baseline.ps1' `
  -OutputName 'generated-current.xml' -VersionTag 'space-v7' -SamplesPerBiome 8 -CookCopies 1
```

Java / Flex SDK 可用同名参数覆盖。工具沿用模组显式引用 playerglobal 与
airglobal 的编译配置，但覆盖输出为本目录的 SynthBaseline.swf。
AIR 描述符的 appId 为 pferr-synth-baseline，窗口隐藏；过程超过 60 秒时
只终止此次 Start-Process 返回的 PID。harness 正常完成后主动退出。

输出在上一级 style-review 目录：

- 默认 `generated-current.xml`：32个完整Room XML；OutputName只接受.xml叶文件名。
- 同名stem的 `-manifest.json`：源码/结果SHA256、维度、底行开口、rrGen/主题/类型。
- 同名stem的 `-progress.txt` / `-error.txt`：启动进度和异常。
- CookCopies>0时同名stem的 `-cooked.xml`：真实cookPool后的整个池及副本数量。
- stdout/stderr 在本 harness 目录的 adl-stdout.txt / adl-stderr.txt。

每份 Room 附 harnessBiome、harnessSeed、harnessValid。
种子为 20260910 + biomeIndex × 1000 + sampleIndex，随后 fork("synth")。
随机源通过闭包调用，避免 AS3 提取方法引用后丢失 this。

2026-09-10 实跑：退出码 0，32/32 字符预检通过；XML 162337 字节，
SHA256 为 9292C75A9F0D8053AAE61DDCA080812927F55C36F8152712DA79EFDC222679E9。
编译仅有生成器原有的 dz / zl 两条重复变量警告。

32/32 均为 25 行 × 48 列；32/32 的底行 x=23,24 都为开放格，总计 64 格。
此处只证实生成器输出，尚未复现玩家从这些位置坠落或死亡。

上述baseline-v66是保留的旧版本出口证据。当前默认不会覆盖它。
SamplesPerBiome范围1..256、BaseSeed可覆盖、CookCopies范围0..8。
2026-09-10 新space-v7实跑formal-c-current.xml：32/32 validate通过且底行封实；
cookPool(...,1)新增0，真实验证生成房保护。输出SHA256为
0177E6EC0B65ED7EF2C92E0D62741BFE99E516EDC45E9D7A882FA0314FE9C5EE。
此工具不包含Land/Location装配或游戏画面；harnessValid不代表通行或审美通过。

注意：File.applicationDirectory 是 app:/ 根，其 parent 为 null；转换为
new File(File.applicationDirectory.nativePath) 后，才能取到真实文件目录的父级。
所有显式输出均在本工作区；harness 没有 applicationStorageDirectory 写入。
生成的 SWF、XML、PNG、JSON、临时日志均为可再生产物，提交时排除。

`-RoomKind connector` 可强制生成连接竖井；也接受 atrium、workshop、offices、
damaged、service、warehouse。省略时保留各主题的正常权重，不强制类型。
v7.1 常规批次为 `-OutputName generated-v71.xml -VersionTag space-v7.1
-SamplesPerBiome 256 -BaseSeed 9301000 -CookCopies 1`；连接竖井批次为
`-OutputName generated-v71-connectors.xml -VersionTag space-v7.1
-SamplesPerBiome 16 -BaseSeed 9310000 -CookCopies 1 -RoomKind connector`。
两批共1088间，包含门/活板门/玻璃窗；独立检查用 build/verify_architecture.py，
把未破坏的玻璃计入阻挡，不假定打碎玻璃才能通行。
