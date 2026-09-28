package rr
{
   /** Bounded, demand-first rectangular floorplans. A five-region staggered
    * operation can break a full-width/full-height slicing seam; each region is
    * recursively subdivided. No native terrain or fixed room coordinates. */
   public class RRPartitionPlan
   {
      public var info:Object;
      public var masses:Array;
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

      public function build(theme:String,form:String,boundary:Array,modern:Boolean=false):Array
      {
         ports=boundary; visits=0; masses=[];
         program=new RRSpaceRules(rnd).create(theme,form,modern);
         var whole:Object=rect(1,1,46,23),out:Array;
         var layout:String=rnd()<program.levels?"storeys":
            (rnd()<0.28 && form!="cistern" && form!="street_links" && form!="rooftops"?"staggered":"sliced");
         if(modern && rnd()<0.48 && form!="street_links" && form!="rooftops") layout="wings";
         out=layout=="wings"?wings(whole,program.rooms):(layout=="storeys"?storeys(whole,program.rooms):(layout=="staggered"?staggered(whole,program.rooms):split(whole,program.rooms)));
         if(out==null) throw new Error("Partition demand search exhausted: "+layout);
         // The explicit common-floor operation must survive local editing.
         var shifted:int=layout=="storeys" || layout=="wings"?0:retile(out);
         var usable:Array=[];
         for each(var cell:Object in out)
            if(cell.role=="mass") masses.push(cell); else usable.push(cell);
         out=usable;
         validatePorts(out);
         info={main:program.main,variant:program.variant,layout:layout,density:program.density,
            requested:program.requested,count:out.length,masses:masses.length,visits:visits,retiled:shifted,extra:program.extra};
         return out;
      }
      private function feasible(r:Object,items:Array):Boolean
      {
         if(!items.length || width(r)<5 || height(r)<3) return false;
         var need:int=0,capacity:int=0;
         for each(var p:Object in items)
         {
            if(p.minW>width(r) || p.minH>height(r) || (p.edge=="top" && r.top!=1)) return false;
            need+=p.minW*p.minH; capacity+=p.hasOwnProperty("maxArea")?Math.min(p.maxArea,p.maxW*p.maxH):p.maxW*p.maxH;
         }
         if(need+(items.length-1)*4>area(r) || capacity<area(r)) return false;
         if(items.length==1)
         {
            p=items[0];
            if(width(r)>p.maxW || height(r)>p.maxH) return false;
            if(p.hasOwnProperty("maxArea") && area(r)>p.maxArea) return false;
            if(p.role=="mass")
               for(var port:int=0;port<22;port++) if(ports[port]>=2)
               {
                  var socket:Object=RRPorts.rect(port,ports[port]);
                  if(RRPorts.vertical(port))
                  {
                     if((port>=17?r.top==1:r.floor==23) && r.x0<=socket.x1+1 && r.x1>=socket.x0-1) return false;
                  }
                  else if((port>=11?r.x0==1:r.x1==46) && r.top<=socket.y1 && r.floor>=socket.y0) return false;
               }
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
            // A solid ceiling directly above the aperture is valid. The old
            // extra-row guard forced a 7-high room at the y=7 side socket.
            if(!vertical && !RRPorts.vertical(p) && ((p>=11 && r.x0==1) || (p<6 && r.x1==46)) && c>=b.y0 && c<=b.y1) return false;
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
            var lo:int=vertical?r.x0+5:r.top+3,hi:int=vertical?r.x1-5:r.floor-3;
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
      /** Generate shared ceiling/floor bands, then allocate the pre-existing
       * use demands to them. Band count and heights vary; vertical room walls
       * do not have to align with the storey above. Not a fixed 3-tier template. */
      private function storeys(r:Object,items:Array):Array
      {
         var tall:int=0;
         for each(var p:Object in items) tall=Math.max(tall,int(p.minH));
         for(var trial:int=0;trial<80 && visits<maxVisits;trial++)
         {
            visits++;
            var counts:Array=program.theme=="mane"?[3,3,3,4,5]:[4,5,5];
            var count:int=tall>7?n(2,3):counts[n(0,counts.length-1)];
            count=Math.min(count,items.length,int((height(r)+1)/4));
            var hs:Array=[],remaining:int=height(r)-(count-1)-3*count;
            if(remaining<0) continue;
            for(var b:int=0;b<count;b++) hs.push(3);
            var tallBand:int=tall>7?n(0,count-1):-1;
            if(tallBand>=0) { hs[tallBand]=tall; remaining-=tall-3; }
            if(remaining<0) continue;
            var tries:int=0;
            while(remaining>0 && tries++<100)
            {
               var preferred:int=program.theme=="mane"?7:4,shorter:Array=[];
               for(b=0;b<count;b++) if(b!=tallBand && hs[b]<preferred) shorter.push(b);
               b=shorter.length?shorter[n(0,shorter.length-1)]:n(0,count-1);
               if(hs[b]>=(b==tallBand?21:(program.theme=="mane"?7:6))) continue;
               hs[b]++; remaining--;
            }
            if(remaining) continue;
            var bands:Array=[],y:int=r.top,good:Boolean=true;
            for(b=0;b<count;b++)
            {
               bands.push(rect(r.x0,y,r.x1,y+hs[b]-1));
               if(b<count-1 && !cutOK(r,false,y+hs[b])) good=false;
               y+=hs[b]+1;
            }
            if(!good) continue;
            for(var assignment:int=0;assignment<20 && visits<maxVisits;assignment++)
            {
               visits++;
               var groups:Array=[],used:Array=[];
               for(b=0;b<count;b++) { groups.push([]); used.push(0); }
               var pending:Array=items.concat(); shuffle(pending);
               pending.sort(function(a:Object,b:Object):Number { return b.minH-a.minH; });
               good=true;
               for(var i:int=0;i<pending.length;i++)
               {
                  p=pending[i]; var choices:Array=[],empty:int=0;
                  for(b=0;b<count;b++) if(!groups[b].length) empty++;
                  for(b=0;b<count;b++)
                  {
                     if(pending.length-i==empty && groups[b].length) continue;
                     if(hs[b]<p.minH || hs[b]>p.maxH || (p.edge=="top" && bands[b].top!=1)) continue;
                     if(used[b]+p.minW+(groups[b].length?1:0)>width(r)) continue;
                     if(p.role=="canal" && !feasible(bands[b],[p])) continue;
                     choices.push({index:b,score:(width(r)-used[b])*(0.5+rnd())});
                  }
                  if(!choices.length) { good=false; break; }
                  choices.sortOn("score",Array.NUMERIC|Array.DESCENDING); b=choices[0].index;
                  used[b]+=p.minW+(groups[b].length?1:0); groups[b].push(p);
               }
               if(!good) continue;
               for(b=0;b<count;b++) if(!feasible(bands[b],groups[b])) good=false;
               if(!good) continue;
               var result:Array=[];
               for(b=0;b<count;b++)
               {
                  var part:Array=split(bands[b],groups[b]);
                  if(part==null) { good=false; break; }
                  result=result.concat(part);
               }
               if(good) return result;
            }
         }
         return null;
      }
      /** Independently aligned wings. The dividing axis, position, use demands
       * and local floor bands are solved together, not chosen from coordinates. */
      private function wings(r:Object,items:Array):Array
      {
         for(var trial:int=0;trial<36 && visits<maxVisits;trial++)
         {
            visits++;
            var order:Array=items.concat(); shuffle(order);
            var k:int=n(2,Math.max(2,items.length-2)),aa:Array=order.slice(0,k),bb:Array=order.slice(k);
            if(!bb.length) continue;
            var vertical:Boolean=rnd()<0.8,c:int=vertical?n(r.x0+12,r.x1-12):n(r.top+7,r.floor-7);
            if(!cutOK(r,vertical,c)) continue;
            var a:Object=rect(r.x0,r.top,vertical?c-1:r.x1,vertical?r.floor:c-1);
            var b:Object=rect(vertical?c+1:r.x0,vertical?r.top:c+1,r.x1,r.floor);
            if(!feasible(a,aa) || !feasible(b,bb)) continue;
            var first:Array=rnd()<0.7?storeys(a,aa):split(a,aa);
            if(first==null) continue;
            var second:Array=rnd()<0.5?storeys(b,bb):split(b,bb);
            if(second!=null) return first.concat(second);
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
