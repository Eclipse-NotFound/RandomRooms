---
domain: world-objects
type: experiments
game-version:
  - "1.02（实玩根目录 pfe.swf）"
confidence: high
verified: true
method: 真机实验（F1 进入 random_rooms + 日志采样 + python 跨实现序列对照）
evidence:
  - kind: runtime-experiment
    summary: "种子模式 preview(5) 与 build/seed-check.py 参考序列逐位一致
      （0.460898014/0.755076896/0.622607368/0.861020401/0.497080652）；
      random_rooms 25 格全生成，beg0 落 (0,0)，混合池 54 房 + 258 副本；
      变异副本（_rr 后缀）大量被选中"
date-updated: 2026-08-18
---

# P1 实验记录：种子系统 + random_rooms 土地（实机验证通过）

## 实验内容

1. RRSeed（xorshift32 + fork 派生）注入 RRCook.rnd（种子模式）
2. random_rooms 新土地：GameData.d 追加 5×5 conf=1 dif=8 land
   + 混合池（rooms_stable 32 rnd 房 + rooms_sewer 22 rnd 房 + stable beg0）
3. RRMenu 主菜单配置条（SharedObject rr_config 持久化）
4. 热键：F1=random_rooms / F2=rbl / F3=rr_test

## 结果（全部通过）

| 项 | 证据 |
|---|---|
| 种子确定性 | preview 与 python 参考序列逐位一致（xorshift32 跨实现验证） |
| 土地注册 | lands[random_rooms]=true，gotoLand 可达 |
| 混合池 | stable 32 + sewer 22 = 54 rnd 房 + beg0；进入后 25 格全有效 |
| 变异副本 | 258 个会话级副本 + 进入级重 cook（+54 副本，变更格 229）；布局大量 _rr 房间 |
| 起点房 | 新档首入 beg0 在 (0,0)（visited 语义确认） |
| 主菜单 UI | RRMenu 配置条显示；开关/种子输入持久化 |

## 技术要点（本模组知识）

- xorshift32 在 AS3 用 uint 位运算精确（<< 转 int32 后 wrap ≡ mod 2^32），
  python 对照版用 MASK32 一致；避免 mulberry32（需 imul，AS3 无，double
  乘法超 2^53 丢精度）。
- AS3 提取方法引用不绑定 this：注入 rnd 必须用闭包
  `function():Number { return seedGen.next(); }`。
- RRSeed.preview(n) 会消耗序列——日志对照用 fork("cook") 从头序列。

## 下一步（P1 收尾）

- PipPage 旅行入口（勘察 PipPageInfo 的列表构建与调用链）
- 深度循环（landStage/upStage 语义勘察）