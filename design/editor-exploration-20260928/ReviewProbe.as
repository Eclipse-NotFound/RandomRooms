package {
    import flash.desktop.NativeApplication;
    import flash.display.*;
    import flash.events.*;
    import flash.filesystem.*;
    import flash.net.URLRequest;
    import flash.system.*;
    import flash.utils.*;

    /** Isolated experiment. The installed editor is loaded unchanged in its own
     * application domain. Only in-memory XML is encoded; never invokes Save. */
    public class ReviewProbe extends Sprite {
        private var editorLoader:Loader=new Loader();
        private var editor:Object;
        private var renderer:RRReviewRenderer;
        private var cases:Array;
        private var results:Object={status:"running",roundtrip:[],render:[]};
        private var poll:Timer=new Timer(100);
        private var started:int;
        private var index:int=0;

        public function ReviewProbe() {
            loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
                e.preventDefault(); fail(e.error);
            });
            try {
                cases=JSON.parse(read("cases.json")) as Array;
                write("progress.json",{stage:"editor-loading"});
                addChild(editorLoader);
                editorLoader.contentLoaderInfo.addEventListener(Event.COMPLETE,editorLoaded);
                editorLoader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR,function(e:Event):void { fail(e); });
                editorLoader.load(new URLRequest(File.applicationDirectory.resolvePath("Editor.swf").url),new LoaderContext(false,new ApplicationDomain(null)));
            } catch(error:Error) { fail(error); }
        }
        private function read(relative:String):String {
            var s:FileStream=new FileStream(); s.open(File.applicationDirectory.resolvePath(relative),FileMode.READ);
            var value:String=s.readUTFBytes(s.bytesAvailable); s.close(); return value;
        }
        private function write(relative:String,value:*):void {
            var f:File=new File(File.applicationDirectory.nativePath).parent.resolvePath(relative);
            f.parent.createDirectory(); var s:FileStream=new FileStream(); s.open(f,FileMode.WRITE);
            if(value is ByteArray) s.writeBytes(value);
            else if(value is String) s.writeUTFBytes(value);
            else s.writeUTFBytes(JSON.stringify(value,null,2));
            s.close();
        }
        private function editorLoaded(e:Event):void {
            try {
                editor=editorLoader.content["ed"];
                if(!editor) throw new Error("Editor instance unavailable");
                started=getTimer(); poll.addEventListener(TimerEvent.TIMER,ready); poll.start();
            } catch(error:Error) { fail(error); }
        }
        private function ready(e:Event):void {
            try {
                if(!editor.ToolsContext().active) {
                    if(getTimer()-started>15000) throw new Error("Editor initialization timeout");
                    return;
                }
                poll.stop();
                write("progress.json",{stage:"actual-editor-encode"});
                for each(var test:Object in cases) roundtrip(test);
                write("results.json",results);
                editorLoader.unloadAndStop(true); removeChild(editorLoader);
                renderer=new RRReviewRenderer(); renderer.load(renderNext,fail);
            } catch(error:Error) { fail(error); }
        }
        private function roundtrip(test:Object):void {
            var pool:XML=new XML(read(test.sample));
            var baseline:String=pool.toXMLString();
            editor.allroom=pool.copy(); editor.decodeAll();
            var original:XML=pool.room[0];
            // ToolsSnapshot itself re-encodes; this reproduces the preview data
            // boundary without pressing GUI buttons or touching disk Save.
            var snapshot:Object=editor.ToolsSnapshot();
            var immediate:XML=snapshot.room;
            write("roundtrip/"+test.theme+"-immediate.xml",immediate.toXMLString());
            // Re-select through the editor's actual CHANGE listener. Loading a
            // one-room serial file without (0,0) leaves cmapX/Y at zero until it.
            editor.ed.roomsList.dispatchEvent(new Event(Event.CHANGE));
            snapshot=editor.ToolsSnapshot();
            var encoded:XML=snapshot.room;
            write("roundtrip/"+test.theme+"-snapshot.xml",encoded.toXMLString());
            editor.mActive=true; editor.encodeCurrent(); editor.encodeAll();
            var saved:XML=editor.allroom;
            write("roundtrip/"+test.theme+"-encoded-all.xml",saved.toXMLString());
            var loss:Array=[];
            for each(var a:XML in original.attributes()) if(!encoded.@[a.name()].length()) loss.push(String(a.name()));
            var rootLoss:Array=[];
            for each(a in pool.attributes()) if(!saved.@[a.name()].length()) rootLoss.push(String(a.name()));
            results.roundtrip.push({theme:test.theme,room:String(original.@name),
                sourceUnchanged:baseline==pool.toXMLString(),lostRoomAttributes:loss,lostRootAttributes:rootLoss,
                coordinates:{original:[String(original.@x),String(original.@y)],immediate:[String(immediate.@x),String(immediate.@y)],selected:[String(encoded.@x),String(encoded.@y)]},
                planBefore:original.rrPlan.length(),planAfter:encoded.rrPlan.length(),
                doorsBefore:original.doors.length(),doorsAfter:encoded.doors.length(),
                objectsBefore:original.obj.length(),objectsAfter:encoded.obj.length(),
                backsBefore:original.back.length(),backsAfter:encoded.back.length()});
        }
        private function renderNext():void {
            try {
                if(index>=cases.length) {
                    results.status="passed"; results.scope="actual editor public API roundtrip in memory; static native rendering; no GUI Save, AI or gameplay";
                    write("results.json",results); renderer.dispose(); NativeApplication.nativeApplication.exit(0); return;
                }
                var test:Object=cases[index++];
                write("progress.json",{stage:"native-render",theme:test.theme});
                var pool:XML=new XML(read(test.sample));
                var original:XML=pool.room[0]; var baseline:String=pool.toXMLString();
                var snapshot:Object={room:original,land:pool.land[0],filename:test.sample,roomNames:[String(original.@name)]};
                var bitmap:BitmapData=renderer.render(snapshot,test.region,true,test.mirror,true,false,test.difficulty);
                write("previews/"+test.theme+".png",PngWriter.encode(bitmap)); bitmap.dispose();
                var result:Object=JSON.parse(JSON.stringify(renderer.report));
                result.sourceUnchanged=baseline==pool.toXMLString();
                result.expectedEcology=test.ecology;
                result.examplePointsEnabled=false;
                result.staticBodies=[];
                for each(var item:Object in renderer.entityLayer.items)
                    result.staticBodies.push({id:item.id,x:item.x,y:item.y,variant:item.variant,
                        visible:item.unit.vis.visible,alpha:item.unit.vis.alpha,
                        initialAI:item.unit.hasOwnProperty("aiState")?item.unit.aiState:null});
                if(!result.sourceUnchanged || result.enemyType!=test.ecology || result.simulationUnits!=0)
                    throw new Error("Readonly/context assertion failed: "+test.theme);
                if(result.warnings.length) throw new Error("Native render warnings: "+JSON.stringify(result.warnings));
                results.render.push(result); write("results.json",results);
                setTimeout(renderNext,30);
            } catch(error:Error) { fail(error); }
        }
        private function fail(error:*):void {
            poll.stop(); results.status="failed"; results.error=String(error);
            if(error is Error) results.stack=Error(error).getStackTrace();
            write("results.json",results); NativeApplication.nativeApplication.exit(1);
        }
    }
}
