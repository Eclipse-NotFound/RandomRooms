---
domain: world-objects
type: experiments
game-version:
  - "1.02（实玩根目录 pfe.swf）"
confidence: high
verified: true
method: 真机实验（F1/F5 进入 + verifyEntry 采样 + 离线 200 房批量）
evidence:
  - kind: runtime-experiment
    summary: "RRSynth 合成房 25 行修复后：展示馆 12 格=11 合成房+вход；random_rooms
      注入 6 合成房+变异副本混排，25 格全有效无崩溃（2026-08-19）"
date-updated: 2026-08-19
---

# RRSynth 实机验证记录（含 25 行根因排查全链）

## 结果：全新构造房间完全可用

- 展示馆（F5）：12 格 11 合成房（syn_0/100/102...）+ вход(beg0)，变异副本
  （syn_101_rr10 等）混排；每次进入重合成
- random_rooms（F1）：注入 6 合成房 + 60 变异副本 + 敌表 122 房，25 格全有效
- 无崩溃、缺口连通正常、敌人/深度循环生态正常

## 核心根因（排查链，逐项实证）

1. 合成房 #1009: 装饰后缀俄文字符被当首字符 → inForm(null) → `_+后缀` 修复
2. 空格后缀：grammar 块行前导空格 → oForms[空格]=null → strip+trim 修复
3. **决定性根因：房间网格 = 25 行 × 48 列**（World.cellsX=48/cellsY=25，
   语料 658 房间全 25×48）——合成房只生成 24 行 → buildLoc `<a>` 循环
   j<spaceY=25 越界 `nroom.a[24]=undefined` → `.split()` #1009。
   "全格替换仍崩"因缺行而非缺格——触发格定位器用"逐格替换"无法找到。
4. 排查手段分层：GAME_ERROR_DIALOG（verror.txt.text 读取）→ 构造预检
   （new Location 复现）→ 触发格定位（逐格替换）→ 语料维度统计（最终定位）

## 教训（本模组）

- 离线原型必须模拟游戏侧解析（Tile.dec/网格维度），不能只做网格操作——
  数据管道两端 strip 不一致曾致"原型过、实机崩"；
- 房间维度/常量（cellsX/Y）是可验证的硬事实，先查语料再假设；
- 预检（构造复现）是"实机前最后防线"，但定位根因仍需离线数据。

## 后续

- 合成强度按层递增（越深越异化）
- 合成房质量调优（块词典扩展/多样化）
- WFC-lite 进阶（路线 B，规划于 room-synthesis-plan.md）