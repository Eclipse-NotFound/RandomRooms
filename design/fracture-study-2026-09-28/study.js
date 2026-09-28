'use strict';
const data = window.FRACTURE_DATA;
const names = {plant:'工厂',stable:'废弃避难厩',sewer:'下水道',mane:'城市废墟'};
const notes = {
 'mane/45':['多层毁损 · 极端样本','y8、y16 的深色横带大部分只剩背景。切换地形图，可以看出实体楼板远少于第一眼感觉到的数量；薄梁和斜梯另行提供落脚。后墙大洞、残架与底部瓦砾共同维持废楼的辨识度。'],
 'mane/26':['断裂 · 完整侧室与跨层空腔','两侧仍保留带门的功能房，中间的楼板和墙段跨层缺失；上下缺口有错位，形成不规则大空间。残楼层、局部梁梯和底部瓦砾互相呼应。'],
 'mane/60':['毁损楼层 · 错开的残墙和断板','同样能读出 y8、y16 两层，但每层留下的墙板段不同。中央 F 杂木块是真实实体；大型后墙洞跨越子房范围，底部集中瓦砾。'],
 'mane/0':['毁损楼层 · 保留一间完整储物室','左上带门房仍有用途，其他区域主要剩梁、短板和少量家具。破碎并没有抹掉所有建筑线索。'],
 'mane/46':['破损屋顶 · 特殊地图位置','主要建筑在下部，顶部是室外。此图已恢复屋顶的后墙裁切，但全房图不含远景，外框仍是隔离展示封边；不能把顶部深色与外框当作原版完整城市外观。'],
 'mane/51':['办公室 · 较完整对照','主要楼板、办公室、设备区仍清楚，局部短墙缺损和一处后墙洞已足以传达破旧。完整房与重度毁损房之间应有明显差异。'],
 'plant/54':['塌方 · 裂纹实体与岩体交错','这间不用 hole/chole 或 heap，仍十分破碎。上部规整房间与下部不规则厚块形成反差；黑色裂纹 E 仍是实体，只是较易破坏，不能当作已存在的空气通道。'],
 'plant/16':['车间 · 规则工业结构对照','大跨度车间与两侧附室、钢架、窗和机器形成明确工业空间。不能把“大且旧”自动当成坍塌；后续破坏应以这种可辨的构造为参照。'],
 'stable/9':['洞穴 2 · 设施在上、岩洞在下','顶部仍是规整金属设施，下部岩体边缘凹凸、宽窄变化明显，结构架穿过大空腔。两种构造相接，比把每个金属房都磨成不规则形更接近这个原例。'],
 'stable/17':['洞穴 · 设施只占局部','大部分空间交给岩洞，右侧只留一段设备设施。存在分离岩台与大小不同的块岛，不能把任何视觉上悬空的块都视为原版不允许的错误。'],
 'stable/22':['洞穴 3 · 水体与设施相接','左下设施仍保持规整金属层级，上部岩洞和积水占据不同份额。它的变化是空间类型和占比变化，不只是旧损贴图变多。'],
 'stable/48':['洞穴 4 · 纯自然空间极端','内框只用岩石 G 与泥土 H，没有金属实体。岩块大小、空隙宽窄和边缘凹入共同造成自然破碎；这是特定类型，不代表常规避难厩房都应如此。'],
 'stable/20':['大厅 · 完整金属设施对照','大厅、侧室、厚基座与楼梯仍有强烈建筑秩序。与洞穴样本对比，说明避难厩内部可以有很不同的主空间，而不是所有房间同等程度“加噪声”。'],
 'sewer/18':['分支隧道 · 粗糙表面与规整厚墙','内框 482 格实体全为苔墙 L。实景很粗糙，但地形图显示大量长直边与厚块。适合局部改变厚壁退缩和通道宽窄，不宜全面撒细洞。'],
 'sewer/9':['隧道 4 · 工程管渠与层级','管线、梯路与厚壁共同组织空间，苔藓和材质边缘增加粗糙感。破碎算法需要保留这些工程方向。'],
 'sewer/19':['排水池 · 大水腔配附属空间','中央是大水腔，两侧安排交通和设备，底部有厚实池底。大尺度空腔不等于坍塌，更不等于要把边界切成许多小孔。']
};
const sceneSelect = document.getElementById('scene');
const roomSelect = document.getElementById('room');
const image = document.getElementById('nativeImage');
const svg = document.getElementById('terrain');
const canvas = document.getElementById('canvas');
const holes = document.getElementById('holes');
let selected, mode = 'native';
for (const scene of ['mane','plant','stable','sewer']) sceneSelect.add(new Option(names[scene],scene));
for (const s of data.scenes) {
 const row = document.createElement('tr');
 for (const v of [names[s.scene],s.ordinary,`${s.ordinaryWithHole} / ${s.ordinary}`,`${s.ordinaryWithHeap} / ${s.ordinary}`]) {
  const td=document.createElement('td'); td.textContent=v; row.appendChild(td);
 }
 document.getElementById('counts').appendChild(row);
}
function key(e){return `${e.scene}/${e.index}`;}
function populate(scene,index){
 sceneSelect.value=scene; roomSelect.replaceChildren();
 const available=data.examples.filter(e=>e.scene===scene);
 for (const e of available) roomSelect.add(new Option(`${e.index} · ${notes[key(e)][0]} · ${e.name}`,String(e.index)));
 roomSelect.value=String(index);
 if (!roomSelect.value) roomSelect.selectedIndex=0;
 choose();
}
function choose(){
 selected=data.examples.find(e=>e.scene===sceneSelect.value&&String(e.index)===roomSelect.value);
 const note=notes[key(selected)];
 document.getElementById('caseTitle').textContent=`${names[selected.scene]} ${selected.index} · ${note[0]}`;
 document.getElementById('caseNote').textContent=note[1];
 document.getElementById('caseSource').textContent=`Rooms/rooms_${selected.scene}.xml，第 ${selected.line} 行；房间序号和坐标从 0 起算。${selected.tip?'此例为 '+selected.tip+' 专用房。':'此例来自普通池。'}`;
 image.src=selected.image; image.alt=`${names[selected.scene]}原版 ${selected.index}：${note[0]}`;
 document.getElementById('fullImage').href=selected.image;
 document.getElementById('caseMetrics').innerHTML=`<div><strong>${selected.solidCells}</strong>内框实体格 / 1058</div><div><strong>${selected.holeObjects}</strong>后墙洞对象</div><div><strong>${selected.heapObjects}</strong>瓦砾背景对象</div>`;
 document.getElementById('tileInfo').textContent='将鼠标移到图上查看编码；地形图不等同于完整碰撞或通行检查。';
 history.replaceState(null,'',`#${key(selected)}`); render();
}
function rect(x,y,w,h,fill,extra=''){return `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${fill}" ${extra}/>`;}
function line(x1,y1,x2,y2,color,width=.13){return `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${color}" stroke-width="${width}"/>`;}
function render(){
 image.style.opacity=mode==='terrain'?'0':'1';
 let marks='';
 const colors={D:'#bd8c6a',E:'#f09e51',F:'#977b54',G:'#879fc3',H:'#977b54',L:'#6c9b72'};
 if(mode!=='native'){
  if(mode==='terrain') marks+=rect(0,0,48,25,'#142025');
  let cells='';
  selected.grid.forEach((row,y)=>row.forEach((code,x)=>{
   if(/^[A-T]/.test(code)) {
    let dy=0,height=1;
    if(code.includes(',')){dy=.25;height=.75;} else if(code.includes(';')){dy=.5;height=.5;} else if(code.includes(':')){dy=.75;height=.25;}
    cells+=rect(x,y+dy,1,height,colors[code[0]]||'#bfc8d0','stroke="#182227" stroke-width=".025"');
   }
   const suffix=code.slice(1);
   if(/[-ДЕКНР]/.test(suffix)) cells+=rect(x,y+.08,1,.17,'#77d5d0');
   if(/[АБ]/.test(suffix)){
    cells+=line(x+.36,y,x+.36,y+1,'#efd68d',.08)+line(x+.67,y,x+.67,y+1,'#efd68d',.08);
    for(let a=.12;a<1;a+=.3)cells+=line(x+.3,y+a,x+.73,y+a,'#efd68d',.07);
   }
   if(/[ВЖИЛОС]/.test(suffix))cells+=line(x,y+1,x+1,y,'#77d5d0');
   if(/[ГЗЙМПТ]/.test(suffix))cells+=line(x,y,x+1,y+1,'#77d5d0');
   if(suffix.includes('*'))cells+=rect(x,y,.98,.98,'#408ac9','opacity=".25"');
  }));
  marks+=`<g opacity="${mode==='overlay'?.62:1}">${cells}</g>`;
 }
 if(holes.checked){
  for(const b of selected.backPlacements.filter(b=>/^(hole|chole)/.test(b.id))){
   const size=data.holeSizes[b.id]||[10,10];
   marks+=rect(+b.x,+b.y,size[0]*(+b.w||1),size[1]*(+b.h||1),'none','stroke="#f1a5ed" stroke-width=".09" stroke-dasharray=".3 .18"');
  }
 }
 svg.innerHTML=marks;
 document.querySelectorAll('[data-mode]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.mode===mode)));
}
sceneSelect.addEventListener('change',()=>populate(sceneSelect.value,-1));
roomSelect.addEventListener('change',choose); holes.addEventListener('change',render);
document.querySelectorAll('[data-mode]').forEach(b=>b.addEventListener('click',()=>{mode=b.dataset.mode;render();}));
document.querySelectorAll('[data-example]').forEach(b=>b.addEventListener('click',()=>{
 const [s,i]=b.dataset.example.split('/');populate(s,+i);document.getElementById('viewer').scrollIntoView({behavior:'smooth'});
}));
canvas.addEventListener('pointermove',event=>{
 const bounds=canvas.getBoundingClientRect();
 const x=Math.min(47,Math.max(0,Math.floor((event.clientX-bounds.left)/bounds.width*48)));
 const y=Math.min(24,Math.max(0,Math.floor((event.clientY-bounds.top)/bounds.height*25)));
 const code=selected.grid[y][x],solid=/^[A-T]/.test(code);
 let meaning=solid?'前景实体':'无前景整块实体';
 if(code[0]==='E') meaning+=' · 裂纹 E：hp150，破坏阈值10';
 if(code[0]==='D') meaning+=' · 破损混凝土 D：hp1000，破坏阈值100';
 if(code[0]==='F') meaning+=' · 杂木/破烂 F，不是玻璃';
 if(/[A-Z]/.test(code.slice(1)))meaning+=' · 含后墙材质';
 if(/[-ДЕКНР]/.test(code.slice(1)))meaning+=' · 含薄梁';
 if(/[АБ]/.test(code.slice(1)))meaning+=' · 含直梯';
 if(/[ВГЖЗИЙЛМОПСТ]/.test(code.slice(1)))meaning+=' · 含斜梯';
 document.getElementById('tileInfo').textContent=`x=${x}，y=${y} ｜ ${code} ｜ ${meaning}`;
});
const initial=data.examples.find(e=>key(e)===location.hash.slice(1))||data.examples.find(e=>key(e)==='mane/45');
populate(initial.scene,initial.index);
