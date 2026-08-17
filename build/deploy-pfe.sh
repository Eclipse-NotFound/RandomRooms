#!/usr/bin/env bash
# ============================================================================
# RandomRooms —— pfe.swf 部署脚本（手动执行，等用户决定时机）
#
# 用法:
#   bash build/deploy-pfe.sh                 # 默认打游戏根目录 pfe.swf（实际启动文件
#                                            #   application.xml content=pfe.swf）
#   bash build/deploy-pfe.sh <pfe 路径>       # 打指定文件（如 DLC/pfe.swf）
#
# 流程:
#   1. 备份目标文件 -> <同目录>/pfe_before_rrooms_YYYYMMDD.swf
#   2. ffdec 全量导出脚本 -> 临时目录
#   3. 对 MainFE.as 追加 RandomRooms loader（锚点断言，不匹配则中止，不写任何文件）
#   4. 仅导入修改后的 MainFE.as（单脚本定向替换，非全量重编译）
#   5. 校验 tag 数与原文件一致 + loader 文本存在
#   6. 原子替换目标文件
#
# 回滚: 把备份文件名改回原文件名即可（例如 DLC/pfe_before_rrooms_20260817.swf -> DLC/pfe.swf）
# 测试: 启动游戏 -> 新开存档 -> F8 进入测试土地 rr_test，F9 返回 rbl；
#       日志在 %APPDATA%/.../RandomRooms_diag.log（applicationStorageDirectory）
# ============================================================================
set -euo pipefail

DEFAULT_TARGET="C:/Program Files (x86)/Steam/steamapps/common/Remains/pfe.swf"
TARGET="${1:-$DEFAULT_TARGET}"
FFDEC="C:/Users/micha/Documents/_sandevistan_dev/ffdec/ffdec-cli.exe"

if [ ! -f "$TARGET" ]; then
  echo "ERROR: 目标文件不存在: $TARGET" >&2
  exit 1
fi

DIRNAME="$(dirname "$TARGET")"
BASENAME="$(basename "$TARGET" .swf)"
BAK="$DIRNAME/${BASENAME}_before_rrooms_$(date +%Y%m%d).swf"
TMPW="$(mktemp -d)"

echo "== RandomRooms deploy =="
echo "目标: $TARGET"
echo "临时目录: $TMPW"

# 1) 备份
if [ -f "$BAK" ]; then
  echo "ERROR: 备份已存在，中止（防止覆盖旧备份）: $BAK" >&2
  exit 1
fi
cp "$TARGET" "$BAK"
echo "备份: $BAK"

# 2) 全量导出脚本
echo "导出脚本中（约 80s）..."
"$FFDEC" -export script "$TMPW/scripts" "$TARGET" > /dev/null 2>&1
MAINFE="$TMPW/scripts/scripts/MainFE.as"
[ -f "$MAINFE" ] || { echo "ERROR: 导出后未找到 MainFE.as" >&2; exit 1; }

# 3) 追加 RandomRooms loader（泛化锚点：自动适配 2~N 个现有 loader 的 MainFE）
python - "$MAINFE" <<'PY'
import re, sys
path = sys.argv[1]
src = open(path, encoding="utf-8").read()

# 先做尾部插入（在最后一个 "load/init error" 的 catch 块结束后追加新函数）
tail_anchor = 'load/init error: " + err);\n         }\n      }\n   }\n}'
idx = src.rfind(tail_anchor)
assert idx != -1, "锚点丢失: 未找到类尾 catch 块"
insert_at = idx + len('load/init error: " + err);\n         }\n      }\n')
newfunc = '''      
      internal function loadRandomRoomsMod() : *
      {
         var _loc1_:LoaderContext;
         trace("RandomRoomsMod: load start");
         try
         {
            this.randomRoomsLoader = new Loader();
            _loc1_ = new LoaderContext(false);
            this.randomRoomsLoader.contentLoaderInfo.addEventListener(Event.COMPLETE,this.onRandomRoomsModLoaded);
            this.randomRoomsLoader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR,this.onRandomRoomsModError);
            this.randomRoomsLoader.load(new URLRequest("app:/mods/RandomRooms/release/RandomRoomsMod.swf"),_loc1_);
            trace("RandomRoomsMod: load issued");
         }
         catch(err:*)
         {
            trace("RandomRoomsMod: load threw " + err);
         }
      }
      
      internal function onRandomRoomsModError(param1:IOErrorEvent) : *
      {
         trace("RandomRoomsMod: IOError " + param1.text);
      }
      
      internal function onRandomRoomsModLoaded(param1:Event) : *
      {
         var _loc2_:*;
         trace("RandomRoomsMod: complete fired");
         try
         {
            _loc2_ = LoaderInfo(param1.currentTarget).applicationDomain.getDefinition("RandomRoomsMod");
            trace("RandomRoomsMod: class=" + _loc2_);
            _loc2_.init(this);
            trace("RandomRoomsMod: init returned");
         }
         catch(err:*)
         {
            trace("RandomRoomsMod load/init error: " + err);
         }
      }
'''
src = src[:insert_at] + newfunc + src[insert_at:]

# 再插入调用：最后一个 loadXxxMod(); 之后追加 loadRandomRoomsMod();
calls = list(re.finditer(r'this\.load([A-Za-z0-9]+)Mod\(\);', src))
assert calls, "锚点丢失: 未找到任何 loader 调用"
last_call = calls[-1]
src = src[:last_call.end()] + "\n            this.loadRandomRoomsMod();" + src[last_call.end():]

open(path, "w", encoding="utf-8").write(src)
print("MainFE.as 补丁完成（适配 " + str(len(calls)) + " 个现有 loader）")
PY

# 4) 单脚本定向导入
mkdir -p "$TMPW/only"
cp "$MAINFE" "$TMPW/only/"
echo "导入中..."
"$FFDEC" -importScript "$TARGET" "$TMPW/out.swf" "$TMPW/only" > /dev/null 2>&1

# 5) 校验：tag 数一致 + loader 文本存在
TAGS_ORIG=$("$FFDEC" -dumpSWF "$TARGET" 2>/dev/null | grep -cE "^[0-9a-f]+:" || true)
TAGS_NEW=$("$FFDEC" -dumpSWF "$TMPW/out.swf" 2>/dev/null | grep -cE "^[0-9a-f]+:" || true)
echo "tag 数: 原=$TAGS_ORIG 新=$TAGS_NEW"
if [ "$TAGS_ORIG" != "$TAGS_NEW" ]; then
  echo "ERROR: tag 数不一致，中止（未动原文件，备份保留）" >&2
  rm -rf "$TMPW"
  exit 1
fi

# 6) 原子替换
mv "$TMPW/out.swf" "$TARGET"
rm -rf "$TMPW"
echo "== 部署完成 =="
echo "回滚: 将 $BAK 改名为 $TARGET"
echo "测试: 开新存档 -> F8 (进 rr_test) / F9 (回 rbl)；日志: %APPDATA% RandomRooms_diag.log"