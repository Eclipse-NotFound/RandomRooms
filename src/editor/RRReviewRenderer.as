package {
    import flash.display.*;
    import flash.events.*;
    import flash.filesystem.*;
    import flash.geom.*;
    import flash.net.URLRequest;
    import flash.system.*;
    import flash.utils.Timer;
    import flash.utils.getTimer;
    import fe.loc.EditorPreviewProfile;

    public class RRReviewRenderer {
        private var loader:Loader=new Loader();
        private var domain:ApplicationDomain;
        private var world:Object;
        private var graph:Object;
        private var timer:Timer;
        private var done:Function;
        private var failed:Function;
        private var started:int;
        private var cachedRegionFiles:Object={};
        public var ready:Boolean=false;
        public var regions:Array=[];
        public var scene:Sprite=new Sprite();
        public var report:Object={};
        public var entityLayer:NativeEntities;
        private var zh:XML;
        private var bg:MovieClip=new MovieClip();
        private var drawing:Sprite=new Sprite();

        public function RRReviewRenderer() { scene.addChild(bg); scene.addChild(drawing); }
        public function load(onReady:Function,onError:Function):void {
            if(ready) { onReady(); return; }
            done=onReady; failed=onError;
            loader.contentLoaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
                e.preventDefault(); failed(e.error is Error ? e.error : new Error(String(e.error)));
            });
            loader.contentLoaderInfo.addEventListener(Event.COMPLETE,loaded);
            loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR,loadError);
            loader.contentLoaderInfo.addEventListener(SecurityErrorEvent.SECURITY_ERROR,loadError);
            loader.load(new URLRequest(File.applicationDirectory.resolvePath("Editor/Enhancements/NativeScene.swf").url),
                new LoaderContext(false,new ApplicationDomain(null)));
        }
        private function readXML(file:File):XML {
            var stream:FileStream=new FileStream();
            stream.open(file,FileMode.READ);
            var result:XML=new XML(stream.readUTFBytes(stream.bytesAvailable));
            stream.close();
            return result;
        }
        private function definition(name:String):Class { return domain.getDefinition(name) as Class; }
        private function loaded(event:Event):void {
            try {
                domain=loader.contentLoaderInfo.applicationDomain;
                var World:Class=definition("fe.World");
                var Graph:Class=definition("fe.graph.Grafon");
                var Game:Class=definition("fe.loc.Game");
                var Pers:Class=definition("fe.unit.Pers");
                world=new World(new Sprite(),{});
                var Form:Class=definition("fe.loc.Form");
                Form["setForms"]();
                var Tile:Class=definition("fe.loc.Tile");
                Tile.tileX=40; Tile.tileY=40;
                world.playerMode="Desktop";
                world.black=false;
                world.landData=[];
                world.game=new Game();
                world.pers=new Pers();
                world.visual=drawing;
                world.vfon=bg;
                var urls:Array=[];
                for each(var asset:String in ["texture.swf","texture1.swf","sprite.swf","sprite1.swf"])
                    urls.push(File.applicationDirectory.resolvePath(asset).url);
                Graph.texUrl=urls;
                graph=new Graph(drawing);
                world.grafon=graph;
                zh=readXML(File.applicationDirectory.resolvePath("text_zh.xml"));
                var Res:Class=definition("fe.Res");
                Res.d=zh; Res.e=zh;
                var Emitter:Class=definition("fe.graph.Emitter");
                Emitter["init"]();
                var Data:Class=definition("fe.GameData");
                for each(var land:XML in Data.d.land) {
                    if(!land.@file.length()) continue;
                    var id:String=String(land.@id);
                    var title:String=id;
                    var translated:XMLList=zh.map.(@id==id);
                    if(translated.length() && translated.n.length()) title=translated.n[0].toString();
                    regions.push({id:id,label:title,xml:land.copy()});
                }
                started=getTimer();
                timer=new Timer(80);
                timer.addEventListener(TimerEvent.TIMER,poll);
                timer.start();
            } catch(error:Error) { failed(error); }
        }
        private function loadError(event:ErrorEvent):void { failed(new Error(event.text)); }
        private function poll(event:Event):void {
            if(graph.resIsLoad) { timer.stop(); ready=true; done(); }
            else if(getTimer()-started>30000) { timer.stop(); failed(new Error("游戏素材加载超时，请检查 texture / sprite 文件。")); }
        }

        public function infer(snapshot:Object):String {
            if(snapshot.land && XML(snapshot.land).@id.length()) {
                var landId:String=String(XML(snapshot.land).@id);
                for each(var candidate:Object in regions) if(candidate.id==landId) return landId;
            }
            var best:String="random_plant",bestScore:Number=0;
            for each(var region:Object in regions) {
                var xml:XML=region.xml;
                var fileName:String=String(xml.@file);
                if(String(snapshot.filename).indexOf(fileName)>=0) return region.id;
                try {
                    if(!cachedRegionFiles.hasOwnProperty(fileName)) {
                        var names:Object={};
                        var data:XML=readXML(File.applicationDirectory.resolvePath("Rooms/"+fileName+".xml"));
                        for each(var room:XML in data.room) names[String(room.@name)]=true;
                        cachedRegionFiles[fileName]=names;
                    }
                    var hits:int=0;
                    for each(var name:String in snapshot.roomNames) if(cachedRegionFiles[fileName][name]) hits++;
                    if(hits>bestScore) { best=region.id; bestScore=hits; }
                } catch(error:Error) { /* A region can use a script-provided room set. */ }
            }
            return best;
        }
        public function labelFor(id:String):String {
            for each(var region:Object in regions) if(region.id==id) return region.label;
            return id;
        }

        public function entityCatalog():Array {
            var All:Class=definition("fe.AllData");
            var ids:Array=[];
            for each(var def:XML in All.d.obj) if(String(def.@tip)=="unit") ids.push(String(def.@id));
            return ids;
        }

        public function render(snapshot:Object,regionId:String,objects:Boolean=true,mirror:Boolean=false,entities:Boolean=true,examples:Boolean=true,difficulty:int=-1):BitmapData {
            if(!ready) throw new Error("绘图组件尚未就绪。");
            var before:int=getTimer();
            var regionXML:XML;
            for each(var region:Object in regions) if(region.id==regionId) regionXML=XML(region.xml).copy();
            if(!regionXML) throw new Error("未找到地区："+regionId);
            // An authored land node can override the selected environment's defaults.
            if(snapshot.land) {
                var authored:XML=XML(snapshot.land);
                if(authored.options.length()) {
                    if(!regionXML.options.length()) regionXML.appendChild(<options/>);
                    for each(var attr:XML in authored.options[0].attributes()) regionXML.options[0].@[attr.name()]=attr;
                }
            }
            var LandAct:Class=definition("fe.loc.LandAct");
            var Land:Class=definition("fe.loc.Land");
            var Location:Class=definition("fe.loc.Location");
            var Box:Class=definition("fe.loc.Box");
            var Trap:Class=definition("fe.loc.Trap");
            var All:Class=definition("fe.AllData");
            var act:Object=new LandAct(regionXML);
            var land:Object=new Land(null,act,1);
            // Constructor is deliberately stopped before procedural map generation.
            land.rnd=false;
            land.itemScripts=[];
            var roomXML:XML=XML(snapshot.room).copy();
            var loc:Object=new Location(land,roomXML,false,{mirror:mirror,water:null,ramka:null,backform:0,transpFon:String(roomXML.@rrTheme)=="mane"});
            land.loc=loc; world.loc=loc; world.land=land;
            EditorPreviewProfile.apply(land,loc,difficulty);
            if(roomXML.@rrEcology.length()) loc.tipEnemy=int(roomXML.@rrEcology);
            loc.active=true;
            var nativeObjects:Array=[];
            var warnings:Array=[];
            var spawns:int=0;
            var triggers:int=0;
            var rendered:int=0;
            entityLayer=new NativeEntities(domain,graph,loc);
            var node:XML;
            for each(node in roomXML.obj) {
                var id:String=String(node.@id);
                var defs:XMLList=All.d.obj.(@id==id);
                if(!defs.length()) { warnings.push(id+"：游戏数据中没有此物体"); continue; }
                var def:XML=defs[0];
                var type:String=String(def.@tip);
                if(type=="spawnpoint") { spawns++; continue; }
                if(type=="unit" || type=="up" || type=="enspawn") {
                    spawns++;
                    if(entities) entityLayer.add(node,def,examples);
                    continue;
                }
                if(!objects) continue;
                var size:int=Math.max(1,int(def.@size));
                var nx:int=int(node.@x);
                var ny:int=int(node.@y);
                if(mirror) nx=48-nx-size;
                if(type=="box" || type=="door") {
                    var copy:XML=node.copy();
                    // Do not run story/event scripts in a static design preview.
                    delete copy.scr;
                    for each(var key:String in ["scr","scropen","scrclose","scrtouch","scrdie","fun"])
                        delete copy.@[key];
                    try {
                        var box:Object=new Box(loc,id,(nx+size*0.5)*40,(ny+1)*40-1,copy,null);
                        nativeObjects.push(box); rendered++;
                    } catch(error:Error) { warnings.push(id+"："+error.message); }
                } else if(type=="trap") {
                    try {
                        nativeObjects.push(new Trap(loc,id,(nx+size*0.5)*40,(ny+1)*40-1));
                        rendered++;
                    } catch(trapError:Error) { warnings.push(id+"："+trapError.message); }
                } else if(type=="area") {
                    triggers++;
                } else if(type=="spawnpoint" || type=="up" || type=="enspawn" || type=="unit") {
                    spawns++;
                } else {
                    // Use the native graphic for remaining simple visual markers.
                    var visual:MovieClip=graph.getObj("vis"+id,1) as MovieClip;
                    if(visual) {
                        visual.stop(); visual.x=(nx+size*0.5)*40; visual.y=(ny+1)*40-1;
                        nativeObjects.push({visual:visual}); rendered++;
                    } else warnings.push(id+"：仅在运行时生成");
                }
            }
            graph.drawFon(bg,act.fon);
            graph.setFonSize(1920,1000);
            graph.drawLoc(loc);
            // Exploration fog is intentionally hidden: the designer can inspect the whole room.
            graph.visLight.visible=false;
            // Camera normally flips these edge masks outward. A full-room image
            // is already clipped to the room bounds and does not need camera masks.
            graph.ramT.visible=graph.ramB.visible=graph.ramL.visible=graph.ramR.visible=false;
            for each(var object:Object in nativeObjects) {
                if(object.hasOwnProperty("visual")) graph.visObjs[1].addChild(object.visual);
                else object.addVisual();
            }
            entityLayer.attach();
            warnings=warnings.concat(entityLayer.warnings);
            var image:BitmapData=new BitmapData(1920,1000,false,0x15191D);
            image.draw(scene,null,null,null,image.rect,true);
            report={room:String(roomXML.@name),region:regionId,regionName:labelFor(regionId),
                milliseconds:getTimer()-before,objects:rendered,spawnMarkers:spawns,invisibleTriggers:triggers,
                warnings:warnings,mirror:mirror,renderSize:[1920,1000],nativeRenderer:true,
                entities:entityLayer.fixedCount,examples:entityLayer.exampleCount,emptyPoints:entityLayer.emptyPoints,
                entityDetails:entityLayer.summary(),difficulty:loc.locDifLevel,enemyLevel:loc.enemyLevel,
                biome:loc.biom,enemyType:loc.tipEnemy,transpFon:loc.transpFon,simulationUnits:loc.units.length,
                mode:"static native entities; random points are examples; no simulation, scripts or discovery fog"};
            // Review rendering never writes into the editor working document.
            return image;
        }
        public function dispose():void {
            if(timer) timer.stop();
            try { loader.unloadAndStop(true); } catch(error:Error) {}
        }
    }
}
