# -*- coding: utf-8 -*-
"""v6.4：边界原版式开放段（通道问题的最终根因修复）。

根因链（反编译实证）：玩家跨合成房 = 像素撞边触发 outLoc → gotoLoc 把玩家放进
目标房同高度边缘位 → collisionUnit 碰撞即弹回。合成房边界 99% 整墙+3 小缺口
→ 玩家几乎处处弹回 = "无通道"。原版作者房边界开放率：左右 35%/上 30%/下 16%
——多高度段可穿行。

修复：每边按原版开放率开段（左右 2 段×3-6 格、上 2 段×4-7 格、下保守 1 段
3-4 格——下边界走出=坠落死亡故从简），开放段向内逐格挖到接上开放区
（复用 carveGapTunnel 的逐进逻辑）。"""
import io

p = 'src/rr/RRSynth.as'
s = io.open(p, encoding='utf-8').read()

# ---- 1) 边界段替换：整墙+6缺口 → 原版式开放段 ----
old = """         // 5) 边界：0/24 行 0/47 列整墙 + 6 缺口
         for (i = 0; i < GRID_W; i++)
         {
            grid[0][i] = wallChar(wallTbl);
            grid[GRID_H - 1][i] = wallChar(wallTbl);
         }
         for (j = 0; j < GRID_H; j++)
         {
            grid[j][0] = wallChar(wallTbl);
            grid[j][GRID_W - 1] = wallChar(wallTbl);
         }
         grid[GY][0] = "_";
         grid[GY][GRID_W - 1] = "_";
         grid[0][GX1] = "_";
         grid[0][GX2] = "_";
         grid[GRID_H - 1][GX1] = "_";
         grid[GRID_H - 1][GX2] = "_";"""
new = """         // 5) 边界（v6.4 原版式开放段）：原版作者房边界开放率 L/R 35%、T 30%、
         //    B 16%——玩家跨房靠"撞边→目标房同高度边缘进入（collisionUnit
         //    过碰撞才放行）"，整墙边界=几乎处处弹回=合成房之间无通道的
         //    最终根因。每边开 1-2 段（下边界走出=坠落死亡，保守单段）。
         for (i = 0; i < GRID_W; i++)
         {
            grid[0][i] = wallChar(wallTbl);
            grid[GRID_H - 1][i] = wallChar(wallTbl);
         }
         for (j = 0; j < GRID_H; j++)
         {
            grid[j][0] = wallChar(wallTbl);
            grid[j][GRID_W - 1] = wallChar(wallTbl);
         }
         var segY:int, segLen:int, segPos:int;
         // 左右边：2 段 × 3-6 格（含 GY 锚点段）
         grid[GY][0] = "_";
         grid[GY][GRID_W - 1] = "_";
         for (var sideLR:int = 0; sideLR < 2; sideLR++)
         {
            segPos = 2 + int(rnd() * (GRID_H - 8));
            segLen = 3 + int(rnd() * 4);
            for (segY = segPos; segY < segPos + segLen && segY < GRID_H - 1; segY++)
            {
               grid[segY][0] = "_";
               grid[segY][GRID_W - 1] = "_";
            }
         }
         // 上边：2 段 × 4-7 格（含 GX 双列锚点）
         grid[0][GX1] = "_";
         grid[0][GX2] = "_";
         for (var sideT:int = 0; sideT < 2; sideT++)
         {
            segPos = 3 + int(rnd() * (GRID_W - 12));
            segLen = 4 + int(rnd() * 4);
            for (var segX:int = segPos; segX < segPos + segLen && segX < GRID_W - 1; segX++)
            {
               grid[0][segX] = "_";
            }
         }
         // 下边：保守 1 段 3-4 格 + GX 双列（走出下边界=坠落死亡，段少且避开）
         grid[GRID_H - 1][GX1] = "_";
         grid[GRID_H - 1][GX2] = "_";
         segPos = 4 + int(rnd() * (GRID_W - 12));
         segLen = 3 + int(rnd() * 2);
         for (segX = segPos; segX < segPos + segLen && segX < GRID_W - 1; segX++)
         {
            grid[GRID_H - 1][segX] = "_";
         }"""
assert old in s, 'boundary'
s = s.replace(old, new, 1)

