import {chromium} from 'playwright-core';
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {readFile, mkdir, writeFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import {loadArticles} from '../article-content.mjs';
import {siteConfig} from '../site-config.mjs';

const root = path.resolve(fileURLToPath(new URL('../dist/',import.meta.url)));
const reportDirectory = new URL('../reports/articles/',import.meta.url);
const mime = {'.html':'text/html; charset=utf-8','.css':'text/css','.js':'text/javascript','.mjs':'text/javascript','.json':'application/json','.xml':'application/rss+xml','.png':'image/png','.woff2':'font/woff2','.wasm':'application/wasm'};
let server, browser;
try {
  let base = process.argv.find(value=>value.startsWith('--base-url='))?.split('=').slice(1).join('=');
  if (!base) {
    server = createServer(async (request,response) => {
      const pathname = decodeURIComponent(new URL(request.url,'http://localhost').pathname);
      const file = path.resolve(root,'.'+pathname+(pathname.endsWith('/')?'index.html':''));
      if (!file.startsWith(root+path.sep)) { response.writeHead(403).end(); return; }
      try { response.writeHead(200,{'Content-Type':mime[path.extname(file)]||'application/octet-stream'}).end(await readFile(file)); }
      catch { response.writeHead(404).end('Not found'); }
    });
    await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
    base = 'http://127.0.0.1:'+server.address().port;
  }
  base = base.replace(/\/$/,'');
  const latest = (await loadArticles())[0];
  assert.ok(latest,'There must be an article to verify.');
  const paths = ['/articles/','/ne/articles/','/articles/'+latest.slug+'/','/ne/articles/'+latest.slug+'/'];
  const errors = [], httpErrors = [], checks = [];
  browser = await chromium.launch({channel:'chrome',headless:true});
  const context = await browser.newContext({permissions:['clipboard-read','clipboard-write']});
  await context.addInitScript(()=>localStorage.setItem('neptype-analytics-opt-out','true'));
  const page = await context.newPage();
  page.on('pageerror',error=>errors.push(error.message));
  page.on('console',message=>{if(message.type()==='error')errors.push(message.text());});
  page.on('response',response=>{if(response.status()>=400)httpErrors.push(response.url());});
  await mkdir(reportDirectory,{recursive:true});
  for (const width of [1440,390,320]) {
    await page.setViewportSize({width,height:900});
    for (const pathname of paths) {
      const response = await page.goto(base+pathname+'?analytics_test=1',{waitUntil:'networkidle'});
      assert.equal(response.status(),200,pathname);
      assert.equal(await page.locator('h1').count(),1);
      const origin = siteConfig().origin;
      assert.equal(await page.locator('link[rel="canonical"]').getAttribute('href'),origin+pathname);
      assert.equal(await page.locator('meta[name="robots"]').getAttribute('content'),'index,follow,max-image-preview:large');
      const englishPath = pathname.replace(/^\/ne\//,'/');
      for(const [language,target] of [['en',englishPath],['ne','/ne'+englishPath],['x-default',englishPath]]) {
        assert.equal(await page.locator(`link[rel="alternate"][hreflang="${language}"]`).getAttribute('href'),origin+target);
      }
      assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=document.documentElement.clientWidth+1),`Overflow: ${pathname} at ${width}`);
      if (pathname.includes(latest.slug)) {
        assert.equal(await page.locator('time').first().getAttribute('datetime'),latest.published);
        assert.ok(await page.locator('main a[href$="#try"]').first().isVisible());
        assert.ok(await page.locator('main table').count()>0,'Article should include a worked example.');
        const entities = JSON.parse(await page.locator('script[type="application/ld+json"]').textContent())['@graph'];
        assert.equal(entities.find(entity=>entity['@type']==='TechArticle').datePublished,latest.published);
      }
      if(width!==320) await page.screenshot({path:fileURLToPath(new URL(width+'-'+pathname.replaceAll('/','_')+'.png',reportDirectory)),fullPage:true});
      checks.push(`${width}px ${pathname}`);
    }
  }
  const plain = await browser.newContext({javaScriptEnabled:false});
  const plainPage = await plain.newPage();
  for(const pathname of paths) {
    await plainPage.goto(base+pathname);
    assert.ok((await plainPage.locator('main').innerText()).length>200);
    assert.ok(await plainPage.locator('main a').first().isVisible());
    checks.push('No JavaScript: '+pathname);
  }
  await page.goto(base+'/?analytics_test=1',{waitUntil:'networkidle'});
  await page.locator('#web-input').fill('ma office janchu.');
  await page.waitForFunction(()=>document.querySelector('#web-output').value==='म office जान्छु।',{},{timeout:120000});
  await page.locator('#web-copy').click();
  assert.equal(await page.evaluate(()=>navigator.clipboard.readText()),'म office जान्छु।');
  checks.push('Article tool destination: real engine typing and clipboard');
  const sitemap = await fetch(base+'/sitemap.xml').then(response=>{assert.equal(response.status,200);return response.text();});
  for(const prefix of ['/','/ne/']) {
    const url = siteConfig().origin+prefix+'articles/'+latest.slug+'/';
    assert.ok(sitemap.includes('<loc>'+url+'</loc>'));
    const feed = await fetch(base+prefix+'articles/feed.xml').then(response=>{assert.equal(response.status,200);return response.text();});
    assert.ok(feed.includes('<link>'+url+'</link>'));
  }
  checks.push('Both article URLs appear in sitemap and localized feeds');
  assert.deepEqual(errors,[]); assert.deepEqual(httpErrors,[]);
  const report = {base,article:latest.slug,checks,consoleErrors:errors,httpErrors,verifiedAt:new Date().toISOString()};
  await writeFile(new URL('results.json',reportDirectory),JSON.stringify(report,null,2));
  console.log(JSON.stringify({base,article:latest.slug,checks:checks.length,consoleErrors:errors.length,httpErrors:httpErrors.length}));
} finally {
  if(browser) await browser.close();
  if(server) await new Promise(resolve=>server.close(resolve));
}
