package rr
{
   /**
    * RRTestLand —— M0 实验：注入自定义土地 + 自定义房间池。
    *
    * M0 验证假设：
    *   H1. 先于 newGame 向 GameData.d 追加 <land> → 新土地 earth 可用（gotoLand 可达）；
    *   H2. 替换 World.w.rooms.rooms[file] + roomsLoad=0 →
    *        LandLoader 进入该土地时使用注入的房间池；
    *   H3. 测试池全部来自真实作者房间（rooms_stable），进入后
    *        土地的房间 id 集合应恰好等于池中模板（可观测判定）。
    *
    * 本类只做数据生成与注入，不触碰游戏文件。
    */
   public class RRTestLand
   {
      /** 测试土地 id */
      public static const LAND_ID:String = "rr_test";
      /** 自定义房间池文件名（= GameData.d land @file） */
      public static const POOL_FILE:String = "rooms_rr_test";
      /** 池的母语土地（作者撰写的 rnd 土地房间，含 beg0 与普通房） */
      public static const SOURCE_LAND:String = "rooms_stable";
      
      private var _diag:RRDiag;
      private var _picked:Array;
      
      public function RRTestLand(diag:RRDiag)
      {
         _diag = diag;
         _picked = [];
      }
      
      /**
       * 生成测试土地 XML（追加到 GameData.d 用）。
       * conf=1（stable 原型：beg0 在 (0,0)，其余随机；无水面）——
       * 使用已实现的 conf，规避未知 conf 全随机分支的偶发风险。
       */
      public function makeLandXML():XML
      {
         return <land id="rr_test" tip="rnd" rnd="1" dif="0" biom="0" conf="1"
                      file="rooms_rr_test" mx="3" my="3" locx="0" locy="0" list="0">
            <options backwall="tBackWall" music="music_plant_1" fon="fonDarkClouds" xp="100"/>
         </land>;
      }
      
      /**
       * 从 sourcePool（rooms_stable 运行时 XML）自动选房构造测试池：
       * 1 个 tip="beg0" 的起点房 + 3 个无 tip 的普通随机房。
       * 返回 <all> 根 XML；选中的房间 id 记录在 picked log。
       */
      public function makePoolXML(sourcePool:XML):XML
      {
         var pool:XML = <all><land serial="1"/></all>;
         _picked = [];
         
         // 起点房：第一个 tip="beg0" 的房间
         var beg:XMLList = sourcePool.room.(options.@tip == "beg0");
         if (beg.length() > 0)
         {
            pool.appendChild(beg[0].copy());
            _picked.push(String(beg[0].@name) + "(beg0)");
         }
         else
         {
            _diag.log("makePoolXML: WARN 源池中没有 tip=beg0 的房间，起点房缺失");
         }
         
         // 普通房：无 tip 的 rnd 房（隔行取，减少同源风格聚集）
         var normals:XMLList = sourcePool.room.(options.@tip.length() == 0);
         var added:int = 0;
         var idx:int = 0;
         while (added < 3 && idx < normals.length())
         {
            var r:XML = normals[idx] as XML;
            if (r == null)
            {
               idx++;
               continue;
            }
            pool.appendChild(r.copy());
            _picked.push(String(r.@name));
            added++;
            idx += 3; // 取样步长
         }
         
         _diag.log("makePoolXML: 池构造完成，选中 " + _picked.length + " 个房间: " + _picked.join(","));
         return pool;
      }
      
      /** 本池选中的房间 id 列表（用于 H3 判定） */
      public function pickedRooms():Array
      {
         return _picked;
      }
   }
}