---
domain: knowledge-validation
type: experiments
game-version:
  - "1.02（实玩 DLC/pfe.swf 构建，MainFE 167）"
confidence: high
verified: true
method: ffdec 26.2.1 定向替换 + 模组 SWF 编译 + 副本干跑
evidence:
  - kind: runtime-experiment
    summary: "在 DLC/pfe.swf 副本上：全量导出 1016 脚本 → 仅修改 MainFE.as →
      importScript 单脚本导回 → dumpSWF tag 数 84384 与原文件一致 → 再导出
      MainFE.as 确认 RandomRooms loader 已注入"
date-updated: 2026-08-17
---

# M0 实验记录：pfe.swf 部署流水线验证（干跑 + 实机部署）

## 背景

RandomRooms M0 实验需要把模组 SWF 挂进游戏启动链。

### 实玩文件（重要修正 2026-08-17）

- 启动链：`1.BAT` → `adl64.exe -runtime runtimes/air/win64 application.xml` →
  **游戏根目录 `application.xml` 的 content = `pfe.swf`**（根目录 1.02 版，
  5 个 loader：Sandevistan → RConnect → RealisticVision → MoreSkills&Weapons →
  TDFC）。
- **首次部署曾误判目标为 `DLC/pfe.swf`**（依据 `app.xml`——注意 `app.xml`
  与 `application.xml` 是两个不同文件；前者 content=DLC/pfe.swf，后者才是
  启动文件且指向根 pfe.swf）。后果：loader 打进 DLC/pfe.swf 但运行中游戏
  加载根 pfe.swf → 模组未加载（F8 无反应）。**已在当天修正**：重新部署到
  根目录 pfe.swf（验证 diff 仅 MainFE 差异）。
- 根目录 pfe.swf 的 `fe.loc.Land.as` 与 1.02 src102 一致，房间系统架构
  勘察结论成立。
- TDFC 通过根 pfe.swf 的第 5 个 loader 加载（tdfc.log 在 pfe/Local Store）。

## 验证的流水线（副本干跑，未触碰真实文件）

```text
1. ffdec -export script <tmp>/scripts <pfe>             # 导出全部 1016 脚本
2. python 修改 MainFE.as：
   - onEnterFrameLoader 调用序列追加 this.loadRandomRoomsMod();
   - 类尾部追加 loadRandomRoomsMod / onRandomRoomsModError / onRandomRoomsModLoaded
     （锚点字符串断言，命中失败即中止）
3. mkdir <tmp>/only && cp MainFE.as only/
   ffdec -importScript <pfe> <out.swf> <only>            # 仅导入 MainFE（非全量重编译）
4. 校验：dumpSWF tag 数 原=84384 新=84384（一致）
         重新导出 MainFE.as 含 3 处 RandomRooms 引用
```

## 结论（已验证）

- **单脚本定向替换流水线无损**：tag 数保持 84384；
  diff 全部 1016 脚本：仅 MainFE.as 真实差异（其余脚本逐字节一致）。
- **反编译导出存在偶发噪音**：连续两次导出同一份文件，fe/AllData.as 一次
  有 diff、一次无 diff——合并验证以"二次导出交叉确认"为准，
  diff 结果需先复现再下结论。
- 部署脚本 `build/deploy-pfe.sh` 封装该流程：备份 → 导出 → 补丁（泛化锚点，
  自动适配 2~N 个现有 loader）→ 单脚本导入 → tag 校验 → 原子替换；
  锚点未命中或 tag 不一致时全程不写原文件。

## 部署记录（账号级）

- 目标：游戏根目录 `pfe.swf`（application.xml 指向，5 个加载器）
- 备份：`pfe_before_rrooms_20260817.swf`（回滚 = 改名恢复）
- 普丁后 MainFE 含 loadRandomRoomsMod 调用 + 3 个函数

## 环境事实（部署无关的杂项）

- AS3 编译：`amxmlc -target-player 32.0 -swf-version 32`（AIR 32.0，
  与 RealisticVision 相同 SWF 版本；运行时实测容忍 v14/v32/v38 混装），
  需 `AIR_HOME` + `PLAYERGLOBAL_HOME` 环境变量；
- 日志：`File.applicationStorageDirectory/RandomRooms_diag.log`（AIR 可用）。
- ffdec 26.2.1 CLI。依赖路径：`C:/Users/micha/Documents/_sandevistan_dev/{flexsdk,ffdec}`。

## 未验证（留给实机 M0）

- 运行时替换 `rooms.rooms` + `roomsLoad=0` 的真实生效（H1/H2/H3）；
- 磁盘房间 XML 与 SWF 内嵌版本存在差异（已观察到 rooms_begin 磁盘 20
  间 vs 内嵌 22 间）——模组预载磁盘内容到数组，保证原版体验不变。