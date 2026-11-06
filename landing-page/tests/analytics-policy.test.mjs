import test from 'node:test';
import assert from 'node:assert/strict';
import {readConsent,consentKey,legacyOptOutKey,analyticsPage,analyticsReferrer,coarseProperties} from '../analytics-policy.mjs';
import {googleAnalytics} from '../google-analytics.mjs';
test('unknown consent and inaccessible storage fail closed; old opt-outs stay denied',()=>{
  const storage=values=>({getItem:key=>values[key]??null});
  assert.equal(readConsent(storage({})),'unset');
  assert.equal(readConsent(storage({[consentKey]:'granted'})),'granted');
  assert.equal(readConsent(storage({[consentKey]:'granted',[legacyOptOutKey]:'true'})),'denied');
  assert.equal(readConsent({getItem(){throw Error('blocked');}}),'unset');
});
test('arbitrary URLs, campaign/query/hash data and event properties are excluded',()=>{
  assert.equal(analyticsPage('https://neptype.com/ne/?q=PRIVATE#PRIVATE',['/','/ne/']),'https://neptype.com/ne/');
  assert.equal(analyticsPage('https://neptype.com/PRIVATE',['/']),'https://neptype.com/404/');
  assert.equal(analyticsReferrer('https://www.google.com/search?q=PRIVATE#PRIVATE'),'https://google.com/');
  assert.equal(analyticsReferrer('https://private.example/PRIVATE?q=PRIVATE'),'');
  assert.equal(analyticsReferrer('https://google.com.evil.example/?q=PRIVATE'),'');
  assert.deepEqual(coarseProperties({mode:'PRIVATE',input:'PRIVATE',user_id:'PRIVATE',platform:'web'}),{platform:'web'});
});
test('revoking while the Google tag loads prevents initialization; opt-in can resume',async()=>{
  let allowed=false,script;const cookies=[];
  const win={location:{hostname:'neptype.com'}};
  const doc={head:{append(value){script=value;}},createElement(){return {remove(){}};},set cookie(v){cookies.push(v);}};
  const ga=googleAnalytics({id:'G-TEST000001',page:'https://neptype.com/',referrer:'https://google.com/',allowed:()=>allowed,win,doc});
  await ga.start();assert.equal(script,undefined);assert.equal(win.dataLayer,undefined);assert.equal(cookies.length,0);
  allowed=true;const pending=ga.start();assert.match(script.src,/googletagmanager.com/);assert.equal(script.referrerPolicy,'no-referrer');
  allowed=false;ga.stop();script.onload();await pending;
  assert.equal(win['ga-disable-G-TEST000001'],true);assert.ok(!win.dataLayer.some(x=>['config','event'].includes(x[0])));
  allowed=true;await ga.start();assert.equal(win['ga-disable-G-TEST000001'],false);
  const config=win.dataLayer.find(x=>x[0]==='config')[2];assert.equal(config.send_page_view,false);assert.equal(config.allow_google_signals,false);assert.equal(config.allow_ad_personalization_signals,false);
  assert.equal(config.page_location,'https://neptype.com/');assert.equal(config.page_referrer,'https://google.com/');
  assert.deepEqual(win.dataLayer.filter(x=>x[0]==='event').map(x=>x[1]),['page_view']);
  ga.stop();assert.equal(win['ga-disable-G-TEST000001'],true);assert.ok(cookies.every(x=>x.includes('Max-Age=0')));
  assert.ok(!win.dataLayer.some(x=>x[0]==='consent'&&x[1]==='update'));
});
