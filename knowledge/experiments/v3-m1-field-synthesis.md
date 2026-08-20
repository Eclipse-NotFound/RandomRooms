---
domain: world-objects
type: experiments
game-version:
  - "1.02"
confidence: high
verified: true
method: 离线原型（值噪声/SDF/Voronoi 场合成 + 挖廊道 + 500 房批量不变式）
evidence:
  - kind: offline-prototype
    summary: "synth-proto3.py：500 房不变式 0 失败；corridor 出现连续弯曲墙带
      （突破 v1/v2 固定切片拼接）；墙占比按类型近似达标"
date-updated: 2026-08-19
---

# RRSynth v3 M1：场合成器离线原型验证

## 结论

- **连续墙路线成立**：值噪声场 → 二分阈值 → 连续弯曲墙带，无"块单元"拼接
  感（corridor/hall/l 已可用形态）；500 房批量不变式 0 失败。
- 墙占比（按类型二分法精确控制）：corridor 0.28 / hall 0.20 / l 0.25 /
  bunker 0.30 / quad 0.38（quad 略高，可调 ds 权重）。

## 暴露的问题（M2 内容）

1. **quad**：Voronoi 区界中央被厚墙占据，无"四分区+区门"结构感——
   需要区门洞挖掘 + 区心开放；
2. **bunker**：掩体岛环墙 OK，但外部 70% 空无一物——需要掩体岛散布
   与装饰填充；
3. **开放区太空**：需要材质场（biome 墙字符）+ 装饰节奏 + 掩体/物件
   布置（M2）。

## 技术要点

- 二分阈值法对聚集分布鲁棒（percentile 对 quad 的 ds[0]+0.7*ds[1]
  分布会失效——曾致 0.99 墙占比）；
- 开放掩码（-1 强制开放带）实现"路由墙定义"：道路是场中挖出的，
  非预留带；四侧缺口始终连通（BFS 兜底）。

## 下一步（M2）

生物群系材质场（墙字符按空间场分配）+ 装饰层 + 掩体岛散布 + quad/
bunker 区门挖掘 → 离线验证 + 视觉评估 → M3 AS3 移植。
