package rr
{
   /** v13 content director. Geometry and native unit strength remain independent.
    * Budgets belong to final merged rooms; streams are split by purpose and zone.
    * No quest actors, artificial loot tables or replacement AI are introduced. */
   public class RRContentPlan
   {
      public var zones:Array=[];
      public var points:Array=[];
      public var turrets:Array=[];
      public var terminal:Object;
      public var danger:int;
      public var value:int;
      public var peaceful:Boolean;
      private var p:RRArchitecture;
      private var pop:RRPopulation;
      private var seed:RRSeed;
      private var context:Object;
      private var tactics:RRTactics;
      private var enemies:int=0;
      private var specials:int=0;
      private var ambient:int=0;
      private var reinforcement:Boolean=false;
      private static const BIAS:Object={workshop:[10,0],warehouse:[4,18],service:[-8,2],control:[8,16],store:[-12,20],living:[-14,-4],medical:[-8,23],office:[-7,7],corridor:[-2,-20],canal:[8,-14],kitchen:[-10,2],hall:[10,-8]};
      public function RRContentPlan(plan:RRArchitecture,population:RRPopulation,rng:RRSeed,options:Object)
      {
         p=plan; pop=population; seed=rng; context=options;
         peaceful=pop.mood=="arrival" || pop.mood=="showroom";
         if(!peaceful) pop.mood="planned";
         tactics=new RRTactics(p);
         var base:RRSeed=seed.fork("baseline"),shared:Number=base.next();
         danger=clamp(5+90*(0.7*base.next()+0.3*shared));
         value=clamp(5+90*(0.7*base.next()+0.3*shared));
         if(context.hasOwnProperty("danger")) danger=clamp(context.danger);
         if(context.hasOwnProperty("value")) value=clamp(context.value);
         if(peaceful) danger=0;
         var byId:Object={},r:Object,z:Object,i:int=0;
         for each(r in p.regions) if(r.hasOwnProperty("id"))
         {
            var key:String=r.hasOwnProperty("room")?"room-"+r.room:"part-"+r.id;
            if(!byId[key]) { byId[key]={id:key,regions:[],role:r.role,area:0,largest:0,pressure:0}; zones.push(byId[key]); }
            z=byId[key]; z.regions.push(r);
            var area:int=(r.x1-r.x0+1)*(r.floor-r.top+1); z.area+=area;
            if(area>z.largest) { z.role=r.role; z.largest=area; }
         }
         // Galleries are traffic space, not a second set of encounter budgets.
         for each(r in p.regions) if(!r.hasOwnProperty("id"))
         {
            var nearest:Object=null,best:Number=1e9;
            for each(z in zones) for each(var part:Object in z.regions)
            {
               var dist:Number=Math.abs(r.x0+r.x1-part.x0-part.x1)+Math.abs(r.top+r.floor-part.top-part.floor);
               if(dist<best) { best=dist; nearest=z; }
            }
            if(nearest) nearest.regions.push(r);
         }
         for each(z in zones)
         {
            var local:RRSeed=seed.fork("values:"+z.id),common:Number=local.next()*2-1;
            var bias:Array=BIAS[z.role] || [0,0];
            z.d=peaceful?0:clamp(danger+bias[0]+32*(0.7*(local.next()*2-1)+0.3*common));
            z.v=clamp(value+bias[1]+32*(0.7*(local.next()*2-1)+0.3*common));
            z.limit=peaceful?0:1.8+5*z.d/100;
            for each(r in z.regions) { r.dvZone=z.id; r.danger=z.d; r.value=z.v; }
         }
      }
      private static function clamp(v:Number):int { return Math.max(0,Math.min(100,Math.round(v))); }
      private function rng(label:String,z:Object=null):RRSeed { return seed.fork(label+(z?":"+z.id:"")); }
      private function belongs(z:Object,x:int,y:int):Boolean
      {
         for each(var r:Object in z.regions) if(x>=r.x0 && x<=r.x1 && y>=r.top && y<=r.floor) return true;
         return false;
      }
      private function choices(z:Object,id:String,mount:String,kind:String,label:String):Array
      {
         var out:Array=[],r:RRSeed=rng(label,z);
         for each(var a:Object in pop.positions(id,mount,kind,null,false)) if(belongs(z,a.x,a.y))
         {
            if(mount=="floor" && !(tactics.stand[a.y*48+a.x] || tactics.stand[a.y*48+a.x-1])) continue;
            if(terminal && ["enemy","special","ambient","hazard","trigger","damager"].indexOf(kind)>=0 &&
               Math.abs(a.x-terminal.x)+Math.abs(a.y-terminal.y)<4) continue;
            a.score=r.fork(a.x+","+a.y).next(); out.push(a);
         }
         out.sortOn("score",Array.NUMERIC); return out;
      }
      private function put(z:Object,id:String,a:Object,kind:String,mount:String="floor",cost:Number=0,attrs:Object=null,reason:String=""):XML
      {
         if(cost>0 && z.pressure+cost>z.limit+0.0001) return null;
         var o:XML=pop.put(id,a,kind,mount,attrs);
         o.@rrZone=z.id; o.@rrD=z.d; o.@rrV=z.v;
         z.pressure+=cost;
         points.push({uid:String(o.@uid),id:id,zone:z.id,x:a.x,y:a.y,mount:mount,kind:kind,cost:cost,reason:reason});
         return o;
      }
      private function add(z:Object,id:String,kind:String,mount:String="floor",cost:Number=0,attrs:Object=null,label:String="",reason:String=""):XML
      {
         if(cost>0 && z.pressure+cost>z.limit+0.0001) return null;
         var a:Array=choices(z,id,mount,kind,label || kind+":"+id);
         return a.length?put(z,id,a[0],kind,mount,cost,attrs,reason):null;
      }
      public function build():void
      {
         if(!peaceful) { security(); securityTerminal(); }
         var z:Object;
         if(!peaceful)
         {
            for each(z in zones) major(z);
            for each(z in zones) wildlife(z);
            for each(z in zones) hazards(z);
            for each(z in zones) fixtures(z);
            for each(z in zones) special(z);
         }
         // Value rolls are deliberately last and never consume encounter RNG.
         for each(z in zones) { rewards(z); services(z); }
         if(peaceful) for each(var o:XML in pop.objects) { o.@mine=0; if(pop.mood=="showroom") o.@lock=0; }
      }
      private function security():void
      {
         if(!pop.ecology.armed() || p.theme=="sewer") return;
         for each(var z:Object in zones)
         {
            var r:RRSeed=rng("turrets",z);
            if(turrets.length>=3 || z.limit<2 || r.next()>=0.02+0.5*z.d/100) continue;
            var mounts:Array=r.next()<0.6?["ceiling","floor"]:["floor","ceiling"];
            var found:Boolean=false;
            for each(var mount:String in mounts)
            {
               var id:String=mount=="ceiling"?(r.next()<0.15?"hturret":"turret"):(r.next()<0.25?"armturret":"landturret");
               var candidates:Array=choices(z,id,mount,"security","turret:"+mount),ranked:Array=[];
               for each(var a:Object in candidates)
               {
                  if(mount=="ceiling" && (!p.solid(a.x-1,a.y-1) || !p.solid(a.x+1,a.y-1))) continue;
                  var t:Object={x:a.x,y:a.y,id:id,mount:mount,turn:a.x<24?1:-1,ox:a.x+0.5,oy:a.y+(mount=="ceiling"?0.675:(id=="landturret"?-0.525:-0.4)),zone:z.id};
                  if(!tactics.protectsEntry(t)) continue;
                  var score:Number=-1,target:Object=null;
                  var anchors:Array=p.links.concat();
                  for each(var ladder:Object in p.ladders) anchors.push({x:ladder.x,y:ladder.bottom,kind:"ladder"});
                  for each(var anchor:Object in anchors)
                  {
                     var ax:Number=Number(anchor.x)+0.5,ay:Number=Number(anchor.y)-0.2;
                     var d:Number=Math.sqrt((ax-t.ox)*(ax-t.ox)+(ay-t.oy)*(ay-t.oy));
                     if(d<4 || d>18 || !tactics.exposed(t,ax,ay)) continue;
                     if(mount=="ceiling" && ay<=t.oy+1) continue;
                     var s:Number=8-Math.abs(d-8)*0.3+a.score;
                     if(s>score) { score=s; target={x:ax,y:ay,kind:String(anchor.kind)}; }
                  }
                  if(target) { t.target=target; t.score=score; ranked.push(t); }
               }
               ranked.sortOn("score",Array.NUMERIC|Array.DESCENDING);
               if(!ranked.length) continue;
               t=ranked[0]; var xml:XML=put(z,t.id,t,"security",mount,2,null,"guard-link");
               if(!xml) continue;
               t.uid=String(xml.@uid); turrets.push(t); found=true;
               // Keep the intended firing line clear of subsequently placed furniture.
               var steps:int=Math.ceil(Math.max(Math.abs(t.target.x-t.ox),Math.abs(t.target.y-t.oy))*3);
               for(var k:int=1;k<steps;k++)
               {
                  var xx:int=int(t.ox+(t.target.x-t.ox)*k/steps),yy:int=int(t.oy+(t.target.y-t.oy)*k/steps);
                  p.reserve(xx,yy,xx,yy);
               }
               break;
            }
         }
      }
      private function securityTerminal():void
      {
         if(!turrets.length || rng("terminal-chance").next()>=0.62) return;
         var blocked:Object=tactics.blockedBy(turrets),reaches:Array=[],all:Array=[];
         for each(var e:Object in tactics.entries)
         { reaches.push(tactics.flood(e.node,blocked)); all.push(tactics.flood(e.node)); }
         var best:Object=null,bestScore:Number=-1e9;
         for each(var z:Object in zones) for each(var a:Object in choices(z,"term1","floor","terminal","terminal-position"))
         {
            for each(var dx:int in [-2,1])
            {
               var node:int=a.y*48+a.x+dx;
               if(!tactics.stand[node] || !tactics.clear[node] || blocked[node] || !operatorFloor(node)) continue;
               var path:Array=[],from:int=-1,dist:Number=1e9,access:Array=[];
               for(var i:int=0;i<reaches.length;i++)
               {
                  var reach:Object=reaches[i],safe:Boolean=reach.distances.hasOwnProperty(node);
                  access.push({slot:tactics.entries[i].slot,state:safe?"covered-route":(all[i].distances.hasOwnProperty(node)?"exposed-route":"unproven")});
                  if(safe && reach.distances[node]>=5 && reach.distances[node]<dist)
                  { dist=reach.distances[node]; from=i; path=tactics.path(reach,node); }
               }
               if(from<0) continue;
               var score:Number=(z.role=="control"?6:(["service","office"].indexOf(z.role)>=0?4:0))+
                  (p.solid(a.x-1,a.y) || p.solid(a.x+1,a.y)?3:0)-dist*0.025+a.score;
               if(score>bestScore) { bestScore=score; best={z:z,x:a.x,y:a.y,node:node,path:path,entries:access,from:tactics.entries[from].slot}; }
            }
         }
         if(!best) return;
         var xml:XML=put(best.z,"term1",best,"terminal","floor",0,null,"location-turret-control");
         terminal={uid:String(xml.@uid),x:best.x,y:best.y,node:best.node,path:best.path,entries:best.entries,from:best.from};
         tactics.reservePath(best.path);
         p.reserve(best.node%48-1,int(best.node/48)-2,best.node%48+2,int(best.node/48));
      }
      private function operatorFloor(node:int):Boolean
      {
         var x:int=node%48,y:int=node/48;
         if(x<1 || x>45 || !p.support(x,y) || !p.support(x+1,y)) return false;
         // A native ladder snaps the pony to its side, up to half a tile away
         // from the two-tile route node's centre. That is not a stationary
         // operating position and can expose the body around a wall edge.
         for(var yy:int=y-1;yy<=y;yy++) for(var xx:int=x;xx<=x+1;xx++)
            if(p.reserved[yy+","+xx] || /[АВГ]/.test(String(p.grid[yy][xx]))) return false;
         return true;
      }
      private function major(z:Object):void
      {
         var r:RRSeed=rng("main",z);
         if(r.next()>=0.04+0.82*z.d/100) return;
         var count:int=Math.min(5,1+int(z.d/42)+(r.next()<0.35?1:0));
         var ecologySeed:RRSeed=rng("main-model",z);
         var eco:RREcology=new RREcology(p.theme,pop.ecology.difficulty,0,function():Number { return ecologySeed.next(); });
         eco.type=pop.ecology.type;
         for(var i:int=0;i<count && enemies<10;i++)
         {
            var id:String=eco.large();
            // Native large() can itself return a turret. All turrets must pass
            // the tactical placement and whole-Location terminal checks above.
            if(id.indexOf("turret")>=0) id="robot";
            if(add(z,id,"enemy","floor",1,null,"main:"+i,"major-group")) enemies++;
         }
      }
      private function wildlife(z:Object):void
      {
         if(ambient>=4 || rng("ambient-chance",z).next()>=0.3) return;
         var r:RRSeed=rng("ambient-model",z),eco:RREcology=new RREcology(p.theme,pop.ecology.difficulty,0,function():Number { return r.next(); });
         eco.type=pop.ecology.type;
         var id:String=eco.small(),mount:String="floor";
         if(eco.type==2) return; // rollers, spider mines and drones are real threats.
         if(r.next()<0.25) { id=eco.ceiling(); mount="ceiling"; }
         if(id.indexOf("turret")>=0) { id="rat"; mount="floor"; }
         // Wildlife occurrence is independent of D; its presence still counts
         // toward the room's total pressure ceiling.
         if(add(z,id,"ambient",mount,0.35,null,"ambient","ambient-ecology")) ambient++;
      }
      private function blind(a:Object):Number
      {
         var seen:int=0,total:int=0;
         for each(var e:Object in tactics.entries)
         { total++; if(tactics.line(e.x+1,e.y,a.x+0.5,a.y+0.5)) seen++; }
         for each(var link:Object in p.links)
         { total++; if(tactics.line(Number(link.x)+0.5,Number(link.y)-0.2,a.x+0.5,a.y+0.5)) seen++; }
         return total?1-seen/total:0;
      }
      private function special(z:Object):void
      {
         if(specials>=3 || !pop.ecology.armed()) return;
         var r:RRSeed=rng("special",z),chance:Number=0.06+0.60*Math.pow(1-z.d/100,0.8)*Math.pow(z.v/100,1.2);
         if(r.next()>=chance || z.pressure+1.5>z.limit) return;
         var ids:Array=["mine"];
         if(pop.ecology.type==2 && pop.ecology.difficulty>=4) ids.push("msp","roller");
         if(pop.ecology.difficulty>=3) ids.push(pop.ecology.type==2?"spritebot":"vortex");
         var id:String=ids[r.nextInt(ids.length)],mount:String=(id=="spritebot" || id=="vortex")?"air":"floor";
         var a:Array=choices(z,id,mount,"special","special-position");
         for each(var pos:Object in a)
         {
            if(mount=="air") pos.score+=Math.abs(pos.y-int(z.regions[0].floor)+2)*0.2;
            else pos.score-=blind(pos)*1.5;
         }
         a.sortOn("score",Array.NUMERIC);
         if(a.length && put(z,id,a[0],"special",mount,1.5,null,mount=="air"?"cache-patrol":"cache-blindspot")) specials++;
      }
      private function hazards(z:Object):void
      {
         var r:RRSeed=rng("hazards",z);
         if(r.next()>0.12 || z.pressure+1>z.limit) return;
         var ecoSeed:RRSeed=rng("hazard-model",z),eco:RREcology=new RREcology(p.theme,pop.ecology.difficulty,r.nextInt(2),function():Number { return ecoSeed.next(); });
         eco.type=pop.ecology.type;
         var id:String=eco.trap();
         if(id=="mine") return; // mine placement belongs exclusively to special().
         if(["trplate","trridge","trlaser"].indexOf(id)>=0)
         {
            var triggers:Array=choices(z,id,"floor","trigger","trigger");
            var weapon:String=r.next()<0.5?"damshot":"damgren",mount:String=weapon=="damgren"?"ceiling":"floor";
            var guns:Array=choices(z,weapon,mount,"damager","circuit");
            for each(var a:Object in triggers) for each(var b:Object in guns)
               if(Math.abs(a.x-b.x)>=4 && Math.abs(a.x-b.x)<=8 && (weapon!="damshot" || Math.abs(a.y-b.y)<=1) && tactics.line(a.x+0.5,a.y+0.5,b.x+0.5,b.y+0.5))
               {
                  var group:String="rrc_"+seed.seed+"_"+z.id;
                  put(z,weapon,b,"damager",mount,1,{allid:group,turn:b.x<a.x?1:-1},"paired-trap");
                  put(z,id,a,"trigger","floor",0,{allid:group,res:""},"paired-trap"); return;
               }
         }
         else add(z,id,"hazard","floor",1,id=="slime"?{tr:"10"}:(id=="trcans"?{res:"noise"}:null),"hazard","native-ecology-trap");
      }
      private function rewards(z:Object):void
      {
         var r:RRSeed=rng("rewards",z),ids:Array;
         if(z.role=="medical") ids=["medbox","bigmed","case"];
         else if(z.role=="office" || z.role=="living") ids=["bookcase","case","medbox"];
         else if(z.role=="control") ids=["instr2","case","chest"];
         else ids=p.theme=="sewer"?["chest","instr1","case"]:["chest","ammobox","instr2","explbox"];
         if(r.next()<0.65) add(z,ids[r.nextInt(ids.length)],"loot","floor",0,null,"loot","ordinary-supplies");
         if(r.next()<0.04+0.8*z.v/100)
         {
            ids=p.theme=="sewer"?["safe","chest","instr2"]:["safe","wallsafe","weapcase","weapbox"];
            var id:String=ids[r.nextInt(ids.length)];
            // Native item tables, lock difficulty and hidden container events
            // remain native. A high V is opportunity, never guaranteed profit.
            var box:XML=add(z,id,"reward","floor",0,null,"prize","high-value-opportunity");
            if(box && id=="wallsafe" && p.theme!="sewer" && r.next()<0.35)
            {
               box.@hack=1;
               add(z,"term2","terminal","floor",0,null,"lock-terminal","optional-cache-control");
            }
            else if(box && r.next()<0.12)
            {
               var button:XML=add(z,p.theme=="stable"?"knop1":"knop3","switch","floor",0,null,"cache-switch","optional-cache-control");
               if(button) button.appendChild(<scr act="unlock" targ={String(box.@uid)}/>);
            }
         }
         if(p.theme!="sewer" && r.next()<0.04+0.08*z.v/100) add(z,"term3","terminal","floor",0,null,"data-terminal","native-data-loot");
      }
      private function fixtures(z:Object):void
      {
         var r:RRSeed=rng("fixtures",z),id:String="";
         if(!reinforcement && z.d>=40 && rng("reinforcement",z).next()<0.08 && ["workshop","control","service","warehouse"].indexOf(z.role)>=0)
         {
            id=pop.ecology.hidden();
            if(id && add(z,id,"reinforcement","floor",2,null,"reinforcement","native-response-device")) reinforcement=true;
         }
         if(r.next()>0.08) return;
         if(p.theme!="stable" && r.next()<0.6)
         {
            id=r.next()<0.35?"fspikes":"spikes";
            add(z,id,"hazard",id=="fspikes"?"ceiling":"floor",1,null,"spikes","optional-environment-hazard");
         }
         else if(p.theme!="mane") add(z,r.next()<0.25?"radbigbarrel":"radbarrel","hazard","floor",0.5,null,"radiation","industrial-residue");
         if(p.theme=="sewer" && ambient<4 && rng("fish",z).next()<0.4)
            for each(var pool:Object in p.pools)
            {
               var x:int=int((pool.x0+pool.x1)/2),y:int=pool.bottom;
               if(belongs(z,x,y) && pop.fit("fish",x,y,"swim","ambient") && put(z,"fish",{x:x,y:y},"ambient","swim",0.35,null,"water-ecology")) { ambient++; break; }
            }
      }
      private function services(z:Object):void
      {
         var r:RRSeed=rng("services",z); if(r.next()>0.24) return;
         var id:String="";
         if(["workshop","service","control"].indexOf(z.role)>=0) id="work";
         if(z.role=="medical" && p.theme!="plant" && p.theme!="sewer") id="himlab";
         if(z.role=="kitchen") id="stove";
         if(!id && p.theme!="sewer" && z.d<30 && r.next()<0.16) id=r.next()<0.7?"vendor":"doctor";
         if(id) add(z,id,"service","floor",0,null,"service","room-purpose");
      }
      public function appendMetadata(meta:XML):void
      {
         for each(var z:Object in zones) meta.appendChild(<zone id={z.id} role={z.role} danger={z.d} value={z.v} pressure={z.pressure.toFixed(2)} limit={z.limit.toFixed(2)}/>);
         for each(var point:Object in points)
         {
            var node:XML=<point/>;
            for(var key:String in point) node.@[key]=point[key];
            meta.appendChild(node);
         }
         for each(var t:Object in turrets) meta.appendChild(<gun uid={t.uid} zone={t.zone} mount={t.mount} x={t.ox} y={t.oy} targetX={t.target.x} targetY={t.target.y} purpose={t.target.kind}/>);
         if(terminal)
         {
            var control:XML=<control uid={terminal.uid} scope="location" operator={terminal.node} from={terminal.from} path={terminal.path.join(",")} model="terrain-walk-climb-cover"/>;
            for each(var entry:Object in terminal.entries) control.appendChild(<entry slot={entry.slot} state={entry.state}/>);
            meta.appendChild(control);
         }
      }
   }
}
