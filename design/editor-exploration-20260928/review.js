/* Read-only view over frozen XML metadata. Does not generate or save rooms. */
'use strict';
const data=window.REVIEW_DATA;
const roles={workshop:'车间',warehouse:'仓储',service:'检修',control:'控制室',store:'储物',living:'居住',medical:'医疗',office:'办公',corridor:'通道',canal:'水渠',kitchen:'厨房',hall:'大厅',roof:'屋顶',street:'街道'};
const kinds={security:'炮塔',terminal:'终端',enemy:'主要敌群',ambient:'零散生物',hazard:'机关',special:'特殊威胁',damager:'伤害装置',trigger:'触发器',loot:'补给',reward:'高价值容器',service:'服务设施'};
const reasons={'major-group':'主要敌群预算','cache-patrol':'低危高值倾向的巡逻威胁','cache-blindspot':'藏物或盲区威胁','native-ecology-trap':'场景生态机关','paired-trap':'成组机关','ordinary-supplies':'普通补给机会','high-value-opportunity':'高价值物品机会','tactical-position':'战术位置','ambient-ecology':'场景中的零散生物','guard-link':'封锁连接处','industrial-residue':'工业残留物','location-turret-control':'为整间合成房的炮塔提供关闭方式','native-data-loot':'沿用原版容器内容','optional-cache-control':'可选藏物点的控制设施','optional-environment-hazard':'可选区域的环境危险','room-purpose':'配合房间用途'};
const labels={plant:'工厂',stable:'废弃避难厩',sewer:'下水道',mane:'城市废墟'};
const el=id=>document.getElementById(id);
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let current=data.cases[0];
function pointKind(p){return p.id==='term1'?'安保终端':kinds[p.kind]||p.kind;}
function xpoint(x){return (current.mirror?48-x:x)*40;}
function rect(x,y,w,h){return `${(current.mirror?48-x-w:x)*40},${y*40},${w*40},${h*40}`.split(',').map(Number);}
function color(kind){return kind==='security'?'#f296ff':kind==='terminal'?'#6fdde8':kind==='enemy'?'#ff6b73':kind==='ambient'?'#b6eaa0':['special','hazard','trigger','damager'].includes(kind)?'#ffb65c':'#ecdc83';}
function overlay(){
 let svg='';
 if(el('spaces').checked) for(const s of current.plan.space){
  const [x,y,w,h]=rect(+s.x0,+s.top,+s.x1-+s.x0+1,+s.floor-+s.top+1);
  const c=+s.danger>=65?'#fa8a91':+s.value>=65?'#eed58b':'#92d2ce';
  svg+=`<rect x="${x+2}" y="${y+2}" width="${w-4}" height="${h-4}" fill="${c}" fill-opacity=".045" stroke="${c}" stroke-opacity=".7"/>`;
  if(s.kind!=='gallery')svg+=`<text x="${x+8}" y="${y+25}" font-size="20" fill="${c}">${esc(roles[s.role]||s.role)} · D${s.danger} / V${s.value}</text>`;
 }
 if(el('tactics').checked){
  for(const g of current.plan.gun)svg+=`<path d="M${xpoint(+g.x)},${+g.y*40} L${xpoint(+g.targetX)},${+g.targetY*40}" fill="none" stroke="#f296ff" stroke-width="3" stroke-dasharray="10 9"/><circle cx="${xpoint(+g.targetX)}" cy="${+g.targetY*40}" r="7" stroke="#f296ff" fill="none"/>`;
  for(const c of current.plan.control){
   const pts=c.path.split(',').map(Number).map(n=>`${xpoint(n%48+1)},${(Math.floor(n/48)+.3)*40}`);
   svg+=`<polyline points="${pts.join(' ')}" fill="none" stroke="#6fdde8" stroke-width="3" stroke-dasharray="7 5"/>`;
  }
 }
 if(el('ports').checked) for(let p=0;p<22;p++){
  const n=current.worldPorts[p];if(n<2)continue;
  let x,y,w,h;
  if((p>=6&&p<=10)||p>=17){x=5+9*(p>=17?p-17:p-6)-(n>2?1:0);y=p>=17?0:23;w=n;h=2;}
  else{x=p>=11?0:46;y=3+4*(p>=11?p-11:p)-(n>2?2:1);w=2;h=n;}
  svg+=`<rect x="${x*40+3}" y="${y*40+3}" width="${w*40-6}" height="${h*40-6}" fill="#94d9ff" fill-opacity=".17" stroke="#a0d9ff" stroke-width="4"/>`;
 }
 if(el('points').checked) current.plan.point.forEach((p,i)=>{
  const width=(data.sizes[p.id]||[1,1])[0],x=xpoint(+p.x+width/2),y=(+p.y+.5)*40,c=color(p.kind);
  svg+=`<g class="point" tabindex="0" role="button" data-point="${i}" aria-label="${esc(pointKind(p)+' '+p.id)}" stroke="${c}"><circle cx="${x}" cy="${y}" r="11" fill="#101a20" fill-opacity=".7" stroke-width="2.5"/><path d="M${x-16},${y} h32 M${x},${y-16} v32" stroke-width="2"/><title>${esc(pointKind(p)+' · '+p.id)}</title></g>`;
  if(p.kind==='security'||p.id==='term1')svg+=`<text x="${Math.min(1730,Math.max(12,x-48))}" y="${y+(p.mount==='ceiling'?56:-28)}" font-size="21" fill="${c}">${p.id==='term1'?'安保终端':p.mount==='ceiling'?'顶装炮塔':'地面炮塔'}</text>`;
 });
 el('overlay').innerHTML=svg;
}
function selectPoint(index){
 const p=current.plan.point[index];if(!p)return;
 el('pointSelect').value=String(index);
 const zone=current.plan.zone.find(z=>z.id===p.zone);
 const pos=`原始格坐标 (${p.x}, ${p.y})${current.mirror?'，画面已镜像':''}`;
 const gun=current.plan.gun.find(g=>g.uid===p.uid);
 const purpose=gun?`；防守${({ladder:'梯口',opening:'开口',door:'门口'})[gun.purpose]||gun.purpose}`:'';
 el('selection').innerHTML=`<strong>${esc(pointKind(p))} · ${esc(p.id)}</strong><br>${esc(pos)}<br>${zone?`${esc(roles[zone.role]||zone.role)} · D ${zone.danger} / V ${zone.value}<br>`:''}依据：${esc(reasons[p.reason]||p.reason)}${esc(purpose)}${p.id==='term1'?'<br>关闭的是整间合成房的炮塔；青线仅为候选接近路。':''}`;
}
function show(theme){
 current=data.cases.find(c=>c.theme===theme)||data.cases[0];el('scene').value=current.theme;
 const c=current.context,r=current.render;
 el('native').src=current.preview;el('native').alt=`${labels[current.theme]} ${current.name} 的原生静态预览`;
 el('context').innerHTML=`<strong>${labels[current.theme]} · (${c.x}, ${c.y})</strong><span>v${c.rrVersion} · 主种子 ${c.rrMasterSeed}</span><span>基调 D ${c.rrDanger} / V ${c.rrValue}</span><span>${current.mirror?'已应用镜像':'未镜像'} · 强度 ${r.difficulty}</span><span>${current.plan.gun.length} 台炮塔 · ${current.plan.control.length} 个安保终端</span><a href="${current.sample}">完整房间 XML</a>`;
 el('pointSelect').innerHTML=current.plan.point.map((p,i)=>`<option value="${i}">${i+1} · ${esc(pointKind(p))} / ${esc(p.id)}</option>`).join('');
 el('neighbours').innerHTML=current.neighbours.map(n=>`<div class="detail-row"><span>${({left:'左',right:'右',up:'上',down:'下'})[n.direction]} · (${n.x}, ${n.y})</span><span class="ok">${!n.room?'未含于快照池':!n.interfaces.length?'两边无开放接口':`${n.interfaces.length} 个接口吻合`}</span></div>`).join('');
 const t=current.roundtrip;
 el('roundtrip').innerHTML=`<div class="detail-row"><span>地形／物体／选项</span><span class="ok">选房后核对一致</span></div><div class="detail-row"><span>房间附加属性</span><span class="lost">丢失 ${t.lostRoomAttributes.length} 项</span></div><div class="detail-row"><span>生成计划、边界接口</span><span class="lost">均丢失</span></div><div class="detail-row"><span>刚载入的坐标</span><span class="lost">误为 (0, 0)</span></div><p>本单房样本重新选房后坐标恢复为 (${c.x}, ${c.y})，附加信息仍丢失。</p>`;
 selectPoint(0);overlay();history.replaceState(null,'','#'+current.theme);
}
el('scene').addEventListener('change',()=>show(el('scene').value));
for(const id of ['spaces','points','tactics','ports'])el(id).addEventListener('change',overlay);
el('plain').addEventListener('click',()=>{for(const id of ['spaces','points','tactics','ports'])el(id).checked=false;overlay();});
el('pointSelect').addEventListener('change',()=>selectPoint(+el('pointSelect').value));
function pick(e){const mark=e.target.closest('[data-point]');if(mark)selectPoint(+mark.dataset.point);}
el('overlay').addEventListener('click',pick);
el('overlay').addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();pick(e);}});
show(location.hash.slice(1));
