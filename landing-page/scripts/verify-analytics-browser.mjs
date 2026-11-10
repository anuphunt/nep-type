import {chromium} from 'playwright-core';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import assert from 'node:assert/strict';
import {gunzipSync} from 'node:zlib';
const root=path.resolve(fileURLToPath(new URL('../dist/',import.meta.url)));
const reports=new URL('../reports/ga-consent-2026-11-06/',import.meta.url);
const mime={'.html':'text/html','.css':'text/css','.js':'text/javascript','.mjs':'text/javascript','.json':'application/json','.png':'image/png','.woff2':'font/woff2','.wasm':'application/wasm'};
const id='G-TEST000001',secret='SYNTHETIC_NEPTYPE_PRIVACY_SENTINEL';
const stub=`(()=>{const id='${id}';const q=window.dataLayer||[];const existing=[...q];const push=q.push.bind(q);function handle(entry){const a=Array.from(entry);window.__vendorCalls||=[];window.__vendorCalls.push(a);if(a[0]==='config')window.__fixtureConfig=a[2];if(a[0]==='event'&&!window['ga-disable-'+id]){const c=window.__fixtureConfig||{};document.cookie='_ga=fixture; Path=/; SameSite=Lax; Secure';document.cookie='_ga_TEST000001=fixture; Path=/; SameSite=Lax; Secure';fetch('https://www.google-analytics.com/g/collect?'+new URLSearchParams({tid:id,en:a[1],dl:c.page_location||'',dr:c.page_referrer||'',dt:c.page_title||''}),{method:'POST',body:''});}}q.push=(...entries)=>{entries.forEach(handle);return push(...entries)};existing.forEach(handle);})();`;
const checks=[],errors=[],providerChecks=[],payloadReview=[];let browser;
const expectPosthog=process.env.EXPECT_POSTHOG==='1';
async function setup(options={},delay){
 const context=await browser.newContext({userAgent:'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36',...options}),requests=[];
 // Exercise the SDK normal-visitor path only in isolated intercepted fixtures.
 // Production bot detection remains unchanged.
 await context.addInitScript(()=>{Object.defineProperty(navigator,'webdriver',{get:()=>false});Object.defineProperty(navigator,'userAgentData',{get:()=>({brands:[{brand:'Chromium',version:'144'}],mobile:false,platform:'macOS'})});});
 context.on('page',p=>p.on('console',m=>{if(m.type()==='error')errors.push(m.text());}));
 await context.route('**/*',async route=>{
  const req=route.request(),url=new URL(req.url());
  if(url.hostname==='neptype.test'){
   const file=path.resolve(root,'.'+decodeURIComponent(url.pathname)+(url.pathname.endsWith('/')?'index.html':''));
   if(!file.startsWith(root+path.sep))return route.fulfill({status:403,body:''});
   try{return route.fulfill({status:200,contentType:mime[path.extname(file)]||'application/octet-stream',body:await readFile(file)});}catch{return route.fulfill({status:404,body:''});}
  }
  requests.push({url:req.url(),method:req.method(),body:req.postData()||'',body64:req.postDataBuffer()?.toString('base64')||'',referer:req.headers().referer||''});
  if(url.hostname==='www.googletagmanager.com'){
   if(delay)await delay;
   return route.fulfill({status:200,contentType:'text/javascript',body:stub});
  }
  if(url.hostname==='events.invalid')return route.fulfill({status:200,contentType:'application/json',headers:{'access-control-allow-origin':'*'},body:'{"status":1}'});
  if(url.hostname==='www.google-analytics.com')return route.fulfill({status:204,headers:{'access-control-allow-origin':'*'},body:''});
  throw Error('Unexpected outbound test request: '+url.origin);
 });
 return {context,requests};
}
const settings=p=>p.locator('.analytics-settings-link');
const grant=p=>p.locator('.analytics-consent [data-choice="granted"]');
const decline=p=>p.locator('.analytics-consent [data-choice="denied"]');
const countGoogle=rs=>rs.filter(r=>new URL(r.url).hostname.includes('google')).length;
const phCount=rs=>rs.filter(r=>new URL(r.url).hostname==='events.invalid').length;
async function recorded(predicate){for(let n=0;n<100;n++){if(predicate())return;await new Promise(resolve=>setTimeout(resolve,50));}throw Error('Fixture provider request not recorded');}
try{
 await mkdir(reports,{recursive:true});browser=await chromium.launch({channel:'chrome',headless:true});
 for(const width of [1440,390,320])for(const locale of ['en','ne']){
  const {context,requests}=await setup({viewport:{width,height:900},permissions:['clipboard-read','clipboard-write']});const p=await context.newPage();
  p.on('pageerror',e=>errors.push(e.message));
  const prefix=locale==='ne'?'/ne/':'/';
  await p.goto('https://neptype.test'+prefix+'?q='+secret+'&utm_campaign='+secret+'#'+secret,{referer:'https://www.google.com/search?q='+secret});
  await p.locator('.analytics-consent').waitFor({state:'visible'});assert.equal(countGoogle(requests),0);assert.equal(requests.length,0);
  assert.deepEqual((await context.cookies()).filter(c=>c.name.startsWith('_ga')),[]);
  assert.equal(await p.evaluate(()=>localStorage.length),0);
  assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
  const contrast=await p.locator('.analytics-consent').evaluate(el=>{
    const rgb=s=>(s.match(/[0-9.]+/g)||[]).slice(0,3).map(Number);
    const luminance=c=>c.map(v=>{v/=255;return v<=.04045?v/12.92:((v+.055)/1.055)**2.4}).reduce((a,v,i)=>a+v*[.2126,.7152,.0722][i],0);
    const ratio=(a,b)=>{const x=luminance(rgb(a)),y=luminance(rgb(b));return(Math.max(x,y)+.05)/(Math.min(x,y)+.05)};
    const background=getComputedStyle(el).backgroundColor;
    return [...el.querySelectorAll('p,button')].map(node=>{const st=getComputedStyle(node),r=node.getBoundingClientRect();return {tag:node.tagName,ratio:ratio(st.color,node.tagName==='BUTTON'?st.backgroundColor:background),height:r.height,width:r.width}});
  });
  assert.ok(contrast.every(x=>x.ratio>=4.5));assert.ok(contrast.filter(x=>x.tag==='BUTTON').every(x=>x.height>=44&&x.width>=44));
  if(width!==320)await p.screenshot({path:fileURLToPath(new URL(`consent-${width}-${locale}.png`,reports)),fullPage:true});
  await decline(p).click();assert.equal(await p.evaluate(()=>document.activeElement.id),'main');await p.locator('#web-input').fill('namaste');
  await p.waitForFunction(()=>document.querySelector('#web-output').value==='नमस्ते',null,{timeout:120000});
  await p.locator('#web-copy').click();assert.equal(await p.evaluate(()=>navigator.clipboard.readText()),'नमस्ते');assert.equal(requests.length,0);
  await p.reload();await settings(p).waitFor();assert.equal(requests.length,0);assert.ok(await p.locator('.analytics-consent').isHidden());
  await settings(p).click();await p.locator('.analytics-dialog [data-choice="granted"]').click();
  await p.waitForFunction(()=>window.__fixtureConfig);assert.equal(requests.filter(r=>r.url.includes('/g/collect')).length,1);
  const data=await p.evaluate(()=>window.__vendorCalls);const config=data.find(a=>a[0]==='config')[2];
  assert.equal(config.page_location,'https://neptype.com'+prefix);assert.equal(config.page_referrer,'https://google.com/');assert.equal(config.page_title,'NepType');
  assert.equal(config.allow_google_signals,false);assert.equal(config.allow_ad_personalization_signals,false);assert.equal(config.send_page_view,false);
  assert.ok(!JSON.stringify(data).includes(secret));
  assert.ok(!await p.evaluate(secret=>JSON.stringify({...localStorage,...sessionStorage}).includes(secret),secret));assert.ok(!JSON.stringify(requests).includes(secret));
  await p.locator('#web-input').fill('namaste');await settings(p).click();await p.locator('[data-revoke]').click();
  assert.equal(await p.locator('#web-input').inputValue(),'namaste');assert.equal(await p.evaluate(id=>window['ga-disable-'+id],id),true);
  assert.deepEqual((await context.cookies()).filter(c=>c.name.startsWith('_ga')),[]);
  const total=requests.length;await p.goto('https://neptype.test'+prefix+'privacy/');await settings(p).waitFor();assert.equal(requests.length,total);
  await settings(p).click();assert.equal(await p.locator('.analytics-dialog').getAttribute('aria-labelledby'),'analytics-settings-title');
  if(width!==320)await p.screenshot({path:fileURLToPath(new URL(`settings-${width}-${locale}.png`,reports)),fullPage:true});
  for(let n=0;n<6;n++){await p.keyboard.press('Tab');assert.ok(await p.locator('.analytics-dialog').evaluate(el=>el.contains(document.activeElement)));}
  await p.keyboard.press('Escape');assert.ok(await p.locator('.analytics-dialog').isHidden());assert.ok(await settings(p).evaluate(el=>document.activeElement===el));
  checks.push(`${width}px ${locale}: no-consent/decline/revisit/allow/revoke/navigation; clean page/referrer; typing/copy preserved`);await context.close();
 }
 {
  const {context,requests}=await setup();const p=await context.newPage();
  await p.goto('https://neptype.test/?q='+secret+'#'+secret,{referer:'https://www.google.com/search?q='+secret});await grant(p).click();await p.waitForFunction(()=>window.__fixtureConfig);
  assert.equal(await p.evaluate(()=>window.__fixtureConfig.page_referrer),'https://google.com/');assert.ok(!JSON.stringify(requests).includes(secret));checks.push('Fresh consent retains only reviewed search-engine origin, excluding source search terms');await context.close();
 }
 {
  const {context,requests}=await setup();const p=await context.newPage();
  await p.goto('https://neptype.test/?q='+secret+'#'+secret);
  await p.evaluate(secret=>window.NepTypeAnalytics.capture('neptype_tool_output_copied',{mode:'all',input:secret}),secret);
  assert.equal(requests.length,0);
  await grant(p).click();await p.waitForFunction(()=>window.__fixtureConfig);
  if(expectPosthog){
   await recorded(()=>phCount(requests)>0);
   assert.ok(requests.some(r=>new URL(r.url).hostname==='events.invalid'),'PostHog capture must actually run after consent');
   const beforeAction=phCount(requests);
   await p.evaluate(secret=>window.NepTypeAnalytics.capture('neptype_tool_mode_changed',{mode:'all',platform:'web',input:secret,user_id:secret,placement:secret}),secret);
   await recorded(()=>phCount(requests)>beforeAction);
  }
  await settings(p).click();await p.locator('[data-revoke]').click();
  const count=requests.length;await p.evaluate(()=>window.NepTypeAnalytics.capture('neptype_tool_output_copied',{mode:'all'}));
  await p.waitForTimeout(150);assert.equal(requests.length,count);
  const beforeResume=phCount(requests);
  await settings(p).click();await p.locator('.analytics-dialog [data-choice="granted"]').click();
  await p.waitForFunction(()=>window.__vendorCalls.filter(x=>x[0]==='event').length===2);
  if(expectPosthog){
   await recorded(()=>phCount(requests)>beforeResume);
   const hits=requests.filter(r=>new URL(r.url).hostname==='events.invalid');
   const payloads=hits.map(r=>{
    const data=Buffer.from(r.body64,'base64');
    if(data[0]===31&&data[1]===139)return gunzipSync(data).toString();
    const encoded=new URLSearchParams(r.body).get('data');
    if(encoded){try{return Buffer.from(encoded,'base64').toString();}catch{}}
    return r.body;
   });
   assert.ok(payloads.some(s=>s.includes('neptype_pageview')),'Read actual PostHog fixture event payloads');
   assert.ok(!payloads.some(s=>s.includes(secret)));
   const findEvents=x=>Array.isArray(x)?x.flatMap(findEvents):x&&typeof x==='object'?(typeof x.event==='string'&&x.properties?[x]:Object.values(x).flatMap(findEvents)):[];
   const events=payloads.flatMap(s=>findEvents(JSON.parse(s)));
   assert.ok(events.length>=3,'Decoded PostHog envelopes contain each reviewed event');
   assert.ok(events.every(e=>!e.$set&&!e.$set_once&&!e.$unset));assert.ok(events.every(e=>e.properties.$process_person_profile===false));assert.ok(events.every(e=>e.properties.is_test===false));
   payloadReview.push({events:events.map(e=>e.event),propertyKeys:[...new Set(events.flatMap(e=>Object.keys(e.properties)))],personProfiles:false});
   assert.ok(!payloads.some(s=>s.includes('neptype_tool_output_copied')),'Pre-consent and revoked captures must never replay');
   assert.ok(payloads.some(s=>s.includes('neptype_tool_mode_changed')),'Reviewed action capture resumes');
   providerChecks.push({posthogRequests:hits.length,actualPayloadDecoded:true,noSentinel:true,noPreConsentReplay:true,samePageReenable:true});
  }
  checks.push('Same-page revoke/re-enable; discarded pre-consent and revoked events; PostHog payload review when configured');await context.close();
 }
 // Consent persists across page loads; a revocation also disables already-open tabs.
 {
  const {context,requests}=await setup();await context.addInitScript(()=>localStorage.setItem('neptype-analytics-consent-v1','granted'));
  const p=await context.newPage();await p.goto('https://neptype.test/');await p.waitForFunction(()=>window.__fixtureConfig);
  const second=await context.newPage();await second.goto('https://neptype.test/privacy/');await second.waitForFunction(()=>window.__fixtureConfig);
  await settings(p).click();await p.locator('[data-revoke]').click();await second.waitForFunction(id=>window['ga-disable-'+id]===true,id);
  assert.equal(requests.filter(r=>r.url.includes('/g/collect')).length,2);checks.push('Cross-tab revoke disables the other loaded Google instance');await context.close();
 }
 // A tag response arriving after revoke must not initialize a destination or emit a page view.
 {
  let release;const delayed=new Promise(resolve=>release=resolve);const {context,requests}=await setup({},delayed);const p=await context.newPage();
  await p.goto('https://neptype.test/');await grant(p).click();await settings(p).click();await p.locator('[data-revoke]').click();release();
  await p.waitForFunction(()=>window.__vendorCalls);assert.equal(await p.evaluate(()=>Boolean(window.__fixtureConfig)),false);assert.equal(requests.filter(r=>r.url.includes('/g/collect')).length,0);
  checks.push('Delayed Google tag response after revoke has no config or collection');await context.close();
 }
 for(const signal of ['doNotTrack','globalPrivacyControl']){
  const {context,requests}=await setup();await context.addInitScript(signal=>Object.defineProperty(navigator,signal,{get:()=>signal==='doNotTrack'?'1':true}),signal);
  const p=await context.newPage();await p.goto('https://neptype.test/');await settings(p).click();assert.ok(await p.locator('.analytics-dialog [data-choice="granted"]').isDisabled());assert.equal(requests.length,0);checks.push(signal+' blocks consent grant and provider requests');await context.close();
 }
 {
  const {context,requests}=await setup();await context.addInitScript(()=>Object.defineProperty(window,'localStorage',{get(){throw new DOMException('Blocked','SecurityError');}}));
  const p=await context.newPage();p.on('pageerror',e=>errors.push(e.message));await p.goto('https://neptype.test/');await decline(p).click();assert.equal(requests.length,0);await settings(p).click();await p.locator('.analytics-dialog [data-choice="granted"]').click();await p.waitForFunction(()=>window.__fixtureConfig);await settings(p).click();await p.locator('[data-revoke]').click();checks.push('Blocked browser storage: denied by default; allow/revoke work in page memory');await context.close();
 }
 {
  const {context,requests}=await setup({javaScriptEnabled:false});const p=await context.newPage();await p.goto('https://neptype.test/ne/privacy/');assert.ok((await p.locator('main').innerText()).includes('Google Analytics'));assert.equal(requests.length,0);checks.push('No JavaScript: localized policy remains available; no providers');await context.close();
 }
 assert.deepEqual(errors,[]);
 await writeFile(new URL('browser-fixture.json',reports),JSON.stringify({verifiedAt:new Date().toISOString(),checks,errors,providerChecks,payloadReview,expectPosthog,scope:'Isolated synthetic fixtures. Vendor responses/collection intercepted; this verifies consent and sanitized commands, not actual Google library payloads or live configuration.',measurementId:id},null,2));
 console.log(JSON.stringify({checks:checks.length,errors:errors.length,actualVendorDataSent:false}));
}finally{if(browser)await browser.close();}
