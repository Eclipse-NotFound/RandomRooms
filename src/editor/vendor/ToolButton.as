package {
    import flash.display.Sprite;
    import flash.events.MouseEvent;
    import flash.text.*;
    public class ToolButton extends Sprite {
        private var text:TextField=new TextField();
        private var w:Number;
        private var h:Number;
        public function ToolButton(label:String,width:Number=110,height:Number=28) {
            w=width; h=height;
            graphics.lineStyle(1,0x708394);
            graphics.beginFill(0xEAF0F4);
            graphics.drawRoundRect(0,0,w,h,5,5);
            graphics.endFill();
            text.defaultTextFormat=new TextFormat("Microsoft YaHei UI",13,0x193B50,false,null,null,null,null,"center");
            text.embedFonts=false;
            text.antiAliasType="advanced";
            text.gridFitType="pixel";
            text.width=w;
            text.height=h;
            text.y=(h-22)/2;
            text.selectable=false;
            text.mouseEnabled=false;
            addChild(text);
            this.label=label;
            buttonMode=true;
            mouseChildren=false;
        }
        public function set label(value:String):void { text.text=value; }
        public function set enabled(value:Boolean):void { mouseEnabled=value; alpha=value?1:0.45; }
    }
}
