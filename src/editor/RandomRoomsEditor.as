package {
    import flash.display.Sprite;
    public class RandomRoomsEditor extends Sprite {
        private var panel:RRReviewPanel;
        public function RandomRoomsEditor() {}
        public function init(host:Object):void { if(!panel) panel=new RRReviewPanel(host); }
        public function open():void { panel.open(); }
        public function get isOpen():Boolean { return panel && panel.isOpen; }
        public function get reviewPanel():RRReviewPanel { return panel; }
        public function dispose():void { if(panel) panel.dispose(); }
    }
}
