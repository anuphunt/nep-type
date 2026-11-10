import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {build} from 'esbuild';

// Execute the real entry point with a small DOM and provider fixture. No network.
const bundled = await build({entryPoints:[new URL('../analytics.mjs',import.meta.url).pathname],bundle:true,write:false,format:'iife',define:{
  __POSTHOG_KEY__:'"fixture"',__POSTHOG_HOST__:'"https://events.invalid"',__GA_MEASUREMENT_ID__:'"G-TEST000001"',__PRODUCTION__:'true',__PUBLIC_PATHS__:'["/"]'
},plugins:[{name:'provider-fixture',setup(build){
  build.onResolve({filter:/^posthog-js$/},()=>({path:'posthog',namespace:'fixture'}));
  build.onLoad({filter:/.*/,namespace:'fixture'},()=>({contents:'export default globalThis.provider'}));
}}]});
async function boot({preference,legacy,dnt,gpc,blocked=false,testMode=false}={}) {
  const saved=new Map();if(preference)saved.set('neptype-analytics-consent-v1',preference);if(legacy)saved.set('neptype-analytics-opt-out','true');
  const created=[],scripts=[],events=[],listeners={};let stops=0;
  function element(tag){
    const children=new Map(),handlers={};
    const el={tag,handlers,hidden:false,open:false,setAttribute(){},addEventListener(name,fn){handlers[name]=fn;},append(){},showModal(){el.open=true;},close(){el.open=false;},querySelector(selector){if(!children.has(selector))children.set(selector,element('control'));return children.get(selector);}};
    return el;
  }
  const doc={documentElement:{lang:'en'},referrer:'https://google.com/search?q=PRIVATE',body:element('body'),head:{append(script){scripts.push(script);script.onload();}},
    createElement(tag){const el=element(tag);created.push(el);return el;},querySelector(){return element('footer');},getElementById(){return null;},addEventListener(){},set cookie(_){} };
  const win={location:{hostname:'neptype.com'},addEventListener(name,fn){listeners[name]=fn;}};
  Object.defineProperty(win,'localStorage',{get(){if(blocked)throw Error('Blocked');return {getItem:k=>saved.get(k)??null,setItem:(k,v)=>saved.set(k,v),removeItem:k=>saved.delete(k)};}});
  const provider={init(){},capture(name){events.push(name);},opt_in_capturing(){},opt_out_capturing(){stops++;}};
  vm.runInNewContext(bundled.outputFiles[0].text,{window:win,document:doc,navigator:{doNotTrack:dnt,globalPrivacyControl:gpc},location:{href:'https://neptype.com/?q=PRIVATE',search:testMode?'?analytics_test=1':''},URL,URLSearchParams,provider});
  await new Promise(resolve=>setImmediate(resolve));
  return {created,scripts,events,win,saved,listeners,get stops(){return stops;},dialog:created.find(el=>el.tag==='dialog')};
}
test('new visits start measurement automatically without a prompt or recording fake consent',async()=>{
  const state=await boot();
  assert.equal(state.scripts.length,1);assert.deepEqual(state.events,['neptype_pageview']);
  assert.equal(state.created.some(el=>el.tag==='section'),false);assert.equal(state.dialog.open,false);
  assert.equal(state.saved.size,0);
  assert.equal(state.win.dataLayer.filter(x=>x[0]==='event').length,1);
  assert.equal(JSON.stringify(state.win.dataLayer).includes('PRIVATE'),false);
});
test('previous opt-outs, DNT, GPC and test visits suppress all measurement',async()=>{
  for(const settings of [{preference:'denied'},{legacy:true},{preference:'granted',legacy:true},{dnt:'1'},{gpc:true},{testMode:true}]){
    const state=await boot(settings);assert.equal(state.scripts.length,0,JSON.stringify(settings));assert.deepEqual(state.events,[]);assert.ok(!state.dialog?.open);
  }
});
test('manual settings stop measurement without storage; opening is always user initiated',async()=>{
  const state=await boot({blocked:true});assert.equal(state.events.length,1);
  state.created.find(el=>el.className==='analytics-settings-link').handlers.click();assert.equal(state.dialog.open,true);
  state.dialog.handlers.click({target:{closest:selector=>selector==='[data-revoke]'?{}:null}});
  assert.equal(state.dialog.open,false);assert.equal(state.stops,1);assert.equal(state.win['ga-disable-G-TEST000001'],true);
  state.win.NepTypeAnalytics.capture('neptype_tool_used');assert.equal(state.events.length,1);
});
test('cross-tab preferences stop and resume without duplicating default-on pageviews',async()=>{
  const state=await boot();const key='neptype-analytics-consent-v1';
  state.saved.set(key,'granted');state.listeners.storage({key});assert.equal(state.events.length,1);
  state.saved.set(key,'denied');state.listeners.storage({key});assert.equal(state.stops,1);
  state.saved.set(key,'granted');state.listeners.storage({key});assert.equal(state.events.length,2);
});
