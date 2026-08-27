# 当前生成器（v5.3）流程

> src/rr/RRSynth.as。2026-08-27 自 state/current-status.md 迁入；演进史与教训见 state/journal.md。

整图填墙 → 干净矩形房间 6-11 个（8-13×6-10，三带轮换，间距 2，互不粘连）→
走廊网络（linkL2 2宽L连廊：排除本房矩形+order下标同步；6 缺口连入；2-4 条额外环连接）→
材质带（2×4 区 90% 主字符）→ 边界 0/24 行 0/47 列整墙 +6 缺口 →
装饰排（安全后缀：排除 `*`水/K网格/`-`横梁/西里尔台阶）→ 水池成片（sewer/plant）→
物件（门朝房内偏移/贴墙箱子 2-4/biome 池/沙发/桌/书架/出生点，全部 footOk 占地校验；
back 3-6 放房间内开放格）→ finishStripRoom：缺口强制 + repairConnectivity
（小口袋<16 填墙、大口袋 2 宽 L 连廊 = 孤立房间兜底）

## 内置诊断

- dumpSynthGrid：对照 genGrid + debugStages 分阶段
- precheckSynth：`new fe.loc.Location` 构造预检

## 回滚

- 游戏 SWF：`pfe_before_rrooms_20260821_184958.swf` → 改回 pfe.swf
- 算法：git 每版本独立提交（v3.3→v5.3 可回退）；`src/rr/RRStripData.as` 保留 v3.6 条带数据（未引用，可复活）
