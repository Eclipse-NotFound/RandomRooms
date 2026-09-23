// Actual browser checks of paired sample selection, layers and responsive layout.
const {chromium}=require('C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {pathToFileURL}=require('node:url');
const {createHash}=require('node:crypto');
const out=path.resolve(__dirname,'../../',process.argv[2]||'design/partition-preview-v12-3');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 try{
  const page=await browser.newPage({viewport:{width:1440,height:1080},deviceScaleFactor:1});
  const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  await page.goto(pathToFileURL(path.join(out,'index.html')).href);
  const cases=await page.evaluate(()=>DATA.cases.map(c=>({scene:c.scene,form:c.form,port:c.port,sample:c.sample,index:c.index})));
  let selected=0;
  // Check every exported case in the selector; exercise all layers on the
  // first/last sample of each fixed scene/use/port set.
  for(const c of cases){
   await page.evaluate(c=>{scene=c.scene;form=c.form;port=c.port;pos=c.sample;$('ports').value=port;setScene(scene,true);},c);
   const expected=await page.evaluate(()=>list()[pos].index);assert.equal(expected,c.index);
   if(c.sample===0||c.sample===7){
    for(const layer of ['roles','terrain','objects']){
     await page.locator(`[data-layer="${layer}"]`).click();
     const maps=await page.locator('.drawing').allTextContents();assert.equal(maps.length,2);
     assert(!/NaN|undefined/.test(await page.locator('.compare').innerHTML()));
    }
   }
   selected++;
  }
  await page.locator('[data-scene="plant"]').click();await page.selectOption('#ports','0');
  await page.locator('[data-layer="roles"]').click();
  const before=await page.locator('#newSeed').textContent();await page.locator('#next').click();
  assert.notEqual(await page.locator('#newSeed').textContent(),before);await page.locator('#previous').click();
  assert.equal(await page.locator('#newSeed').textContent(),before);
  await page.locator('#newMap .region').first().click();assert.match(await page.locator('#inspect').textContent(),/格。连接/);
  await page.locator('#newMap .region').first().focus();await page.keyboard.press('Enter');
  assert.match(await page.locator('#inspect').textContent(),/格。连接/);
  await page.evaluate(()=>{const c=DATA.cases.find(c=>DATA.new[c.index]?.floors.length);scene=c.scene;form=c.form;port=c.port;pos=c.sample;$('ports').value=port;setScene(scene,true);});
  await page.locator('#floorLines').check();
  assert(await page.locator('#newMap path[stroke-dasharray="10 5"]').count()>0);await page.locator('#floorLines').uncheck();
  await page.locator('#partitions').check();assert(await page.locator('#newMap rect[stroke-dasharray="3 4"]').count()>0);await page.locator('#partitions').uncheck();
  await page.locator('#links').check();assert(await page.locator('#newMap path[stroke-dasharray]').count()>0);await page.locator('#links').uncheck();
  await page.locator('.thumb').nth(4).click();assert.equal(await page.locator('.thumb[aria-current="true"]').count(),1);
  assert.match(await page.locator('#sampleStatus').textContent(),/5 \/ 8/);
  await page.locator('.thumb').first().click();
  await page.locator('[data-scene="plant"]').click();await page.selectOption('#ports','0');
  await page.evaluate(()=>scrollTo(0,0));
  await page.screenshot({path:path.join(out,'preview-desktop.png')});
  await page.locator('.compare').screenshot({path:path.join(out,'preview-compare.png')});
  await page.locator('.batch').screenshot({path:path.join(out,'preview-variations.png')});
  await page.locator('[data-scene="sewer"]').click();await page.selectOption('#form','cistern');
  await page.locator('[data-layer="terrain"]').click();await page.locator('.compare').screenshot({path:path.join(out,'preview-sewer.png')});
  const photos=await page.locator('#photoSelect option').count();
  for(let i=0;i<photos;i++){
   await page.selectOption('#photoSelect',String(i));
   await page.locator('#photos').scrollIntoViewIfNeeded();
   await page.waitForFunction(()=>[...document.querySelectorAll('#photos img')].every(i=>i.complete&&i.naturalWidth>0));
   await page.locator('#photos button').click();
   assert.equal(await page.evaluate(()=>list()[pos].index),await page.evaluate(i=>DATA.photos[i].caseId,i));
  }
  if(photos){await page.selectOption('#photoSelect','0');await page.locator('.native').first().screenshot({path:path.join(out,'preview-native.png')});}
  const references=await page.evaluate(()=>DATA.references.length);
  for(const scene of ['plant','stable','sewer','mane']){
   await page.locator(`[data-scene="${scene}"]`).click();
   if(references){await page.locator('#nativeReference').scrollIntoViewIfNeeded();await page.waitForFunction(()=>document.querySelector('#nativeReference img')?.naturalWidth>0);}
  }
  const viewports=[];
  for(const [width,height]of [[1440,1080],[390,844]]){
   await page.setViewportSize({width,height});const dims=await page.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth}));
   assert(dims.scroll<=dims.width);viewports.push(dims);
  }
  await page.locator('[data-scene="plant"]').click();await page.locator('[data-layer="roles"]').click();
  await page.locator('.toolbar').scrollIntoViewIfNeeded();await page.screenshot({path:path.join(out,'preview-mobile.png')});
  assert.deepEqual(errors,[]);
  const result={status:'passed',scope:'HTML interaction and browser rendering; not game navigation',cases:selected,photos,references,viewports,pageErrors:errors,sha256:createHash('sha256').update(fs.readFileSync(path.join(out,'index.html'))).digest('hex')};
  fs.writeFileSync(path.join(out,'browser-check.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
