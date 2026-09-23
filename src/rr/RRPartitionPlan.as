package rr
{
   /** Bounded, demand-first rectangular floorplans. A five-region staggered
    * operation can break a full-width/full-height slicing seam; each region is
    * recursively subdivided. No native terrain or fixed room coordinates. */
   public class RRPartitionPlan
   {
      public var info:Object;
      private var rnd:Function;
      private var ports:Array;
      private var program:Object;
      private var visits:int;
      private var maxVisits:int=2400;
      private function n(a:int,b:int):int { return a+int(rnd()*(b-a+1)); }
      private function shuffle(a:Array):void
      { for(var i:int=a.length-1;i>0;i--) { var j:int=n(0,i),v:*=a[i]; a[i]=a[j]; a[j]=v; } }
      private function rect(x:int,y:int,right:int,bottom:int):Object { return {x0:x,top:y,x1:right,floor:bottom}; }
      private function width(r:Object):int { return r.x1-r.x0+1; }
      private function height(r:Object):int { return r.floor-r.top+1; }
      private function area(r:Object):int { return width(r)*height(r); }
      public function RRPartitionPlan(random:Function) { rnd=random; }

      public function build(theme:String,form:String,boundary:Array):Array
      {
         ports=boundary; visits=0;
         program=new RRSpaceRules(rnd).create(theme,form);
         var whole:Object=rect(1,1,46,23),out:Array;
         var interlocked:Boolean=rnd()<0.32 && form!="cistern" && form!="street_links" && form!="rooftops";
         out=interlocked?staggered(whole,program.rooms):split(whole,program.rooms);
         if(out==null) throw new Error("Partition demand search exhausted: "+(interlocked?"staggered":"sliced"));
         var shifted:int=retile(out);
         validatePorts(out);
         info={main:program.main,variant:program.variant,layout:interlocked?"staggered":"sliced",
            count:out.length,visits:visits,retiled:shifted,extra:program.extra};
         return out;
      }
      private function feasible(r:Object,items:Array):Boolean
      {
         if(!items.length || width(r)<7 || height(r)<4) return false;
         var need:int=0,capacity:int=0;
         for each(var p:Object in items)
         {
            if(p.minW>width(r) || p.minH>height(r) || (p.edge=="top" && r.top!=1)) return false;
            need+=p.minW*p.minH; capacity+=p.maxW*p.maxH;
         }
         if(need+(items.length-1)*4>area(r) || capacity<area(r)) return false;
         if(items.length==1)
         {
            p=items[0];
            if(width(r)>p.maxW || height(r)>p.maxH) return false;
            // Keep descending upper sockets out of the water vessel itself.
            // Its roof-adjacent dry spaces take those sockets instead.
            if(p.role=="canal" && r.top==1)
               for(var k:int=17;k<22;k++) if(ports[k]>=2)
               { var b:Object=RRPorts.rect(k,ports[k]); if(b.x0>=r.x0 && b.x0<=r.x1) return false; }
         }
         return true;
      }
      private function cutOK(r:Object,vertical:Boolean,c:int):Boolean
      {
         for(var p:int=0;p<22;p++) if(ports[p]>=2)
         {
            var b:Object=RRPorts.rect(p,ports[p]);
            if(vertical && RRPorts.vertical(p) && ((p>=17 && r.top==1) || (p<11 && r.floor==23)) && c>=b.x0-1 && c<=b.x1+1) return false;
            if(!vertical && !RRPorts.vertical(p) && ((p>=11 && r.x0==1) || (p<6 && r.x1==46)) && c>=b.y0-1 && c<=b.y1) return false;
         }
         return true;
      }
      private function weight(a:Array):Number
      { var w:Number=0; for each(var p:Object in a) w+=p.weight; return w; }
      private function split(r:Object,items:Array):Array
      {
         if(++visits>maxVisits || !feasible(r,items)) return null;
         if(items.length==1)
         {
            var p:Object=items[0],leaf:Object=rect(r.x0,r.top,r.x1,r.floor);
            leaf.role=p.role; leaf.spec=p; return [leaf];
         }
         for(var t:int=0;t<30 && visits<maxVisits;t++)
         {
            var order:Array=items.concat(); shuffle(order);
            if(rnd()<0.65)
            {
               var anchor:String=order[0].role,ranked:Array=[];
               for each(var related:Object in order)
                  ranked.push({item:related,score:RRSpaceRules.affinity(program.theme,anchor,related.role)*(0.35+rnd())});
               ranked.sortOn("score",Array.NUMERIC|Array.DESCENDING); order=[];
               for each(var rankedItem:Object in ranked) order.push(rankedItem.item);
            }
            var k:int=n(1,order.length-1),left:Array=order.slice(0,k),right:Array=order.slice(k);
            var vertical:Boolean=rnd()<program.vertical;
            var lo:int=vertical?r.x0+7:r.top+4,hi:int=vertical?r.x1-7:r.floor-4;
            if(lo>hi) continue;
            var fraction:Number=weight(left)/(weight(left)+weight(right));
            var c:int=rnd()<0.25?n(lo,hi):int((vertical?r.x0:r.top)+(vertical?width(r):height(r))*(fraction+(rnd()-0.5)*0.34));
            c=Math.max(lo,Math.min(hi,c));
            if(!cutOK(r,vertical,c)) continue;
            var a:Object=rect(r.x0,r.top,vertical?c-1:r.x1,vertical?r.floor:c-1);
            var b:Object=rect(vertical?c+1:r.x0,vertical?r.top:c+1,r.x1,r.floor);
            if(!feasible(a,left) || !feasible(b,right)) continue;
            var aa:Array=split(a,left); if(aa==null) continue;
            var bb:Array=split(b,right); if(bb!=null) return aa.concat(bb);
         }
         return null;
      }
      private function staggered(r:Object,items:Array):Array
      {
         for(var attempt:int=0;attempt<18 && visits<maxVisits;attempt++)
         {
            var lx:int=n(8,19),rx:int=n(lx+6,38),ty:int=n(6,11),by:int=n(ty+4,18);
            var boxes:Array=[rect(lx,ty,rx,by),rect(1,1,rx,ty-2),rect(rx+2,1,46,by),rect(lx,by+2,46,23),rect(1,ty,lx-2,23)];
            if(rnd()<0.5) for each(var mirror:Object in boxes)
            { var old:int=mirror.x0; mirror.x0=47-mirror.x1; mirror.x1=47-old; }
            for(var assignment:int=0;assignment<12 && visits<maxVisits;assignment++)
            {
               var groups:Array=[[],[],[],[],[]],pending:Array=items.concat();
               pending.sort(function(a:Object,b:Object):Number { return b.minW*b.minH-a.minW*a.minH; });
               var good:Boolean=true;
               for(var i:int=0;i<pending.length;i++)
               {
                  var empty:int=0;
                  for(var q:int=0;q<5;q++) if(!groups[q].length) empty++;
                  var choices:Array=[];
                  for(q=0;q<5;q++)
                  {
                     if(pending.length-i==empty && groups[q].length) continue;
                     var candidate:Array=groups[q].concat([pending[i]]);
                     // Prefixes need only minimum fit; maximum fill is checked
                     // after all demands have been assigned to a region.
                     var minArea:int=0,ok:Boolean=true;
                     for each(var item:Object in candidate)
                     { minArea+=item.minW*item.minH; if(item.minW>width(boxes[q]) || item.minH>height(boxes[q])) ok=false; }
                     if(ok && minArea+4*(candidate.length-1)<=area(boxes[q]))
                        choices.push({index:q,score:area(boxes[q])/(weight(candidate)+0.5)*(0.35+rnd())});
                  }
                  if(!choices.length) { good=false; break; }
                  choices.sortOn("score",Array.NUMERIC|Array.DESCENDING);
                  groups[choices[0].index].push(pending[i]);
               }
               if(!good) continue;
               for(q=0;q<5;q++) if(!feasible(boxes[q],groups[q])) good=false;
               if(!good) continue;
               var out:Array=[];
               for(q=0;q<5;q++)
               { var part:Array=split(boxes[q],groups[q]); if(part==null) { good=false; break; } out=out.concat(part); }
               if(good) return out;
            }
         }
         return null;
      }
      private function retile(a:Array):int
      {
         var changed:int=0;
         for(var t:int=0;t<12;t++)
         {
            var i:int=n(0,a.length-1),j:int=n(0,a.length-1); if(i==j) continue;
            var p:Object=a[i],q:Object=a[j];
            var side:Boolean=p.top==q.top && p.floor==q.floor && (p.x1+2==q.x0 || q.x1+2==p.x0);
            var stack:Boolean=p.x0==q.x0 && p.x1==q.x1 && (p.floor+2==q.top || q.floor+2==p.top);
            if(!side && !stack) continue;
            var box:Object=rect(Math.min(p.x0,q.x0),Math.min(p.top,q.top),Math.max(p.x1,q.x1),Math.max(p.floor,q.floor));
            maxVisits=visits+100;
            var fresh:Array=split(box,[p.spec,q.spec]);
            maxVisits=2400;
            if(fresh!=null && JSON.stringify([p.x0,p.top,p.x1,p.floor])!=JSON.stringify([fresh[0].x0,fresh[0].top,fresh[0].x1,fresh[0].floor]))
            { a[i]=fresh[0]; a[j]=fresh[1]; changed++; }
         }
         return changed;
      }
      private function validatePorts(rooms:Array):void
      {
         for(var p:int=0;p<22;p++) if(ports[p]>=2)
         {
            var b:Object=RRPorts.rect(p,ports[p]),found:Boolean=false;
            for each(var r:Object in rooms)
            {
               if(RRPorts.vertical(p))
               { if((p>=17?r.top==1:r.floor==23) && r.x0<=b.x0-1 && r.x1>=b.x1+1) found=true; }
               else if((p>=11?r.x0==1:r.x1==46) && r.top<=b.y0 && r.floor>=b.y1) found=true;
            }
            if(!found) throw new Error("Partition splits a shared socket "+p);
         }
      }
   }
}
