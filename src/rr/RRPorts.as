package rr
{
   /** The 22 native Location.setDoor slots, shared by planning and growth. */
   public class RRPorts
   {
      public static function empty():Array
      {
         var a:Array=[];
         for (var i:int=0;i<22;i++) a.push(0);
         return a;
      }
      public static function vertical(p:int):Boolean { return (p>=6 && p<=10) || p>=17; }
      public static function opposite(p:int):int { return p<11?p+11:p-11; }
      public static function mirrored(p:int):int
      {
         if (p<6) return p+11;
         if (p<11) return 16-p;
         if (p<17) return p-11;
         return 38-p;
      }
      public static function mirror(a:Array):Array
      {
         var b:Array=empty();
         for (var p:int=0;p<22;p++) b[mirrored(p)]=a[p];
         return b;
      }
      public static function rect(p:int, amount:int=2):Object
      {
         var x:int,y:int;
         if (vertical(p))
         {
            x=5+9*(p>=17?p-17:p-6); y=p>=17?0:23;
            return {x0:x-(amount>2?1:0),y0:y,x1:x+1+(amount>2?1:0),y1:y+1};
         }
         x=p>=11?0:46; y=3+4*(p>=11?p-11:p);
         return {x0:x,y0:y-(amount>2?2:1),x1:x+1,y1:y};
      }
      public static function sample(random:Function):Array
      {
         var a:Array=empty();
         a[1+int(random()*5)]=3;
         a[12+int(random()*5)]=3;
         var top:int=int(random()*5), bottom:int=(top+1+int(random()*4))%5;
         if (random()<0.7) a[17+top]=2;
         if (random()<0.7) a[6+bottom]=2;
         return a;
      }
   }
}
