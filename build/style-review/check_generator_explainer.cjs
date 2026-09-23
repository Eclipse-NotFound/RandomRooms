// Browser verification of the explainer controls, not of the AS3 generator.
const {chromium} = require('C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs = require('node:fs');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const {createHash} = require('node:crypto');
const assert = require('node:assert/strict');
const out = path.resolve(__dirname, '../../design/generator-explained-v11.1');
(async()=>{
  const browser = await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
  try {
    const page = await browser.newPage({viewport:{width:1440,height:1000},deviceScaleFactor:1});
    const errors=[];page.on('pageerror',e=>errors.push(String(e)));
    await page.goto(pathToFileURL(path.join(out,'guide.html')).href);
    await page.screenshot({path:path.join(out,'guide-overview.png')});
    let inspected=0;
    for(const scene of ['plant','stable','sewer','mane']) {
      await page.selectOption('#scene',scene);
      const values=await page.locator('#sample option').evaluateAll(a=>a.map(o=>o.value));
      for(const value of values) {
        await page.selectOption('#sample',value);
        for(const layer of ['0','1','2','3']) {
          await page.locator(`[data-layer="${layer}"]`).click();
          assert.equal(await page.locator(`[data-layer="${layer}"]`).getAttribute('aria-pressed'),'true');
          const geometry=await page.locator('#roomSvg').innerHTML();
          assert(!/NaN|undefined/.test(geometry));
          assert((await page.locator('#roomSvg rect').count())>0);
        }
        inspected++;
      }
    }
    assert.equal(inspected,16);
    await page.selectOption('#scene','plant');
    await page.locator('[data-layer="0"]').click();
    await page.locator('#room').screenshot({path:path.join(out,'guide-room.png')});
    await page.locator('[data-scene="sewer"]').click();
    assert.equal(await page.locator('#scene').inputValue(),'sewer');
    await page.selectOption('#sample','8');
    await page.locator('[data-layer="3"]').click();
    await page.locator('#room').screenshot({path:path.join(out,'guide-sewer.png')});
    await page.locator('#widthTest').fill('16');await page.locator('#heightTest').fill('8');
    assert.match(await page.locator('#splitResult').textContent(),/候选/);
    await page.selectOption('#roleTest','hall');
    assert.match(await page.locator('#splitResult').textContent(),/保留/);
    await page.selectOption('#roleTest','keep');
    assert.match(await page.locator('#splitResult').textContent(),/不进入/);
    await page.selectOption('#roleTest','ordinary');
    await page.locator('#scale').screenshot({path:path.join(out,'guide-scale.png')});
    const measures=[];
    for(const [width,height] of [[1440,1000],[390,844]]) {
      await page.setViewportSize({width,height});
      const d=await page.evaluate(()=>({w:innerWidth,sw:document.documentElement.scrollWidth}));
      assert(d.sw<=d.w); measures.push({...d,width,height});
    }
    await page.locator('#room').screenshot({path:path.join(out,'guide-mobile.png')});
    assert.deepEqual(errors,[]);
    const artifact=fs.readFileSync(path.join(out,'guide.html'));
    const receipt={status:'pass',scope:'Guide browser controls and layout only; not a game rerun',rooms:inspected,layersPerRoom:4,sliderCases:3,viewports:measures,pageErrors:errors,sha256:createHash('sha256').update(artifact).digest('hex')};
    fs.writeFileSync(path.join(out,'guide-browser-check.json'),JSON.stringify(receipt,null,2)+'\n');
    console.log(JSON.stringify(receipt));
  } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
