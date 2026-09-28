'use strict';
const $=id=>document.getElementById(id),roles={workshop:'车间',warehouse:'仓储',service:'检修',control:'控制',living:'居住',office:'办公',store:'储物',medical:'医疗',hall:'大厅',corridor:'通道',canal:'水渠',kitchen:'厨房',street:'街道',roof:'屋顶'};
const layouts={sliced:'递归分区',storeys:'对齐楼层',staggered:'错位分区',wings:'局部楼层＋分翼'};
let list=[];
function populate(){list=window.reviewData.filter(r=>r.scene===$('scene').value);$('sample').replaceChildren(...list.map((r,i)=>{const o=document.createElement('option');o.value=i;o.textContent=`${r.image?'★ ':''}${r.seed} · 坐标 ${r.x},${r.y}`;return o;}));$('sample').value=Math.max(0,list.findIndex(r=>r.image));draw();}
function render(name,room){const c=$(name).getContext('2d'),s=20;c.clearRect(0,0,960,500);let solid=0;
 room.grid.forEach((row,y)=>row.forEach((v,x)=>{const wall=/^[A-T]/.test(v);if(wall&&x>0&&x<47&&y>0&&y<24)solid++;
 c.fillStyle=wall?(v[0]==='F'?'#ae805d':'#5c7075'):(v.includes('*')?'#245b70':'#1c2c33');c.fillRect(x*s,y*s,s,s);
 if(/[АБ]/.test(v)){c.strokeStyle='#bbcaaf';c.beginPath();c.moveTo(x*s+5,y*s);c.lineTo(x*s+5,(y+1)*s);c.moveTo(x*s+15,y*s);c.lineTo(x*s+15,(y+1)*s);c.moveTo(x*s+5,y*s+10);c.lineTo(x*s+15,y*s+10);c.stroke();}
 if(/[-ДЕКНР]/.test(v)){c.fillStyle='#bbcaaf';c.fillRect(x*s,y*s,s,3);}if(/[ВГИЙЛМ]/.test(v)){c.strokeStyle='#bbcaaf';c.beginPath();c.moveTo(x*s,(y+1)*s);c.lineTo((x+1)*s,y*s);c.stroke();}}));
 if($('values').checked)room.spaces.filter(r=>r.kind!=='gallery').forEach(r=>{c.strokeStyle='#70b9b788';c.strokeRect(+r.x0*s,+r.top*s,(r.x1-r.x0+1)*s,(r.floor-r.top+1)*s);c.font='12px Microsoft YaHei';c.fillStyle='#e5eddf';c.fillText(`${roles[r.role]||r.role} D${r.danger} V${r.value}`,+r.x0*s+4,+r.top*s+15);});
 room.objects.forEach(o=>{const x=(+o.x+.5)*s,y=(+o.y+.5)*s,k=o.rrContent;
 if(o.rrFixture==='door'||o.rrFixture==='hatch'){c.fillStyle='#6dc9d7';if(o.rrFixture==='door')c.fillRect(x-3,y-30,6,40);else c.fillRect(x-10,y-3,40,6);}
 else if(k==='enemy'||k==='security'){c.fillStyle=k==='enemy'?'#fe7d80':'#e79bfc';c.beginPath();c.arc(x,y,6,0,Math.PI*2);c.fill();}
 else if(['reward','loot','cache'].includes(k)){c.strokeStyle='#e9c175';c.lineWidth=2;c.strokeRect(x-5,y-5,10,10);c.lineWidth=1;}
 else if(['special','hazard'].includes(k)){c.fillStyle='#e9a46f';c.fillRect(x-3,y-3,6,6);}});
 const enemies=room.objects.filter(o=>o.rrContent==='enemy'||o.rrContent==='security').length;
 $(name+'Info').textContent=`${layouts[room.attrs.rrP_layout]} · 主要敌人 / 炮塔 ${enemies} · 内框实体占比 ${(solid/1058*100).toFixed(1)}% · 隐藏奖励 ${room.caches.length}`;
}
function draw(){const r=list[+$('sample').value];if(!r)return;render('old',r.old);render('new',r.new);$('native').hidden=!r.image;$('noImage').hidden=!!r.image;if(r.image){for(const v of ['before','after']){$(v+'Img').src=`native/${r.image}-${v}.png`;$(v+'Link').href=`native/${r.image}-${v}.png`;}}location.hash=`${r.scene}/${r.index}`;}
$('scene').addEventListener('change',populate);$('sample').addEventListener('change',draw);$('values').addEventListener('change',draw);$('next').addEventListener('click',()=>{$('sample').value=(+$('sample').value+1)%list.length;draw();});
const initial=location.hash.slice(1).split('/');if(['plant','stable','sewer','mane'].includes(initial[0]))$('scene').value=initial[0];populate();const start=list.findIndex(r=>String(r.index)===initial[1]);if(start>=0){$('sample').value=start;draw();}
