# -*- coding: utf-8 -*-
"""v6.1：层界 profile 库（原版 23 条真实组合加权抽样）、修 lastDoorSpots/
lastHatchSpots 的 per-rect 过滤 bug（门口/洞位不属于任何 rect 导致门与活板门
从未放置）、back 距墙收紧 ≤2、checkpoint 加入词表、列区边界多样化。"""
import io

p = 'src/rr/RRSynth.as'
s = io.open(p, encoding='utf-8').read()

# ---- 1) LAYER_PROFILES 常量（插在 ANCHOR_POOL 后） ----
anchor1 = '      public static const ANCHOR_POOL:Array = [["mcrate2", 4], ["table", 2], ["woodbox", 2]];'
prof_const = anchor1 + """

      /** v6.1 层界 profile 库：原版 658 房行剖面提取的真实层界组合（频次≥4，
       *  23 条覆盖 320 房）。[层1顶,层1底],[层2顶,层2底],... 层间 gap 即墙带。
       *  含通高大堂(1,23)、浮中层(8,19)、蜂窝(1,3)(5,7)... 全谱形态 */
      public static const LAYER_PROFILES:Array = [
         [[[1, 23]], 43], [[[1, 7], [9, 15], [17, 23]], 42], [[[1, 21]], 31],
         [[[1, 15], [17, 23]], 25], [[[1, 11], [13, 23]], 24], [[[1, 19]], 17],
         [[[1, 22]], 15], [[[1, 7], [9, 23]], 14], [[[1, 19], [21, 23]], 12],
         [[[1, 15]], 10], [[[1, 20]], 10], [[[8, 19]], 9], [[[8, 15]], 8],
         [[[9, 15]], 8], [[[1, 3], [5, 7], [9, 15], [17, 19], [21, 23]], 6],
         [[[1, 9], [11, 23]], 5], [[[1, 10], [12, 15], [17, 23]], 5],
         [[[1, 7], [9, 11], [13, 23]], 5], [[[1, 3], [5, 7], [9, 15], [17, 23]], 5],
         [[[1, 11], [13, 15], [17, 23]], 5], [[[1, 4], [8, 11], [16, 19]], 4],
         [[[4, 7], [12, 15], [20, 23]], 4], [[[1, 3], [5, 19], [21, 23]], 4],
      ];"""
assert anchor1 in s
s = s.replace(anchor1, prof_const)

# ---- 2) 列区边界多样化 ----
old_zx = '         var zx:int = 14 + int(rnd() * 17);'
new_zx = '         var zx:int = 10 + int(rnd() * 27);   // 10..36：双区宽度可悬殊'
assert old_zx in s
s = s.replace(old_zx, new_zx)

# ---- 3) profile 驱动层界：替换 v6.0 的"层数分布+随机撒"块 ----
start = s.index('            // 层数按原版分布；受区宽约束（每层至少容得下隔断与洞）')
end = s.index('            zones.push({x0: zx0, x1: zx1, layers: zLayers, bands: zBands, walls: []});')
end = s.index('\n', end) + 1
prof_block = """            // v6.1 层界 profile 库：加权抽一条原版真实组合（含通高/浮中层/
            // 蜂窝全谱形态）；带厚 = 层间 gap（天然来自 profile）
            var totalW:int = 0;
            for (b3 = 0; b3 < LAYER_PROFILES.length; b3++) totalW += LAYER_PROFILES[b3][1];
            var pv:Number = rnd() * totalW;
            var pi:int = 0;
            for (b3 = 0; b3 < LAYER_PROFILES.length; b3++)
            {
               pv -= int(LAYER_PROFILES[b3][1]);
               if (pv < 0)
               {
                  pi = b3;
                  break;
               }
            }
            var prof:Array = LAYER_PROFILES[pi][0];
            var zLayers:Array = [];
            var zBands:Array = [];
            for (l3 = 0; l3 < prof.length; l3++)
            {
               var pt:int = int(prof[l3][0]);
               var pb:int = int(prof[l3][1]);
               if (l3 > 0)
               {
                  var prevB:int = int(prof[l3 - 1][1]);
                  var gapRows:int = pt - prevB - 1;
                  if (gapRows >= 1) zBands.push([prevB + 1, gapRows]);
               }
               zLayers.push([pt, pb]);
            }
            zones.push({x0: zx0, x1: zx1, layers: zLayers, bands: zBands, walls: []});
"""
s = s[:start] + prof_block + s[end:]

