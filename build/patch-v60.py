# -*- coding: utf-8 -*-
"""v6.0 分层语法重构：替换 RRSynth.v5Skeleton 的 2a-2e 段。"""
import io

p = 'src/rr/RRSynth.as'
s = io.open(p, encoding='utf-8').read()
start_anchor = '         // 2) 分层大厅（v5.6 范式，对齐原版语料结构：整层开放 × 1 行薄墙带 ×'
end_anchor = '         // 4) 材质带（90% 主字符；v5.7 按层分区 + 对比补丁区）'
i0 = s.index(start_anchor)
i1 = s.index(end_anchor)

new = """         // 2) 分层大厅 v6.0（原版取经）：层数按语料分布（658 房实证 1 层 31%/
         //    2 层 26%/3 层 26%/4 层 10%/5 层 3%）、层界非均分随机；40% 概率
         //    左右双列区各自独立分层（同一合成房内分层变化）；区界通高墙+门口
         var roomRects:Array = [];
         // 房间个性向量（DEC-0004 反均匀；语料校准：10/658 房全空 → 空房率 ~5%）
         emptyRoom = rnd() < 0.06;
         density = emptyRoom ? 0.0 : (0.5 + rnd() * 0.9);
         // 2a) 列区划分：单区=整宽统一分层；双区=左右各自分层（区界通高墙）
         var zones:Array = [];   // 每区 {x0,x1,layers,bands,walls}
         var nZone:int = rnd() < 0.4 ? 2 : 1;
         var zx:int = 14 + int(rnd() * 17);
         var zw:int = rnd() < 0.3 ? 2 : 1;
         var zoneBounds:Array = nZone == 2 ? [[1, zx - 1], [zx + zw, GRID_W - 2]] : [[1, GRID_W - 2]];
         var zoneWalls:Array = nZone == 2 ? [[zx, zw]] : [];
         var zi:int;
         var li:int, y2:int, x2:int, r2:int, l3:int, b3:int;
         for (zi = 0; zi < zoneBounds.length; zi++)
         {
            var zx0:int = zoneBounds[zi][0];
            var zx1:int = zoneBounds[zi][1];
            var zw2:int = zx1 - zx0 + 1;
            // 层数按原版分布；受区宽约束（每层至少容得下隔断与洞）
            var roll:Number = rnd();
            var nLayer:int = roll < 0.31 ? 1 : (roll < 0.57 ? 2 : (roll < 0.83 ? 3 : (roll < 0.93 ? 4 : 5)));
            while (nLayer > 1 && zw2 < nLayer * 6) nLayer--;
            while (nLayer * 3 + (nLayer - 1) > 23) nLayer--;
            // 非均分切层：每层 3 行保底，余量随机撒
            var nBand:int = nLayer - 1;
            var bts:Array = [];
            var bandTotal:int = 0;
            for (b3 = 0; b3 < nBand; b3++)
            {
               var bt3:int = 1 + int(rnd() * 2);
               bts.push(bt3);
               bandTotal += bt3;
            }
            var extra:int = 23 - bandTotal - 3 * nLayer;
            var heights:Array = [];
            for (l3 = 0; l3 < nLayer; l3++) heights.push(3);
            for (l3 = 0; l3 < extra; l3++) heights[int(rnd() * nLayer)]++;
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
            zones.push({x0: zx0, x1: zx1, layers: zLayers, bands: zBands, walls: []});
         }
         // 2a') 挖开放层
         for (zi = 0; zi < zones.length; zi++)
         {
            var zl0:Array = zones[zi].layers;
            for (li = 0; li < zl0.length; li++)
            {
               for (y2 = zl0[li][0]; y2 <= zl0[li][1]; y2++)
               {
                  for (x2 = zones[zi].x0; x2 <= zones[zi].x1; x2++) grid[y2][x2] = "_";
               }
            }
         }
         // 2b) 层间墙带 + 主次洞 + hatch2 结构化（主洞 40% 出活板门——
         //     洞即层间通道口，活板门=其盖口，原版语义 0.40/房）
         var bandTop:int, bandRows:int, holeK:int, holeX:int, holeW:int, holeLast:int, gx:int;
         lastHatchSpots = [];
         for (zi = 0; zi < zones.length; zi++)
         {
            var zb0:Array = zones[zi].bands;
            for (li = 0; li < zb0.length; li++)
            {
               bandTop = int(zb0[li][0]);
               bandRows = int(zb0[li][1]);
               for (r2 = 0; r2 < bandRows; r2++)
               {
                  for (x2 = zones[zi].x0; x2 <= zones[zi].x1; x2++) grid[bandTop + r2][x2] = wallChar(wallTbl);
               }
               holeLast = zones[zi].x0;
               for (holeK = 0; holeK < 2 + int(rnd() * 2); holeK++)
               {
                  holeW = holeK == 0 ? 4 + int(rnd() * 2) : 3;
                  holeX = holeLast + 4 + int(rnd() * Math.max(1, zones[zi].x1 - 6 - holeLast));
                  if (holeX > zones[zi].x1 - holeW + 1) holeX = zones[zi].x1 - holeW + 1;
                  for (x2 = holeX; x2 < holeX + holeW && x2 <= zones[zi].x1; x2++)
                  {
                     for (r2 = 0; r2 < bandRows; r2++) grid[bandTop + r2][x2] = "_";
                  }
                  if (holeK == 0 && rnd() < 0.4)
                  {
                     lastHatchSpots.push([holeX, bandTop]);
                  }
                  holeLast = holeX + holeW;
               }
               // 十字动线：GX1/GX2 列对齐洞（若落在区内）
               if (rnd() < 0.6)
               {
                  gx = rnd() < 0.5 ? GX1 - 1 : GX2 - 1;
                  if (gx >= zones[zi].x0 && gx + 3 <= zones[zi].x1 + 1)
                  {
                     for (x2 = gx; x2 < gx + 3; x2++)
                     {
                        for (r2 = 0; r2 < bandRows; r2++) grid[bandTop + r2][x2] = "_";
                     }
                  }
               }
            }
         }
         // 2c) 区界墙（双区）：通高 1-2 格厚 + 2-3 个 3 宽×3 高门口
         var wallW:int, w2:int, doorK:int, doorY:int;
         for (zi = 0; zi < zoneWalls.length; zi++)
         {
            var zwx:int = zoneWalls[zi][0];
            var zww:int = zoneWalls[zi][1];
            for (y2 = 1; y2 <= GRID_H - 2; y2++)
            {
               for (w2 = 0; w2 < zww; w2++) grid[y2][zwx + w2] = wallChar(wallTbl);
            }
            for (doorK = 0; doorK < 2 + int(rnd() * 2); doorK++)
            {
               doorY = 2 + int(rnd() * (GRID_H - 7));
               for (var dz:int = 0; dz < 3; dz++)
               {
                  for (w2 = 0; w2 < zww; w2++) grid[doorY + dz][zwx + w2] = "_";
               }
               lastDoorSpots.push([zwx, doorY]);
            }
         }
         // 2d) 层内竖隔断（层型三档：大厅 0 隔断 / 普通 1-2 / 蜂窝 3-4，每层
         //     独立抽）；隔断厚 1-2 格；主门口宽 3、次门口宽 2，高 3
         var segIdx:int, wallX:int, dOK:Boolean;
         for (zi = 0; zi < zones.length; zi++)
         {
            var zl:Array = zones[zi].layers;
            var zx0b:int = zones[zi].x0;
            var zx1b:int = zones[zi].x1;
            for (li = 0; li < zl.length; li++)
            {
               var ltop:int = zl[li][0];
               var lbot:int = zl[li][1];
               var styleRoll:Number = rnd();
               var segs:int = styleRoll < 0.25 ? 0 : (styleRoll < 0.75 ? 1 + int(rnd() * 2) : 3 + int(rnd() * 2));
               var availW:int = zx1b - zx0b + 1;
               if (availW < 10) segs = Math.min(segs, 1);
               for (segIdx = 0; segIdx < segs; segIdx++)
               {
                  var placedW:Boolean = false;
                  for (tries = 0; tries < 20 && !placedW; tries++)
                  {
                     wallX = zx0b + 4 + int(rnd() * Math.max(1, availW - 8));
                     wallW = rnd() < 0.3 ? 2 : 1;
                     dOK = true;
                     for (k = 0; k < (zones[zi].walls as Array).length; k++)
                     {
                        if (Math.abs(int((zones[zi].walls[k] as Array)[0]) - wallX) < 6)
                        {
                           dOK = false;
                           break;
                        }
                     }
                     if (!dOK) continue;
                     for (y2 = ltop; y2 <= lbot; y2++)
                     {
                        for (w2 = 0; w2 < wallW; w2++) grid[y2][wallX + w2] = wallChar(wallTbl);
                     }
                     var nDoor:int = 1 + int(rnd() * 2);
                     for (doorK = 0; doorK < nDoor; doorK++)
                     {
                        doorY = ltop + 1 + int(rnd() * Math.max(1, lbot - ltop - 3));
                        var doorW:int = doorK == 0 ? 3 : 2;
                        for (var dz:int = 0; dz < 3 && doorY + dz <= lbot; dz++)
                        {
                           for (w2 = 0; w2 < Math.min(doorW, wallW); w2++) grid[doorY + dz][wallX + w2] = "_";
                        }
                        lastDoorSpots.push([wallX, doorY]);
                     }
                     (zones[zi].walls as Array).push([wallX, wallW, ltop, lbot]);
                     placedW = true;
                  }
               }
            }
         }
         // 2e) roomRects：每区每层，按隔断切段（段宽 ≥4 才算房间）
         for (zi = 0; zi < zones.length; zi++)
         {
            var zl2:Array = zones[zi].layers;
            var zwalls:Array = zones[zi].walls;
            for (li = 0; li < zl2.length; li++)
            {
               var ltop2:int = zl2[li][0];
               var lbot2:int = zl2[li][1];
               var xs:Array = [];
               for (k = 0; k < zwalls.length; k++)
               {
                  var wrec:Array = zwalls[k] as Array;
                  if (int(wrec[2]) <= lbot2 && int(wrec[3]) >= ltop2) xs.push(int(wrec[0]));
               }
               xs.sort(Array.NUMERIC);
               var x0:int = zones[zi].x0;
               for (k = 0; k <= xs.length; k++)
               {
                  var x1:int = k < xs.length ? int(xs[k]) : zones[zi].x1 + 1;
                  if (x1 - x0 >= 4) roomRects.push([x0, ltop2, x1 - x0, lbot2 - ltop2 + 1]);
                  x0 = x1 + 1;
                  if (k < xs.length)
                  {
                     for (var wk:int = 0; wk < zwalls.length; wk++)
                     {
                        if (int((zwalls[wk] as Array)[0]) == x1)
                        {
                           x0 += int((zwalls[wk] as Array)[1]) - 1;
                           break;
                        }
                     }
                  }
               }
            }
         }
"""
s2 = s[:i0] + new + s[i1:]
io.open(p, 'w', encoding='utf-8', newline='').write(s2)
print('replaced ok, delta chars:', len(s2) - len(s))
