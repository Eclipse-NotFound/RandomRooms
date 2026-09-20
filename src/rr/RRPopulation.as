package rr
{
   /** Gameplay contents are planned before furniture. Native classes keep their
    * AI, loot, hacking, disarming and activation rules; this class owns placement. */
   public class RRPopulation
   {
      public var objects:Array=[];
      public var mood:String;
      public var stage:int;
      private var p:RRArchitecture;
      private var random:Function;
      private var used:Object={};
      private var serial:int;
      private var prefix:String;
      // Footprints from AllData; mount: floor / ceiling / wall / swim.
      public static const SIZES:Object={
         chest:[2,1],safe:[2,2],wallsafe:[1,1],ammobox:[1,1],explbox:[1,1],
         bigexpl:[3,1],weapbox:[2,2],weapcase:[3,1],"case":[1,1],basechest:[2,1],
         medbox:[1,1],bigmed:[2,3],instr1:[2,2],instr2:[2,1],bookcase:[2,3],
         cryocap:[2,3],term1:[1,1],term2:[1,1],term3:[1,1],
         work:[2,2],himlab:[2,2],stove:[1,1],vendor:[2,2],doctor:[2,2],
         mine:[1,1],trap:[1,1],spikes:[1,1],fspikes:[1,1],trcans:[1,2],
         trridge:[1,1],trplate:[1,1],trlaser:[1,1],damshot:[1,2],damgren:[1,1],expl1:[1,1],
         robocell:[2,2],alarm:[1,2],radbarrel:[1,2],radbigbarrel:[2,3],
         transm:[1,1],moln1:[1,3],elpanel:[1,1],knop1:[1,1],knop2:[1,1],knop3:[1,1],knop4:[1,1],
         turret:[1,1],landturret:[1,2],armturret:[1,2],hturret:[1,1],wturret:[1,1],cturret:[1,1],
         raider:[2,2],slaver:[2,2],merc:[2,2],zebra:[2,2],zombie:[2,2],
         alicorn:[2,3],hellhound:[2,3],necros:[2,2],robot:[2,2],protect:[2,2],gutsy:[2,2],eqd:[2,2],
         bloat:[1,1],tarakan:[1,1],rat:[1,1],ant:[1,1],molerat:[2,1],scorp:[2,1],
         slime:[1,1],bloodwing:[1,1],fish:[1,1],roller:[1,1],spritebot:[1,1],msp:[1,1]
      };
      public function RRPopulation(plan:RRArchitecture,rnd:Function,n:int,depth:int,peaceful:Boolean,safe:Boolean)
      {
         p=plan; random=rnd; prefix="rrp_"+n+"_"; stage=Math.max(0,depth);
         // Native setDoor/setNoObj suppresses removable objects farther from
         // an opening than the visible border. Reserve that whole landing for
         // contents AND subsequent furniture, including mirrored placements.
         for(var slot:int=0;slot<22;slot++) if(p.ports[slot]>=2)
         {
            var b:Object=RRPorts.rect(slot,int(p.ports[slot]));
            if(slot<6) b.x0=42;
            else if(slot>=11 && slot<17) b.x1=5;
            else if(slot>=17) b.y1=2;
            else b.y0=22;
            for(var y:int=b.y0;y<=b.y1;y++) for(var x:int=b.x0;x<=b.x1;x++) p.reserved[y+","+x]=true;
         }
         var roll:Number=random();
         mood=peaceful?"showroom":(safe?"arrival":(roll<0.18?"quiet":(roll<0.42?"cache":(roll<0.77?"patrol":"guarded"))));
      }
      private function pick(a:Array):String { return String(a[int(random()*a.length)]); }
      private function shuffle(a:Array):void
      { for(var i:int=a.length-1;i>0;i--) { var j:int=int(random()*(i+1)); var o:*=a[i]; a[i]=a[j]; a[j]=o; } }
      private function dangerous(kind:String):Boolean
      { return ["enemy","security","hazard","trigger","damager"].indexOf(kind)>=0; }
      private function fit(id:String,x:int,y:int,mount:String,kind:String):Boolean
      {
         var d:Array=SIZES[id], w:int=d[0], h:int=d[1];
         if(x<3 || x+w>45 || y-h<1 || y>23) return false;
         if(dangerous(kind) && Math.abs(x-p.spawn.x)+Math.abs(y-p.spawn.y)<8) return false;
         for(var yy:int=y-h+1;yy<=y;yy++) for(var xx:int=x;xx<x+w;xx++)
         {
            var key:String=yy+","+xx;
            var code:String=String(p.grid[yy][xx]);
            // Basin reservations protect the dry deck and furniture clearance;
            // aquatic units may occupy actual water, away from the return ladder.
            if(p.solid(xx,yy) || used[key] || (p.reserved[key] && !(mount=="swim" && code.indexOf("*")>=0))) return false;
            if(code.indexOf("-")>=0 || code.indexOf("А")>=0 || code.indexOf("Г")>=0) return false;
            if(mount!="swim" && (code.indexOf("*")>=0 || code.indexOf(",")>=0 || code.indexOf(";")>=0)) return false;
         }
         if(mount=="floor")
            for(xx=x;xx<x+w;xx++) if(!p.support(xx,y)) return false;
         if(mount=="ceiling" && !p.solid(x,y-h)) return false;
         if(mount=="wall" && !p.solid(x-1,y) && !p.solid(x+w,y)) return false;
         return true;
      }
      private function positions(id:String,mount:String,kind:String,region:Object=null):Array
      {
         var a:Array=[];
         for(var y:int=2;y<=23;y++) for(var x:int=3;x<=44;x++)
         {
            if(region && (x<region.x0 || x+SIZES[id][0]-1>region.x1 || y<region.top || y>region.floor)) continue;
            if(fit(id,x,y,mount,kind)) a.push({x:x,y:y});
         }
         shuffle(a); return a;
      }
      private function put(id:String,pos:Object,kind:String,mount:String="floor",attrs:Object=null):XML
      {
         var o:XML=<obj id={id} x={pos.x} y={pos.y} rrContent={kind} rrMount={mount} uid={prefix+serial++}/>;
         if(attrs) for(var key:String in attrs) o.@[key]=attrs[key];
         if(id=="armturret") o.@turn=pos.x<24?"1":"-1";
         if(id=="wturret") o.@vis=p.solid(pos.x-1,pos.y)?"right":"left";
         objects.push(o);
         var d:Array=SIZES[id];
         for(var y:int=pos.y-d[1]+1;y<=pos.y;y++) for(var x:int=pos.x;x<pos.x+d[0];x++)
         { used[y+","+x]=true; p.reserved[y+","+x]=true; }
         return o;
      }
      private function add(id:String,kind:String,mount:String="floor",attrs:Object=null,region:Object=null):XML
      {
         var choices:Array=positions(id,mount,kind,region);
         return choices.length?put(id,choices[0],kind,mount,attrs):null;
      }
      private function rewards():void
      {
         var containers:Array=p.theme=="plant"?["chest","ammobox","explbox","instr2","weapbox"]:
            (p.theme=="stable"?["basechest","medbox","bigmed","bookcase","case","cryocap"]:
             (p.theme=="sewer"?["chest","ammobox","instr1","explbox","case"]:["chest","ammobox","medbox","bookcase","case"]));
         var count:int=mood=="cache" || mood=="guarded"?3:1+int(random()*2);
         for(var i:int=0;i<count;i++) add(pick(containers),"loot");
         if(mood=="guarded" || mood=="cache")
         {
            var prize:String=pick(["safe","wallsafe","weapcase","weapbox","bigexpl"]);
            if(p.theme=="sewer" && prize=="wallsafe") prize="safe";
            add(prize,"reward");
         }
         // A lock-control terminal always has an actual hackable optional cache.
         if(p.theme!="sewer" && random()<0.32)
         {
            var a:Array=positions("term2","floor","terminal");
            if(a.length)
            {
               var box:XML=add("wallsafe","reward","floor",{lock:1+Math.min(4,int(stage/2)),mine:0,hack:1});
               if(box!=null) add("term2","terminal","floor");
            }
         }
         if(p.theme!="sewer" && random()<0.2) add("term3","terminal");
         // Buttons have a local optional reward target, never a quest target.
         if(random()<0.12)
         {
            var reward:XML=add("chest","reward","floor",{lock:1+Math.min(4,int(stage/2)),mine:0});
            if(reward!=null)
            {
               var button:XML=add(pick(["knop1","knop2","knop3","knop4"]),"switch");
               if(button!=null) button.appendChild(<scr act="unlock" targ={String(reward.@uid)}/>);
            }
         }
      }
      private function services():void
      {
         if(random()<0.3 || mood=="arrival")
         {
            var stations:Array=p.theme=="plant"?["work","work","himlab"]:
               (p.theme=="sewer"?["work","stove"]:["work","himlab","stove"]);
            add(pick(stations),"service");
         }
         if(mood=="quiet" && p.theme!="sewer" && random()<0.3)
            add(pick(["vendor","vendor","doctor"]),"service");
      }
      private function enemies():void
      {
         var groups:Array;
         if(p.theme=="sewer") groups=[["zombie"],["rat","molerat","slime","ant"],["bloat","bloodwing","tarakan"]];
         else if(p.theme=="plant") groups=[["raider"],["robot","protect"],["rat","scorp","tarakan","molerat"]];
         else if(p.theme=="stable") groups=[["zombie"],["robot","protect"],["raider"],["rat","tarakan","slime"]];
         else groups=[["raider"],["zombie"],["merc"],["bloat","bloodwing","scorp","ant"]];
         if(stage>=2 && p.theme=="plant") groups.push(["gutsy","robot","msp","roller"]);
         if(stage>=3 && p.theme=="stable") groups.push(["gutsy","spritebot","roller"]);
         if(stage>=3 && p.theme=="mane") groups.push(["slaver","zebra"],["alicorn"]);
         if(stage>=6 && p.theme=="plant") groups.push(["eqd","gutsy"]);
         if(stage>=6 && p.theme=="sewer") groups.push(["zombie","necros"]);
         var group:Array=groups[int(random()*groups.length)];
         var count:int=(mood=="guarded"?4:2)+int(random()*3)+Math.min(2,int(stage/3));
         if(mood=="cache") count=1+int(random()*2);
         for(var i:int=0;i<count;i++) add(pick(group),"enemy");
         if(p.theme=="sewer" && random()<0.45)
            for each(var pool:Object in p.pools)
            {
               var x:int=int((pool.x0+pool.x1)/2), y:int=pool.bottom;
               if(fit("fish",x,y,"swim","enemy")) put("fish",{x:x,y:y},"enemy","swim");
            }
      }
      private function security():void
      {
         if(p.theme=="sewer" || random()>0.42) return;
         var id:String=pick(["landturret","turret","hturret","armturret","wturret"]);
         if(stage>=4 && random()<0.2) id="cturret";
         var mount:String=["turret","hturret","cturret"].indexOf(id)>=0?"ceiling":(id=="wturret"?"wall":"floor");
         var turret:XML=add(id,"security",mount);
         if(turret!=null) add("term1","terminal");
         if(random()<0.2) add(pick(["robocell","alarm"]),"security");
      }
      private function circuit():void
      {
         // Explicit same-room allid prevents UnitTrigger's unbounded native
         // fallback from creating its gun inside a wall or outside this room.
         var regions:Array=p.regions.concat(); shuffle(regions);
         for each(var r:Object in regions)
         {
            if(r.x1-r.x0<8 || r.floor-r.top<4) continue;
            var id:String=pick(["trridge","trplate","trlaser"]);
            var triggers:Array=positions(id,"floor","trigger",r);
            if(!triggers.length) continue;
            var hit:String=pick(["damshot","damgren","expl1"]);
            var mount:String=hit=="damgren"?"ceiling":"floor";
            var weapons:Array=positions(hit,mount,"damager",r);
            for each(var a:Object in triggers) for each(var b:Object in weapons)
            {
               if(Math.abs(a.x-b.x)<4 || Math.abs(a.x-b.x)>8) continue;
               if(hit=="damshot" && Math.abs(a.y-b.y)>1) continue;
               var group:String=prefix+"circuit_"+serial;
               put(hit,b,"damager",mount,{allid:group,turn:b.x<a.x?1:-1});
               put(id,a,"trigger","floor",{allid:group,res:""});
               return;
            }
         }
      }
      private function hazards():void
      {
         if(random()<0.5) add(pick(p.theme=="sewer"?["trap","spikes"]:["mine","mine","trap","spikes"]),"hazard");
         if(random()<0.17) add("fspikes","hazard","ceiling");
         if(p.theme!="sewer" && random()<0.25) circuit();
         if(p.theme!="sewer" && random()<0.13) add("trcans","hazard","floor",{res:"noise"});
         if((p.theme=="plant" || p.theme=="sewer") && random()<0.13)
            add(pick(["radbarrel","radbarrel","radbigbarrel"]),"hazard");
         if((p.theme=="plant" || p.theme=="stable") && random()<0.12) add("moln1","hazard");
         if(stage>=2 && p.theme=="sewer" && random()<0.08) add("transm","hazard","floor",{on:1});
         // This native panel electrifies the entire Location. It must start
         // switched off so entering from another boundary is never an ambush.
         if(p.theme=="plant" && random()<0.08) add("elpanel","service","floor",{open:1,lock:0,mine:0});
      }
      public function build():void
      {
         rewards(); services();
         if(mood=="showroom" || mood=="arrival" || mood=="quiet")
         {
            if(mood!="quiet") for each(var o:XML in objects)
            { o.@mine="0"; if(mood=="showroom") o.@lock="0"; }
            return;
         }
         security(); hazards(); enemies();
      }
   }
}
