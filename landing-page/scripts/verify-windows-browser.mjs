import {chromium} from 'playwright-core';
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {readFile, mkdir, writeFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {windowsDownload} from '../windows-release.mjs';

const root = path.resolve(fileURLToPath(new URL('../dist/', import.meta.url)));
const reports = new URL('../reports/windows/', import.meta.url);
const release = windowsDownload(JSON.parse(await readFile(new URL('../windows-release.json', import.meta.url))));
const mac = JSON.parse(await readFile(new URL('../mac-release.json', import.meta.url)));
const mime = {'.html':'text/html; charset=utf-8','.css':'text/css','.js':'text/javascript','.mjs':'text/javascript','.json':'application/json','.png':'image/png','.woff2':'font/woff2','.wasm':'application/wasm'};
const server = createServer(async(req,res)=>{
  const pathname = new URL(req.url,'http://localhost').pathname;
  const file = path.resolve(root,'.'+pathname+(pathname.endsWith('/')?'index.html':''));
  if (!file.startsWith(root+path.sep)) { res.writeHead(403).end(); return; }
  try { res.writeHead(200,{'Content-Type':mime[path.extname(file)]||'application/octet-stream'}).end(await readFile(file)); }
  catch { res.writeHead(404).end(); }
});
let browser;
const checks=[],errors=[];
try {
  await mkdir(reports,{recursive:true});
  let base=process.argv.find(value=>value.startsWith('--base-url='))?.slice('--base-url='.length);
  if(!base) {
    await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
    base='http://127.0.0.1:'+server.address().port;
  }
  base=base.replace(/\/$/,'');
  browser=await chromium.launch({channel:'chrome',headless:true});
  const context=await browser.newContext();
  await context.addInitScript(()=>localStorage.setItem('neptype-analytics-opt-out','true'));
  const page=await context.newPage();
  page.on('pageerror',error=>errors.push(error.message));
  page.on('console',message=>{if(message.type()==='error')errors.push(message.text());});
  page.on('response',response=>{if(response.status()>=400)errors.push(response.url());});
  for(const width of [1440,390,320]) {
    await page.setViewportSize({width,height:900});
    for(const prefix of ['/','/ne/']) {
      await page.goto(base+prefix,{waitUntil:'networkidle'});
      assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1), `Home overflow: ${width}px ${prefix}`);
      const windows=page.locator('.hero-actions a[href="'+prefix+'windows/"]');
      assert.equal(await windows.count(),1);
      assert.equal(await page.locator('a[data-mac-download]').getAttribute('href'),mac.url);
      await windows.click();
      await page.waitForLoadState('networkidle');
      await page.evaluate(()=>document.fonts.ready);
      await page.locator('h1').waitFor({state:'visible'});
      assert.equal(new URL(page.url()).pathname,prefix+'windows/');
      assert.equal(await page.locator('dialog[open]').count(),0);
      assert.equal(await page.locator('h1').count(),1);
      assert.equal(await page.locator('link[rel="canonical"]').getAttribute('href'),'https://neptype.com'+prefix+'windows/');
      assert.equal(await page.locator('link[hreflang="en"]').getAttribute('href'),'https://neptype.com/windows/');
      assert.equal(await page.locator('link[hreflang="ne"]').getAttribute('href'),'https://neptype.com/ne/windows/');
      const fits=await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1);
      if(!fits) await page.screenshot({path:fileURLToPath(new URL(`overflow-${width}-${prefix==='/ne/'?'ne':'en'}.png`,reports)),fullPage:true});
      assert.ok(fits, `Windows page overflow: ${width}px ${prefix}`);
      const downloads=page.locator('main a[data-analytics-event="neptype_download_clicked"]');
      if(release) {
        assert.equal(await downloads.getAttribute('href'),release.url);
        assert.equal(await downloads.getAttribute('data-platform'),'Windows');
        assert.ok((await page.locator('main').innerText()).includes(release.sha256));
        assert.equal(await page.locator('a[href="'+release.url+'.sha256"]').count(),1);
      } else {
        assert.equal(await downloads.count(),0);
        const schema=JSON.parse(await page.locator('script[type="application/ld+json"]').textContent());
        assert.ok(!schema['@graph'].some(entity=>entity['@type']==='SoftwareApplication'));
      }
      if(width!==320) await page.screenshot({path:fileURLToPath(new URL(`${width}-${prefix==='/ne/'?'ne':'en'}.png`,reports)),fullPage:true});
      checks.push(`${width}px ${prefix}windows/: navigation, locale, metadata, release gate, overflow; Mac link retained`);
    }
  }
  const plain=await browser.newContext({javaScriptEnabled:false});
  const plainPage=await plain.newPage();
  for(const route of ['/windows/','/ne/windows/']) {
    await plainPage.goto(base+route);
    assert.ok((await plainPage.locator('main').innerText()).length>500);
    assert.equal(await plainPage.locator('main a[href="'+(route.startsWith('/ne/')?'/ne/':'/')+'#try"]').count(),2);
    checks.push(`No JavaScript: ${route}`);
  }
  assert.deepEqual(errors,[]);
  await writeFile(new URL('results.json',reports),JSON.stringify({base,checks,errors,releaseVerified:Boolean(release),testedAt:new Date().toISOString()},null,2));
  console.log(JSON.stringify({checks:checks.length,errors:errors.length,releaseVerified:Boolean(release)}));
} finally {
  if(browser) await browser.close();
  if(server.listening) await new Promise(resolve=>server.close(resolve));
}
