package rr
{
   /** Excavate usable recesses in real solid masses. A minority are optional
    * native weak F-material caches. No mandatory route depends on breaking a tile. */
   public class RRMassDetail
   {
      private var p:RRArchitecture;
      private var rnd:Function;
      public function RRMassDetail(plan:RRArchitecture,random:Function) { p=plan; rnd=random; }
      private function n(a:int,b:int):int { return a+int(rnd()*(b-a+1)); }
      public function build():void
      {
         var candidates:Array=[];
         for each(var r:Object in p.regions) if(r.hasOwnProperty("id") && r.role!="canal" && r.role!="street")
            for each(var dir:int in [-1,1])
            {
               var face:int=dir>0?r.x1+1:r.x0-1,f:int=r.floor;
               var depth:int=n(4,7),top:int=f-2,end:int=face+dir*(depth-1),lo:int=Math.min(face,end),hi:int=Math.max(face,end);
               if(lo<3 || hi>44 || top<2 || f>22) continue;
               var ok:Boolean=true;
               // A real floor at the mouth, clear approach, and a solid roof,
               // floor and far end. Do not cut a room, water bank or door frame.
               for(var x:int=face-dir*2;x!=face;x+=dir)
               {
                  if(!p.support(x,f)) ok=false;
                  for(var y:int=f-1;y<=f;y++) if(p.solid(x,y) || p.reserved[y+","+x]) ok=false;
               }
               for(y=top-1;y<=f+1;y++) for(x=lo;x<=hi;x++)
                  if(!p.solid(x,y) || p.reserved[y+","+x]) ok=false;
               for(y=top;y<=f;y++) if(!p.solid(end+dir,y)) ok=false;
               if(ok) candidates.push({face:face,dir:dir,x0:lo,x1:hi,top:top,floor:f,parent:r,score:rnd()});
            }
         candidates.sortOn("score",Array.NUMERIC);
         var changed:int=0,removed:int=0,target:int=n(1,p.theme=="sewer"?3:2);
         for each(var c:Object in candidates)
         {
            if(changed>=target) break;
            ok=true;
            for(y=c.top;y<=c.floor;y++) for(x=c.x0;x<=c.x1;x++) if(!p.solid(x,y) || p.reserved[y+","+x]) ok=false;
            if(!ok) continue;
            var sealed:Boolean=p.caches.length==0 && rnd()<0.48;
            var before:Array=[];
            for(y=c.top;y<=c.floor;y++) for(x=c.x0;x<=c.x1;x++)
            {
               before.push({x:x,y:y,code:p.grid[y][x]});
               p.grid[y][x]=sealed && x==c.face?"F"+c.parent.bg:"_"+c.parent.bg;
               if(sealed) p.hiddenCells[y*48+x]=true;
            }
            c.sealed=sealed; p.caches.push(c);
            if(!valid())
            {
               p.caches.pop();
               for each(var cell:Object in before) { p.grid[cell.y][cell.x]=cell.code; delete p.hiddenCells[cell.y*48+cell.x]; }
               continue;
            }
            changed++; removed+=(c.x1-c.x0+1-(sealed?1:0))*3;
            if(sealed)
            {
               // Content planning cannot use this as a troop pocket or a
               // terminal operating position. Its loot is placed separately.
               p.reserve(c.x0,c.top,c.x1,c.floor);
               c.x=c.dir>0?c.x1-1:c.x0; c.y=c.floor;
            }
            else
            {
               p.caches.pop();
               p.regions.push({id:p.regions.length,room:c.parent.room,x0:c.x0,x1:c.x1,top:c.top,floor:c.floor,
                  role:c.parent.role,bg:c.parent.bg,recess:true});
            }
            p.reserve(Math.min(c.face-c.dir*2,c.face),c.floor-1,Math.max(c.face-c.dir*2,c.face),c.floor);
         }
         if(p.partitionInfo) { p.partitionInfo.recesses=changed; p.partitionInfo.excavated=removed; p.partitionInfo.caches=p.caches.length; }
      }
      private function valid():Boolean
      {
         var saved:Array=[],hidden:Object=p.hiddenCells,good:Boolean=false;
         try
         {
            RRTraversal.check(p); if(p.pools.length) RRTraversal.check(p,true);
            // Check every newly reachable floor after ALL cache faces break,
            // including return paths. Closed caches were exempt only above.
            for each(var c:Object in p.caches) if(c.sealed)
               for(var y:int=c.top;y<=c.floor;y++)
               { saved.push({x:c.face,y:y,code:p.grid[y][c.face]}); p.grid[y][c.face]="_"+c.parent.bg; }
            p.hiddenCells={}; RRTraversal.check(p); if(p.pools.length) RRTraversal.check(p,true);
            good=true;
         }
         catch(error:*) { good=false; }
         for each(var cell:Object in saved) p.grid[cell.y][cell.x]=cell.code;
         p.hiddenCells=hidden; return good;
      }
   }
}
