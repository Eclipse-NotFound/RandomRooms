package {
    import flash.desktop.NativeApplication;
    import flash.display.*;
    import flash.events.*;
    import flash.filesystem.*;
    import flash.utils.*;
    public class RenderSamples extends Sprite {
        private var renderer:RRReviewRenderer=new RRReviewRenderer();
        private var cases:Array,index:int=0,results:Array=[];
        private var folder:File=new File(File.applicationDirectory.nativePath);
        public function RenderSamples() {
            cases=JSON.parse(read("cases.json")) as Array;
            loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void { e.preventDefault(); fail(e.error); });
            renderer.load(next,fail);
        }
        private function read(name:String):String { var s:FileStream=new FileStream();s.open(folder.resolvePath(name),FileMode.READ);var v:String=s.readUTFBytes(s.bytesAvailable);s.close();return v; }
        private function write(name:String,data:*):void { var f:File=folder.resolvePath(name);f.parent.createDirectory();var s:FileStream=new FileStream();s.open(f,FileMode.WRITE);if(data is ByteArray)s.writeBytes(data);else s.writeUTFBytes(JSON.stringify(data,null,2));s.close(); }
        private function next():void {
            try {
                if(index>=cases.length) { write("results.json",{status:"passed",renders:results});renderer.dispose();NativeApplication.nativeApplication.exit(0);return; }
                var c:Object=cases[index++],pool:XML=new XML(read(c.sample)),room:XML=pool.room[0],before:String=pool.toXMLString();
                var bmp:BitmapData=renderer.render({room:room,land:null,filename:c.sample,roomNames:[String(room.@name)]},c.region,true,false,true,false,c.difficulty);
                if(renderer.report.warnings.length || renderer.report.simulationUnits!=0 || before!=pool.toXMLString()) throw new Error("Native render contract "+c.id);
                write("images/"+c.id+".png",PngWriter.encode(bmp));bmp.dispose();
                results.push({id:c.id,report:JSON.parse(JSON.stringify(renderer.report))});write("progress.json",{count:index});setTimeout(next,20);
            } catch(e:Error) { fail(e); }
        }
        private function fail(e:*):void { write("results.json",{status:"failed",error:String(e),renders:results});NativeApplication.nativeApplication.exit(1); }
    }
}
