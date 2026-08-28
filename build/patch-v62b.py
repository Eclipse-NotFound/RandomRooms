# -*- coding: utf-8 -*-
"""v6.2b：层界算法化（用户偏好）——替换 profile 抽样为主层模式算法生成。"""
import io

p = 'src/rr/RRSynth.as'
s = io.open(p, encoding='utf-8').read()

start = s.index('            // v6.1 层界 profile 库：加权抽一条原版真实组合（含通高/浮中层/')
endmark = '            zones.push({x0: zx0, x1: zx1, layers: zLayers, bands: zBands, walls: []});'
end = s.index(endmark)

new = """            // v6.2 层界算法生成（用户偏好：算法产生更多样的组合，不抽样原版；
            // 层数分布仍以 658 房语料为规律校准）。变数来源：
            //   a) 主层模式——一层拿 35-70% 行数（大堂 vs 蜂窝对比）
            //   b) 带厚 1-2 随机、小层 3-6 行、余量随机撒
            var nBand:int = nLayer - 1;
            var bts:Array = [];
            var bandTotal:int = 0;
            for (b3 = 0; b3 < nBand; b3++)
            {
               var bt3:int = 1 + int(rnd() * 2);
               bts.push(bt3);
               bandTotal += bt3;
            }
            var rem:int = 23 - bandTotal;
            var heights:Array = [];
            var mainIdx:int = int(rnd() * nLayer);
            if (nLayer == 1)
            {
               heights.push(rem);
            }
            else
            {
               var minOthers:int = 3 * (nLayer - 1);
               var mainH:int = 3 + int(rnd() * Math.max(1, rem - minOthers + 1));
               // 55% 概率强化主层（拿走剩余的 40-70%），制造大小悬殊
               if (rnd() < 0.55)
               {
                  mainH = Math.min(rem - minOthers, Math.max(mainH, int(rem * (0.35 + rnd() * 0.35))));
               }
               mainH = Math.max(3, Math.min(rem - minOthers, mainH));
               for (l3 = 0; l3 < nLayer; l3++) heights.push(3);
               heights[mainIdx] += mainH - 3;
               var restExtra:int = rem - mainH - 3 * (nLayer - 1);
               for (l3 = 0; l3 < restExtra; l3++)
               {
                  var hi:int = int(rnd() * nLayer);
                  if (hi == mainIdx) hi = (mainIdx + 1 + int(rnd() * (nLayer - 1))) % nLayer;
                  heights[hi]++;
               }
            }
            var zLayers:Array = [];
            var zBands:Array = [];
            var cur:int = 1;
            for (l3 = 0; l3 < nLayer; l3++)
            {
               zLayers.push([cur, cur + heights[l3] - 1]);
               cur += heights[l3];
               if (l3 < nBand)
               {
                  zBands.push([cur, bts[l3]]);
                  cur += bts[l3];
               }
            }
""" + endmark

s2 = s[:start] + new + s[end + len(endmark):]
io.open(p, 'w', encoding='utf-8', newline='').write(s2)
print('v6.2b ok')
