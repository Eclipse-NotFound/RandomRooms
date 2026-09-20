package rr
{
   /** Conservative two-tile clearance with directed walking, climbing and
    * falling edges. Falling is never treated as evidence of a return route.
    * Real movement probes remain necessary; this is a generation rejection
    * gate, not an imitation of the game's complete physics. */
   public class RRTraversal
   {
      public static function check(plan:RRArchitecture,dry:Boolean=false):void
      {
         var clear:Array=[],climb:Array=[],stand:Array=[],hard:Array=[],slope:Array=[];
         var forward:Array=[],reverse:Array=[];
         var glass:Object={};
         for each (var window:Object in plan.windows)
         { glass[window.y*48+window.x]=true; glass[(window.y-1)*48+window.x]=true; }
         var x:int,y:int,i:int;
         for (y=0;y<25;y++) for (x=0;x<48;x++)
         { i=y*48+x; hard[i]=plan.solid(x,y) || glass[i]; }
         for (y=1;y<25;y++) for (x=0;x<47;x++)
         {
            i=y*48+x;
            clear[i]=!hard[i] && !hard[i+1] && !hard[i-48] && !hard[i-47];
            if (dry && (String(plan.grid[y][x]).indexOf("*")>=0 || String(plan.grid[y][x+1]).indexOf("*")>=0 ||
               String(plan.grid[y-1][x]).indexOf("*")>=0 || String(plan.grid[y-1][x+1]).indexOf("*")>=0)) clear[i]=false;
            if (!clear[i]) continue;
            forward[i]=[]; reverse[i]=[];
            climb[i]=false;
            if (String(plan.grid[y][x+1]).indexOf("А")>=0) climb[i]=true;
            stand[i]=false;
            slope[i]=false;
            for (var sy:int=y;sy<=Math.min(24,y+1);sy++) for (var sx:int=x;sx<=x+1;sx++)
               if(/[ВГ]/.test(String(plan.grid[sy][sx]))) slope[i]=true;
            if (y<24)
               for (var xx:int=x;xx<=x+1;xx++)
                  if (hard[(y+1)*48+xx] || String(plan.grid[y+1][xx]).indexOf("-")>=0 ||
                     (String(plan.grid[y+1][xx]).indexOf("А")>=0 && String(plan.grid[y][xx]).indexOf("А")<0)) stand[i]=true;
            if(slope[i]) stand[i]=true;
         }
         for (y=1;y<25;y++) for (x=0;x<47;x++)
         {
            i=y*48+x;
            if (!clear[i]) continue;
            for each (var dx:int in [-1,1])
            {
               var n:int=i+dx;
               if (x+dx>=0 && x+dx<47 && clear[n] && (stand[i] || stand[n] || climb[i] || climb[n])) edge(forward,reverse,i,n);
               for each(var dy:int in [-1,1])
               {
                  var diagonal:int=n+dy*48;
                  if(x+dx>=0 && x+dx<47 && clear[diagonal] && (slope[i] || slope[diagonal]) &&
                     (clear[n] || clear[i+dy*48])) edge(forward,reverse,i,diagonal);
               }
            }
            n=i-48;
            if (clear[n] && (climb[i] || climb[n])) edge(forward,reverse,i,n);
            n=i+48;
            if (clear[n] && (!hard[n] && !hard[n+1])) edge(forward,reverse,i,n);
         }
         var start:int=plan.spawn.y*48+plan.spawn.x;
         var reached:Object=flood(forward,start), returned:Object=flood(reverse,start);
         for (i=0;i<clear.length;i++)
            if (clear[i] && stand[i] && (!reached[i] || !returned[i]))
               throw new Error((dry?"Dry ":"")+"floor lacks a walking/climbing return "+(i%48)+","+int(i/48));
         for (var p:int=0;p<22;p++) if (plan.ports[p]>=2)
         {
            var b:Object=RRPorts.rect(p,plan.ports[p]);
            x=RRPorts.vertical(p)?b.x0:(p>=11?0:46);
            y=RRPorts.vertical(p)?(p>=17?1:24):b.y1;
            i=y*48+x;
            if (!reached[i] || !returned[i]) throw new Error("Port lacks a walking/climbing return "+p);
         }
      }
      private static function edge(a:Array,b:Array,from:int,to:int):void { a[from].push(to); b[to].push(from); }
      private static function flood(edges:Array,start:int):Object
      {
         var seen:Object={},q:Array=[start]; seen[start]=true;
         for (var at:int=0;at<q.length;at++) for each (var n:int in edges[q[at]])
            if (!seen[n]) { seen[n]=true; q.push(n); }
         return seen;
      }
   }
}
