package rr
{
   /**
    * RRSeed —— 确定性 PRNG（P1 种子系统）。
    *
    * 算法：xorshift32（纯位运算，AS3 uint 精确；python 对照版见
    * build/seed-check.py——已离线验证序列一致）。
    *
    * 用途：
    *   - 注入 RRCook.rnd：同种子 → 同变异内容（同种子同世界）；
    *   - fork(label) 派生子序列，隔离各用途（cook/布局/内容……）；
    *   - 种子 0 自动映射为 1（xorshift 全零死循环）。
    */
   public class RRSeed
   {
      public var seed:uint;
      private var _x:uint;
      
      public function RRSeed(s:uint)
      {
         seed = s;
         _x = (s == 0) ? 1 : s;
      }
      
      /** 派生新序列（不改本序列状态） */
      public function fork(label:String):RRSeed
      {
         var h:uint = seed ^ 0x9E3779B9;
         for (var i:int = 0; i < label.length; i++)
         {
            h ^= label.charCodeAt(i);
            h ^= h << 13;
            h ^= h >>> 17;
            h ^= h << 5;
         }
         return new RRSeed(h);
      }
      
      /** [0,1) */
      public function next():Number
      {
         _x ^= _x << 13;
         _x ^= _x >>> 17;
         _x ^= _x << 5;
         return _x / 4294967296;
      }
      
      /** [0,n) 整数 */
      public function nextInt(n:int):int
      {
         if (n <= 0) return 0;
         return int(next() * n);
      }
      
      /** 序列前 n 个值（诊断/离线对照用） */
      public function preview(n:int):Array
      {
         var out:Array = [];
         for (var i:int = 0; i < n; i++)
         {
            out.push(next());
         }
         return out;
      }
   }
}