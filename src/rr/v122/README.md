# v12.2 对照快照

七个 AS3 类取自提交 `93e7fef`，只移动到 `rr.v122` 包并添加共享依赖的导入。
`RRArchitecture`、`RRPartitionPlan`、`RRSpaceRules`、`RRSynth` 保留 v12.2 算法；
其余三类一并冻结以保留 AS3 的具体类型关联。
共享 `RRScene`、`RREcology`、`RRPorts`、`RRSeed` 的生成规则与该提交一致。

正式入口由 `RRExpedition` 选择 v12.2 或当前 v12.3，地图连接和坐标种子共用。
请勿为了同步新版而改写此快照；必要的修复须说明差异并重放历史证据。
`build/style-review/harness/run-comparison.ps1` 对两版各 512 个冻结 HTML 样本做语义全量对照，再检查实际地图输入。
