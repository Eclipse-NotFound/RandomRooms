import copy,hashlib,json,pathlib,shutil,xml.etree.ElementTree as E
HERE=pathlib.Path(__file__).resolve().parent; MOD=HERE.parent.parent; GAME=MOD.parent.parent
APP=MOD/'build/spatial-v132/render'; APP.mkdir(parents=True,exist_ok=True)
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
assets={}
for name in ['Editor/Enhancements/NativeScene.swf','texture.swf','texture1.swf','sprite.swf','sprite1.swf','text_zh.xml']:
 p=GAME/name; q=APP/name;q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,q);assets[name]=digest(p)
old=E.parse(MOD/'build/spatial-v132/baseline.xml').getroot().findall('room')
new=E.parse(MOD/'build/style-review/content-batch/rooms.xml').getroot().findall('room')
byseed={r.get('rrSeed'):r for r in old}; data=[]; cases=[]
def compact(r):
 return dict(attrs=dict(r.attrib),grid=[a.text.split('.') for a in r.findall('a')],objects=[dict(a.attrib) for a in r.findall('obj')],
             spaces=[dict(a.attrib) for a in r.findall('rrPlan/space')],caches=[dict(a.attrib) for a in r.findall('rrPlan/cache')])
for i,r in enumerate(new): data.append(dict(index=i,scene=r.get('rrTheme'),seed=r.get('batchSeed'),x=r.get('batchX'),y=r.get('batchY'),old=compact(byseed[r.get('rrSeed')]),new=compact(r)))
for scene in ['plant','stable','sewer','mane']:
 options=[r for r in new if r.get('rrTheme')==scene and r.get('rrPopulation')!='arrival']
 chosen=max(options,key=lambda r:4*len(r.findall('rrPlan/cache'))+3*(r.get('rrP_layout')=='wings')+len(r.findall('rrPlan/merge'))/10)
 for version,r in [('before',byseed[chosen.get('rrSeed')]),('after',chosen)]:
  ident=f'{scene}-{version}'; pool=E.Element('all');pool.append(copy.deepcopy(r));E.ElementTree(pool).write(APP/(ident+'.xml'),encoding='utf-8')
  cases.append(dict(id=ident,sample=ident+'.xml',region='random_'+scene,difficulty=int(r.get('rrDifficulty')),scene=scene))
 for row in data:
  if row['new']['attrs']['rrSeed']==chosen.get('rrSeed'):row['image']=scene
for scene,index in [('plant',6),('sewer',4)]:
 r=E.parse(GAME/'Rooms'/f'rooms_{scene}.xml').getroot().findall('room')[index];pool=E.Element('all');r=copy.deepcopy(r);r.set('rrTheme',scene);pool.append(r)
 ident=f'native-{scene}-{index}';E.ElementTree(pool).write(APP/(ident+'.xml'),encoding='utf-8')
 cases.append(dict(id=ident,sample=ident+'.xml',region='random_'+scene,difficulty=8,scene=scene))
(APP/'cases.json').write_text(json.dumps(cases),encoding='utf-8')
(HERE/'data.js').write_text('window.reviewData='+json.dumps(data,ensure_ascii=False,separators=(',',':'))+';\n',encoding='utf-8')
(HERE/'render-inputs.json').write_text(json.dumps(dict(assets=assets,cases=cases,samples={p.name:digest(p) for p in APP.glob('*.xml')}),indent=2),encoding='utf-8')
print('Prepared',len(data),'actual AS3 pairs and',len(cases),'native images.')
