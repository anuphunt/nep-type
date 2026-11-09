import {chromium} from 'playwright-core';
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {readFile, mkdir, writeFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {detectPlatform, downloadAction} from '../platform.mjs';
import {windowsDownload} from '../windows-release.mjs';

const root = fileURLToPath(new URL('../dist/',import.meta.url));
const reports = new URL('../reports/downloads/',import.meta.url);
const mac = JSON.parse(await readFile(new URL('../mac-release.json',import.meta.url)));
const windows = windowsDownload(JSON.parse(await readFile(new URL('../windows-release.json',import.meta.url))));
const mime = {'.html':'text/html; charset=utf-8','.css':'text/css','.js':'text/javascript','.mjs':'text/javascript','.json':'application/json','.png':'image/png','.woff2':'font/woff2','.wasm':'application/wasm'};
const server = createServer(async(req,res) => {
  const pathname = new URL(req.url,'http://localhost').pathname;
  const file = path.resolve(root,'.'+pathname+(pathname.endsWith('/')?'index.html':''));
  if (!file.startsWith(root)) return res.writeHead(403).end();
  try {res.writeHead(200,{'Content-Type':mime[path.extname(file)]||'application/octet-stream'}).end(await readFile(file));}
  catch {res.writeHead(404).end();}
});
const checks = [], errors = [], accessibility = [], liveDownloads = [];
let browser;
try {
  await mkdir(reports,{recursive:true});
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const base = 'http://127.0.0.1:'+server.address().port;
  browser = await chromium.launch({channel:'chrome',headless:true});
  const context = await browser.newContext({permissions:['clipboard-read','clipboard-write']});
  const page = await context.newPage();
  page.on('pageerror',error=>errors.push(error.message));
  page.on('console',message=>{if(message.type()==='error')errors.push(message.text());});
  page.on('response',response=>{if(response.status()>=400)errors.push(response.url());});
  for (const width of [1440,1024,768,390,320]) {
    await page.setViewportSize({width,height:1000});
    for (const prefix of ['/','/ne/']) {
      const locale = prefix === '/' ? 'en' : 'ne';
      for (const slug of ['', 'download/']) {
        await page.goto(base+prefix+slug,{waitUntil:'networkidle'});
        await page.evaluate(()=>document.fonts.ready);
        assert.equal(await page.locator('h1').count(),1);
        assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),`${prefix}${slug} overflow at ${width}`);
        if (slug) {
          assert.equal(await page.locator('link[rel="canonical"]').getAttribute('href'),'https://neptype.com'+prefix+slug);
          assert.equal(await page.locator('link[hreflang="en"]').getAttribute('href'),'https://neptype.com/download/');
          assert.equal(await page.locator('link[hreflang="ne"]').getAttribute('href'),'https://neptype.com/ne/download/');
          const cards = page.locator('[data-platform-card]');
          assert.equal(await cards.count(),5);
          const columns = await page.locator('.download-grid').evaluate(el=>getComputedStyle(el).gridTemplateColumns.split(' ').length);
          assert.equal(columns,width>1100 ? 5 : width>600 ? 2 : 1);
          const boxes = await cards.evaluateAll(cards=>cards.map(card=>{const r=card.getBoundingClientRect();return {x:r.x,y:r.y,width:r.width};}));
          if (width>1100) assert.equal(new Set(boxes.map(box=>box.y)).size,1,'All five cards share one row');
          assert.equal(await page.locator('main .platform-download[data-platform="macOS"]').getAttribute('href'),mac.url);
          if(windows) {
            assert.equal(await page.locator('main .platform-download[data-platform="Windows"]').getAttribute('href'),windows.url);
            assert.equal((await page.locator('[data-platform-card="Windows"] .release-status').innerText()).trim(),locale==='ne'?'उपलब्ध छ':'Available now');
          }
          for (const platform of ['iOS','Android','Linux']) {
            assert.equal(await page.locator(`[data-platform-card="${platform}"] .platform-download`).count(),0);
            assert.ok(await page.locator(`[data-platform-card="${platform}"] .coming-soon`).isVisible());
            assert.equal(await page.locator(`[data-platform-card="${platform}"] .coming-soon`).innerText(),locale==='ne'?'छिट्टै आउँदैछ':'Coming soon');
            assert.equal(await page.locator(`[data-platform-card="${platform}"] .setup-link`).getAttribute('href'),prefix+'#try');
          }
          for (const slug of ['mac','windows']) {
            await page.locator(`main .setup-link[href="${prefix}${slug}/"]`).click();
            await page.waitForLoadState('networkidle');
            assert.equal(new URL(page.url()).pathname,prefix+slug+'/');
            if(slug==='windows') assert.ok((await page.locator('main').innerText()).includes('SmartScreen'));
            await page.goBack({waitUntil:'networkidle'});
          }
          if (process.env.AXE_CORE_PATH) {
            await page.addScriptTag({path:process.env.AXE_CORE_PATH});
            const result = await page.evaluate(async()=>await axe.run(document,{runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21aa']}}));
            accessibility.push({width,locale,violations:result.violations.map(v=>({id:v.id,impact:v.impact,targets:v.nodes.map(n=>n.target)}))});
            assert.deepEqual(accessibility.at(-1).violations,[],`Accessibility ${width} ${locale}`);
          }
          if ([1440,390].includes(width)) await page.screenshot({path:fileURLToPath(new URL(`${width}-${locale}-download.png`,reports)),fullPage:true});
        } else {
          assert.equal(await page.locator('.hero-actions .button').count(),1);
          assert.equal(await page.locator('.other-platforms-link').getAttribute('href'),prefix+'download/');
          if ([1440,390].includes(width)) await page.screenshot({path:fileURLToPath(new URL(`${width}-${locale}-home.png`,reports)),fullPage:true});
          if(width<=600) {
            await page.getByRole('button',{name:locale==='ne'?'नेभिगेसन खोल्नुहोस्':'Toggle navigation'}).click();
            assert.equal(await page.locator('.mobile-menu').getAttribute('aria-expanded'),'true');
            await page.keyboard.press('Escape');
            assert.equal(await page.locator('.mobile-menu').getAttribute('aria-expanded'),'false');
          }
        }
        checks.push(`${width}px ${prefix}${slug}: layout, locale, navigation, links`);
      }
    }
  }
  const devices = [
    {name:'Mac', userAgent:'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',platform:'MacIntel',maxTouchPoints:0},
    {name:'Windows',userAgent:'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',platform:'Win32',maxTouchPoints:0},
    {name:'iPhone',userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)',platform:'iPhone',maxTouchPoints:5},
    {name:'iPad desktop mode',userAgent:'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15)',platform:'MacIntel',maxTouchPoints:5},
    {name:'Android',userAgent:'Mozilla/5.0 (Linux; Android 14; Pixel)',platform:'Linux armv8l',maxTouchPoints:5},
    {name:'Linux',userAgent:'Mozilla/5.0 (X11; Linux x86_64)',platform:'Linux x86_64',maxTouchPoints:0},
    {name:'Unknown',userAgent:'Test browser',platform:'',maxTouchPoints:0},
    {name:'UA hints Windows',userAgent:'Mozilla/5.0',platform:'',maxTouchPoints:0,userAgentData:{platform:'Windows'}}
  ];
  for (const device of devices) {
    const ctx = await browser.newContext({viewport:{width:390,height:844},userAgent:device.userAgent});
    await ctx.addInitScript(device=>{
      for(const key of ['platform','maxTouchPoints','userAgentData']) Object.defineProperty(navigator,key,{get:()=>device[key],configurable:true});
    },device);
    const devicePage = await ctx.newPage();
    devicePage.on('pageerror',error=>errors.push(error.message));
    for (const locale of ['en','ne']) {
      const prefix = locale==='ne'?'/ne':'', platform = detectPlatform(device);
      await devicePage.goto(base+prefix+'/',{waitUntil:'networkidle'});
      const expected = downloadAction(platform,locale,{mac:mac.url,windows:windows?.url});
      const primary = devicePage.locator('.hero-actions [data-device-download]');
      assert.equal(await primary.getAttribute('href'),expected.href);
      assert.equal(await primary.textContent(),expected.label);
      assert.equal(await primary.getAttribute('data-analytics-event'),expected.event);
      assert.equal(await primary.getAttribute('data-platform'),expected.platform);
      if (['iOS','Android','Linux'].includes(platform)) {
        assert.equal(await devicePage.locator('#web-input').count(),1);
        await primary.click();
        await devicePage.waitForFunction(()=>{const box=document.querySelector('#web-input').getBoundingClientRect();return box.bottom>0 && box.top<innerHeight;});
      }
      if (platform==='unknown') {
        await primary.click();
      } else {
        await devicePage.locator('.other-platforms-link').click();
      }
      await devicePage.waitForLoadState('networkidle');
      assert.equal(new URL(devicePage.url()).pathname,prefix+'/download/');
      assert.equal(await devicePage.locator('[data-current-device]:visible').count(),['macOS','Windows','iOS','Android','Linux'].includes(platform)?1:0);
      checks.push(`${device.name} ${locale}: primary action, fallback, other platforms, device badge`);
    }
    await ctx.close();
  }
  const plain = await browser.newContext({javaScriptEnabled:false});
  const plainPage = await plain.newPage();
  for (const prefix of ['/','/ne/']) {
    await plainPage.goto(base+prefix);
    await plainPage.locator('.hero-actions .button').click();
    assert.equal(new URL(plainPage.url()).pathname,prefix+'download/');
    assert.equal(await plainPage.locator('main .platform-download').count(),windows?2:1);
    checks.push(`No JavaScript ${prefix}: fallback and installers`);
  }
  await page.setViewportSize({width:1440,height:900});
  await page.goto(base+'/download/',{waitUntil:'networkidle'});
  await page.keyboard.press('Tab');
  assert.equal(await page.locator('.skip-link').evaluate(el=>el===document.activeElement),true);
  await page.keyboard.press('Enter');
  assert.equal(new URL(page.url()).hash,'#main');
  const firstInstaller=page.locator('.platform-download').first();
  await firstInstaller.focus();
  assert.equal(await firstInstaller.evaluate(el=>getComputedStyle(el).outlineStyle),'solid');
  checks.push('Keyboard: skip link and visible installer focus');
  await page.goto(base+'/#try',{waitUntil:'networkidle'});
  await page.locator('#web-input').fill('namaste');
  await page.waitForFunction(()=>document.querySelector('#web-output').value==='नमस्ते',null,{timeout:120000});
  await page.locator('#web-copy').click();
  assert.equal(await page.evaluate(()=>navigator.clipboard.readText()),'नमस्ते');
  checks.push('Online destination: shared engine typing and Unicode clipboard');
  await page.locator('#web-input').fill('gaadi gadi gayera');
  await page.waitForFunction(()=>document.querySelector('#web-output').value==='गाडी गाडी गएर');
  checks.push('Published dictionary: vehicle and gayera spelling regressions');
  if(process.argv.includes('--verify-downloads')) {
    for(const [platform,release] of [['macOS',mac],['Windows',windows]]) {
      if(!release)continue;
      const response=await fetch(release.url,{signal:AbortSignal.timeout(120000)});
      assert.equal(response.status,200);
      const hash=createHash('sha256');let bytes=0;
      for await(const chunk of response.body){hash.update(chunk);bytes+=chunk.length;}
      const sha256=hash.digest('hex');
      assert.equal(bytes,release.bytes);assert.equal(sha256,release.sha256);
      liveDownloads.push({platform,url:release.url,status:response.status,bytes,sha256});
      checks.push(`Live ${platform} installer: HTTP 200, exact size and SHA-256`);
    }
  }
  assert.deepEqual(errors,[]);
  await writeFile(new URL('results.json',reports),JSON.stringify({base,checks,errors,accessibility,liveDownloads,verifiedAt:new Date().toISOString()},null,2));
  console.log(JSON.stringify({checks:checks.length,errors:errors.length,axeRuns:accessibility.length,verifiedDownloads:liveDownloads.length}));
} finally {
  if(browser)await browser.close();
  if(server.listening)await new Promise(resolve=>server.close(resolve));
}
