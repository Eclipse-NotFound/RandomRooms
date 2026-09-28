package rr
{
   /** Closed native doors split immediate contact sectors, not sound-proof
    * rooms. Open bypasses rejoin sectors. Nearby sectors still share a cap. */
   public class RREncounters
   {
      public var sectors:Array=[];
      public var rejected:int=0;
      private var nodes:Object={};
      private var gates:Object={};
      private var p:RRArchitecture;
      private var tactics:RRTactics;
      private var placed:Array=[];
      private var limit:Number;
      public function RREncounters(plan:RRArchitecture,model:RRTactics,danger:int)
      {
         p=plan; tactics=model; limit=2.8+2.2*danger/100;
         var blocked:Object={},adj:Object={},i:int,x:int,y:int;
         for each(var d:Object in p.doors)
            for(y=d.y-(d.id=="stdoor" || d.id=="door3"?2:1);y<=d.y;y++) gates[y*48+d.x]=true;
         for each(d in p.hatches) { gates[d.y*48+d.x]=true; gates[d.y*48+d.x+1]=true; }
         for(i=0;i<tactics.clear.length;i++) if(tactics.clear[i])
         {
            if(gates[i] || gates[i+1] || gates[i-48] || gates[i-47]) blocked[i]=true;
            else adj[i]=[];
         }
         for(i=0;i<tactics.edges.length;i++) if(adj[i])
            for each(var next:int in tactics.edges[i]) if(adj[next]) { adj[i].push(next); adj[next].push(i); }
         for(var key:String in adj) if(!nodes.hasOwnProperty(key))
         {
            var sector:Object={id:sectors.length,pressure:0,limit:limit,nodes:0},queue:Array=[int(key)];
            nodes[key]=sector.id; sectors.push(sector);
            for(var at:int=0;at<queue.length;at++)
            {
               sector.nodes++;
               for each(next in adj[queue[at]]) if(!nodes.hasOwnProperty(next)) { nodes[next]=sector.id; queue.push(next); }
            }
         }
      }
      public function sectorAt(a:Object):int
      {
         var n:int=a.y*48+a.x;
         for each(var delta:int in [0,-1,1,-48,48]) if(nodes.hasOwnProperty(n+delta)) return int(nodes[n+delta]);
         // One-tile flying/ceiling actors can fit where the pony's 2x2 graph
         // has no node. Attach them to the nearest unobstructed contact space,
         // never through a closed gate or solid corner.
         var nearest:int=-1,best:Number=1e9;
         for(var key:String in nodes)
         {
            var node:int=int(key),x:Number=node%48+1,y:Number=int(node/48)+0.2;
            var dx:Number=x-a.x-0.5,dy:Number=y-a.y-0.5,d:Number=dx*dx+dy*dy;
            if(d>=best) continue;
            var clear:Boolean=true,steps:int=Math.ceil(Math.max(Math.abs(dx),Math.abs(dy))*5);
            for(var i:int=0;i<=steps;i++)
            {
               var xx:int=int(a.x+0.5+dx*i/Math.max(1,steps)),yy:int=int(a.y+0.5+dy*i/Math.max(1,steps));
               if(p.solid(xx,yy) || gates[yy*48+xx]) { clear=false; break; }
            }
            if(clear) { best=d; nearest=int(nodes[key]); }
         }
         return nearest;
      }
      public function separation(a:Object):Number
      {
         var nearest:Number=14;
         for each(var b:Object in placed) nearest=Math.min(nearest,Math.sqrt(distance(a,b)));
         return nearest;
      }
      private function distance(a:Object,b:Object):Number
      { return (a.x-b.x)*(a.x-b.x)+(a.y-b.y)*(a.y-b.y); }
      public function allows(a:Object,kind:String,cost:Number):Boolean
      {
         if(cost<=0) return true;
         var sector:int=sectorAt(a);
         if(sector<0) { rejected++; return false; }
         if(sector>=0 && sectors[sector].pressure+cost>limit+0.0001) { rejected++; return false; }
         var near:Number=cost;
         for each(var b:Object in placed)
         {
            var dist:Number=distance(a,b);
            // Major defenders have at least 160 px between spawn anchors.
            // A door does not make touching spawn points acceptable.
            if((kind=="enemy" || kind=="security") && (b.kind=="enemy" || b.kind=="security") && dist<16)
            { rejected++; return false; }
            if(dist<49) near+=b.cost;
         }
         if(near>limit+1.0) { rejected++; return false; }
         // A new point must also respect each existing neighbourhood's cap.
         for each(b in placed) if(distance(a,b)<49)
         {
            near=cost+b.cost;
            for each(var other:Object in placed) if(other!=b && distance(b,other)<49) near+=other.cost;
            if(near>limit+1.0) { rejected++; return false; }
         }
         return true;
      }
      public function record(a:Object,kind:String,cost:Number):int
      {
         var id:int=sectorAt(a);
         if(cost>0)
         {
            if(id>=0) sectors[id].pressure+=cost;
            placed.push({x:a.x,y:a.y,kind:kind,cost:cost});
         }
         return id;
      }
      public function append(meta:XML):void
      {
         for each(var s:Object in sectors) if(s.pressure>0)
            meta.appendChild(<encounter id={s.id} pressure={s.pressure.toFixed(2)} limit={s.limit.toFixed(2)} nodes={s.nodes} model="closed-doors-open-bypasses-nearby-pressure"/>);
      }
   }
}
