package
{
   import flash.display.Sprite;
   /** Our own driver uses an empty loader slot only inside the isolated app. */
   public class TDFCMod extends Sprite
   {
      public static function init(host:*):void { StyleDriver.init(host); }
   }
}
