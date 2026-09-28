package {
    import flash.display.*;
    import flash.events.*;
    import flash.geom.*;
    import flash.text.*;
    import flash.utils.Timer;
    import flash.filesystem.*;
    import flash.net.URLRequest;
    import flash.system.*;

    public class EditorTools extends Sprite {
        private var host:Object;
        private var view:MovieClip;
        private var labels:MapLabels;
        private var preview:PreviewPanel;
        private var timer:Timer;
        private var button:ToolButton;
        private var lastLanguage:String = "";
        private var reviewButton:ToolButton;
        private var reviewLoader:Loader;
        private var reviewModule:Object;

        public function EditorTools() {}

        public function init(editor:Object):void {
            host=editor;
            view=host.ToolsContext().view;
            labels=new MapLabels(host);
            button=new ToolButton("预渲染",116,30);
            button.x=view.butCheck.x+view.butCheck.width+20;
            button.y=view.butCheck.y-8;
            view.addChild(button);
            button.addEventListener(MouseEvent.CLICK,openPreview);
            preview=new PreviewPanel(host);
            reviewButton=new ToolButton("随机房审查",126,30);
            reviewButton.name="RandomRooms_ReviewEntry";
            reviewButton.x=button.x+126;reviewButton.y=button.y;
            view.addChild(reviewButton);
            reviewButton.addEventListener(MouseEvent.CLICK,openReview);
            timer=new Timer(220);
            timer.addEventListener(TimerEvent.TIMER,tick);
            timer.start();
            view.addEventListener(MouseEvent.MOUSE_UP,artChanged,true);
            view.addEventListener(Event.REMOVED_FROM_STAGE,dispose);
            tick();
        }

        private function tick(event:Event=null):void {
            var context:Object=host.ToolsContext();
            if (lastLanguage!=String(context.language)) {
                lastLanguage=String(context.language);
                button.label=host.ToolsText("editorPreRender","预渲染");
            }
            if (!preview.isOpen && !(reviewModule && reviewModule.isOpen)) labels.update(context);
            button.enabled=context.active;
            reviewButton.enabled=context.active && (reviewLoader==null || reviewModule!=null);
        }
        private function openReview(event:MouseEvent):void {
            if(preview.isOpen) preview.close();
            if(reviewModule) { reviewModule.open();return; }
            if(reviewLoader) return;
            reviewLoader=new Loader();
            reviewLoader.contentLoaderInfo.addEventListener(Event.COMPLETE,function(e:Event):void {
                reviewModule=reviewLoader.content;reviewModule.init(host);reviewModule.open();
            });
            reviewLoader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR,reviewFailed);
            reviewLoader.contentLoaderInfo.addEventListener(SecurityErrorEvent.SECURITY_ERROR,reviewFailed);
            reviewLoader.load(new URLRequest(File.applicationDirectory.resolvePath("mods/RandomRooms/release/RandomRoomsEditor.swf").url),new LoaderContext(false,new ApplicationDomain(null)));
        }
        private function reviewFailed(event:ErrorEvent):void {
            reviewLoader=null;view.objInfo.text="随机房审查加载失败："+event.text;view.objInfo.visible=true;
        }
        private function artChanged(event:Event):void { labels.invalidate(); }
        private function openPreview(event:MouseEvent):void {
            preview.open();
        }
        private function dispose(event:Event):void {
            timer.stop();
            view.removeEventListener(MouseEvent.MOUSE_UP,artChanged,true);
            labels.dispose();
            preview.dispose();
            if(reviewModule) reviewModule.dispose();
        }
        public function get diagnostics():Object { return labels.diagnostics; }

        public static function log(name:String, value:Object):void {
            try {
                var f:File=new File(File.applicationDirectory.resolvePath("Editor/logs/"+name+".json").nativePath);
                f.parent.createDirectory();
                var stream:FileStream=new FileStream();
                stream.open(f,FileMode.WRITE);
                stream.writeUTFBytes(JSON.stringify(value,null,2));
                stream.close();
            } catch (error:Error) { trace(error.message); }
        }
    }
}
