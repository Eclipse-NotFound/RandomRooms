package {
    import flash.display.*;
    import flash.events.*;
    import flash.filesystem.*;
    import flash.net.FileFilter;
    import flash.net.FileReference;
    import flash.geom.*;
    import flash.text.*;
    import flash.utils.ByteArray;
    import rr.RRReviewExport;

    /** Complete source XML remains separate from native editor encoding.
     * Draft comparison is diagnostic only: it never replaces a generated map. */
    public class RRReviewPanel {
        private var host:Object,view:MovieClip;
        public var panel:Sprite;
        private var viewport:Sprite=new Sprite(),content:Sprite=new Sprite(),bitmap:Bitmap=new Bitmap();
        private var overlay:RRPlanOverlay=new RRPlanOverlay(),map:Sprite=new Sprite();
        private var renderer:RRReviewRenderer=new RRReviewRenderer();
        private var status:TextField,details:TextField,title:TextField;
        private var pool:XML,room:XML,draft:XML;
        private var sourcePath:String="",sourceCRC:String="";
        private var pixels:BitmapData,draftPixels:BitmapData;
        private var loading:Boolean=false,showDraft:Boolean=false;
        private var file:File;
        private var flags:Object={spaces:true,points:true,tactics:true,ports:true};
        private var buttons:Object={};
        private var zoom:Number=1,dragPoint:Point,dragOrigin:Point;
        public var isOpen:Boolean=false;
        private static const VW:Number=1400,VH:Number=730;
        public function RRReviewPanel(editor:Object) {
            host=editor; view=host.ToolsContext().view;
            panel=new RRReviewSurface(this);
            panel.name="RandomRooms_EditorReview"; panel.x=20; panel.y=20;
            panel.graphics.beginFill(0x101B25,0.995); panel.graphics.drawRect(-20,-20,1800,950); panel.graphics.endFill();
            title=text("随机房审查 · v13.1",0,0,1740,32,22,0xE8EEF1);
            button("latest","读取最新导出",0,43,124,function():void { openFile(File.applicationDirectory.resolvePath("mods/RandomRooms/exports/review/latest.xml")); });
            button("file","选择快照…",134,43,115,chooseFile);
            button("previous","上一间",263,43,85,function():void { step(-1); });
            button("next","下一间",356,43,85,function():void { step(1); });
            button("left","← 邻房",455,43,83,function():void { neighbour(-1,0); });
            button("right","邻房 →",546,43,83,function():void { neighbour(1,0); });
            button("up","↑ 邻房",637,43,83,function():void { neighbour(0,-1); });
            button("down","↓ 邻房",728,43,83,function():void { neighbour(0,1); });
            button("fit","适合窗口",827,43,95,function():void { changeZoom(1); });
            button("minus","−",930,43,40,function():void { changeZoom(zoom/1.3); });
            button("plus","＋",978,43,40,function():void { changeZoom(zoom*1.3); });
            button("png","导出当前图…",1032,43,125,savePNG);
            button("draft","读取编辑稿对照",1171,43,145,compareDraft);
            button("base","显示：原始生成",1324,43,145,function():void { if(draftPixels) { showDraft=!showDraft; updateImage(); } });
            button("close","返回编辑器",1595,43,145,close);
            toggle("spaces","用途 / D·V",0); toggle("points","物体生成点",145); toggle("tactics","布防与接近路",290); toggle("ports","相邻接口",435);
            text("紫虚线＝炮塔防守意图　青虚线＝终端候选接近路　蓝接口＝邻房匹配　橙接口＝未配对 / 尚未扩张",595,83,1145,30,14,0x9EB7C7);
            viewport.y=120; viewport.graphics.beginFill(0x071017); viewport.graphics.drawRect(0,0,VW,VH); viewport.graphics.endFill();
            viewport.scrollRect=new Rectangle(0,0,VW,VH); viewport.addChild(content); content.addChild(bitmap); content.addChild(overlay); panel.addChild(viewport);
            viewport.addEventListener(MouseEvent.MOUSE_WHEEL,wheel); viewport.addEventListener(MouseEvent.MOUSE_DOWN,beginDrag);
            overlay.selected=selectPoint;
            map.x=1420; map.y=120; panel.addChild(map);
            details=text("游戏中按 Shift+F5 导出当前地图。\n这里保留完整生成信息，点击物体标记可查看用途与挂装位置。",1420,390,320,430,15,0xCBDFE8);
            details.wordWrap=true; details.multiline=true;
            status=text("等待导出。",0,859,1735,48,14,0xAEC2CE); status.wordWrap=true; status.multiline=true;
            for each(var type:String in [MouseEvent.MOUSE_DOWN,MouseEvent.MOUSE_UP,MouseEvent.MOUSE_MOVE,MouseEvent.CLICK,MouseEvent.DOUBLE_CLICK,MouseEvent.MOUSE_WHEEL])
                panel.addEventListener(type,function(e:Event):void { e.stopPropagation(); });
        }
        private function text(value:String,x:Number,y:Number,w:Number,h:Number,size:int,color:uint):TextField {
            var t:TextField=new TextField(); t.defaultTextFormat=new TextFormat("Microsoft YaHei UI",size,color);
            t.x=x;t.y=y;t.width=w;t.height=h;t.text=value;t.selectable=false;panel.addChild(t);return t;
        }
        private function button(id:String,label:String,x:Number,y:Number,w:Number,action:Function):void {
            var b:ToolButton=new ToolButton(label,w,30); b.name="rr-review-"+id;b.x=x;b.y=y;panel.addChild(b);buttons[id]=b;
            b.addEventListener(MouseEvent.CLICK,function(e:Event):void { try { action(); } catch(error:Error) { fail(error); } });
        }
        private function toggle(id:String,label:String,x:Number):void {
            button(id,"✓ "+label,x,81,135,function():void { flags[id]=!flags[id]; buttons[id].label=(flags[id]?"✓ ":"○ ")+label; redraw(); });
        }
        public function open():void {
            if(isOpen) return; isOpen=true; view.addChild(panel);
            view.stage.addEventListener(KeyboardEvent.KEY_DOWN,key,true,1000); view.stage.focus=panel;
            if(!loading) { loading=true; renderer.load(function():void { if(room) renderRoom(); },fail); }
            if(!pool) {
                var latest:File=File.applicationDirectory.resolvePath("mods/RandomRooms/exports/review/latest.xml");
                if(latest.exists) openFile(latest); else status.text="尚无快照：先进入游戏随机房，按 Shift+F5；然后点击“读取最新导出”。";
            }
        }
        private function key(e:KeyboardEvent):void { if(!isOpen) return; e.stopImmediatePropagation(); if(e.keyCode==27) close(); }
        private function chooseFile():void {
            file=File.applicationDirectory.resolvePath("mods/RandomRooms/exports/review");
            file.addEventListener(Event.SELECT,function(e:Event):void { try { openFile(file); } catch(error:Error) { fail(error); } });
            file.browseForOpen("选择完整随机房快照",[new FileFilter("随机房 XML","*.xml")]);
        }
        public function openFile(source:File):void {
            if(!source.exists) throw new Error("尚无导出，请在游戏随机房中按 Shift+F5。");
            if(source.size>32*1024*1024) throw new Error("快照超过 32 MB，请使用较小的探索地图。");
            var stream:FileStream=new FileStream(),xml:XML;
            try { stream.open(source,FileMode.READ);xml=new XML(stream.readUTFBytes(stream.bytesAvailable)); } finally { stream.close(); }
            if(xml.name()!="all" || !xml.room.length() || xml.room.length()>4096) throw new Error("不是完整的随机房地图。");
            var coords:Object={};
            for each(var r:XML in xml.room) {
                if(!r.@rrTheme.length() || r.a.length()!=25 || !r.@x.length() || !r.@y.length()) throw new Error("快照缺少场景、坐标或完整格网。");
                if(["plant","stable","sewer","mane"].indexOf(String(r.@rrTheme))<0) throw new Error("快照场景不受支持。");
                for each(var a:XML in r.a) if(String(a).split(".").length!=48) throw new Error("房间不是 48 × 25 格。");
                var ck:String=r.@x+","+r.@y; if(coords[ck]) throw new Error("地图坐标重复。"); coords[ck]=true;
            }
            var original:XML=xml.copy(); delete original.rrReview;
            var checksum:String=RRReviewExport.crc(original.toXMLString());
            if(xml.rrReview.length() && (xml.rrReview.@schema!="1" || xml.rrReview.@sourceCRC32!=checksum)) throw new Error("快照校验不一致；请重新从游戏导出。编辑稿请用“读取编辑稿对照”。");
            pool=xml;sourcePath=source.nativePath;sourceCRC=checksum;
            selectRoom(xml.rrReview.length()?int(xml.rrReview.@selectedX):int(xml.room[0].@x),xml.rrReview.length()?int(xml.rrReview.@selectedY):int(xml.room[0].@y));
        }
        public function selectRoom(x:int,y:int):void {
            if(!pool) return;
            for each(var r:XML in pool.room) if(int(r.@x)==x && int(r.@y)==y) {
                room=r; draft=null;showDraft=false;if(draftPixels) { draftPixels.dispose();draftPixels=null; }
                if(renderer.ready) renderRoom(); else status.text="正在加载原版画面组件…";
                drawMap(); return;
            }
            status.text="该方向尚未生成合成房。";
        }
        private function step(amount:int):void {
            if(!room) return; var rooms:XMLList=pool.room;
            for(var i:int=0;i<rooms.length();i++) if(rooms[i]===room) { var n:int=(i+amount+rooms.length())%rooms.length();selectRoom(int(rooms[n].@x),int(rooms[n].@y));return; }
        }
        private function neighbour(dx:int,dy:int):void { if(room) selectRoom(int(room.@x)+dx,int(room.@y)+dy); }
        private function render(xml:XML):BitmapData {
            return renderer.render({room:xml.copy(),land:pool.land[0],filename:sourcePath,roomNames:[]},"random_"+xml.@rrTheme,true,xml.@rrMirror=="1",true,false,int(xml.@rrDifficulty));
        }
        private function renderRoom():void {
            try {
                var next:BitmapData=render(room);if(pixels) pixels.dispose();pixels=next;
                updateImage(); changeZoom(1);
                details.text="点击物体标记查看生成依据。\n\n生成房："+room.@name+"\n场景："+sceneName(String(room.@rrTheme))+"\n坐标：("+room.@x+", "+room.@y+")\n种子："+pool.@rrSeed+"\n版本："+room.@rrVersion+"\nD "+room.@rrDanger+" / V "+room.@rrValue+"\n镜像："+(room.@rrMirror=="1"?"是":"否")+"\n\n生成记录不包含游玩后的破坏、掉落和敌人移动。\n静态画面不模拟 AI、开火或通行。\n切换叠层沿用同一张底图。";
                if(renderer.report.warnings.length) status.appendText("　绘制提示："+renderer.report.warnings.join("；"));
            } catch(error:Error) { fail(error); }
        }
        private function updateImage():void { bitmap.bitmapData=showDraft?draftPixels:pixels;bitmap.smoothing=true;buttons.base.label=showDraft?"显示：编辑草稿":"显示：原始生成";redraw(); }
        private function redraw():void {
            if(!room) return;
            overlay.draw(room,pool,flags,showDraft?draft:null);
            title.text="随机房审查 · "+sceneName(String(room.@rrTheme))+" · ("+room.@x+", "+room.@y+") · "+room.@name+" · "+(showDraft?"草稿对照":"完整生成快照");
            status.text=showDraft?"草稿对照：橙框为前景变化，青框为附加层变化；旧用途 / D·V / 布防仅供参考，未重新校验。改动 "+overlay.summary.diffCells+" 格。":"完整生成记录 · "+pool.room.length()+" 间 · CRC32 "+sourceCRC+" · 叠层中的枪线是防守意图，实际枪线请在游戏按 Shift+F3 查看。";
        }
        private function drawMap():void {
            map.graphics.clear();while(map.numChildren) map.removeChildAt(0);
            var mx:int=1,my:int=1;
            for each(var r:XML in pool.room) { mx=Math.max(mx,int(r.@x)+1);my=Math.max(my,int(r.@y)+1); }
            var cell:Number=Math.min(39,310/mx,245/my);
            for each(r in pool.room) {
                var tile:RRReviewMapCell=new RRReviewMapCell(int(r.@x),int(r.@y),cell,r===room,selectRoom);map.addChild(tile);
            }
        }
        private function selectPoint(p:XML):void {
            var zone:XML;
            for each(var z:XML in room.rrPlan.zone) if(z.@id==p.@zone) zone=z;
            details.text=(p.@id=="term1"?"安保终端":String(p.@id))+"\n用途："+String(p.@kind)+"\n区域："+(zone?(RRPlanOverlay.ROLES[String(zone.@role)]||zone.@role):p.@zone)+"\n原始格：("+p.@x+", "+p.@y+")\n生成依据："+p.@reason;
            if(zone) details.appendText("\nD "+zone.@danger+" / V "+zone.@value);
            if(p.@floorY.length()) details.appendText("\n安装：距操作地面 "+((Number(p.@floorY)-Number(p.@y))*40)+" 像素\n青色小圈标出地面操作位。");
            if(p.@id=="term1") details.appendText("\n\n控制范围：整间合成房的炮塔。\n候选接近路并不保证每个入口都能避火。");
            if(showDraft) details.appendText("\n\n草稿中的规划尚未重新校验。");
        }
        private function compareDraft():void {
            if(!room || !renderer.ready) return;
            var snapshot:Object=host.ToolsSnapshot(),edited:XML=XML(snapshot.room);
            if(edited.@name!=room.@name) throw new Error("先在编辑器打开这份导出，编辑同名房间，再回到审查对照。当前编辑房间："+edited.@name);
            var candidate:XML=room.copy();
            for each(var key:String in ["a","obj","back","options"]) { delete candidate[key];for each(var child:XML in edited[key]) candidate.appendChild(child.copy()); }
            if(candidate.a.length()!=25) throw new Error("编辑稿格网不完整。");
            var result:BitmapData=render(candidate);if(draftPixels) draftPixels.dispose();draftPixels=result;draft=candidate;showDraft=true;updateImage();
        }
        public function imageBytes():ByteArray {
            if(!bitmap.bitmapData) throw new Error("还没有可导出的画面。");
            var output:BitmapData=bitmap.bitmapData.clone();output.draw(overlay);var bytes:ByteArray=PngWriter.encode(output);output.dispose();return bytes;
        }
        private function savePNG():void { new FileReference().save(imageBytes(),"rr-"+room.@rrTheme+"-"+room.@name+(showDraft?"-draft":"-review")+".png"); }
        public function get diagnostics():Object { return {open:isOpen,room:room?String(room.@name):null,source:sourcePath,sourceCRC32:sourceCRC,rooms:pool?pool.room.length():0,draft:showDraft,overlay:overlay.summary,render:renderer.report}; }
        private function changeZoom(value:Number):void {
            zoom=Math.max(0.5,Math.min(5,value));content.scaleX=content.scaleY=Math.min(VW/1920,VH/1000)*zoom;
            content.x=(VW-1920*content.scaleX)/2;content.y=(VH-1000*content.scaleY)/2;constrain();
        }
        private function constrain():void { var w:Number=1920*content.scaleX,h:Number=1000*content.scaleY;content.x=w<VW?(VW-w)/2:Math.min(0,Math.max(VW-w,content.x));content.y=h<VH?(VH-h)/2:Math.min(0,Math.max(VH-h,content.y)); }
        private function wheel(e:MouseEvent):void { changeZoom(zoom*Math.pow(1.15,e.delta));e.stopPropagation(); }
        private function beginDrag(e:MouseEvent):void { dragPoint=new Point(viewport.mouseX,viewport.mouseY);dragOrigin=new Point(content.x,content.y);view.stage.addEventListener(MouseEvent.MOUSE_MOVE,drag,true);view.stage.addEventListener(MouseEvent.MOUSE_UP,endDrag,true); }
        private function drag(e:MouseEvent):void { content.x=dragOrigin.x+viewport.mouseX-dragPoint.x;content.y=dragOrigin.y+viewport.mouseY-dragPoint.y;constrain(); }
        private function endDrag(e:Event=null):void { if(view.stage) { view.stage.removeEventListener(MouseEvent.MOUSE_MOVE,drag,true);view.stage.removeEventListener(MouseEvent.MOUSE_UP,endDrag,true); } }
        private function fail(error:Error):void { status.text="无法完成："+error.message; }
        private function sceneName(id:String):String { return {plant:"工厂",stable:"废弃避难厩",sewer:"下水道",mane:"城市废墟"}[id]||id; }
        public function close():void { if(!isOpen) return;endDrag();view.stage.removeEventListener(KeyboardEvent.KEY_DOWN,key,true);panel.parent.removeChild(panel);isOpen=false;view.stage.focus=null; }
        public function dispose():void { if(isOpen) close();if(pixels) pixels.dispose();if(draftPixels) draftPixels.dispose();renderer.dispose(); }
    }
}
import flash.display.Sprite;
import flash.events.MouseEvent;
import flash.text.*;
class RRReviewSurface extends Sprite {
    public var controller:Object;
    public function RRReviewSurface(owner:Object) { controller=owner; }
}
class RRReviewMapCell extends Sprite {
    public function RRReviewMapCell(cx:int,cy:int,cell:Number,selected:Boolean,select:Function) {
        x=cx*cell;y=cy*cell;graphics.lineStyle(1,selected?0xFFFFFF:0x5D7A8A);graphics.beginFill(selected?0x3987A3:0x223B4B);graphics.drawRect(1,1,cell-2,cell-2);graphics.endFill();buttonMode=true;
        if(cell>=26) { var t:TextField=new TextField();t.defaultTextFormat=new TextFormat("Arial",11,0xE5EEF0);t.width=cell;t.height=22;t.y=cell/2-9;t.text=cx+","+cy;t.mouseEnabled=false;t.selectable=false;addChild(t); }
        addEventListener(MouseEvent.CLICK,function(e:MouseEvent):void { select(cx,cy); });
    }
}
