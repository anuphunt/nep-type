import {chromium} from 'playwright-core';
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

const root=fileURLToPath(new URL('../dist/',import.meta.url));
const reports=new URL('../reports/homepage/',import.meta.url);
const mime={'.html':'text/html; charset=utf-8','.css':'text/css','.js':'text/javascript','.mjs':'text/javascript','.json':'application/json','.png':'image/png','.woff2':'font/woff2','.wasm':'application/wasm'};
let server,browser;
const checks=[],errors=[],telemetry=[];
let base=process.argv.find(arg=>arg.startsWith('--base-url='))?.slice(11);
const live=Boolean(base);
try {
  await mkdir(reports,{recursive:true});
  if(!base){
    server=createServer(async(req,res)=>{
      const pathname=new URL(req.url,'http://localhost').pathname;
      const file=path.resolve(root,'.'+pathname+(pathname.endsWith('/')?'index.html':''));
      if(!file.startsWith(root))return res.writeHead(403).end();
      try {const contents=await readFile(file);res.writeHead(200,{'Content-Type':mime[path.extname(file)]||'application/octet-stream'}).end(contents);}
      catch {res.writeHead(404).end();}
    });
    await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
    base='http://127.0.0.1:'+server.address().port;
  }
  browser=await chromium.launch({channel:'chrome',headless:true});
  const devices=[
    {name:'desktop',width:1440,platform:'MacIntel',touch:0,ua:'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',mobile:false},
    {name:'phone',width:390,platform:'iPhone',touch:5,ua:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)',mobile:true},
    {name:'ipad-desktop',width:1024,platform:'MacIntel',touch:5,ua:'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',mobile:true},
    {name:'android-tablet',width:768,platform:'Linux armv8l',touch:5,ua:'Mozilla/5.0 (Linux; Android 14)',mobile:true},
    {name:'small-phone',width:320,platform:'Linux armv8l',touch:5,ua:'Mozilla/5.0 (Linux; Android 14)',mobile:true}
  ];
  for(const device of devices.filter(device=>!process.argv.includes('--small-only') || device.name==='small-phone')){
    const context=await browser.newContext({viewport:{width:device.width,height:900},hasTouch:device.mobile,userAgent:device.ua,permissions:['clipboard-read','clipboard-write']});
    await context.addInitScript(device=>{
      localStorage.setItem('neptype-analytics-opt-out','true');
      Object.defineProperty(navigator,'platform',{get:()=>device.platform});
      Object.defineProperty(navigator,'maxTouchPoints',{get:()=>device.touch});
      Object.defineProperty(navigator,'userAgentData',{get:()=>undefined});
    },device);
    await context.route(/google-analytics\.com|googletagmanager\.com|posthog\.com/,route=>{telemetry.push(route.request().url());route.abort();});
    const page=await context.newPage();
    page.on('pageerror',e=>errors.push(e.message));
    page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
    page.on('response',r=>{if(r.status()>=400)errors.push(r.url());});
    const output=page.locator('#web-output'),input=page.locator('#web-input');
    const waitOutput=async text=>{try{await page.waitForFunction(expected=>document.querySelector('#web-output').value===expected,text,{timeout:30000});}catch(error){throw Error(`${device.name}: expected ${text}, got ${await output.inputValue()}. ${error.message}`);}};
    const type=async text=>{await input.fill(text);await page.waitForFunction(()=>document.querySelector('#web-pad').dataset.dictionaryId && !document.querySelector('#web-copy').disabled,null,{timeout:120000});};
    for(const prefix of ['/','/ne/']){
      console.log(`Checking ${device.name} ${prefix}`);
      const response=await page.goto(base+prefix+'?analytics_test=1',{waitUntil:'networkidle'});
      assert.equal(response.status(),200);
      assert.equal(await page.locator('h1').count(),1);
      assert.equal(await input.count(),1);
      assert.equal(await page.locator('link[rel="canonical"]').getAttribute('href'),'https://neptype.com'+prefix);
      assert.equal(await page.locator('meta[name="robots"]').getAttribute('content'),'index,follow,max-image-preview:large');
      assert.equal(await page.locator('.hero-visual').count(),0);
      const downloads = page.locator('#downloads');
      assert.equal(await downloads.locator('[data-platform-card]').count(),5);
      assert.equal(await downloads.locator('h2').count(),1);
      assert.equal(await downloads.locator('h3').count(),5);
      assert.equal(await downloads.locator('.platform-download').count(),2);
      assert.equal(await downloads.locator('[data-current-device]:visible').count(),1);
      const columns = await downloads.locator('.download-grid').evaluate(el=>getComputedStyle(el).gridTemplateColumns.split(' ').length);
      assert.equal(columns,device.width>1100?5:device.width>600?2:1);
      const editorBox = await page.locator('#try').boundingBox(), downloadBox = await downloads.boundingBox();
      assert.ok(downloadBox.y >= editorBox.y + editorBox.height);
      assert.ok(downloadBox.y < (await page.locator('.typing-help').boundingBox()).y);
      for (const platform of ['iOS','Android','Linux']) {
        assert.equal(await downloads.locator(`[data-platform-card="${platform}"] .platform-download`).count(),0);
        assert.equal(await downloads.locator(`[data-platform-card="${platform}"] .setup-link`).getAttribute('href'),prefix+'#try');
      }
      for (const slug of ['mac','windows']) assert.equal(await downloads.locator(`.setup-link[href="${prefix}${slug}/"]`).count(),1);
      assert.ok((await input.boundingBox()).y<360,`${device.name} ${prefix}: editor above fold`);
      assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
      await type('pani');await waitOutput('पनि');
      const hints=await page.locator('#web-suggestions kbd').allTextContents();
      assert.ok(hints.length>=3);
      if(device.width<=600) assert.ok((await page.locator('#web-suggestions').boundingBox()).y < (await output.boundingBox()).y, 'phone suggestions are above output');
      assert.ok(hints.every(hint=>device.mobile?/^[1-5]$/.test(hint):/^⌥[1-5]$/.test(hint)));
      const candidate=page.locator('#web-suggestions button').filter({hasText:'पानी'});
      const index=Number((await candidate.locator('kbd').textContent()).replace(/\D/g,''));
      await input.focus();await page.keyboard.press(device.mobile?String(index):'Alt+Digit'+index);
      await waitOutput('पानी');assert.equal(await input.inputValue(),'pani');
      await page.keyboard.press('Meta+z');await waitOutput('पनि');
      await page.keyboard.press('Meta+Shift+z');await waitOutput('पानी');
      if(device.mobile){
        // This exercises the beforeinput path emitted by virtual keyboards.
        await type('pani');await waitOutput('पानी');
        const first=page.locator('#web-suggestions button').filter({hasText:'पनि'});
        const digit=await first.locator('kbd').textContent();
        const prevented=await input.evaluate((el,data)=>!el.dispatchEvent(new InputEvent('beforeinput',{bubbles:true,cancelable:true,inputType:'insertText',data})),digit);
        assert.equal(prevented,true);await waitOutput('पनि');assert.equal(await input.inputValue(),'pani');
        for(const attrs of [
          {inputType:'insertFromPaste',data:'2'},
          {inputType:'insertCompositionText',data:'2',isComposing:true},
          {inputType:'insertText',data:'2',isComposing:true},
          {inputType:'insertReplacementText',data:'2'},
          {inputType:'insertText',data:'12'}
        ]) assert.equal(await input.evaluate((el,attrs)=>el.dispatchEvent(new InputEvent('beforeinput',{bubbles:true,cancelable:true,...attrs})),attrs),true);
        await type('pani ');await page.keyboard.press('2');
        assert.equal(await input.inputValue(),'pani 2');
        await type('pani');await input.evaluate(el=>el.setSelectionRange(0,4));await page.keyboard.press('2');
        assert.equal(await input.inputValue(),'2','selected source can be replaced by literal digit');
      } else {
        await type('pani');await page.keyboard.press('2');assert.equal(await input.inputValue(),'pani2');
      }
      await type('namaste');await waitOutput('नमस्ते');
      await page.locator('#web-copy').click();assert.equal(await page.evaluate(()=>navigator.clipboard.readText()),'नमस्ते');
      await type('gaadi gadi gayera');await waitOutput('गाडी गाडी गएर');
      await type('mero phone naya cha.');await waitOutput('मेरो phone नयाँ छ।');
      await page.locator('#web-mode').selectOption('all');await waitOutput('मेरो फोने नयाँ छ।');
      await page.locator('#web-mode').selectOption('mixed');await waitOutput('मेरो phone नयाँ छ।');
      await page.locator('#web-clear').click();await page.waitForFunction(()=>document.querySelector('#web-output').value==='');
      assert.equal(await input.inputValue(),'');assert.equal(await page.locator('#web-copy').isDisabled(),true);
      await page.locator('#web-example').click();await page.waitForFunction(()=>document.querySelector('#web-output').value.includes('नमस्ते'));
      await page.locator('#web-clear').click();
      await type('pani');await waitOutput('पनि');
      if(device.mobile) await candidate.tap(); else await candidate.click();
      await waitOutput('पानी');
      await candidate.focus();await page.keyboard.press('Enter');
      await page.waitForFunction(()=>document.querySelector('#web-input')===document.activeElement);
      await page.evaluate(()=>window.scrollTo(0,0));
      await page.screenshot({path:fileURLToPath(new URL(`${live?'live':'local'}-${device.name}-${prefix==='/ne/'?'ne':'en'}-suggestions.png`,reports))});
      await page.waitForFunction(()=>document.querySelector('#web-input')===document.activeElement);
      await page.locator('#web-clear').click();await page.waitForFunction(()=>document.querySelector('#web-output').value==='');
      await page.evaluate(()=>window.scrollTo(0,0));await page.evaluate(()=>document.activeElement.blur());await page.evaluate(()=>document.fonts.ready);
      await page.screenshot({path:fileURLToPath(new URL(`${live?'live':'local'}-${device.name}-${prefix==='/ne/'?'ne':'en'}.png`,reports)),fullPage:true});
      if(device.width<=600){
        await page.locator('.mobile-menu').click();assert.equal(await page.locator('.mobile-menu').getAttribute('aria-expanded'),'true');
        await page.keyboard.press('Escape');assert.equal(await page.locator('.mobile-menu').getAttribute('aria-expanded'),'false');
        await page.locator('.mobile-menu').click();
        await page.locator('.nav-links a[href$="typing-guide/"]').click();
        await page.waitForLoadState('networkidle');
        await page.goBack({waitUntil:'networkidle'});assert.equal(await page.locator('.mobile-menu').getAttribute('aria-expanded'),'false');
      }
      checks.push(`${device.name} ${prefix}: layout, full download component, metadata, typing, shortcut labels/selection, undo/redo, copy, modes, clear, example, tap${device.mobile?', soft-keyboard input, literal digits, composition/paste safeguards':''}`);
    }
    await context.close();
  }
  const plain=await browser.newContext({javaScriptEnabled:false,viewport:{width:390,height:844}}),page=await plain.newPage();
  for(const prefix of ['/','/ne/']){
    await page.goto(base+prefix+'?analytics_test=1');
    assert.equal(await page.locator('#web-input').count(),1);
    assert.ok(await page.locator('noscript').isVisible());
    assert.equal(await page.locator('#downloads [data-platform-card]').count(),5);
    assert.equal(await page.locator('#downloads .platform-download').count(),2);
    await page.locator('.site-footer a[href$="/download/"]').click();assert.equal(new URL(page.url()).pathname,prefix+'download/');
    checks.push(`${prefix}: no-JavaScript editor explanation and crawlable downloads`);
  }
  assert.deepEqual(errors,[]);assert.deepEqual(telemetry,[]);
  const result={base,checks,errors,telemetry,verifiedAt:new Date().toISOString()};
  await writeFile(new URL(`${live?'live':'local'}-results.json`,reports),JSON.stringify(result,null,2));
  console.log(JSON.stringify(result,null,2));
}finally{if(browser)await browser.close();if(server)await new Promise(resolve=>server.close(resolve));}
