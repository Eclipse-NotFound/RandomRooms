package {
    import flash.desktop.NativeApplication;
    import flash.display.*;
    import flash.events.*;
    import flash.filesystem.*;
    import flash.net.URLRequest;
    import flash.system.*;
    import flash.utils.*;
    /** Loads exact production candidates through the original editor loader. */
    public class EditorRuntimeProbe extends Sprite {
        private var loader:Loader=new Loader(),editor:Object,view:MovieClip,controller:Object,surface:Sprite;
        private var poll:Timer=new Timer(100),started:int,phase:int=0;
        private var report:Object={status:"running",cases:[],checks:[]};
        public function EditorRuntimeProbe() {
            loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void { e.preventDefault();fail(e.error); });
            addChild(loader);loader.contentLoaderInfo.addEventListener(Event.COMPLETE,function(e:Event):void { editor=loader.content["ed"]; });
            loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR,function(e:Event):void { fail(e); });
            loader.load(new URLRequest(File.applicationDirectory.resolvePath("Editor.swf").url),new LoaderContext(false,new ApplicationDomain(null)));
            started=getTimer();poll.addEventListener(TimerEvent.TIMER,tick);poll.start();
        }
        private function read(path:String):String { var s:FileStream=new FileStream();s.open(File.applicationDirectory.resolvePath(path),FileMode.READ);var text:String=s.readUTFBytes(s.bytesAvailable);s.close();return text; }
        private function write(path:String,data:*):void {
            var f:File=new File(File.applicationDirectory.nativePath).parent.resolvePath(path);f.parent.createDirectory();
            var s:FileStream=new FileStream();s.open(f,FileMode.WRITE);if(data is ByteArray) s.writeBytes(data);else s.writeUTFBytes(data is String?data:JSON.stringify(data,null,2));s.close();
        }
        private function require(ok:Boolean,msg:String):void { if(!ok) throw new Error(msg); }
        private function same(a:ByteArray,b:ByteArray):Boolean { if(a.length!=b.length) return false;for(var i:int=0;i<a.length;i++) if(a[i]!=b[i]) return false;return true; }
        private function click(name:String):void {
            var b:DisplayObject=surface.getChildByName("rr-review-"+name);require(b!=null,"Missing button "+name);b.dispatchEvent(new MouseEvent(MouseEvent.CLICK,true));
        }
        private function tick(e:Event):void {
            try {
                if(getTimer()-started>65000) throw new Error("Editor probe timeout at "+phase);
                if(!editor || !editor.ToolsContext().active) return;
                view=editor.ToolsContext().view;
                if(phase==0) {
                    var entry:DisplayObject=view.getChildByName("RandomRooms_ReviewEntry");if(!entry) return;
                    report.entryBounds={x:entry.x,y:entry.y,width:entry.width,height:entry.height};
                    require(entry.x>=0 && entry.x+entry.width<=1800,"Review entry off screen");
                    entry.dispatchEvent(new MouseEvent(MouseEvent.CLICK,true));phase=1;return;
                }
                if(phase==1) {
                    surface=view.getChildByName("RandomRooms_EditorReview") as Sprite;if(!surface) return;
                    controller=Object(surface).controller;if(!controller.diagnostics.render.room) return;
                    phase=2;poll.stop();runCases();
                }
            } catch(error:Error) { fail(error); }
        }
        private function runCases():void {
            var workingBefore:String=editor.ToolsSnapshot().room.toXMLString();
            for each(var scene:String in ["plant","stable","sewer","mane"]) {
                var name:String="samples/"+scene+".xml",before:String=read(name),xml:XML=new XML(before);
                controller.openFile(File.applicationDirectory.resolvePath(name));
                var d:Object=controller.diagnostics;
                require(d.rooms==xml.room.length() && d.render.region=="random_"+scene,"Wrong review region or room count");
                require(d.render.simulationUnits==0 && d.render.warnings.length==0,"Native renderer simulates or warns");
                var selected:XML;
                for each(var r:XML in xml.room) if(r.@name==d.room) selected=r;
                require(selected!=null && d.render.mirror==(selected.@rrMirror=="1"),"Mirror lost");
                require(d.render.enemyType==int(selected.@rrEcology) && d.render.difficulty==int(selected.@rrDifficulty),"Ecology or difficulty lost");
                require(d.overlay.points==selected.rrPlan.point.length(),"Missing content points");
                var original:ByteArray=controller.imageBytes();
                for each(var key:String in ["spaces","points","tactics","ports"]) { click(key);click(key); }
                require(same(original,controller.imageBytes()),"Overlay toggles rerolled native image");
                write("native/"+scene+".png",original);
                var shot:BitmapData=new BitmapData(1800,950,false,0x101B25);shot.draw(surface);write("native/"+scene+"-panel.png",PngWriter.encode(shot));shot.dispose();
                var roomBefore:String=d.room;click("next");require(controller.diagnostics.room!=roomBefore,"Next room failed");click("previous");require(controller.diagnostics.room==roomBefore,"Previous room failed");
                require(read(name)==before,"Review changed source file");
                report.cases.push(d);write("results.json",report);
            }
            require(editor.ToolsSnapshot().room.toXMLString()==workingBefore,"Read-only review modified editor working document");
            report.checks.push("actual bridge click","four native scenes","mirror ecology difficulty","complete metadata","fixed image during overlay toggles","next previous navigation","source and editor document unchanged");
            // Native editor draft decoding/encoding; source snapshot remains frozen.
            var source:XML=new XML(read("samples/mane.xml")),selectedRoom:XML;
            for each(r in source.room) if(r.@name==controller.diagnostics.room) selectedRoom=r.copy();
            var row:int=2,cols:Array=String(selectedRoom.a[row]).split(".");
            for(var col:int=2;col<46;col++) if(String(cols[col]).charAt(0)=="_") { cols[col]=String(cols[col]).indexOf("_C")==0?"_D":"_C";break; }
            selectedRoom.a[row]=<a>{cols.join(".")}</a>;
            var draft:XML=<all><land serial="1"/></all>;draft.appendChild(selectedRoom);
            editor.allroom=draft;editor.decodeAll();editor.ed.roomsList.dispatchEvent(new Event(Event.CHANGE));
            click("draft");require(controller.diagnostics.draft && controller.diagnostics.overlay.diffCells==1,"Draft comparison failed");
            write("native/draft.png",controller.imageBytes());click("base");require(!controller.diagnostics.draft,"Baseline toggle failed");
            var latest:String=read("samples/mane.xml");require(latest==source.toXMLString() || new XML(latest).toXMLString()==source.toXMLString(),"Draft wrote source");
            report.checks.push("native draft encode / one changed cell / baseline toggle");
            stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,true,0,27));require(!controller.isOpen,"Escape did not close review");
            view.getChildByName("RandomRooms_ReviewEntry").dispatchEvent(new MouseEvent(MouseEvent.CLICK,true));require(controller.isOpen,"Review cannot reopen");
            click("close");require(!controller.isOpen,"Return did not close");report.checks.push("Escape / reopen / return");
            report.status="passed";write("results.json",report);NativeApplication.nativeApplication.exit(0);
        }
        private function fail(error:*):void { poll.stop();report.status="failed";report.error=String(error);if(error is Error) report.stack=error.getStackTrace();write("results.json",report);NativeApplication.nativeApplication.exit(1); }
    }
}
