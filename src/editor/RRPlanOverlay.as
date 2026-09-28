package {
    import flash.display.*;
    import flash.text.*;
    import flash.geom.Point;
    import flash.filters.GlowFilter;
    import rr.RRPorts;
    import rr.RRPopulation;
    public class RRPlanOverlay extends Sprite {
        public function RRPlanOverlay() {}
        public static const ROLES:Object={workshop:"车间",warehouse:"仓储",service:"检修",control:"控制室",store:"储物",living:"居住",medical:"医疗",office:"办公",corridor:"通道",canal:"水渠",kitchen:"厨房",hall:"大厅",roof:"屋顶",street:"街道"};
        public var selected:Function;
        public var summary:Object={};
        private var mirror:Boolean;
        private function tx(x:Number):Number { return (mirror?48-x:x)*40; }
        private function label(text:String,x:Number,y:Number,color:uint,w:int=210):void {
            var t:TextField=new TextField(); t.defaultTextFormat=new TextFormat("Microsoft YaHei UI",19,color,true);
            t.width=w; t.height=58; t.multiline=true; t.text=text; t.x=Math.max(3,Math.min(1910-w,x)); t.y=y;
            t.selectable=false; t.mouseEnabled=false; t.filters=[new GlowFilter(0x0A1520,1,4,4,6)]; addChild(t);
        }
        private function dashed(a:Point,b:Point,c:uint):void {
            var steps:int=Math.max(1,Math.ceil(Point.distance(a,b)/12)); graphics.lineStyle(3,c,0.85);
            for(var i:int=0;i<steps;i+=2) { graphics.moveTo(a.x+(b.x-a.x)*i/steps,a.y+(b.y-a.y)*i/steps); graphics.lineTo(a.x+(b.x-a.x)*Math.min(i+1,steps)/steps,a.y+(b.y-a.y)*Math.min(i+1,steps)/steps); }
        }
        public function draw(room:XML,pool:XML,flags:Object,draft:XML=null):void {
            graphics.clear(); while(numChildren) removeChildAt(0);
            mirror=room.@rrMirror=="1"; summary={spaces:0,points:0,guns:0,controls:0,ports:0,unpaired:0,diffCells:0};
            if(flags.spaces) for each(var s:XML in room.rrPlan.space) {
                var x0:Number=Number(s.@x0),w:Number=Number(s.@x1)-x0+1;
                var x:Number=tx(mirror?x0+w:x0),y:Number=Number(s.@top)*40,h:Number=(Number(s.@floor)-Number(s.@top)+1)*40;
                var c:uint=Number(s.@danger)>=65?0xFA8A91:Number(s.@value)>=65?0xEED58B:0x92D2CE;
                graphics.lineStyle(2,c,0.7); graphics.beginFill(c,0.04); graphics.drawRect(x+2,y+2,w*40-4,h-4); graphics.endFill();
                if(s.@kind!="gallery") label((ROLES[String(s.@role)]||String(s.@role))+"\nD "+s.@danger+"  /  V "+s.@value,x+8,y+3,c,Math.max(100,Math.min(220,w*40-12)));
                summary.spaces++;
            }
            if(flags.tactics) {
                for each(var gun:XML in room.rrPlan.gun) {
                    dashed(new Point(tx(Number(gun.@x)),Number(gun.@y)*40),new Point(tx(Number(gun.@targetX)),Number(gun.@targetY)*40),0xF296FF); summary.guns++;
                }
                for each(var control:XML in room.rrPlan.control) {
                    var previous:Point=null;
                    for each(var str:String in String(control.@path).split(",")) {
                        var n:int=int(str),pt:Point=new Point(tx(n%48+1),(int(n/48)+0.3)*40);
                        if(previous) dashed(previous,pt,0x6FDDE8); previous=pt;
                    }
                    if(previous) { graphics.lineStyle(3,0x6FDDE8); graphics.drawCircle(previous.x,previous.y,12); }
                    summary.controls++;
                }
            }
            if(flags.ports && room.doors.length()) {
                var ports:Array=String(room.doors).split("."); if(mirror) ports=RRPorts.mirror(ports);
                for(var slot:int=0;slot<22;slot++) if(int(ports[slot])>=2) {
                    var dx:int=slot<6?1:slot>=11&&slot<17?-1:0,dy:int=slot>=6&&slot<11?1:slot>=17?-1:0;
                    var neighbour:XML=null;
                    for each(var other:XML in pool.room) if(int(other.@x)==int(room.@x)+dx && int(other.@y)==int(room.@y)+dy) { neighbour=other; break; }
                    var matched:Boolean=false;
                    if(neighbour) {
                        var np:Array=String(neighbour.doors).split("."); if(neighbour.@rrMirror=="1") np=RRPorts.mirror(np);
                        matched=int(np[RRPorts.opposite(slot)])==int(ports[slot]);
                    }
                    var b:Object=RRPorts.rect(slot,int(ports[slot]));
                    c=matched?0xA0D9FF:0xFFB65C; graphics.lineStyle(4,c); graphics.beginFill(c,0.12);
                    graphics.drawRect(b.x0*40+3,b.y0*40+3,(b.x1-b.x0+1)*40-6,(b.y1-b.y0+1)*40-6); graphics.endFill();
                    summary.ports++; if(!matched) summary.unpaired++;
                }
            }
            if(flags.points) for each(var p:XML in room.rrPlan.point) {
                var size:Array=RRPopulation.SIZES[String(p.@id)]||[1,1];
                x=tx(Number(p.@x)+size[0]/2); y=(Number(p.@y)+0.5)*40;
                c=p.@kind=="security"?0xF296FF:p.@kind=="enemy"?0xFF6B73:p.@kind=="terminal"?0x6FDDE8:p.@kind=="ambient"?0xB6EAA0:0xFFCE83;
                var marker:RRReviewMarker=new RRReviewMarker(p,c,selected); marker.x=x; marker.y=y; addChild(marker);
                if(p.@kind=="security" || p.@id=="term1") label(p.@id=="term1"?"安保终端":p.@mount=="ceiling"?"顶装炮塔":"地面炮塔",x-48,y+(p.@mount=="ceiling"?55:-37),c);
                if(p.@operator.length()) {
                    n=int(p.@operator); graphics.lineStyle(2,0x6FDDE8,0.65); graphics.drawCircle(tx(n%48+1),(int(n/48)+0.3)*40,8);
                }
                summary.points++;
            }
            if(draft) for(var row:int=0;row<25;row++) {
                var aa:Array=String(room.a[row]).split("."),bb:Array=String(draft.a[row]).split(".");
                for(var col:int=0;col<48;col++) if(aa[col]!=bb[col]) {
                    summary.diffCells++; c=String(aa[col]).charAt(0)!=String(bb[col]).charAt(0)?0xFF9966:0x60DDED;
                    graphics.lineStyle(2,c); graphics.beginFill(c,0.2); graphics.drawRect(tx(mirror?col+1:col),row*40,40,40); graphics.endFill();
                }
            }
        }
    }
}
import flash.display.Sprite;
import flash.events.MouseEvent;
class RRReviewMarker extends Sprite {
    public function RRReviewMarker(xml:XML,color:uint,select:Function) {
        graphics.lineStyle(2.5,color); graphics.beginFill(0x101A20,0.8); graphics.drawCircle(0,0,11); graphics.endFill();
        graphics.moveTo(-16,0); graphics.lineTo(16,0); graphics.moveTo(0,-16); graphics.lineTo(0,16); buttonMode=true;
        addEventListener(MouseEvent.CLICK,function(e:MouseEvent):void { e.stopPropagation(); if(select!=null) select(xml); });
        addEventListener(MouseEvent.MOUSE_DOWN,function(e:MouseEvent):void { e.stopPropagation(); });
    }
}
