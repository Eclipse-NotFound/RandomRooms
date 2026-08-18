package rr
{
   import flash.net.SharedObject;
   
   /**
    * RRConfig —— RandomRooms 配置（SharedObject 持久化，rr_config）。
    * 主菜单 UI 读写；变异/种子开关。
    */
   public class RRConfig
   {
      public static const SO_NAME:String = "rr_config";
      
      public var enabled:Boolean = true;        // 变异总开关
      public var seedEnabled:Boolean = true;    // 种子模式（false=Math.random）
      public var seed:uint = 20260818;          // 主种子（0 显示为默认）
      
      public function load(soData:Object = null):void
      {
         if (soData == null) return;
         if (soData.enabled != null) enabled = Boolean(soData.enabled);
         if (soData.seedEnabled != null) seedEnabled = Boolean(soData.seedEnabled);
         if (soData.seed != null) seed = uint(soData.seed);
      }
      
      public function save():void
      {
         try
         {
            var so:SharedObject = SharedObject.getLocal(SO_NAME, "/");
            so.data.enabled = enabled;
            so.data.seedEnabled = seedEnabled;
            so.data.seed = seed;
            so.flush();
         }
         catch (e:*)
         {
         }
      }
      
      public static function loadFromDisk():RRConfig
      {
         var cfg:RRConfig = new RRConfig();
         try
         {
            var so:SharedObject = SharedObject.getLocal(SO_NAME, "/");
            cfg.load(so.data);
         }
         catch (e:*)
         {
         }
         return cfg;
      }
   }
}