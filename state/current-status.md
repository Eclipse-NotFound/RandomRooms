# RandomRooms —— 项目状态

> 本文件记录当前开发状态，可频繁更新；不是长期游戏事实（游戏机制结论
> 在 knowledge/ 与 shared-knowledge/）。

## 当前版本

- 阶段：**M0 —— 已部署，等待实机测试**（2026-08-17 用户授权部署）
- 范围：DEC-0001 已确认（P0+P1；种子/联机延后；PipPage 入口；主菜单配置 UI）
- 设计文档：`design/vision-and-proposals.md`（v0.1）

## 部署记录（2026-08-17，两次部署后）

- **实玩文件 = 游戏根目录 `pfe.swf`**（`application.xml` 的 content 字段；
  5 个 loader：Sandevistan→RConnect→RealisticVision→MoreSkills&Weapons→TDFC）。
  误判教训：`app.xml` ≠ `application.xml`，启动链以 application.xml 为准。
- 第一次误部署到 `DLC/pfe.swf`（备份 `DLC/pfe_before_rrooms_20260817.swf`，
  无害残留，未回滚）；**第二次已正确部署到根目录 pfe.swf**。
- 根目录备份：`pfe_before_rrooms_20260817.swf`（回滚=改回原名）
- 补丁：MainFE.as 泛化锚点追加 loadRandomRoomsMod 调用+3 函数（适配 5 loader）
- **合并验证**：1016 脚本 diff 仅 MainFE.as 差异（AllData 噪音二次导出确认）
- tag 数：84384 原/新一致
- 注意：部署时游戏在运行（内存中仍是旧代码），**需再次重启游戏才加载新模组

## 已完成

- [x] 上下文恢复 + 架构勘察（knowledge/discoveries/room-system-architecture.md）
- [x] 设计提案 v0.1 + 方向确认（DEC-0001）
- [x] 实玩文件确认：`DLC/pfe.swf`（application.xml 启动路径；Land.as 与 1.02 逐字节一致）
- [x] 工具链：amxmlc AIR 32.0 编译成功（release/RandomRoomsMod.swf，5850B）
- [x] M0 代码：RRDiag + RRTestLand（rooms_stable 自动选房）+ RandomRoomsMod 文档类
- [x] 部署流水线干跑验证（tag 数 84384 无损；knowledge/experiments/m0-deploy-pipeline-validation.md）
- [x] 部署脚本 build/deploy-pfe.sh（备份/补丁/校验/回滚）就绪

## 当前状态

**用户暂不打 pfe.swf 补丁**（2026-08-17 答复）。交付物已就绪：

- `release/RandomRoomsMod.swf` —— M0 实验模组
- `build/deploy-pfe.sh` —— 手动部署脚本（默认打 DLC/pfe.swf，可指定文件）

## 部署后测试流程（用户执行时机由用户决定）

1. `bash build/deploy-pfe.sh`（打补丁 + 备份 DLC/pfe_before_rrooms_YYYYMMDD.swf）
2. 启动游戏 → 新开存档（或读档，读档也走 newGame 流程，rr_test 会注册）
3. 按 **F8** 进入测试土地 `rr_test`；按 **F9** 返回 rbl
4. 日志：`%APPDATA%` 下 applicationStorageDirectory 的 `RandomRooms_diag.log`
   （标记 `[RR:0.0.1-M0]`）——重点看 H1/H2/H3 判定行
5. 回滚：把备份文件改回原名

## 已确认的关键事实（本模组知识）

- 注入点（public，运行时内存级，零文件改动）：
  `World.w.rooms.rooms[file]`（房间池数组）、`World.w.roomsLoad`、
  `GameData.d`（newGame 前追加 `<land>`）、`Game.gotoLand`
- 磁盘房间文件 ≠ SWF 内嵌版（rooms_begin 磁盘 20 间 vs 内嵌 22 间）
- rnd 土地每次进入重建（visited 不置位）；conf=1 原型 beg0 在 (0,0)

## 下一步

1. （待用户决定时机）部署 → 实机 M0 实验验证 H1/H2/H3
2. 验证通过后进入 P0（池重掷 + 模板变异器）与 P1（rr 新土地 + 种子 + 主菜单）

## 权限提醒

- 部署（改 pfe.swf）必须用户明确授权——当前已获知：暂不部署
- 其他模组不访问；shared-knowledge 谨慎贡献（当前零写入，等待运行时验证）