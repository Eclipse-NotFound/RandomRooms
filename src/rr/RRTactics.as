package rr
{
   /** Terrain-only conservative movement and exposure model. Doors and glass
    * are never counted as permanent ballistic cover. Furniture is placed later
    * and kept off the selected approach. Actual native movement is tested too. */
   public class RRTactics
   {
      public var entries:Array=[];
      public var edges:Array=[];
      public var stand:Array=[];
      public var clear:Array=[];
      private var p:RRArchitecture;
      public function RRTactics(plan:RRArchitecture)
      {
         p=plan;
         var climb:Array=[],slope:Array=[],direction:Array=[],hard:Array=[],glass:Object={};
         for each(var window:Object in p.windows)
         { glass[window.y*48+window.x]=true; glass[(window.y-1)*48+window.x]=true; }
         var x:int,y:int,i:int,n:int,xx:int;
         for(y=0;y<25;y++) for(x=0;x<48;x++) hard[y*48+x]=p.solid(x,y) || glass[y*48+x];
         for(y=1;y<25;y++) for(x=0;x<47;x++)
         {
            i=y*48+x;
            clear[i]=!hard[i] && !hard[i+1] && !hard[i-48] && !hard[i-47];
            for(var yy:int=y-1;yy<=y;yy++) for(xx=x;xx<=x+1;xx++)
               if(/[*,;]/.test(String(p.grid[yy][xx]))) clear[i]=false;
            if(!clear[i]) continue;
            edges[i]=[]; climb[i]=String(p.grid[y][x+1]).indexOf("А")>=0; stand[i]=false;
            for(var sy:int=y;sy<=Math.min(24,y+1);sy++) for(var sx:int=x;sx<=x+1;sx++)
               if(/[ВГ]/.test(String(p.grid[sy][sx])))
               { slope[i]=true; direction[i]=String(p.grid[sy][sx]).indexOf("Г")>=0?1:-1; }
            if(y<24) for(xx=x;xx<=x+1;xx++)
               if(hard[(y+1)*48+xx] || String(p.grid[y+1][xx]).indexOf("-")>=0 ||
                  (String(p.grid[y+1][xx]).indexOf("А")>=0 && String(p.grid[y][xx]).indexOf("А")<0)) stand[i]=true;
            if(slope[i]) stand[i]=true;
         }
         for(y=1;y<25;y++) for(x=0;x<47;x++)
         {
            i=y*48+x; if(!clear[i]) continue;
            for each(var dx:int in [-1,1])
            {
               n=i+dx;
               if(x+dx<0 || x+dx>=47) continue;
               if(clear[n] && (stand[i] || stand[n] || climb[i] || climb[n])) edges[i].push(n);
               for each(var dy:int in [-1,1])
               {
                  var d:int=n+dy*48;
                  if(clear[d] && (slope[i] || slope[d]) && dy==dx*(slope[i]?direction[i]:direction[d]) &&
                     (clear[n] || clear[i+dy*48])) edges[i].push(d);
               }
            }
            if(clear[i-48] && (climb[i] || climb[i-48])) edges[i].push(i-48);
            if(clear[i+48]) edges[i].push(i+48);
         }
         for(var slot:int=0;slot<22;slot++) if(p.ports[slot]>=2)
         {
            var b:Object=RRPorts.rect(slot,p.ports[slot]);
            x=RRPorts.vertical(slot)?b.x0:(slot>=11?0:46);
            y=RRPorts.vertical(slot)?(slot>=17?1:24):b.y1;
            entries.push({slot:slot,x:x,y:y,node:y*48+x});
         }
      }
      public function line(ax:Number,ay:Number,bx:Number,by:Number):Boolean
      {
         var steps:int=Math.ceil(Math.max(Math.abs(ax-bx),Math.abs(ay-by))*5);
         for(var i:int=1;i<steps;i++) if(p.solid(int(ax+(bx-ax)*i/steps),int(ay+(by-ay)*i/steps))) return false;
         return true;
      }
      public function exposed(t:Object,x:Number,y:Number):Boolean
      {
         var dx:Number=x-t.ox,dy:Number=y-t.oy;
         // Native fixRot=1 excludes the upper wedge, not everything beyond
         // the idle aRot=[30,150] scan. No artificial short safe range.
         var angle:Number=Math.atan2(dy,dx)*180/Math.PI;
         if(t.mount=="ceiling" && angle>-150 && angle<-30) return false;
         if(t.id=="armturret" && (t.turn>0?Math.abs(angle)>30:Math.abs(angle)<150)) return false;
         return line(t.ox,t.oy,x,y);
      }
      public function bodyExposed(t:Object,x:int,y:int):Boolean
      {
         for each(var px:Number in [x+0.2,x+1,x+1.8])
            for each(var py:Number in [y-0.8,y+0.1,y+0.8]) if(exposed(t,px,py)) return true;
         return false;
      }
      public function protectsEntry(t:Object):Boolean
      {
         for each(var e:Object in entries)
            for(var dx:int=-1;dx<=1;dx++) for(var dy:int=-1;dy<=1;dy++)
               if(clear[(e.y+dy)*48+e.x+dx] && bodyExposed(t,e.x+dx,e.y+dy)) return false;
         return !bodyExposed(t,p.spawn.x,p.spawn.y);
      }
      public function blockedBy(turrets:Array):Object
      {
         var blocked:Object={};
         for(var i:int=0;i<clear.length;i++) if(clear[i])
            for each(var t:Object in turrets) if(bodyExposed(t,i%48,int(i/48))) { blocked[i]=true; break; }
         return blocked;
      }
      public function flood(start:int,blocked:Object=null):Object
      {
         var distances:Object={},parents:Object={},q:Array=[];
         if(clear[start] && !(blocked && blocked[start])) { distances[start]=0; q.push(start); }
         for(var at:int=0;at<q.length;at++) for each(var next:int in edges[q[at]])
            if(!distances.hasOwnProperty(next) && !(blocked && blocked[next]))
            { distances[next]=distances[q[at]]+1; parents[next]=q[at]; q.push(next); }
         return {distances:distances,parents:parents,start:start};
      }
      public function path(reach:Object,to:int):Array
      {
         var out:Array=[];
         if(!reach.distances.hasOwnProperty(to)) return out;
         while(to!=reach.start) { out.unshift(to); to=reach.parents[to]; }
         out.unshift(reach.start); return out;
      }
      public function reservePath(nodes:Array):void
      {
         for each(var node:int in nodes) p.reserve(node%48,int(node/48)-1,node%48+1,int(node/48));
      }
   }
}
