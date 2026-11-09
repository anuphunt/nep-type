// Recreate social previews from the actual built homepage, never a mock editor.
import {chromium} from 'playwright-core';
import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const root=fileURLToPath(new URL('../dist/',import.meta.url));
const mime={'.html':'text/html; charset=utf-8','.css':'text/css','.js':'text/javascript','.mjs':'text/javascript','.json':'application/json','.png':'image/png','.woff2':'font/woff2','.wasm':'application/wasm'};
const server=createServer(async(req,res)=>{
  const pathname=new URL(req.url,'http://localhost').pathname;
  const file=path.resolve(root,'.'+pathname+(pathname.endsWith('/')?'index.html':''));
  if(!file.startsWith(root))return res.writeHead(403).end();
  try{const contents=await readFile(file);res.writeHead(200,{'Content-Type':mime[path.extname(file)]||'application/octet-stream'}).end(contents);}catch{res.writeHead(404).end();}
});
let browser;
try{
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  browser=await chromium.launch({channel:'chrome',headless:true});
  const context=await browser.newContext({viewport:{width:1200,height:630},deviceScaleFactor:1});
  await context.addInitScript(()=>localStorage.setItem('neptype-analytics-opt-out','true'));
  await context.route(/google-analytics\.com|googletagmanager\.com|posthog\.com/,route=>route.abort());
  const page=await context.newPage();
  for(const locale of ['en','ne']){
    await page.goto(`http://127.0.0.1:${server.address().port}/${locale==='ne'?'ne/':''}?analytics_test=1`,{waitUntil:'networkidle'});
    await page.locator('#web-input').fill('namaste! malai momo man parcha.');
    await page.waitForFunction(()=>document.querySelector('#web-output').value==='नमस्ते! मलाई मोमो मन पर्छ।',null,{timeout:120000});
    await page.evaluate(()=>{document.activeElement.blur();window.scrollTo(0,0);});
    await page.evaluate(()=>document.fonts.ready);
    await page.screenshot({path:fileURLToPath(new URL(`../assets/neptype-web-${locale}.png`,import.meta.url))});
  }
}finally{if(browser)await browser.close();await new Promise(resolve=>server.close(resolve));}
