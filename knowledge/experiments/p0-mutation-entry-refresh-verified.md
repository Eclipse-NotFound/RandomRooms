---
domain: world-objects
type: experiments
game-version:
  - "1.02（实玩根目录 pfe.swf）"
confidence: high
verified: true
method: 真机实验（连续 6 次 F1 进入 + 日志逐格采样）
evidence:
  - kind: runtime-experiment
    summary: "refreshLandPool 每轮变异变更格 14/10/10/12/4/15 各不相同；
      起点房四次采样 13_rr1→13_rr1→служ.пом._rr2→служ.пом.；
      9 格完整无崩溃；集合 4-5 个唯一房间名（含 _rr 副本）"
date-updated: 2026-08-18
---

# P0 实验记录：模板变异 + 进入级刷新（实机验证通过）

## 实验内容

1. RRCook 变异器（规则经 15750 次离线不变式验证）
2. 会话级：preflight 对 tip=rnd 土地池 cook（+副本）
3. 进入级：F1 前 refreshLandPool——原始池快照重 cook → 覆写
   LandAct.allroom → land=null 强制重建

## 结果（全部通过）

- 变异副本被 newRandomLoc 加权选房选中（13_rr1 ×3、служ. пом._rr2 ×2 等）
- 进入级刷新：连续 6 次进入，每次变异变更格数不同、布局不同、起点房随机
- 强制重建（act.land=null）无损生效（rnd 土地内容可再生）
- 全程无崩溃、网格 3×3 完整、不变式（边界/doors/tip）由 selfCheck 守护

## 过程中确认的原生语义（详见 shared-knowledge 对应文件）

- rnd 土地 visited：首入才有 beg0，重入全随机（enterLand 置位+存档持久化）
- LandAct.allroom 与 land 均为 public，进入级干预可行

## 下一阶段（P1）

- random_rooms 独立新土地（复用 M0 土地注册链路）
- 种子系统（RRSeed：确定性 PRNG 注入 RRCook.rnd）
- 主菜单配置 UI + PipPage 旅行入口（接管入口后进入级刷新覆盖全部进入路径）