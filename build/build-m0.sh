#!/usr/bin/env bash
# RandomRooms M0 构建脚本 —— 产出 release/RandomRoomsMod.swf
# 目标：AIR 32.0（与现场已验证的 RealisticVision 相同的 SWF 版本）
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SRC="$ROOT/src"
RELEASE="$ROOT/release"
FLEX_BIN="C:/Users/micha/Documents/_sandevistan_dev/flexsdk/bin"
FLEX_HOME="C:/Users/micha/Documents/_sandevistan_dev/flexsdk"

mkdir -p "$RELEASE"

export AIR_HOME="$FLEX_HOME"
export PLAYERGLOBAL_HOME="$FLEX_HOME/frameworks/libs/player"

echo "== RandomRooms build (M0) =="
"$FLEX_BIN/amxmlc" \
  -target-player 32.0 \
  -swf-version 32 \
  -use-network=false \
  -static-link-runtime-shared-libraries=true \
  -source-path "$SRC" \
  -output "$RELEASE/RandomRoomsMod.swf" \
  "$SRC/RandomRoomsMod.as"

echo "== done: $RELEASE/RandomRoomsMod.swf =="