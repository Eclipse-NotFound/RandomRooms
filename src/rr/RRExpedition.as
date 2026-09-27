package rr
{
   import rr.v122.RRSynth;
   /** One immutable choice per exploration. Version never participates in
    * seed derivation: both generators receive the same map and room inputs. */
   public class RRExpedition
   {
      public var version:String;
      public var seed:uint;
      public var theme:String;
      public var depth:int;
      public var show:Boolean;
      private var root:RRSeed;
      private var generator:Object;

      public function RRExpedition(v:String,s:uint,biome:String,stage:int,peaceful:Boolean)
      {
         version=valid(v)?v:"13"; seed=s; theme=biome; depth=stage; show=peaceful;
         root=new RRSeed(seed).fork(theme+":"+depth);
         generator=version=="12.2"?new rr.v122.RRSynth():new rr.RRSynth();
      }
      public static function valid(v:String):Boolean { return v=="12.2" || v=="12.3" || v=="13"; }
      public function planner():RRMapPlan
      {
         var rng:RRSeed=root.fork("map");
         return new RRMapPlan(function():Number { return rng.next(); });
      }
      public function mirror(x:int,y:int):Boolean
      { return theme!="mane" && roomSeed(x,y).fork("mirror").next()<0.5; }
      public function checkpoint(x:int,y:int):Boolean
      { return roomSeed(x,y).fork("checkpoint").next()<0.22; }
      private function roomSeed(x:int,y:int):RRSeed { return root.fork("room:"+x+":"+y); }
      public function generate(n:int,x:int,y:int,ports:Array,city:Object,difficulty:Number):XML
      {
         var kind:String="";
         for(var p:int=6;p<=10;p++) if(ports[p]>=2 && ports[p+11]>=2) kind="connector";
         var room:XML=generator.generate(n,theme,kind,ports,depth,show,x==0 && y==0,
            {partition:"rules",seed:roomSeed(x,y).seed,difficulty:difficulty,parity:x+y,city:city,contentVersion:version});
         room.@rrVersion=version; room.@rrMasterSeed=seed;
         return room;
      }
   }
}
