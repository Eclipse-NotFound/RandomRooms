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

# M0 实验记录：pfe.swf 部署流水线验证（干跑）

## 背景

RandomRooms M0 实验需要把模组 SWF 挂进游戏启动链。实玩文件确认：

- `1.BAT` / `application.xml` 启动路径 → **`DLC/pfe.swf`**（MainFE 167，
  仅含 Sandevistan + RConnect 两个 loader），版本字节 0x29=41；
- 根目录 `pfe.swf`（1.02，4 个 loader）与 `DLC/pfeUI.swf` 不是当前启动路径；
- `DLC/pfe.swf` 的 `fe.loc.Land.as` 与 1.02 src102 **逐字节一致**（diff 干净），
  房间系统架构勘察结论对实玩版本成立。

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

- **单脚本定向替换流水线无损**：tag 数保持 84384。
- 部署脚本 `build/deploy-pfe.sh` 封装上述流程：备份 → 导出 → 补丁（锚点
  断言）→ 单脚本导入 → tag 校验 → 原子替换；未命中锚点或 tag 不一致时
  全程不写原文件。

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