# ---- 2) finishStripRoom：缺口隧道扩为"边界开放位隧道"——左右边全高逐行、
#          上边全宽逐列挖到开放区（保证每个开放边界位真的能进/出） ----
old = """         // v6.3 缺口贯通隧道：从每缺口向内逐层挖 2 宽通道，直到接上开放区
         // （最多 7 步）。任何分层/隔断结构下缺口→房内可达（跨合成房通行的
         // 房内侧保证；此前无此步——分层结构恰好把缺口堵在墙外=合成房之间
         // 无通道的直接根因）
         carveGapTunnel(grid, GY, 0, 1, 0);      // 左缺口 → 向右
         carveGapTunnel(grid, GY, GRID_W - 1, -1, 0); // 右缺口 → 向左
         carveGapTunnel(grid, 0, GX1, 0, 1);     // 上缺口1 → 向下
         carveGapTunnel(grid, 0, GX2, 0, 1);     // 上缺口2
         carveGapTunnel(grid, GRID_H - 1, GX1, 0, -1); // 下缺口1 → 向上
         carveGapTunnel(grid, GRID_H - 1, GX2, 0, -1); // 下缺口2
         repairConnectivity(grid);"""
new = """         // v6.4 边界开放位贯通：每个开放的边界格向内挖到接上开放区
         // （逐格 1 宽×≤6 步，玩家身位 2 格——相邻两位共同构成通道）
         var by:int, bx:int;
         for (by = 0; by < GRID_H; by++)
         {
            if (isOpenCell(grid[by][0])) carveGapTunnel(grid, by, 0, 1, 0);
            if (isOpenCell(grid[by][GRID_W - 1])) carveGapTunnel(grid, by, GRID_W - 1, -1, 0);
         }
         for (bx = 0; bx < GRID_W; bx++)
         {
            if (isOpenCell(grid[0][bx])) carveGapTunnel(grid, 0, bx, 0, 1);
            if (isOpenCell(grid[GRID_H - 1][bx])) carveGapTunnel(grid, GRID_H - 1, bx, 0, -1);
         }
         repairConnectivity(grid);"""
assert old in s, 'gap tunnels'
s = s.replace(old, new, 1)

io.open(p, 'w', encoding='utf-8', newline='').write(s)

# ---- 3) 缺口检查改为运行时 space 边界开放率（Room 非 XML，#1034 根因） ----
p2 = 'src/RandomRoomsMod.as'
s2 = io.open(p2, encoding='utf-8').read()
start = s2.index('         // 缺口贯通检查（v5.9）：对首个 loc 的 room，验证 6 缺口的')
endmark = '         f8Issued = false;'
end = s2.index(endmark)
new_check = """         // 边界通行检查（v6.4）：读运行时 Location.space 的四边 phis，
         // 输出每边开放率与可通过高度/宽度段——对应 gotoLoc 的碰撞判定
         try
         {
            var vloc:* = world.land.locs[0][0][0];
            var vsp:* = vloc.space;
            var openL:int = 0, openR:int = 0, openT:int = 0, openB:int = 0;
            var vi:int;
            for (vi = 0; vi < vloc.spaceY; vi++)
            {
               if (vsp[vi][0].phis <= 0) openL++;
               if (vsp[vi][vloc.spaceX - 1].phis <= 0) openR++;
            }
            for (vi = 0; vi < vloc.spaceX; vi++)
            {
               if (vsp[0][vi].phis <= 0) openT++;
               if (vsp[vloc.spaceY - 1][vi].phis <= 0) openB++;
            }
            diag.log("verifyEntry: 边界通行 L=" + openL + "/" + vloc.spaceY +
                     " R=" + openR + "/" + vloc.spaceY +
                     " T=" + openT + "/" + vloc.spaceX +
                     " B=" + openB + "/" + vloc.spaceX +
                     "（开放格数；gotoLoc 同高度进入，开放位=可通行）");
         }
         catch (e:*)
         {
            diag.log("verifyEntry: 边界检查异常 " + e);
         }
         """
s2 = s2[:start] + new_check + s2[end:]
io.open(p2, 'w', encoding='utf-8', newline='').write(s2)
print('v6.4 patch ok')
