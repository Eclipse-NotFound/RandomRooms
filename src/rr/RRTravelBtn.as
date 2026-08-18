package rr
{
   import flash.display.Sprite;
   import flash.events.MouseEvent;
   import flash.text.TextField;
   import flash.text.TextFormat;
   
   /**
    * RRTravelBtn —— PipPage 旅行入口按钮（P1 收尾）。
    * 挂载于 vpip（哔哔小马视觉树）内，随哔哔小马一起显示/隐藏。
    * 点击回调由宿主注入（RandomRoomsMod.doTravel）。
    */
   public class RRTravelBtn extends Sprite
   {
      public var travelFn:Function;
      
      public function RRTravelBtn(diag:RRDiag)
      {
         graphics.beginFill(0x111111, 0.85);
         graphics.drawRect(0, 0, 170, 26);
         graphics.endFill();
         graphics.lineStyle(1, 0x888888);
         graphics.drawRect(0, 0, 170, 26);
         
         var t:TextField = new TextField();
         t.width = 170;
         t.height = 26;
         t.selectable = false;
         t.text = "  RandomRooms 废墟 ->";
         var fmt:TextFormat = new TextFormat();
         fmt.color = 0xFFDD88;
         fmt.size = 12;
         fmt.font = "Lucida Console";
         t.setTextFormat(fmt);
         t.defaultTextFormat = fmt;
         addChild(t);
         
         addEventListener(MouseEvent.CLICK, onClick);
      }
      
      private function onClick(ev:MouseEvent):void
      {
         if (travelFn != null)
         {
            try
            {
               travelFn();
            }
            catch (e:*)
            {
            }
         }
      }
   }
}