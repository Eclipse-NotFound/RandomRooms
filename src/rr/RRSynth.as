package rr
{
   /**
    * RRSynth —— 全新房间合成器（路线 A：模板拼接）。
    *
    * 算法（与 build/synth-proto.py 同构，已离线批量验证 200 房）：
    *   1. 48x24 空地网格；外圈边界墙（语料最常见 'A'）；
    *   2. 内部铺 5-8 个墙块（RRGrammar.BLOCKS，间距 ≥1 防连墙）；
    *   3. 空地 5% 装饰后缀（语料频率加权）；
    *   4. 统一缺口（左右=行12，上下=列23/24——与 normalizeGaps 一致，
    *      保证与任何池房间配对连通）；
    *   5. BFS 可达性：不可达空地回填墙（保证无孤岛）；
    *   6. 输出 <room name='syn_N'> XML（无 options=普通 rnd 房；
    *      无 doors=游戏默认全 2，不影响通行——gotoLoc 只看碰撞）。
    *
    * rnd 函数可注入（种子确定性）。纯逻辑，无游戏依赖。
    */
   public class RRSynth
   {
      public static const GRID_W:int = 48;
      public static const GRID_H:int = 24;
      
      // 合法字符集（与 AllData.d.mat 对照）：
      // 首字符 = fForms 键（拉丁 A-T，均实体）+ "_"（空地）
      public static const FCHARS:String = "ABCDEFGHIJKLMNOPQRST_";
      // 后缀 = oForms 键：拉丁 A-Z + 俄文（shelf/rear）+ "-" + 硬编码 "*,;:"
      public static const OCHARS:String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
         "АБВГДЕЖЗИЙКЛМОПСТ-ДЕКНР" + "*,;:";
      private static const BLOCK_W:int = 6;
      private static const BLOCK_H:int = 4;
      private static const WALL:String = "ABCDEFGHIJKLMNOPQRST";
      private static const GY:int = 12;   // 左右缺口行（与 normalizeGaps 一致）
      private static const GX1:int = 23;  // 上下缺口列
      private static const GX2:int = 24;
      
      public var rnd:Function;
      
      public function RRSynth(rndFn:Function = null)
      {
         rnd = rndFn != null ? rndFn : Math.random;
      }
      
      /** 生成一个合成房 XML（name = syn_<n>） */
      public function generate(n:int):XML
      {
         var grid:Array = genGrid();
         var room:XML = <room name={"syn_" + n}/>;
         for (var j:int = 0; j < GRID_H; j++)
         {
            room.appendChild(<a>{grid[j].join(".")}</a>);
         }
         // 与作者房对齐：显式补空 <options>（消除"无 options 元素"的解析差异）
         room.appendChild(<options/>);
         return room;
      }
      
      /**
       * 合成房预检（进入池前过滤）：
       *   1. 行数 = GRID_H、每行列数 = GRID_W；
       *   2. 每格首字符 ∈ FCHARS、后缀 ∈ OCHARS（与 Tile.dec 解析一致）；
       *   3. 存在 <options>。
       * 不合格返回 false（由调用方丢弃，避免 buildLoc #1009）。
       */
      public static function validateRoom(room:XML):Boolean
      {
         try
         {
            var rows:XMLList = room.a;
            if (rows.length() != GRID_H) return false;
            var j:int = 0;
            while (j < GRID_H)
            {
               var cols:Array = String(rows[j]).split(".");
               if (cols.length != GRID_W) return false;
               var i:int = 0;
               while (i < GRID_W)
               {
                  var code:String = String(cols[i]);
                  if (code.length == 0) return false;
                  if (FCHARS.indexOf(code.charAt(0)) < 0) return false;
                  var k:int = 1;
                  while (k < code.length)
                  {
                     if (OCHARS.indexOf(code.charAt(k)) < 0) return false;
                     k++;
                  }
                  i++;
               }
               j++;
            }
            return room.options.length() > 0;
         }
         catch (e:*)
         {
            return false;
         }
         return false;   // 兜底（满足编译器返回分析）
      }
      
      /** 核心生成：返回字符网格 */
      public function genGrid():Array
      {
         var grid:Array = [];
         for (var j:int = 0; j < GRID_H; j++)
         {
            grid[j] = [];
            for (var i:int = 0; i < GRID_W; i++)
            {
               grid[j][i] = "_";
            }
         }
         // 外圈边界墙
         for (i = 0; i < GRID_W; i++)
         {
            grid[0][i] = "A";
            grid[GRID_H - 1][i] = "A";
         }
         for (j = 0; j < GRID_H; j++)
         {
            grid[j][0] = "A";
            grid[j][GRID_W - 1] = "A";
         }
         // 统一缺口
         grid[GY][0] = "_";
         grid[GY][GRID_W - 1] = "_";
         grid[0][GX1] = "_";
         grid[0][GX2] = "_";
         grid[GRID_H - 1][GX1] = "_";
         grid[GRID_H - 1][GX2] = "_";
         
         // 铺块（间距 ≥1）
         var nblocks:int = 5 + int(rnd() * 4);   // 5-8
         var placed:int = 0;
         var attempts:int = 0;
         while (placed < nblocks && attempts < 120)
         {
            attempts++;
            var blk:Array = RRGrammar.BLOCKS[int(rnd() * RRGrammar.BLOCKS.length)];
            var bx:int = 2 + int(rnd() * (GRID_W - 4 - BLOCK_W));
            var by:int = 2 + int(rnd() * (GRID_H - 4 - BLOCK_H));
            var ok:Boolean = true;
            for (var dj:int = -1; dj <= BLOCK_H; dj++)
            {
               for (var di:int = -1; di <= BLOCK_W; di++)
               {
                  var ty:int = by + dj;
                  var tx:int = bx + di;
                  if (ty >= 0 && ty < GRID_H && tx >= 0 && tx < GRID_W && grid[ty][tx] != "_")
                  {
                     ok = false;
                     break;
                  }
               }
               if (!ok) break;
            }
            if (!ok) continue;
            for (dj = 0; dj < BLOCK_H; dj++)
            {
               var brow:Array = String(blk[dj]).split("|");
               for (di = 0; di < BLOCK_W; di++)
               {
                  var code:String = String(brow[di]);
                  code = code.split(" ").join("");   // 防御：trim 空格（历史 #1009 教训）
                  if (code.length > 0)
                  {
                     grid[by + dj][bx + di] = code;
                  }
               }
            }
            placed++;
         }
         
         // 装饰后缀（空地 5%，语料频率加权）
         // 注意：后缀必须挂在 "_" 之后（如 "_Е"）——俄文字符 charCode>64
         // 会被 Tile.dec 当作首字符查 fForms（只有拉丁 A-T）→ inForm(null) #1009
         var totalW:int = 0;
         for (var wI:int = 0; wI < RRGrammar.DECOR.length; wI++)
         {
            totalW += int(RRGrammar.DECOR[wI][1]);
         }
         for (j = 1; j < GRID_H - 1; j++)
         {
            for (i = 1; i < GRID_W - 1; i++)
            {
               if (grid[j][i] == "_" && rnd() < 0.05)
               {
                  var r:int = int(rnd() * totalW);
                  var acc:int = 0;
                  for (var dI:int = 0; dI < RRGrammar.DECOR.length; dI++)
                  {
                     acc += int(RRGrammar.DECOR[dI][1]);
                     if (r < acc)
                     {
                        grid[j][i] = "_" + String(RRGrammar.DECOR[dI][0]);
                        break;
                     }
                  }
               }
            }
         }
         
         // BFS 可达性（缺口格出发，不可达空地回填墙）
         var seen:Array = [];
         var qx:Array = [];
         var qy:Array = [];
         var starts:Array = [[GY,0],[GY,GRID_W-1],[0,GX1],[0,GX2],[GRID_H-1,GX1],[GRID_H-1,GX2]];
         for (var sI:int = 0; sI < starts.length; sI++)
         {
            var sy:int = starts[sI][0];
            var sx:int = starts[sI][1];
            if (WALL.indexOf(grid[sy][sx].charAt(0)) < 0)
            {
               seen.push(sy * GRID_W + sx);
               qy.push(sy);
               qx.push(sx);
            }
         }
         var head:int = 0;
         while (head < qx.length)
         {
            var cy:int = qy[head];
            var cx:int = qx[head];
            head++;
            var dirs:Array = [[1,0],[-1,0],[0,1],[0,-1]];
            for (var dd:int = 0; dd < 4; dd++)
            {
               var ny:int = cy + dirs[dd][0];
               var nx:int = cx + dirs[dd][1];
               if (ny < 0 || ny >= GRID_H || nx < 0 || nx >= GRID_W) continue;
               var key:int = ny * GRID_W + nx;
               if (seen.indexOf(key) >= 0) continue;
               if (WALL.indexOf(grid[ny][nx].charAt(0)) >= 0) continue;
               seen.push(key);
               qy.push(ny);
               qx.push(nx);
            }
         }
         for (j = 0; j < GRID_H; j++)
         {
            for (i = 0; i < GRID_W; i++)
            {
               if (WALL.indexOf(grid[j][i].charAt(0)) < 0 && seen.indexOf(j * GRID_W + i) < 0)
               {
                  grid[j][i] = "C";   // 孤岛空地回填墙
               }
            }
         }
         return grid;
      }
   }
}