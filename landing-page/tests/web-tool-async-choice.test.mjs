import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

const moduleSource=fs.readFileSync(new URL('../web-tool.mjs',import.meta.url),'utf8').replace(/^import .*\n/gm,'');
const flush=()=>new Promise(resolve=>setImmediate(resolve));
async function setup(){
  let document;
  class Element{
    constructor(){this.value='';this.selectionStart=0;this.selectionEnd=0;this.handlers={};this.dataset={};}
    addEventListener(type,fn){(this.handlers[type]??=[]).push(fn);}
    fire(type,event={}){for(const fn of this.handlers[type]||[])fn(event);}
    setSelectionRange(start,end){this.selectionStart=start;this.selectionEnd=end;}
    focus(){document.activeElement=this;}
    replaceChildren(){} append(){} prepend(){} setAttribute(){}
  }
  const ids=['web-pad','web-input','web-output','web-status','web-suggestions','web-copy','web-mode','web-shortcut-help','web-example','web-clear'];
  const elements=Object.fromEntries(ids.map(id=>[id,new Element()]));
  elements['web-pad'].querySelector=selector=>elements[selector.slice(1)];
  elements['web-mode'].value='mixed';
  const input=elements['web-input'];
  document={getElementById:id=>elements[id],documentElement:{lang:'en'},createElement:()=>new Element(),activeElement:input};
  const pending=[];
  const engine={compose:request=>new Promise(resolve=>pending.push({request,resolve}))};
  vm.runInNewContext(moduleSource,{document,navigator:{platform:'iPhone'},window:{matchMedia:()=>({matches:true})},WebEngine:{load:async()=>engine},usesNumberSuggestions:()=>true,candidateIndex:value=>/^[1-5]$/.test(value||'')?Number(value)-1:-1});
  const response=request=>({source:request.source,active:{start:0,end:4,text:'pani',literal:false},candidates:['पानी','पनि','pani'],rendered:{text:request.choice||'पानी',words:[{start:0,value:request.choice||'पानी',outputStart:0,outputEnd:4}]}});
  input.value='pani';input.setSelectionRange(4,4);input.fire('input');await flush();
  const initial=pending.shift();initial.resolve(response(initial.request));await flush();
  async function choose(){let prevented=false;input.fire('beforeinput',{cancelable:true,inputType:'insertText',data:'2',preventDefault(){prevented=true;}});assert.equal(prevented,true);await flush();return pending.shift();}
  async function resolve(item){item.resolve(response(item.request));await flush();}
  return {input,document,elements,pending,choose,resolve};
}
test('superseded number choice does not restore stale caret or focus',async()=>{
  const h=await setup(),choice=await h.choose();h.input.setSelectionRange(1,1);h.input.fire('select');h.elements['web-mode'].focus();await flush();await h.resolve(choice);
  assert.equal(h.input.selectionStart,1);assert.equal(h.document.activeElement,h.elements['web-mode']);assert.equal(h.pending.length,1);
  await h.resolve(h.pending.shift());assert.equal(h.input.selectionStart,1);assert.equal(h.document.activeElement,h.elements['web-mode']);
});
test('applied number choice does not steal changed focus',async()=>{
  const h=await setup(),choice=await h.choose();h.elements['web-mode'].focus();await h.resolve(choice);assert.equal(h.document.activeElement,h.elements['web-mode']);
});
test('applied number choice preserves independently changed selection',async()=>{
  const h=await setup(),choice=await h.choose();h.input.setSelectionRange(1,1);await h.resolve(choice);assert.equal(h.input.selectionStart,1);
});
test('undisturbed number choice applies and preserves caret',async()=>{
  const h=await setup(),choice=await h.choose();await h.resolve(choice);assert.equal(h.elements['web-output'].value,'पनि');assert.equal(h.input.selectionStart,4);assert.equal(h.document.activeElement,h.input);
});
