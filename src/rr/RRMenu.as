package rr
{
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.KeyboardEvent;
   import flash.events.MouseEvent;
   import flash.text.TextField;
   import flash.text.TextFieldType;
   import flash.text.TextFormat;
   
   /**
    * RRMenu —— 主菜单集成配置条（P1）。
    * 主菜单阶段右下角显示：变异开关（点击切换）+ 种子（INPUT，Enter 应用）。
    * 纯自带 UI（TextField + 矩形），不依赖游戏组件。
    */
   public class RRMenu extends Sprite
   {
      private var cfg:RRConfig;
      private var label:TextField;   // 状态行（点击切换开关）
      private var input:TextField;   // 种子输入
      private var diag:RRDiag;
      
      public function RRMenu(cfg:RRConfig, diag:RRDiag)
      {
         this.cfg = cfg;
         this.diag = diag;
         build();
         refresh();
      }
      
      private function build():void
      {
         // 背景
         graphics.beginFill(0x000000, 0.75);
         graphics.drawRect(0, 0, 300, 64);
         graphics.endFill();
         
         // 状态行（点击切换 enabled）
         label = new TextField();
         label.width = 290;
         label.height = 26;
         label.x = 6;
         label.y = 4;
         label.selectable = false;
         label.mouseEnabled = true;
         label.addEventListener(MouseEvent.CLICK, onToggle);
         var fmt:TextFormat = new TextFormat();
         fmt.color = 0xFFFFFF;
         fmt.size = 13;
         fmt.font = "Lucida Console";
         label.setTextFormat(fmt);
         label.defaultTextFormat = fmt;
         addChild(label);
         
         // 种子输入
         input = new TextField();
         input.width = 200;
         input.height = 22;
         input.x = 6;
         input.y = 34;
         input.type = TextFieldType.INPUT;
         input.border = true;
         input.background = true;
         input.backgroundColor = 0x222222;
         input.restrict = "0-9";
         input.maxChars = 10;
         var ifmt:TextFormat = new TextFormat();
         ifmt.color = 0xFFFFFF;
         ifmt.size = 12;
         input.defaultTextFormat = ifmt;
         input.addEventListener(KeyboardEvent.KEY_DOWN, onInputKey);
         addChild(input);
         // 热键提示行（游戏内测试通道一览）
         var hint:TextField = new TextField();
         hint.width = 290;
         hint.height = 26;
         hint.x = 6;
         hint.y = 60;
         hint.selectable = false;
         hint.text = "热键: F1废墟 F2回城 F4升层 F5合成房展示馆 F7跳合成房";
         var hfmt:TextFormat = new TextFormat();
         hfmt.color = 0xAAAAAA;
         hfmt.size = 10;
         hint.setTextFormat(hfmt);
         hint.defaultTextFormat = hfmt;
         addChild(hint);
      }
      
      private function onToggle(ev:MouseEvent):void
      {
         cfg.enabled = !cfg.enabled;
         cfg.save();
         diag.log("RRMenu: 变异开关 -> " + cfg.enabled);
         refresh();
      }
      
      private function onInputKey(ev:KeyboardEvent):void
      {
         if (ev.keyCode == 13)   // Enter
         {
            var v:uint = uint(input.text);
            if (v == 0)
            {
               v = 20260818;   // 空/0 → 默认种子
            }
            cfg.seed = v;
            cfg.save();
            diag.log("RRMenu: 种子已应用 -> " + cfg.seed);
            refresh();
         }
      }
      
      public function refresh():void
      {
         label.text = "RandomRooms v0.2  [变异:" + (cfg.enabled ? "开" : "关") +
                      " 种子:" + (cfg.seedEnabled ? String(cfg.seed) : "随机") + "]  (点击切换)";
         input.text = cfg.seedEnabled ? String(cfg.seed) : "";
      }
      
      /** 是否处于主菜单阶段（未开始游戏） */
      public static function isMenuTime(world:*):Boolean
      {
         if (world == null) return false;
         var game:* = null;
         try { game = world["game"]; } catch (e:*) {}
         return game == null;
      }
   }
}