# ---- 4) lastDoorSpots/lastHatchSpots 全局放置（修 per-rect 过滤 bug） ----
# 4a) 删除 rect 循环内的门/hatch2 两段
door_block_start = '            // 门（v5.6）：放竖隔断门口（lastDoorSpots 命中本 rect 的位），'
i0 = s.index(door_block_start)
crate_marker = '            // 活板门（v6.0 结构化）：层间主洞 40% 出 hatch2（洞=通道口，'
i1 = s.index(crate_marker)
crate_end = s.index('            // 箱子（贴墙，占地校验；数量随房间个性密度缩放；全格占用防叠放）')
hatch_block = s[i1:crate_end]
s = s[:i0] + s[crate_end:]
# 4b) 全局段：插在 rect 循环之前（mainBacks 声明后）
anchor2 = '         // 房间个性（DEC-0004）：空房只留出生点与结构；密度系数缩放物件量'
global_block = '''         // 门与活板门（v6.1 全局放置修复：门口/洞位在隔断列与墙带行上，
         // 不属于任何 rect——旧 per-rect 过滤把它们全部跳过，导致门/活板门
         // 自 v5.6 起从未实际生成）
         var dFoot2:Array = objFoot(doorId);
         for (k = 0; k < lastDoorSpots.length; k++)
         {
            var dsp:Array = lastDoorSpots[k] as Array;
            var dsx:int = int(dsp[0]);
            var dsy:int = int(dsp[1]);
            if (usedGlobal[dsy + "," + dsx] == true) continue;
            if (rnd() >= 0.7) continue;
            if (!footOk(grid, dsx, dsy, dFoot2[0], dFoot2[1])) continue;
            lastObjs.push([doorId, genCode(), dsx, dsy]);
            for (var dfy:int = 0; dfy < dFoot2[1]; dfy++) usedGlobal[(dsy + dfy) + "," + dsx] = true;
         }
         for (k = 0; k < lastHatchSpots.length; k++)
         {
            var hsp:Array = lastHatchSpots[k] as Array;
            var hfx:int = int(hsp[0]);
            var hfy:int = int(hsp[1]);
            if (usedGlobal[hfy + "," + hfx] == true || usedGlobal[hfy + "," + (hfx + 1)] == true) continue;
            if (rnd() >= 0.85) continue;
            if (!footOk(grid, hfx, hfy, 2, 1)) continue;
            lastObjs.push(["hatch2", genCode(), hfx, hfy]);
            usedGlobal[hfy + "," + hfx] = true;
            usedGlobal[hfy + "," + (hfx + 1)] = true;
         }
         // 房间个性（DEC-0004）：空房只留出生点与结构；密度系数缩放物件量'''
assert anchor2 in s
s = s.replace(anchor2, global_block, 1)
# 4c) usedGlobal 声明（旧 rect 内门/hatch2 段已由 4a 一并删除）
anchor3 = '         var rectUsed:Array = [];    // 各 rect 的占用表（平行 rects；player/敌标记房间级放置用）'
s = s.replace(anchor3, '         var usedGlobal:Object = {};  // 全局占用（门/活板门等跨 rect 结构物）\n' + anchor3, 1)

# ---- 5) back 距墙 ≤2（原版 45% 贴墙 1 格内，2-3 格仍显悬浮） ----
old_dd = '                  for (dd = 1; dd <= 3 && !dHit; dd++)'
new_dd = '                  for (dd = 1; dd <= 2 && !dHit; dd++)'
assert old_dd in s
s = s.replace(old_dd, new_dd)

# ---- 6) checkpoint 加入词表（各 biome crates）+ objFoot ----
s = s.replace('"bookcase"] :', '"bookcase", "checkpoint"] :')
s = s.replace('"hatch2"] :\n                           (bIdx == 2', '"hatch2", "checkpoint"] :\n                           (bIdx == 2')
s = s.replace('"bookcase", "hatch2"] :', '"bookcase", "hatch2", "checkpoint"] :')
s = s.replace('case "wallcab": case "medbox": case "trash": return [1, 1];',
              'case "wallcab": case "medbox": case "trash": return [1, 1];\n            case "checkpoint": return [2, 3];')

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('v6.1 patch ok')
