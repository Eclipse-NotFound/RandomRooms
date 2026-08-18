package rr
{
   /**
    * RRCook —— 房间模板变异器（P0）。
    *
    * 规则表与 build/p0-proto.py 对照维护（已通过 15750 次离线不变式验证：
    * 尺寸/边界/doors/tip/可解析）。
    *
    * 安全原则：
    *   - 只变异普通 rnd 房（tip 固定功能房与 uniq 稀有房不变异）；
    *   - 边界行列、doors 字符串不变（门位=连接契约）；
    *   - 首字符仅同材质组内互换（ed=1 全实体，组内同碰撞只换外观）；
    *   - 后缀仅 shelf/rear 组内互换；台阶（А/Б）与拉丁后缀不动；
    *   - 属性仅重掷 tilespawn（概率 ±0.2）/ kolspawn（数量 ±30%）。
    *
    * rnd 函数可注入（P1 种子系统预留：确定性 PRNG 替换 Math.random）。
    * 纯 XML 变换，无游戏依赖。
    */
   public class RRCook
   {
      // 首字符组（ed=1 实体；组内互换=同碰撞，只换外观/耐久观感）
      private static const F_METAL:String = "AKJSMOT";     // mat=1 金属
      private static const F_CONCRETE:String = "CDGLNPQ";  // mat=2 混凝土 hp1000
      private static const F_HEAVY:String = "BI";          // 坚固组（B 超混 5000 / I 特殊）
      private static const F_CRACKED:String = "ER";        // 脆墙组（E 裂纹 150 / R 特殊）
      private static const F_GLASS:String = "FH";          // 易碎/特殊组
      private static const F_GROUPS:Array = [F_METAL, F_CONCRETE, F_HEAVY, F_CRACKED, F_GLASS];
      
      // 后缀组：shelf 物件（可站立）/ rear 背景装饰（无碰撞）
      private static const S_SHELF:String = "-ДЕКНР";
      private static const S_REAR:String = "ВГЖЗИЙЛМОПСТ";
      
      // 变异强度参数
      private static const TILE_MUT_RATE:Number = 0.02;  // ~2% 格尝试
      private static const FIRST_SWAP_P:Number = 0.6;
      private static const SUFFIX_SWAP_P:Number = 0.3;
      
      public var rnd:Function;   // 注入随机源（P1 种子系统替换）
      public var lastChangedTotal:int = 0;   // 最近一次 cookPool 的瓦片/属性变更总数（诊断用）
      
      public function RRCook(rndFn:Function = null)
      {
         rnd = rndFn != null ? rndFn : Math.random;
      }
      
      /** 变异单个普通 rnd 房，返回副本（name 追加 _rrN）；自检失败返回 null */
      public function cookRoom(room:XML, suffixNum:int):XML
      {
         var rows:XMLList = room.a;
         var h:int = rows.length();
         if (h == 0) return null;
         var grid:Array = [];
         var w:int = 0;
         var changed:int = 0;
         for (var j:int = 0; j < h; j++)
         {
            grid[j] = String(rows[j]).split(".");
            if (w == 0) w = grid[j].length;
         }
         if (w == 0) return null;
         
         // ---- 瓦片微突变（边界行列受保护） ----
         var tries:int = int(w * h * TILE_MUT_RATE) + 1;
         for (var t:int = 0; t < tries; t++)
         {
            var jj:int = int(rnd() * h);
            var ii:int = int(rnd() * w);
            if (jj == 0 || jj == h - 1 || ii == 0 || ii == w - 1) continue;
            var code:String = grid[jj][ii];
            if (code == null || code.length == 0) continue;
            var first:String = code.charAt(0);
            var suffixChars:String = code.substr(1);
            var nf:String = first;
            for each (var g:String in F_GROUPS)
            {
               if (g.indexOf(first) >= 0)
               {
                  if (g.length > 1 && rnd() < FIRST_SWAP_P)
                  {
                     var c2:String;
                     do { c2 = g.charAt(int(rnd() * g.length)); } while (c2 == first);
                     nf = c2;
                  }
                  break;
               }
            }
            var ns:String = suffixChars;
            var si:int = 0;
            while (si < suffixChars.length)
            {
               var ch:String = suffixChars.charAt(si);
               if (S_SHELF.indexOf(ch) >= 0 && rnd() < SUFFIX_SWAP_P)
               {
                  var c3:String;
                  do { c3 = S_SHELF.charAt(int(rnd() * S_SHELF.length)); } while (c3 == ch);
                  ns = ns.substr(0, si) + c3 + ns.substr(si + 1);
               }
               else if (S_REAR.indexOf(ch) >= 0 && rnd() < SUFFIX_SWAP_P)
               {
                  var c4:String;
                  do { c4 = S_REAR.charAt(int(rnd() * S_REAR.length)); } while (c4 == ch);
                  ns = ns.substr(0, si) + c4 + ns.substr(si + 1);
               }
               si++;
            }
            if (nf + ns != code)
            {
               grid[jj][ii] = nf + ns;
               changed++;
            }
         }
         
         // ---- 属性重掷 ----
         var hasOpts:Boolean = room.options.length() > 0;
         if (hasOpts)
         {
            // tilespawn 概率 ±0.2（0-1 区间）
            if (room.options.@tilespawn.length() && rnd() < 0.7)
            {
               var ts:Number = Number(String(room.options.@tilespawn));
               ts += (rnd() - 0.5) * 0.4;
               if (ts < 0) ts = 0;
               if (ts > 1) ts = 1;
               // 延迟到副本上写
            }
            // kolspawn 数量 ±30%（0 下限）
         }
         
         // ---- 构建副本 ----
         var copy:XML = room.copy();
         copy.@name = String(room.@name) + "_rr" + suffixNum;
         // 写回变异网格
         var newRows:XMLList = copy.a;
         for (var j2:int = 0; j2 < h; j2++)
         {
            newRows[j2] = <a>{grid[j2].join(".")}</a>;
         }
         // 属性重掷写副本（原房间不动）
         if (hasOpts)
         {
            if (String(room.options.@tilespawn).length > 0 && rnd() < 0.7)
            {
               var ts2:Number = Number(String(room.options.@tilespawn));
               ts2 += (rnd() - 0.5) * 0.4;
               if (ts2 < 0) ts2 = 0;
               if (ts2 > 1) ts2 = 1;
               copy.options.@tilespawn = ts2.toFixed(2);
               changed++;
            }
            if (String(room.options.@kolspawn).length > 0 && rnd() < 0.7)
            {
               var ks:int = parseInt(String(room.options.@kolspawn), 10);
               var nks:int = Math.max(0, Math.round(ks * (0.7 + rnd() * 0.6)));
               copy.options.@kolspawn = String(nks);
               changed++;
            }
         }
         lastChangedTotal += changed;
         
         // ---- 自检（失败返回 null，不污染池） ----
         if (!selfCheck(copy, room)) return null;
         return copy;
      }
      
      /** 变异整池：每个普通 rnd 房生成 perRoom 个副本并追加；返回副本数 */
      public function cookPool(pool:XML, perRoom:int = 1):int
      {
         lastChangedTotal = 0;
         var made:int = 0;
         var addList:Array = [];
         for each (var room:XML in pool.room)
         {
            if (isTipRoom(room)) continue;
            for (var n:int = 0; n < perRoom; n++)
            {
               made++;
               var copy:XML = cookRoom(room, made);
               if (copy != null)
               {
                  addList.push(copy);
               }
            }
         }
         for each (var c:XML in addList)
         {
            pool.appendChild(c);
         }
         return addList.length;
      }
      
      /** 是否为可变异/可随机选用的普通 rnd 房（与 isTipRoom 相反） */
      public function isRndRoom(room:XML):Boolean
      {
         return !isTipRoom(room);
      }
      
      /** tip 固定功能房 / uniq 稀有房不变异 */
      private function isTipRoom(room:XML):Boolean
      {
         var tip:String = "";
         if (room.options.@tip.length())
         {
            tip = String(room.options.@tip);
         }
         switch (tip)
         {
            case "beg0": case "beg": case "beg1":
            case "end": case "end1":
            case "pass": case "passroof": case "roofpass": case "vert":
            case "surf": case "roof": case "back": case "uniq":
               return true;
         }
         return false;
      }
      private function selfCheck(copy:XML, orig:XML):Boolean
      {
         var ok:Boolean = true;
         try
         {
            if (copy.a.length() != orig.a.length()) ok = false;
            if (ok)
            {
               var h:int = orig.a.length();
               var r0a:Array = String(orig.a[0]).split(".");
               var r0b:Array = String(copy.a[0]).split(".");
               if (r0a.join("|") != r0b.join("|")) ok = false;
               var rLa:Array = String(orig.a[h - 1]).split(".");
               var rLb:Array = String(copy.a[h - 1]).split(".");
               if (rLa.join("|") != rLb.join("|")) ok = false;
               var d1:String = orig.doors.length() ? String(orig.doors) : "";
               var d2:String = copy.doors.length() ? String(copy.doors) : "";
               if (d1 != d2) ok = false;
            }
         }
         catch (e:*)
         {
            ok = false;
         }
         return ok;
      }
   }
}