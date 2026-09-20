package rr
{
   /** Native 1.02 Land.setLocDif / Location.randomUnit ecology, sampled once
    * per room. All defence and companion choices refer to this same occupant.
    * Difficulty is the host Location difficulty, not the exploration counter. */
   public class RREcology
   {
      public var type:int;
      public var difficulty:Number;
      private var scene:String;
      private var random:Function;
      private var even:Boolean;
      public function RREcology(theme:String,dif:Number,parity:int,rnd:Function)
      {
         scene=theme; difficulty=Math.max(0,dif); random=rnd; even=parity%2==0;
         type=int(random()*3);
         if(scene=="plant" && random()<0.25) type=1;
         if(scene=="sewer") type=0;
         if(scene=="stable" && type==1 && random()<difficulty/20) type=3;
         if(scene=="mane") type=3+int(random()*3);
         if(scene!="sewer" && difficulty>12 && random()<0.1) type=6;
      }
      public function large():String
      {
         if(type==0) return "zombie";
         if(type==1) return "raider";
         if(type==3) return "slaver";
         if(type==4) return "merc";
         if(type==5) return "alicorn";
         if(type==6) return "zebra";
         if(scene=="stable" && difficulty>=12 && random()<Math.min(difficulty/100,0.15)) return "eqd";
         if(difficulty>=5 && random()<0.1) return "landturret";
         if(difficulty>=6 && random()<Math.min(difficulty/40,0.3)) return "gutsy";
         if(difficulty>=2 && random()<Math.min(difficulty/10,0.5)) return "protect";
         return "robot";
      }
      public function small():String
      {
         if(type==2 && difficulty>=4) return even?"roller":"msp";
         if(type==0 || type==5 || type==6)
         {
            var id:String=difficulty>=2 && random()<Math.min(difficulty/30,0.5)?"scorp":(even?"slime":"ant");
            if(scene=="sewer" && random()<0.25) id="rat";
            return id;
         }
         if(difficulty>=2 && random()<Math.min(difficulty/30,0.5)) return "molerat";
         return random()<0.6?"tarakan":"rat";
      }
      public function flying():String
      {
         if(type==0 || type==5) return "bloat";
         if(difficulty<3) return "";
         return type==2?"spritebot":"vortex";
      }
      public function ceiling():String
      {
         if(type==0 || type==5 || type==6) return scene=="sewer" && random()<0.6?"slime":"bloodwing";
         return "turret";
      }
      public function trap():String
      {
         // The slime mine is a subtype of slime; map XML supplies tr=10.
         if(type==0) return even?"slime":"trap";
         if((type==1 || type==3 || type==4 || type==6) && even)
         {
            if(difficulty>=10 && random()<0.5) return "trridge";
            return random()<0.5?"trplate":"trcans";
         }
         if(scene=="stable" && type==2 && even) return "trlaser";
         return "mine";
      }
      public function hidden():String { return type==2?"robocell":(type==1 || type==3?"alarm":""); }
      public function armed():Boolean { return type==1 || type==2 || type==3 || type==4 || type==6; }
   }
}
