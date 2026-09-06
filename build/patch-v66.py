# -*- coding: utf-8 -*-
"""v6.6 横版语义全面修复。

根因认知修正（多证据实证）：本作是横版平台游戏——
  墙带行=地板/平台（玩家站上面）；层间洞=楼板缺口；物件"悬空"=锚点下方
  无实体；左右边界=唯一通道方向（底部越界=坠死）；v6.3 背墙校验方向全错。

修复：
  1) hasGround 校验（y+1 行实体或 `_-` 站台）应用于 wallSpot/interiorSpot/
     back/锚/player/en 标记——替换背墙校验；
  2) 左右边界列重做：除墙带行（地板伸出）外全部开放+逐位贯通——玩家沿
     地板走到边界可越界；相邻房层内行无碰撞可进入（弹回率≈地板行占比）；
  3) 撤销 v6.4 的 T/B 随机开放段（B 段=坠死陷阱）；T/B 全实体+GY/GX 锚点；
  4) 门频率 65→85%/墙带；
  5) RRDiag TAG 加版本号（教训：日志无法区分部署版本）。"""
import io

p = 'src/rr/RRSynth.as'
s = io.open(p, encoding='utf-8').read()

# ---- 1) hasGround 辅助（放 footOk 前） ----
anchor = '      /** 占地格全开放校验（防悬空/穿墙） */'
helper = '''      /** 脚下支撑校验（横版语义 v6.6）：锚点 y 行的物件需要 y+1 行在其
       *  宽度范围内存在实体格（地板），或 y 行本身是 `_-` 站台（横梁） */
      private static function hasGround(grid:Array, x:int, y:int, w:int):Boolean
      {
         if (y >= 0 && y < GRID_H && x >= 0 && x + w - 1 < GRID_W)
         {
            var beamOK:Boolean = true;
            for (var bx2:int = 0; bx2 < w; bx2++)
            {
               var c2:String = grid[y][x + bx2];
               if (c2 == null || c2.length < 2 || c2.charAt(1) != "-") { beamOK = false; break; }
            }
            if (beamOK) return true;
         }
         if (y + 1 >= GRID_H) return false;
         for (var gx2:int = 0; gx2 < w; gx2++)
         {
            var xx:int = x + gx2;
            if (xx < 0 || xx >= GRID_W) continue;
            if (WALL_CHARS.indexOf(grid[y + 1][xx].charAt(0)) >= 0) return true;
         }
         return false;
      }

      /** 占地格全开放校验（防悬空/穿墙） */'''
assert anchor in s, 'anchor footOk'
s = s.replace(anchor, helper, 1)

# ---- 2) wallSpot：背墙校验 → 脚下地板校验 ----
old = """            if (x < 0 || y < 0 || x >= GRID_W || y >= GRID_H) continue;
            // 背墙校验（原版 98% 竖高家具距墙 1 格；采样边背后必须部分是墙，
            // 否则物件立在洞口/开放区边缘=悬空观感）
            var backWall:Boolean = false;
            for (var bc:int = 0; bc < fs && !backWall; bc++)
            {
               if (side == 0 && y - 1 >= 0 && WALL_CHARS.indexOf(grid[y - 1][x + bc].charAt(0)) >= 0) backWall = true;
               if (side == 1 && y + fw < GRID_H && WALL_CHARS.indexOf(grid[y + fw][x + bc].charAt(0)) >= 0) backWall = true;
               if (side == 2 && x - 1 >= 0 && WALL_CHARS.indexOf(grid[y - 0][x - 1].charAt(0)) >= 0) backWall = true;
               if (side == 3 && x + fs < GRID_W && WALL_CHARS.indexOf(grid[y][x + fs].charAt(0)) >= 0) backWall = true;
            }
            if (!backWall) continue;
            if (isOpenCell(grid[y][x]) && used[y + "," + x] != true && footOk(grid, x, y, fs, fw)) return [x, y];"""
new = """            if (x < 0 || y < 0 || x >= GRID_W || y >= GRID_H) continue;
            // v6.6 横版语义：物件必须脚下有地板（y+1 实体或 `_-` 站台）——
            // 背墙校验方向错误（横版里上方是墙无支撑意义），已替换
            if (!hasGround(grid, x, y, fs)) continue;
            if (isOpenCell(grid[y][x]) && used[y + "," + x] != true && footOk(grid, x, y, fs, fw)) return [x, y];"""
assert old in s, 'wallSpot'
s = s.replace(old, new, 1)

# ---- 3) interiorSpot：加脚下地板校验 ----
old = """         if (x < 0 || y < 0 || x >= GRID_W || y >= GRID_H) continue;
         if (isOpenCell(grid[y][x]) && used[y + "," + x] != true && footOk(grid, x, y, fs, fw)) return [x, y];"""
assert old in s, 'interiorSpot'
new = """         if (x < 0 || y < 0 || x >= GRID_W || y >= GRID_H) continue;
         if (!hasGround(grid, x, y, fs)) continue;
         if (isOpenCell(grid[y][x]) && used[y + "," + x] != true && footOk(grid, x, y, fs, fw)) return [x, y];"""
s = s.replace(old, new, 1)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('v6.6 part1 ok (ground checks)')
