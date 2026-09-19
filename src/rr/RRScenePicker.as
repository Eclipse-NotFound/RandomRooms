package rr
{
   import flash.display.Sprite;
   import flash.display.Stage;
   import flash.events.Event;
   import flash.events.KeyboardEvent;
   import flash.events.MouseEvent;
   import flash.text.TextField;
   import flash.text.TextFormat;

   /** A modal owns input and restores the pause state it found. */
   public class RRScenePicker extends Sprite
   {
      private var host:Stage;
      private var world:*;
      private var paused:Boolean;
      private var done:Function;
      private var panel:Sprite=new Sprite();
      private var closed:Boolean=false;
      public function RRScenePicker(w:*,s:Stage,show:Boolean,callback:Function)
      {
         world=w; host=s; done=callback; paused=Boolean(w.onPause);
         w.ctr.clearAll(); w.onPause=true;
         addChild(panel);
         panel.graphics.beginFill(0x17201C,0.98); panel.graphics.lineStyle(1,0x809C81);
         panel.graphics.drawRoundRect(0,0,640,390,12); panel.graphics.endFill();
         label(panel,show?"选择展示场景":"下一次探索，去哪里？",26,20,590,36,24,0xD8E8C9);
         label(panel,"本次探索、向外扩张和深入新层均保持所选场景。",26,62,590,30,15,0xA5BAA6);
         var hints:Array=["高大厂房 · 设备与库房","金属隔间 · 居住与公共空间","污水渠池 · 干燥检修通路","破损楼层 · 街道与屋顶"];
         for (var i:int=0;i<4;i++) button(i,26+(i%2)*300,104+int(i/2)*91,288,79,RRScene.NAMES[i],hints[i]);
         button(4,26,293,288,61,"随机选择","随机决定本次探索的场景");
         button(-1,326,293,288,61,"返回","Esc 取消，保留当前进度");
         label(panel,"也可按 1–4 选择，5 随机",26,360,590,22,13,0x8DA08F);
         host.addChild(this);
         host.addEventListener(KeyboardEvent.KEY_DOWN,key,true,10000);
         host.addEventListener(KeyboardEvent.KEY_UP,keyUp,true,10000);
         host.addEventListener(Event.RESIZE,layout);
         layout(null);
      }
      private function label(parent:Sprite,text:String,x:int,y:int,w:int,h:int,size:int,color:uint):void
      {
         var t:TextField=new TextField(); t.defaultTextFormat=new TextFormat("Microsoft YaHei",size,color);
         t.text=text; t.x=x; t.y=y; t.width=w; t.height=h; t.selectable=false; t.mouseEnabled=false;
         parent.addChild(t);
      }
      private function button(index:int,x:int,y:int,w:int,h:int,title:String,subtitle:String):void
      {
         var b:Sprite=new Sprite(); b.x=x; b.y=y; b.buttonMode=true; b.mouseChildren=false;
         b.graphics.beginFill(0x283A2F); b.graphics.lineStyle(1,0x586E59);
         b.graphics.drawRoundRect(0,0,w,h,6); b.graphics.endFill();
         label(b,(index>=0?String(index+1)+"  ":"")+title,13,7,w-22,29,19,0xE0EBCF);
         label(b,subtitle,13,38,w-22,26,13,0xADBFAE);
         b.addEventListener(MouseEvent.CLICK,function(e:MouseEvent):void { e.stopImmediatePropagation(); finish(index); });
         panel.addChild(b);
      }
      private function layout(e:Event):void
      {
         graphics.clear(); graphics.beginFill(0x000000,0.65);
         graphics.drawRect(0,0,host.stageWidth,host.stageHeight); graphics.endFill();
         var scale:Number=Math.min(1,(host.stageWidth-24)/640,(host.stageHeight-24)/390);
         panel.scaleX=panel.scaleY=scale;
         panel.x=(host.stageWidth-640*scale)/2; panel.y=(host.stageHeight-390*scale)/2;
      }
      private function key(e:KeyboardEvent):void
      {
         e.stopImmediatePropagation(); e.preventDefault();
         if (e.keyCode==27) finish(-1);
         else if (e.keyCode>=49 && e.keyCode<=53) finish(e.keyCode-49);
         else if (e.keyCode>=97 && e.keyCode<=101) finish(e.keyCode-97);
      }
      private function keyUp(e:KeyboardEvent):void { e.stopImmediatePropagation(); e.preventDefault(); }
      private function finish(index:int):void
      {
         if (closed) return; closed=true;
         host.removeEventListener(KeyboardEvent.KEY_DOWN,key,true);
         host.removeEventListener(KeyboardEvent.KEY_UP,keyUp,true);
         host.removeEventListener(Event.RESIZE,layout);
         if (parent) parent.removeChild(this);
         world.ctr.clearAll(); world.onPause=paused;
         done(index<0?null:(index==4?"random":String(RRScene.IDS[index])));
      }
   }
}
