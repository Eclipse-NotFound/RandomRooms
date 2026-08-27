#!/usr/bin/env bash
# RandomRooms 构建脚本 —— 产出 release/RandomRoomsMod.swf
# 目标：player 32.0 / swf-version 32（AIR API 经 airglobal.swc external 链接，不嵌入）
#
# 本机工具链（2026-08-27 实测打通，与 TDFC 同路线）：
#   - mxmlc：D:\RemainsMod\mods\Sandevistan\build\tools\flexsdk\bin（Apache Flex 4.16.1）
#   - Java ：Adobe Animate 2024 自带 JRE（Java 17 可跑 mxmlc）
#   - SWC  ：build/rr-config.xml 显式指向 airsdk 的 playerglobal 32.0 + airglobal
#   注意：air-config.xml 的 {airHome} 令牌已失效（SDK 被移动），勿用 amxmlc 直编。
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
MXMLC="D:\\RemainsMod\\mods\\Sandevistan\\build\\tools\\flexsdk\\bin\\mxmlc.bat"
ANIMATE_JRE="D:\\Program Files\\Adobe Animate 2024\\jre\\bin"

mkdir -p "$ROOT/release"

# mxmlc.bat 经 cmd 找 java，需要 Animate JRE 在 PATH 前列
export PATH="$(cygpath -u "$ANIMATE_JRE" 2>/dev/null || echo "$ANIMATE_JRE"):$PATH"

echo "== RandomRooms build =="
cmd //c "$MXMLC -load-config build\\rr-config.xml -swf-version 32 -use-network=false -static-link-runtime-shared-libraries=true src\\RandomRoomsMod.as"

echo "== done: $ROOT/release/RandomRoomsMod.swf =="
