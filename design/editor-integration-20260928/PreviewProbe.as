package {
    import flash.desktop.NativeApplication;
    import flash.display.*;
    import flash.events.*;
    import flash.filesystem.*;
    import flash.net.URLRequest;
    import flash.system.*;
    import flash.utils.*;

    // Independent driver. NativeRenderer and PngWriter are dynamically loaded
    // from a byte-identical copy of the installed EditorTools.swf.
    public class PreviewProbe extends Sprite {
        private var loader:Loader = new Loader();
        private var renderer:Object;
        private var encoder:Class;
        private var reports:Array = [];
        private var timer:Timer = new Timer(55000, 1);

        public function PreviewProbe() {
            write("probe-progress.json", "{\"stage\":\"started\"}");
            loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, function(e:UncaughtErrorEvent):void {
                e.preventDefault(); fail(e.error);
            });
            timer.addEventListener(TimerEvent.TIMER_COMPLETE, function(e:Event):void { fail("probe timeout"); });
            timer.start();
            loader.contentLoaderInfo.addEventListener(Event.COMPLETE, loaded);
            loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, function(e:Event):void { fail(e); });
            loader.load(new URLRequest(File.applicationDirectory.resolvePath("Editor/Enhancements/EditorTools.swf").url),
                new LoaderContext(false, new ApplicationDomain(null)));
        }
        private function textFile(relative:String):String {
            var stream:FileStream = new FileStream();
            stream.open(File.applicationDirectory.resolvePath(relative), FileMode.READ);
            var value:String = stream.readUTFBytes(stream.bytesAvailable);
            stream.close();
            return value;
        }
        private function write(relative:String, value:*):void {
            var file:File = new File(File.applicationDirectory.nativePath).parent.resolvePath(relative);
            file.parent.createDirectory();
            var stream:FileStream = new FileStream();
            stream.open(file, FileMode.WRITE);
            if (value is ByteArray) stream.writeBytes(value);
            else stream.writeUTFBytes(String(value));
            stream.close();
        }
        private function loaded(e:Event):void {
            try {
                write("probe-progress.json", "{\"stage\":\"helper-loaded\"}");
                var domain:ApplicationDomain = loader.contentLoaderInfo.applicationDomain;
                var Renderer:Class = domain.getDefinition("NativeRenderer") as Class;
                encoder = domain.getDefinition("PngWriter") as Class;
                renderer = new Renderer();
                renderer.load(run, fail);
            } catch (error:Error) { fail(error); }
        }
        private function run():void {
            try {
                var cases:Array = JSON.parse(textFile("cases.json")) as Array;
                for each (var test:Object in cases) {
                    write("probe-progress.json", JSON.stringify({stage:"render-start", theme:test.theme}));
                    var pool:XML = new XML(textFile(test.filename));
                    var room:XML = pool.room[0].copy();
                    var before:String = room.toXMLString();
                    var snapshot:Object = {room:room, land:pool.land[0].copy(), filename:test.filename,
                        roomNames:[String(room.@name)]};
                    var inferred:String = renderer.infer(snapshot);
                    var bitmap:BitmapData = renderer.render(snapshot, test.region, true, test.mirror);
                    write("probe-progress.json", JSON.stringify({stage:"encode-start", theme:test.theme}));
                    write("previews/" + test.theme + ".png", encoder["encode"](bitmap));
                    write("probe-progress.json", JSON.stringify({stage:"encode-done", theme:test.theme}));
                    bitmap.dispose();
                    var result:Object = JSON.parse(JSON.stringify(renderer.report));
                    result.inferredFromNamedSample = inferred;
                    result.inputUnchanged = before == room.toXMLString();
                    result.sample = test.filename;
                    // Archived generic filenames lack the native rooms_* token.
                    snapshot.filename = "rrstyle-navigation-" + test.theme + "-pool";
                    result.inferredFromOriginalName = renderer.infer(snapshot);
                    reports.push(result);
                    write("preview-results.json", JSON.stringify({status:"running", results:reports}, null, 2));
                }
                write("preview-results.json", JSON.stringify({status:"passed", results:reports,
                    scope:"unchanged installed renderer; archived XML; isolated hidden AIR; no editor save, AI or gameplay"}, null, 2));
                renderer.dispose();
                timer.stop();
                NativeApplication.nativeApplication.exit(0);
            } catch (error:Error) { fail(error); }
        }
        private function fail(error:*):void {
            write("preview-results.json", JSON.stringify({status:"failed", error:String(error), results:reports}, null, 2));
            timer.stop();
            NativeApplication.nativeApplication.exit(1);
        }
    }
}
