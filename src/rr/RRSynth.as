package rr
{
   /**
    * RRSynth v2 —— 全新房间合成器（道路模板 × 生物群系分组）。
    *
    * 解决 v1 两缺陷：
    *   1. 材质混搭 → 整房只用单一 biome 组块/装饰（材料一致）；
    *   2. 无道路 → vcorr(纵向走廊)/hall(大厅) 道路模板：先画贯穿开放带，
    *      块只贴道路两侧分区，沿廊装饰带界定道路边界。
    *
    * 算法与 build/synth-proto2.py 同构（离线 200 房不变式已验证）。
    * 硬性约束：25 行 x 48 列（World.cellsY=25，作者房同维度）；
    * 缺口统一（左右=行12，上下=列23/24）；BFS 可达性（孤岛回填墙）。
    * rnd 可注入（种子确定性）。
    */
   public class RRSynth
   {
      public static const GRID_W:int = 48;
      public static const GRID_H:int = 25;   // 作者房均为 25 行（World.cellsY）；24 行致 buildLoc 越界 #1009
      
      public static const FCHARS:String = "ABCDEFGHIJKLMNOPQRST_";
      public static const OCHARS:String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
         "АБВГДЕЖЗИЙКЛМОПСТ-ДЕКНР" + "*,;:";
      /** 实体墙首字符（不含 _ 空地）——判墙必须用此集；FCHARS 含 _ 会误判 */
      public static const WALL_CHARS:String = "ABCDEFGHIJKLMNOPQRST";
      
      public static const BIOMES:Array = ["stable", "sewer", "plant", "mane"];
      
      private static const BLOCK_W:int = 6;
      private static const BLOCK_H:int = 4;
      private static const GY:int = 12;
      private static const GX1:int = 23;
      private static const GX2:int = 24;
      
      public var rnd:Function;
      /** 分阶段诊断：genGrid 每步墙数（定位全墙 bug） */
      public var debugStages:Array = [];
      /** v3.2 连通细胞表：主廊/纵连/腔室连廊落盘格（供腔室就近连廊） */
      private var pathCells:Array = [];
      /** v5.1 物件表：generate() 输出 <obj>/<back> 元素 */
      public var lastObjs:Array = [];
      public var lastBacks:Array = [];
      
      public function RRSynth(rndFn:Function = null)
      {
         rnd = rndFn != null ? rndFn : Math.random;
      }
      
      /** 生成一个合成房；biome 指定材质主题，rtype: "vcorr"/"hall"/""随机 */
      public function generate(n:int, biome:String = "stable", rtype:String = ""):XML
      {
         var grid:Array = genGrid(biome, rtype);
         var room:XML = <room name={"syn_" + n}/>;
         for (var j:int = 0; j < GRID_H; j++)
         {
            room.appendChild(<a>{grid[j].join(".")}</a>);
         }
         // v5.1 物件：门/箱子/家具/出生点/敌人标记
         if (lastObjs != null)
         {
            for (var k:int = 0; k < lastObjs.length; k++)
            {
               var o:Array = lastObjs[k] as Array;
               room.appendChild(<obj id={o[0]} code={o[1]} x={o[2]} y={o[3]}/>);
            }
         }
         if (lastBacks != null)
         {
            for (k = 0; k < lastBacks.length; k++)
            {
               var b:Array = lastBacks[k] as Array;
               room.appendChild(<back id={b[0]} x={b[1]} y={b[2]}/>);
            }
         }
         room.appendChild(<doors/>);
         room.appendChild(<options/>);
         return room;
      }
      
      /** 核心生成：场驱动（v3） */
      public function genGrid(biome:String, rtype:String):Array
      {
         var bIdx:int = RRGrammar.BIOME_ORDER.indexOf(biome);
         if (bIdx < 0) bIdx = 0;
         var wallTbl:Array = RRGrammar.BIOME_WALLS[bIdx] as Array;
         var decor:Array = RRGrammar.BIOME_DECORS[bIdx] as Array;
         if (rtype == null || rtype.length == 0)
         {
            var rt:int = int(rnd() * 4);
            rtype = rt == 0 ? "corridor" : (rt == 1 ? "hall" : (rt == 2 ? "l" : "split"));
         }
         
         var grid:Array = [];
         var j:int;
         var i:int;
         for (j = 0; j < GRID_H; j++)
         {
            grid[j] = [];
            for (i = 0; i < GRID_W; i++)
            {
               grid[j][i] = "_";
            }
         }
         debugStages = [];
         debugStages.push(["init", wallCount(grid)]);
         
         var f:Array = null;
         if (rtype == "corridor" || rtype == "hall" || rtype == "l" || rtype == "split")
         {
            // v5 房间-走廊骨架生成：显式房间 + 2 宽走廊网络 + 干净边界 +
            // 安全装饰（排除水/网格/横梁/台阶）+ 成片水池 + 连通修复
            v5Skeleton(grid, Math.min(bIdx, 3), rtype, wallTbl, decor);
            debugStages.push(["skeleton", wallCount(grid)]);
            finishStripRoom(grid);
            debugStages.push(["final", wallCount(grid)]);
            return grid;
         }
         else if (rtype == "quad")
         {
            f = quadField();
            var th:Number = threshWall(f, 0.22);
            for (j = 0; j < GRID_H; j++)
            {
               for (i = 0; i < GRID_W; i++)
               {
                  if (f[j][i] >= th)
                  {
                     grid[j][i] = wallChar(wallTbl);
                  }
               }
            }
            carveRooms(grid, rtype, wallTbl);
            materialBands(grid, wallTbl);
            applyBoundaryAndDecor(grid, decor, wallTbl, rtype);
            return grid;
         }
         else
         {
            // bunker：SDF 环带（掩体岛），独立画墙
            var ncen:int = 2 + int(rnd() * 2);
            var cx:Array = [];
            var cy:Array = [];
            for (var kc:int = 0; kc < ncen; kc++)
            {
               cx.push(8 + int(rnd() * (GRID_W - 17)));
               cy.push(5 + int(rnd() * (GRID_H - 11)));
            }
            for (j = 0; j < GRID_H; j++)
            {
               for (i = 0; i < GRID_W; i++)
               {
                  var d:Number = 1e9;
                  for (var kd:int = 0; kd < ncen; kd++)
                  {
                     var dd:Number = Math.sqrt((i - cx[kd]) * (i - cx[kd]) + (j - cy[kd]) * (j - cy[kd]));
                     if (dd < d) d = dd;
                  }
                  d += (rnd() - 0.5) * 1.2;
                  if (d >= 3.4 && d <= 5.6)
                  {
                     grid[j][i] = wallChar(wallTbl);
                  }
               }
            }
            applyBoundaryAndDecor(grid, decor, wallTbl, rtype);
            return grid;
         }
      }
      
      /** v5 房间-走廊骨架生成：
       * 1) 整图填墙（biome 材质）→ 2) 干净矩形房间(间距约束) 挖空
       * 3) 2 宽 L 形走廊网络：每房间连入生成树 + 6 缺口连入 → 房间-通道分明
       * 4) 边界 0/24 行 0/47 列整墙 + 6 缺口（干净边框）
       * 5) 材质带(2x4 区 90% 主字符) → 墙体区域统一不拼贴
       * 6) 装饰排仅安全地板纹理（排除 *水/K网格/-横梁/台阶/楼梯）
       * 7) 水池成片(sewer/plant)；连通修复由 finishStripRoom 完成 */
      private function v5Skeleton(grid:Array, bIdx:int, rtype:String, wallTbl:Array, decor:Array):void
      {
         var j:int, i:int, y:int, x:int, k:int;
         // 1) 填墙
         for (j = 0; j < GRID_H; j++)
         {
            for (i = 0; i < GRID_W; i++)
            {
               grid[j][i] = wallChar(wallTbl);
            }
         }
         // 2) 房间
         var nLo:int, nHi:int, cwLo:int, cwHi:int, chLo:int, chHi:int;
         if (rtype == "hall") { nLo = 5; nHi = 7; cwLo = 9; cwHi = 13; chLo = 7; chHi = 10; }
         else if (rtype == "split") { nLo = 8; nHi = 11; cwLo = 8; cwHi = 12; chLo = 6; chHi = 9; }
         else { nLo = 6; nHi = 8; cwLo = 8; cwHi = 13; chLo = 6; chHi = 10; }
         var n:int = nLo + int(rnd() * (nHi - nLo + 1));
         var pat:Object = {};
         var patArr:Array = [];
         var rooms:Array = [];
         var roomRects:Array = [];
         var placed:int = 0;
         var tries:int = 0;
         var bi:int = 0;
         var bands:Array = [[2, 6], [8, 14], [16, 21]];
         while (placed < n && tries < 200)
         {
            tries++;
            var cw:int = cwLo + int(rnd() * (cwHi - cwLo + 1));
            var ch2:int = chLo + int(rnd() * (chHi - chLo + 1));
            var cwx:int = 2 + int(rnd() * (GRID_W - cw - 4));
            var band:Array = bands[bi % 3] as Array;
            bi++;
            var cwy:int = band[0] + int(rnd() * (band[1] - band[0] + 1));
            if (cwy > GRID_H - ch2 - 2) cwy = GRID_H - ch2 - 2;
            var ok:Boolean = true;
            // 间距 2：房间之间至少 2 格墙 → 走廊有可见长度、通道可用
            for (y = cwy - 2; y <= cwy + ch2 + 2; y++)
            {
               for (x = cwx - 2; x <= cwx + cw + 2; x++)
               {
                  if (y >= 0 && y < GRID_H && x >= 0 && x < GRID_W && pat[y + "," + x] == true)
                  {
                     ok = false;
                     break;
                  }
               }
               if (!ok) break;
            }
            if (!ok) continue;
            for (y = cwy; y < cwy + ch2; y++)
            {
               for (x = cwx; x < cwx + cw; x++)
               {
                  if (WALL_CHARS.indexOf(grid[y][x].charAt(0)) >= 0) grid[y][x] = "_";
                  pat[y + "," + x] = true;
                  patArr.push([y, x]);
               }
            }
            rooms.push([cwx + int(cw / 2), cwy + int(ch2 / 2)]);
            roomRects.push([cwx, cwy, cw, ch2]);
            placed++;
         }
         // 3) 走廊网络：每房间 2 宽 L 形连入网络 + 6 缺口连入 + 额外环连接
         var order:Array = [];
         for (k = 0; k < rooms.length; k++) order.push(k);
         for (k = order.length - 1; k > 0; k--)
         {
            var sw:int = int(rnd() * (k + 1));
            var tmp:int = order[k];
            order[k] = order[sw];
            order[sw] = tmp;
         }
         for (k = 0; k < order.length; k++)
         {
            // 排除本房间矩形（用下标同步房间与矩形，防误排除他房 → 房间孤立）
            var oi:int = order[k];
            var rr:Array = roomRects[oi] as Array;
            linkL2(grid, pat, patArr, int(rooms[oi][0]), int(rooms[oi][1]), int(rr[0]), int(rr[1]), int(rr[0]) + int(rr[2]) - 1, int(rr[1]) + int(rr[3]) - 1);
         }
         var gs:Array = [[GY, 0], [GY, GRID_W - 1], [0, GX1], [0, GX2], [GRID_H - 1, GX1], [GRID_H - 1, GX2]];
         for (k = 0; k < gs.length; k++)
         {
            var gy2:int = gs[k][0];
            var gx2:int = gs[k][1];
            if (pat[gy2 + "," + gx2] != true) linkL2(grid, pat, patArr, gx2, gy2, -1, -1, -1, -1);
         }
         // 额外环连接 2-4 条：随机房间对（走廊网络更密、通道更明显）
         var extra:int = 2 + int(rnd() * 3);
         for (k = 0; k < extra; k++)
         {
            if (rooms.length < 2) break;
            var ra:int = int(rnd() * rooms.length);
            var rb:int = int(rnd() * rooms.length);
            if (ra == rb) continue;
            var rr2:Array = roomRects[rb] as Array;
            linkL2(grid, pat, patArr, int(rooms[rb][0]), int(rooms[rb][1]), int(rr2[0]), int(rr2[1]), int(rr2[0]) + int(rr2[2]) - 1, int(rr2[1]) + int(rr2[3]) - 1);
         }
         // 4) 材质带（90% 主字符）
         materialBands(grid, wallTbl);
         // 5) 边界：0/24 行 0/47 列整墙 + 6 缺口
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
         grid[GRID_H - 1][GX2] = "_";
         // 6) 装饰排：仅安全地板纹理后缀
         var safeDec:Array = safeDecor(decor);
         if (safeDec.length > 0)
         {
            var den:Number = bIdx == 0 ? 0.40 : (bIdx == 1 ? 0.30 : (bIdx == 2 ? 0.28 : 0.34));
            for (y = 1; y < GRID_H - 1; y++)
            {
               x = 1;
               while (x < GRID_W - 1)
               {
                  if (grid[y][x] == "_" && rnd() < den)
                  {
                     var L:int = 2 + int(rnd() * 5);
                     for (k = 0; k < L; k++)
                     {
                        var dx2:int = x + k;
                        if (dx2 < GRID_W - 1 && grid[y][dx2] == "_") grid[y][dx2] = "_" + pickWeighted(safeDec);
                     }
                     x += L;
                  }
                  else
                  {
                     x++;
                  }
               }
            }
         }
         // 7) 水池成片（sewer/plant）
         var pools:int = bIdx == 1 ? (1 + int(rnd() * 3)) : (bIdx == 2 ? (1 + int(rnd() * 2)) : 0);
         for (k = 0; k < pools; k++)
         {
            var pw:int = 5 + int(rnd() * 7);
            var ph2:int = 1 + int(rnd() * 3);
            var px:int = 2 + int(rnd() * (GRID_W - pw - 4));
            var py:int = 2 + int(rnd() * (GRID_H - ph2 - 3));
            for (y = py; y < py + ph2; y++)
            {
               for (x = px; x < px + pw; x++)
               {
                  if (grid[y][x] == "_") grid[y][x] = "_*";
               }
            }
         }
         // 8) 房间物件：门(走廊交汇处)/贴墙箱子/室内家具/书架/出生点/背景装饰
         lastObjs = [];
         lastBacks = [];
         placeRoomObjects(grid, bIdx, roomRects);
      }

      /** 房间物件放置：每房间 门+2-4箱子+沙发/桌/书架/出生点；外围背景装饰。
       * 全部按占地格(size×wid)校验开放 → 无悬空/穿墙 */
      private function placeRoomObjects(grid:Array, bIdx:int, rects:Array):void
      {
         var doorId:String = bIdx == 2 ? "door1" : "stdoor";
         var crates:Array = bIdx == 0 ? ["ammobox", "explbox", "case", "mcrate2", "chest", "locker"] :
                           (bIdx == 1 ? ["case", "ammobox", "explbox", "box", "woodbox", "chest", "locker", "radbarrel"] :
                           (bIdx == 2 ? ["ammobox", "case", "box", "explbox", "chest", "radbarrel", "woodbox"] :
                                        ["case", "ammobox", "explbox", "mcrate2", "filecab", "locker"]));
         var sofas:Array = bIdx == 0 ? ["couch", "lov"] : ["lov"];
         var tableId:String = bIdx == 0 ? "table2" : "table";
         var backs:Array = ["konstr", "vkonstr", "hkonstr", "stlight1", "vents", "pipe4"];
         var r:int, k:int, tries:int, placed:int;
         for (r = 0; r < rects.length; r++)
         {
            var rect:Array = rects[r] as Array;
            var cwx:int = rect[0];
            var cwy:int = rect[1];
            var cw:int = rect[2];
            var ch2:int = rect[3];
            var used:Object = {};
            // 门：走廊交汇边界格；占地朝房间内放置（走廊保持畅通）
            var doorCell:Array = findJunction(grid, cwx, cwy, cw, ch2);
            if (doorCell != null && rnd() < 0.6)
            {
               var dFoot:Array = objFoot(doorId);
               var placedDoor:Boolean = false;
               // 门洞锚点向房间内偏移尝试（门不占走廊格）
               for (var off:int = 0; off < 3; off++)
               {
                  var ay:int = doorCell[1] - off;
                  if (ay >= cwy && ay < cwy + ch2 && footOk(grid, doorCell[0], ay, dFoot[0], dFoot[1]))
                  {
                     lastObjs.push([doorId, genCode(), doorCell[0], ay]);
                     used[ay + "," + doorCell[0]] = true;
                     placedDoor = true;
                     break;
                  }
               }
               if (!placedDoor) doorCell = null;
            }
            else
            {
               doorCell = null;
            }
            if (doorCell != null)
            {
               lastObjs.push([doorId, genCode(), doorCell[0], doorCell[1]]);
               used[doorCell[1] + "," + doorCell[0]] = true;
            }
            // 箱子 2-4 个（贴墙，占地校验）
            var nCrate:int = 2 + int(rnd() * 3);
            tries = 0;
            placed = 0;
            while (placed < nCrate && tries < 60)
            {
               tries++;
               var cid:String = crates[int(rnd() * crates.length)];
               var c:Array = wallSpot(grid, cwx, cwy, cw, ch2, used, cid);
               if (c == null) break;
               lastObjs.push([cid, genCode(), c[0], c[1]]);
               used[c[1] + "," + c[0]] = true;
               placed++;
            }
            // 沙发/桌子/书架/出生点（室内，占地校验）
            var sofaId:String = sofas[int(rnd() * sofas.length)];
            var in1:Array = interiorSpot(grid, cwx, cwy, cw, ch2, used, sofaId);
            if (in1 != null && rnd() < 0.7)
            {
               lastObjs.push([sofaId, genCode(), in1[0], in1[1]]);
               used[in1[1] + "," + in1[0]] = true;
            }
            var in2:Array = interiorSpot(grid, cwx, cwy, cw, ch2, used, tableId);
            if (in2 != null && rnd() < 0.6)
            {
               lastObjs.push([tableId, genCode(), in2[0], in2[1]]);
               used[in2[1] + "," + in2[0]] = true;
            }
            var in3:Array = interiorSpot(grid, cwx, cwy, cw, ch2, used, "bookcase");
            if (in3 != null && rnd() < 0.5)
            {
               lastObjs.push(["bookcase", genCode(), in3[0], in3[1]]);
               used[in3[1] + "," + in3[0]] = true;
            }
            var in4:Array = interiorSpot(grid, cwx, cwy, cw, ch2, used, "player");
            if (in4 != null)
            {
               lastObjs.push(["player", genCode(), in4[0], in4[1]]);
               used[in4[1] + "," + in4[0]] = true;
            }
            // 背景装饰 3-6（开放格上，同原版 back 摆放规律 —— 原版 85%+ 在开放格）
            var nBack:int = 3 + int(rnd() * 4);
            tries = 0;
            placed = 0;
            while (placed < nBack && tries < 40)
            {
               tries++;
               var bx:int = cwx + int(rnd() * cw);
               var by:int = cwy + int(rnd() * ch2);
               if (bx < 0 || by < 0 || bx >= GRID_W || by >= GRID_H) continue;
               if (grid[by][bx] != "_") continue;
               lastBacks.push([backs[int(rnd() * backs.length)], bx, by]);
               placed++;
            }
         }
      }

      /** 物件占地格 [size(宽), wid(高)]（AllData 实测） */
      private function objFoot(id:String):Array
      {
         switch (id)
         {
            case "case": case "ammobox": case "explbox": case "lov": case "enl1": return [1, 1];
            case "couch": case "table2": case "table": case "chest": return [2, 1];
            case "mcrate2": case "box": case "woodbox": case "player": case "enl2": case "hatch2": return [2, 2];
            case "radbarrel": case "filecab": case "door1": return [1, 2];
            case "locker": case "bookcase": return [2, 3];
            case "stdoor": return [1, 3];
            default: return [1, 1];
         }
      }

      /** 占地格全开放校验（防悬空/穿墙） */
      private function footOk(grid:Array, x:int, y:int, size:int, wid:int):Boolean
      {
         for (var dy:int = 0; dy < wid; dy++)
         {
            for (var dx:int = 0; dx < size; dx++)
            {
               var xx:int = x + dx;
               var yy:int = y + dy;
               if (xx < 0 || yy < 0 || xx >= GRID_W || yy >= GRID_H) return false;
               if (grid[yy][xx] != "_") return false;
            }
         }
         return true;
      }

      /** 找房间边界上与走廊相邻的开放格（门洞位） */
      private function findJunction(grid:Array, cwx:int, cwy:int, cw:int, ch2:int):Array
      {
         var y:int, x:int;
         // 上/下边
         for (x = cwx; x < cwx + cw; x++)
         {
            if (cellJunction(grid, cwy, x, cwx, cwy, cw, ch2)) return [x, cwy];
            if (cellJunction(grid, cwy + ch2 - 1, x, cwx, cwy, cw, ch2)) return [x, cwy + ch2 - 1];
         }
         // 左/右边
         for (y = cwy; y < cwy + ch2; y++)
         {
            if (cellJunction(grid, y, cwx, cwx, cwy, cw, ch2)) return [cwx, y];
            if (cellJunction(grid, y, cwx + cw - 1, cwx, cwy, cw, ch2)) return [cwx + cw - 1, y];
         }
         return null;
      }

      private function cellJunction(grid:Array, y:int, x:int, cwx:int, cwy:int, cw:int, ch2:int):Boolean
      {
         if (y < 1 || y >= GRID_H - 1 || x < 1 || x >= GRID_W - 1) return false;
         if (grid[y][x] != "_") return false;
         var inside:Boolean = (y > cwy && y < cwy + ch2 - 1 && x > cwx && x < cwx + cw - 1);
         if (inside) return false;
         // 邻格在房间外且开放 → 门洞
         var nb:Array = [[y - 1, x], [y + 1, x], [y, x - 1], [y, x + 1]];
         for (var k:int = 0; k < 4; k++)
         {
            var ny:int = nb[k][0];
            var nx:int = nb[k][1];
            if (ny < 0 || ny >= GRID_H || nx < 0 || nx >= GRID_W) continue;
            var out:Boolean = !(ny >= cwy && ny < cwy + ch2 && nx >= cwx && nx < cwx + cw);
            if (out && grid[ny][nx] == "_") return true;
         }
         return false;
      }

      /** 贴墙位：房间边内 1 格、占地格全开放、未占用 */
      private function wallSpot(grid:Array, cwx:int, cwy:int, cw:int, ch2:int, used:Object, id:String):Array
      {
         var foot:Array = objFoot(id);
         var fs:int = foot[0];
         var fw:int = foot[1];
         for (var t:int = 0; t < 25; t++)
         {
            var side:int = int(rnd() * 4);
            var x:int, y:int;
            if (side == 0) { y = cwy + 1; x = cwx + 1 + int(rnd() * Math.max(1, cw - 2 - fs)); }
            else if (side == 1) { y = cwy + ch2 - 2; x = cwx + 1 + int(rnd() * Math.max(1, cw - 2 - fs)); }
            else if (side == 2) { x = cwx + 1; y = cwy + 1 + int(rnd() * Math.max(1, ch2 - 2 - fw)); }
            else { x = cwx + cw - 2; y = cwy + 1 + int(rnd() * Math.max(1, ch2 - 2 - fw)); }
            if (x < 0 || y < 0 || x >= GRID_W || y >= GRID_H) continue;
            if (grid[y][x] == "_" && used[y + "," + x] != true && footOk(grid, x, y, fs, fw)) return [x, y];
         }
         return null;
      }

      /** 室内位：离房间边 >=2、占地格全开放、未占用 */
      private function interiorSpot(grid:Array, cwx:int, cwy:int, cw:int, ch2:int, used:Object, id:String):Array
      {
         var foot:Array = objFoot(id);
         var fs:int = foot[0];
         var fw:int = foot[1];
         for (var t:int = 0; t < 40; t++)
         {
            var x:int = cwx + 2 + int(rnd() * Math.max(1, cw - 4 - fs));
            var y:int = cwy + 2 + int(rnd() * Math.max(1, ch2 - 4 - fw));
            if (x < 0 || y < 0 || x >= GRID_W || y >= GRID_H) continue;
            if (grid[y][x] == "_" && used[y + "," + x] != true && footOk(grid, x, y, fs, fw)) return [x, y];
         }
         return null;
      }

      /** 随机 16 位物件码（同原版 code 格式） */
      private function genCode():String
      {
         var chars:String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
         var s:String = "";
         for (var i:int = 0; i < 16; i++)
         {
            s += chars.charAt(int(rnd() * chars.length));
         }
         return s;
      }

      /** 2 宽 L 形走廊：最近开放格（排除 ex 矩形）-> (tx,ty)（目标=房间中心/缺口）
       * 排除自身矩形是必须的：否则最近格=目标自身，走廊不挖 → 房间孤立 */
      private function linkL2(grid:Array, pat:Object, patArr:Array, tx:int, ty:int, exX0:int, exY0:int, exX1:int, exY1:int):void
      {
         if (patArr.length == 0) return;
         var bi:int = 0;
         var bd:Number = 1e9;
         for (var k:int = 0; k < patArr.length; k++)
         {
            var cy0:int = patArr[k][0];
            var cx0:int = patArr[k][1];
            if (cx0 >= exX0 && cx0 <= exX1 && cy0 >= exY0 && cy0 <= exY1) continue;
            var dy:Number = cy0 - ty;
            var dx:Number = cx0 - tx;
            var d:Number = dy * dy + dx * dx;
            if (d < bd) { bd = d; bi = k; }
         }
         var y:int = patArr[bi][0];
         var x:int = patArr[bi][1];
         var st:int = 0;
         while ((y != ty || x != tx) && st < 120)
         {
            st++;
            for (var k2:int = 0; k2 < 2; k2++)
            {
               if (x + k2 < GRID_W)
               {
                  if (WALL_CHARS.indexOf(grid[y][x + k2].charAt(0)) >= 0) grid[y][x + k2] = "_";
                  if (pat[y + "," + (x + k2)] != true)
                  {
                     pat[y + "," + (x + k2)] = true;
                     patArr.push([y, x + k2]);
                  }
               }
            }
            var dx2:int = tx - x;
            var dy2:int = ty - y;
            if (Math.abs(dx2) >= Math.abs(dy2)) x += dx2 > 0 ? 1 : -1;
            else y += dy2 > 0 ? 1 : -1;
            y = Math.max(1, Math.min(GRID_H - 2, y));
            x = Math.max(1, Math.min(GRID_W - 2, x));
         }
         for (k2 = 0; k2 < 2; k2++)
         {
            if (x + k2 < GRID_W)
            {
               if (WALL_CHARS.indexOf(grid[y][x + k2].charAt(0)) >= 0) grid[y][x + k2] = "_";
               if (pat[y + "," + (x + k2)] != true)
               {
                  pat[y + "," + (x + k2)] = true;
                  patArr.push([y, x + k2]);
               }
            }
         }
      }

      /** 装饰表过滤：仅保留安全地板纹理（排除 *水 / K网格(框架地板) /
       *  -横梁 / 西里尔台阶楼梯横梁） */
      private function safeDecor(decor:Array):Array
      {
         var out:Array = [];
         if (decor == null) return out;
         var bad:String = "*-,КАБВГЖЗИЙЛМОПСТНРK";
         for (var k:int = 0; k < decor.length; k++)
         {
            var ch:String = String(decor[k][0]);
            if (bad.indexOf(ch) < 0) out.push(decor[k]);
         }
         return out;
      }

      private function finishStripRoom(grid:Array):void
      {
         grid[GY][0] = "_";
         grid[GY][GRID_W - 1] = "_";
         grid[0][GX1] = "_";
         grid[0][GX2] = "_";
         grid[GRID_H - 1][GX1] = "_";
         grid[GRID_H - 1][GX2] = "_";
         repairConnectivity(grid);
      }

      /** 连通修复：从 6 缺口 BFS；未连通开放组件 <16 格填墙，否则挖 2 宽 L 连廊 */
      private function repairConnectivity(grid:Array):void
      {
         var j:int;
         var i:int;
         var seen:Array = [];
         for (j = 0; j < GRID_H; j++)
         {
            seen[j] = [];
            for (i = 0; i < GRID_W; i++) seen[j][i] = false;
         }
         var mainOpen:Array = [];
         var qy:Array = [];
         var qx:Array = [];
         var starts:Array = [[GY, 0], [GY, GRID_W - 1], [0, GX1], [0, GX2], [GRID_H - 1, GX1], [GRID_H - 1, GX2]];
         for (var s:int = 0; s < starts.length; s++)
         {
            var sy:int = starts[s][0];
            var sx:int = starts[s][1];
            if (!seen[sy][sx] && WALL_CHARS.indexOf(grid[sy][sx].charAt(0)) < 0)
            {
               seen[sy][sx] = true;
               qy.push(sy);
               qx.push(sx);
               mainOpen.push([sy, sx]);
            }
         }
         var head:int = 0;
         while (head < qx.length)
         {
            var cy:int = qy[head];
            var cx:int = qx[head];
            head++;
            if (cy > 0 && !seen[cy - 1][cx] && WALL_CHARS.indexOf(grid[cy - 1][cx].charAt(0)) < 0)
            {
               seen[cy - 1][cx] = true; qy.push(cy - 1); qx.push(cx); mainOpen.push([cy - 1, cx]);
            }
            if (cy < GRID_H - 1 && !seen[cy + 1][cx] && WALL_CHARS.indexOf(grid[cy + 1][cx].charAt(0)) < 0)
            {
               seen[cy + 1][cx] = true; qy.push(cy + 1); qx.push(cx); mainOpen.push([cy + 1, cx]);
            }
            if (cx > 0 && !seen[cy][cx - 1] && WALL_CHARS.indexOf(grid[cy][cx - 1].charAt(0)) < 0)
            {
               seen[cy][cx - 1] = true; qy.push(cy); qx.push(cx - 1); mainOpen.push([cy, cx - 1]);
            }
            if (cx < GRID_W - 1 && !seen[cy][cx + 1] && WALL_CHARS.indexOf(grid[cy][cx + 1].charAt(0)) < 0)
            {
               seen[cy][cx + 1] = true; qy.push(cy); qx.push(cx + 1); mainOpen.push([cy, cx + 1]);
            }
         }
         // 扫描未连通开放组件
         for (j = 0; j < GRID_H; j++)
         {
            for (i = 0; i < GRID_W; i++)
            {
               if (seen[j][i] || WALL_CHARS.indexOf(grid[j][i].charAt(0)) >= 0) continue;
               var comp:Array = [];
               var cqy:Array = [j];
               var cqx:Array = [i];
               seen[j][i] = true;
               var ch:int = 0;
               while (ch < cqx.length)
               {
                  var cy2:int = cqy[ch];
                  var cx2:int = cqx[ch];
                  ch++;
                  comp.push([cy2, cx2]);
                  if (cy2 > 0 && !seen[cy2 - 1][cx2] && WALL_CHARS.indexOf(grid[cy2 - 1][cx2].charAt(0)) < 0)
                  {
                     seen[cy2 - 1][cx2] = true; cqy.push(cy2 - 1); cqx.push(cx2);
                  }
                  if (cy2 < GRID_H - 1 && !seen[cy2 + 1][cx2] && WALL_CHARS.indexOf(grid[cy2 + 1][cx2].charAt(0)) < 0)
                  {
                     seen[cy2 + 1][cx2] = true; cqy.push(cy2 + 1); cqx.push(cx2);
                  }
                  if (cx2 > 0 && !seen[cy2][cx2 - 1] && WALL_CHARS.indexOf(grid[cy2][cx2 - 1].charAt(0)) < 0)
                  {
                     seen[cy2][cx2 - 1] = true; cqy.push(cy2); cqx.push(cx2 - 1);
                  }
                  if (cx2 < GRID_W - 1 && !seen[cy2][cx2 + 1] && WALL_CHARS.indexOf(grid[cy2][cx2 + 1].charAt(0)) < 0)
                  {
                     seen[cy2][cx2 + 1] = true; cqy.push(cy2); cqx.push(cx2 + 1);
                  }
               }
               if (comp.length < 16)
               {
                  for (var ck:int = 0; ck < comp.length; ck++)
                  {
                     grid[comp[ck][0]][comp[ck][1]] = "C";
                  }
               }
               else
               {
                  carveConnector(grid, seen, comp, mainOpen);
               }
            }
         }
      }

      /** 组件最近格 -> 主网最近开放格：L 形 2 宽连廊 */
      private function carveConnector(grid:Array, seen:Array, comp:Array, mainOpen:Array):void
      {
         var bi:int = 0;
         var bm:int = 0;
         var bd:Number = 1e9;
         for (var a:int = 0; a < comp.length; a++)
         {
            for (var b:int = 0; b < mainOpen.length; b++)
            {
               var dy:Number = comp[a][0] - mainOpen[b][0];
               var dx:Number = comp[a][1] - mainOpen[b][1];
               var d:Number = dy * dy + dx * dx;
               if (d < bd) { bd = d; bi = a; bm = b; }
            }
         }
         var y0:int = comp[bi][0];
         var x0:int = comp[bi][1];
         var y1:int = mainOpen[bm][0];
         var x1:int = mainOpen[bm][1];
         // L 形：横段 + 竖段（2 宽），挖出的格标记 seen 防重复处理
         if (rnd() < 0.5)
         {
            carveH(grid, seen, x0, x1, y0, 2);
            carveV(grid, seen, y0, y1, x1, 2);
         }
         else
         {
            carveV(grid, seen, y0, y1, x0, 2);
            carveH(grid, seen, x0, x1, y1, 2);
         }
      }

      /** 横扫 w 宽（挖开放 + 标记 seen） */
      private function carveH(grid:Array, seen:Array, xa:int, xb:int, y:int, w:int):void
      {
         var lo:int = Math.min(xa, xb);
         var hi:int = Math.max(xa, xb);
         for (var x:int = lo; x <= hi; x++)
         {
            for (var dy:int = 0; dy < w; dy++)
            {
               var yy:int = y + dy;
               if (yy >= 0 && yy < GRID_H)
               {
                  grid[yy][x] = "_";
                  if (seen[yy] != null) seen[yy][x] = true;
               }
            }
         }
      }

      /** 竖扫 w 宽（挖开放 + 标记 seen） */
      private function carveV(grid:Array, seen:Array, ya:int, yb:int, x:int, w:int):void
      {
         var lo:int = Math.min(ya, yb);
         var hi:int = Math.max(ya, yb);
         for (var y:int = lo; y <= hi; y++)
         {
            for (var dx:int = 0; dx < w; dx++)
            {
               var xx:int = x + dx;
               if (xx >= 0 && xx < GRID_W)
               {
                  grid[y][xx] = "_";
                  if (seen[y] != null) seen[y][xx] = true;
               }
            }
         }
      }

      /** Voronoi 四区场（近区心低->开放，区界高->墙） */
      private function quadField():Array
      {
         var centers:Array = [[7, 7], [41, 7], [7, 18], [41, 18]];
         var f:Array = [];
         for (var y:int = 0; y < GRID_H; y++)
         {
            f[y] = [];
            for (var x:int = 0; x < GRID_W; x++)
            {
               var ds:Array = [];
               for (var k:int = 0; k < centers.length; k++)
               {
                  ds.push(Math.sqrt((x - centers[k][0]) * (x - centers[k][0]) + (y - centers[k][1]) * (y - centers[k][1])));
               }
               ds.sort(Array.NUMERIC);
               f[y][x] = ds[0] + 0.7 * ds[1];
            }
         }
         return f;
      }
      
      /** 二分阈值：f>=th 占 ratio（对聚集分布鲁棒，免排序） */
      private function threshWall(f:Array, ratio:Number):Number
      {
         var lo:Number = 1e9;
         var hi:Number = -1e9;
         var count:int = 0;
         for (var j:int = 0; j < GRID_H; j++)
         {
            for (var i:int = 0; i < GRID_W; i++)
            {
               if (f[j][i] < 0) continue;
               count++;
               if (f[j][i] < lo) lo = f[j][i];
               if (f[j][i] > hi) hi = f[j][i];
            }
         }
         if (count == 0) return 0.5;
         for (var it:int = 0; it < 14; it++)
         {
            var mid:Number = (lo + hi) / 2;
            var c3:int = 0;
            for (j = 0; j < GRID_H; j++)
            {
               for (i = 0; i < GRID_W; i++)
               {
                  if (f[j][i] >= 0 && f[j][i] >= mid) c3++;
               }
            }
            if (c3 / count > ratio) lo = mid;
            else hi = mid;
         }
         return (lo + hi) / 2;
      }
      
      private function pickWeighted(tbl:Array):String
      {
         var tot:int = 0;
         for (var k:int = 0; k < tbl.length; k++)
         {
            tot += int(tbl[k][1]);
         }
         var r:int = int(rnd() * tot);
         var acc:int = 0;
         for (k = 0; k < tbl.length; k++)
         {
            acc += int(tbl[k][1]);
            if (r < acc) return String(tbl[k][0]);
         }
         return String(tbl[0][0]);
      }
      
      /** 统计墙格数 */
      public function wallCount(grid:Array):int
      {
         var n:int = 0;
         for (var j:int = 0; j < grid.length; j++)
         {
            for (var i:int = 0; i < grid[j].length; i++)
            {
               if (WALL_CHARS.indexOf(String(grid[j][i]).charAt(0)) >= 0) n++;
            }
         }
         return n;
      }
      
      private function wallChar(wallTbl:Array):String
      {
         return pickWeighted(wallTbl);
      }
      
      /** 边界/缺口 + 装饰掩体层 + BFS */
      private function applyBoundaryAndDecor(grid:Array, decor:Array, wallTbl:Array, rtype:String = null):void
      {
         for (var i:int = 0; i < GRID_W; i++)
         {
            grid[0][i] = "A";
            grid[GRID_H - 1][i] = "A";
         }
         for (var j:int = 0; j < GRID_H; j++)
         {
            grid[j][0] = "A";
            grid[j][GRID_W - 1] = "A";
         }
         grid[GY][0] = "_";
         grid[GY][GRID_W - 1] = "_";
         grid[0][GX1] = "_";
         grid[0][GX2] = "_";
         grid[GRID_H - 1][GX1] = "_";
         grid[GRID_H - 1][GX2] = "_";
         if (decor != null && decor.length > 0)
         {
            for (j = 1; j < GRID_H - 1; j++)
            {
               for (i = 1; i < GRID_W - 1; i++)
               {
                  if (grid[j][i] == "_" && rnd() < 0.16)
                  {
                     grid[j][i] = "_" + pickWeighted(decor);
                  }
               }
            }
         }
         for (var m:int = 0; m < 6; m++)
         {
            j = 2 + int(rnd() * (GRID_H - 4));
            i = 2 + int(rnd() * (GRID_W - 4));
            if (grid[j][i] == "_")
            {
               grid[j][i] = "_-";
            }
         }
         if (rtype == "quad")
         {
            quadGates(grid);
         }
         gapGuard(grid);
         bfsFill(grid);
      }
      
      /** v3.5 原版分区墙（语料实证：原版墙占比 0.15-0.36，墙=1-2 格厚的
       * 部分宽度横/竖分区带，带缺口；开放为底 + 边缘墙条 + 高密度装饰）。
       * 分区带锚定层高 {4,12,20} / 列 {8,24,40}（原版块层结构），
       * 缺口+两端边道保证区块连通 → 出口不会被堵。 */
      private function carveRooms(grid:Array, rtype:String, wallTbl:Array):void
      {
         var k:int, g:int, xx:int, yy:int, x:int, y:int;
         var nH:int = rtype == "hall" ? 2 : (rtype == "split" ? 5 : 3);
         var levels:Array = [4, 12, 20];
         for (k = 0; k < nH; k++)
         {
            y = int(levels[int(rnd() * 3)]) + int(rnd() * 3) - 1;
            y = Math.max(2, Math.min(GRID_H - 3, y));
            var wseg:int = 24 + int(rnd() * 21);          // 24-44
            var x0:int = 2 + int(rnd() * (GRID_W - wseg - 2));
            var thick:int = rnd() < 0.7 ? 1 : 2;
            var ng:int = 2 + int(rnd() * 3);              // 2-4 缺口
            var gaps:Object = {};
            for (g = 0; g < ng; g++) gaps[x0 + int(rnd() * wseg)] = true;
            for (xx = x0 + 2; xx < x0 + wseg - 2; xx++)   // 两端留 2 格边道
            {
               if (gaps[xx] != null) continue;
               for (yy = y; yy < Math.min(y + thick, GRID_H - 1); yy++)
               {
                  if (grid[yy][xx] == "_") grid[yy][xx] = wallChar(wallTbl);
               }
            }
         }
         var nV:int = rtype == "hall" ? 0 : (rtype == "split" ? 3 : (rtype == "l" ? 2 : 1));
         var cols:Array = [8, 24, 40];
         for (k = 0; k < nV; k++)
         {
            x = int(cols[int(rnd() * 3)]) + int(rnd() * 3) - 1;
            x = Math.max(2, Math.min(GRID_W - 3, x));
            var hseg:int = 6 + int(rnd() * 13);           // 6-18
            var y0:int = 2 + int(rnd() * (GRID_H - hseg - 2));
            var thick2:int = rnd() < 0.8 ? 1 : 2;
            var ng2:int = 1 + int(rnd() * 2);             // 1-2 缺口
            var gaps2:Object = {};
            for (g = 0; g < ng2; g++) gaps2[y0 + int(rnd() * hseg)] = true;
            for (yy = y0 + 1; yy < y0 + hseg - 1; yy++)   // 两端留 1 格通道
            {
               if (gaps2[yy] != null) continue;
               for (xx = x; xx < Math.min(x + thick2, GRID_W - 1); xx++)
               {
                  if (grid[yy][xx] == "_") grid[yy][xx] = wallChar(wallTbl);
               }
            }
         }
         // 左右边缘墙条（带缺口，非整高）
         for (var si:int = 0; si < 2; si++)
         {
            var side:int = si == 0 ? 1 : GRID_W - 2;
            for (y = 2; y < GRID_H - 2; y++)
            {
               if (rnd() < 0.75 && Math.abs(y - GY) > 2 && grid[y][side] == "_")
               {
                  grid[y][side] = wallChar(wallTbl);
               }
            }
         }
         // 掩体墩 2-5 个（实心块，射击掩体）
         var nubN:int = 2 + int(rnd() * 4);
         for (k = 0; k < nubN; k++)
         {
            var ny:int = 2 + int(rnd() * (GRID_H - 4));
            var nx:int = 2 + int(rnd() * (GRID_W - 4));
            if (grid[ny][nx] == "_") grid[ny][nx] = wallChar(wallTbl);
         }
      }
      
      /** v3.1 材质带：2x4 大区主字符（区内 85% 同色） → 墙整体统一 */
      private function materialBands(grid:Array, wallTbl:Array):void
      {
         var zone:Array = [];
         for (var zy:int = 0; zy < 2; zy++)
         {
            zone[zy] = [];
            for (var zx:int = 0; zx < 4; zx++)
            {
               zone[zy][zx] = (rnd() < 0.6 ? wallTbl[0][0] : pickWeighted(wallTbl));
            }
         }
         for (var j:int = 0; j < GRID_H; j++)
         {
            for (var i:int = 0; i < GRID_W; i++)
            {
               if (WALL_CHARS.indexOf(grid[j][i].charAt(0)) >= 0)
               {
                  var main:String = String(zone[Math.min(int(j / 13), 1)][Math.min(int(i / 12), 3)]);
                  grid[j][i] = (rnd() < 0.90) ? main : pickWeighted(wallTbl);
               }
            }
         }
      }
      
      /** v3.1 缺口保护：缺口 3x3 邻域 + 向心隧道强制开放（通道不堵） */
      private function gapGuard(grid:Array):void
      {
         var j:int;
         var i:int;
         for (j = Math.max(0, GY - 1); j < Math.min(GRID_H, GY + 2); j++)
         {
            for (i = 0; i < 3; i++) { if (grid[j][i] == "C") grid[j][i] = "_"; }
            for (i = GRID_W - 3; i < GRID_W; i++) { if (grid[j][i] == "C") grid[j][i] = "_"; }
            for (i = 3; i < 8; i++) { if (grid[j][i] == "C") grid[j][i] = "_"; }
            for (i = GRID_W - 8; i < GRID_W - 3; i++) { if (grid[j][i] == "C") grid[j][i] = "_"; }
         }
         for (i = Math.max(0, GX1 - 1); i < Math.min(GRID_W, GX2 + 2); i++)
         {
            for (j = 0; j < 2; j++) { if (grid[j][i] == "C") grid[j][i] = "_"; }
            for (j = GRID_H - 2; j < GRID_H; j++) { if (grid[j][i] == "C") grid[j][i] = "_"; }
            for (j = 2; j < 7; j++) { if (grid[j][i] == "C") grid[j][i] = "_"; }
            for (j = GRID_H - 7; j < GRID_H - 2; j++) { if (grid[j][i] == "C") grid[j][i] = "_"; }
         }
      }
      
      /** v3.1 quad 区门：中央十字挖通四区 */
      private function quadGates(grid:Array):void
      {
         for (var y:int = 11; y <= 13; y++)
         {
            for (var x:int = 22; x <= 25; x++)
            {
               if (grid[y][x] == "C") grid[y][x] = "_";
            }
         }
         for (x = 21; x <= 26; x++)
         {
            for (y = 11; y <= 13; y += 2)
            {
               if (grid[y][x] == "C") grid[y][x] = "_";
            }
         }
      }

      private function pickDecor(decor:Array, total:int):String
      {
         var r:int = int(rnd() * total);
         var acc:int = 0;
         for (var k:int = 0; k < decor.length; k++)
         {
            acc += int(decor[k][1]);
            if (r < acc)
            {
               return String(decor[k][0]);
            }
         }
         return "-";
      }
      
      private function placeBlocks(grid:Array, regions:Array, blocks:Array, count:int):void
      {
         var placed:int = 0;
         var tries:int = 0;
         while (placed < count && tries < 200)
         {
            tries++;
            var rg:Array = regions[int(rnd() * regions.length)] as Array;
            var x0:int = rg[0];
            var x1:int = rg[1];
            var y0:int = rg[2];
            var y1:int = rg[3];
            var bx:int = x0 + int(rnd() * (Math.max(x0, x1 - BLOCK_W) - x0 + 1));
            var by:int = y0 + int(rnd() * (Math.max(y0, y1 - BLOCK_H) - y0 + 1));
            if (bx + BLOCK_W - 1 > x1) bx = x1 - BLOCK_W + 1;
            if (by + BLOCK_H - 1 > y1) by = y1 - BLOCK_H + 1;
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
            var blk:Array = blocks[int(rnd() * blocks.length)] as Array;
            for (dj = 0; dj < BLOCK_H; dj++)
            {
               var brow:Array = String(blk[dj]).split("|");
               for (di = 0; di < BLOCK_W; di++)
               {
                  var code:String = String(brow[di]);
                  code = code.split(" ").join("");
                  if (code.length > 0)
                  {
                     grid[by + dj][bx + di] = code;
                  }
               }
            }
            placed++;
         }
      }
      
      private function bfsFill(grid:Array):void
      {
         var seen:Object = {};
         var qx:Array = [];
         var qy:Array = [];
         var starts:Array = [[GY, 0], [GY, GRID_W - 1], [0, GX1], [0, GX2], [GRID_H - 1, GX1], [GRID_H - 1, GX2]];
         for (var sI:int = 0; sI < starts.length; sI++)
         {
            var sy:int = starts[sI][0];
            var sx:int = starts[sI][1];
            if (WALL_CHARS.indexOf(grid[sy][sx].charAt(0)) < 0)
            {
               seen[sy * GRID_W + sx] = 1;
               qy.push(sy);
               qx.push(sx);
            }
         }
         var head:int = 0;
         var dirs:Array = [[1, 0], [-1, 0], [0, 1], [0, -1]];
         while (head < qx.length)
         {
            var cy:int = qy[head];
            var cx:int = qx[head];
            head++;
            for (var dd:int = 0; dd < 4; dd++)
            {
               var ny:int = cy + dirs[dd][0];
               var nx:int = cx + dirs[dd][1];
               if (ny < 0 || ny >= GRID_H || nx < 0 || nx >= GRID_W) continue;
               var key:int = ny * GRID_W + nx;
               if (seen[key] != null) continue;
               if (WALL_CHARS.indexOf(grid[ny][nx].charAt(0)) >= 0) continue;
               seen[key] = 1;
               qy.push(ny);
               qx.push(nx);
            }
         }
         for (var j:int = 0; j < GRID_H; j++)
         {
            for (var i:int = 0; i < GRID_W; i++)
            {
               if (WALL_CHARS.indexOf(grid[j][i].charAt(0)) < 0 && seen[j * GRID_W + i] == null)
               {
                  grid[j][i] = "C";
               }
            }
         }
      }
      
      /** 合成房预检：行数/列数/字符/options 全检（与 Tile.dec 解析一致） */
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
         return false;
      }
   }
}