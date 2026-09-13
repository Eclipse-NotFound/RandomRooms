package rr
{
   /** Immutable shared edges of one unbounded map. Every cell has a parent
    * towards the origin; extra edges form loops without prescribing room tours.
    * Border sockets are decided now, even if their neighbour is built later. */
   public class RRMapPlan
   {
      private var seed:uint;
      private var verticalSlots:Object={};
      public function RRMapPlan(random:Function) { seed=uint(random()*4294967295); }
      private function mul(a:uint,b:uint):uint
      { return uint((a&65535)*b)+uint((a>>>16)*(b&65535)<<16); }
      private function value(x:int,y:int,salt:int):uint
      {
         var v:uint=seed ^ mul(uint(x),73856093) ^ mul(uint(y),19349663) ^ mul(uint(salt),83492791);
         v^=v>>>16; v=mul(v,0x85ebca6b);
         v^=v>>>13; v=mul(v,0xc2b2ae35); v^=v>>>16;
         return v;
      }
      private function parentLeft(x:int,y:int):Boolean
      { return y==0 || (x>0 && value(x,y,1)%2==0); }
      private function horizontal(x:int,y:int):Boolean
      { return parentLeft(x+1,y) || value(x,y,2)%100<62; }
      private function downward(x:int,y:int):Boolean
      { return !parentLeft(x,y+1) || value(x,y,3)%100<62; }
      private function vslot(x:int,y:int):int
      {
         var prev:int=-1;
         for (var row:int=0;row<=y;row++)
         {
            var key:String=x+","+row;
            if (verticalSlots[key]===undefined)
            {
               var n:int=int(value(x,row,4)%(prev<0?5:4));
               if (prev>=0 && n>=prev) n++;
               if (prev>=0 && value(x,row,5)%100<4) n=prev;
               verticalSlots[key]=n;
            }
            prev=int(verticalSlots[key]);
         }
         return prev;
      }
      public function ports(x:int,y:int):Array
      {
         var a:Array=RRPorts.empty();
         if (horizontal(x,y)) a[1+int(value(x,y,6)%5)]=3;
         if (x>0 && horizontal(x-1,y)) a[12+int(value(x-1,y,6)%5)]=3;
         if (downward(x,y)) a[6+vslot(x,y)]=2;
         if (y>0 && downward(x,y-1)) a[17+vslot(x,y-1)]=2;
         return a;
      }
   }
}
