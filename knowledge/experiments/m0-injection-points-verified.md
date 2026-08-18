---
domain: world-objects
type: experiments
game-version:
  - "1.02（实玩根目录 pfe.swf）"
confidence: high
verified: true
method: 真机实验（模组加载 + 热键传送 + 日志取证）
evidence:
  - kind: runtime-experiment
    summary: "RandomRooms M0：F1 gotoLand(rr_test) 成功；verifyEntry 富采样
      9/9 loc 全部来自注入池 {вход(beg0),13,служ. пом.,пещера2}，beg0 落 (0,0)；
      过渡期 act.id 门控正确识别旧 land（rbl）"
date-updated: 2026-08-18
---

# M0 实验记录：注入点验证（H1/H2/H3 全通过）

## 实验内容

向运行时注入自定义土地 + 自定义房间池，验证链路：

1. `GameData.d` appendChild `<land id='rr_test' tip='rnd' rnd='1' conf='1'
   file='rooms_rr_test' mx='3' my='3' ...>`（newGame 前）
2. `rooms.rooms["rooms_rr_test"]` = 测试池（从 rooms_stable 自动选 4 房：
   вход(beg0) + 13 + служ. пом. + пещера2）
3. `World.w.roomsLoad = 0`（LandLoader 读内存池）
4. 热键 F1 → `Game.gotoLand("rr_test")`；F2 → `gotoLand("rbl")`

## 结果（全部通过）

| 假设 | 结论 | 证据 |
|---|---|---|
| H1 土地注册 | ✓ | `lands[rr_test]=true`，gotoLand 可达 |
| H2 池注入生效 | ✓ | 9/9 loc 全部来自注入池 |
| H3 生成链路 | ✓ | 房间集合 100% = 池模板；beg0 按 conf=1 落 (0,0)；网格 3×3 |

## 过程中的关键失败与修复（log-forensics 全过程）

1. loader #1056：`this.randomRoomsLoader` 非 MainFE 声明字段 → 局部变量
2. `init` 实例方法 vs 类级静态调用 → #1006 → static init
3. `World.w.rooms` 恒 null → 反射实例化 fe.rooms.Rooms 挂接（见
   shared-knowledge/world-objects/discoveries/world-rooms-field-injection.md）
4. URLLoader 相对路径基于 mod SWF 位置 → `app:/Rooms/` 绝对路径
5. F8 被其它模组 KEY_DOWN 拦截 → F1/F2 + capture 阶段监听
6. verifyEntry 过渡期误采旧 land（curLandId 已改、World.land 未切）→
   `land.act.id` 硬门控 + 30 帧稳定期

## 教训（本模组）

- 传送是异步过程：判定"已进入"必须同时验证
  `game.curLandId` 与 `land.act.id`（LandAct.id），两者切换有间隔；
- 热键设计先查已有模组占用（F8/F9 均被占用）；
- SharedObject 是 loader 层错误落盘的可靠通道（sol 二进制可 python 解码）；
- 跨会话日志 append，判读按最新一组（会话边界 = 版本标记行 + init 行）。