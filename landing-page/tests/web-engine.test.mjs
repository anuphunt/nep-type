import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import init, {query, dictionaryId, PadEngine} from '../engine-build/neptype_engine.js';
await init({module_or_path:await readFile(new URL('../engine-build/neptype_engine_bg.wasm',import.meta.url))});
const run = request => JSON.parse(query(JSON.stringify(request)));

test('WebAssembly matches all standalone dictionary candidate, rendering and session cases',async()=>{
  const cases=(await readFile(new URL('../../shared/fixtures/standalone-baseline.jsonl',import.meta.url),'utf8')).trim().split('\n');
  for (const line of cases) { const {request,expected}=JSON.parse(line); const value=run(request); assert.deepEqual(request.op==='session'?{trace:value.trace}:value,expected,JSON.stringify(request)); }
  assert.ok(cases.length>2000);
});
test('browser embeds the exact pinned native dictionary and source versions',async()=>{
  const manifest=JSON.parse(await readFile(new URL('../../engine/data/manifest.json',import.meta.url),'utf8'));
  assert.equal(dictionaryId(),manifest.id);
  assert.deepEqual(run({op:'info'}).dictionary,manifest);
  for(const [source,spelling] of [['bato','बाटो'],['bhaisakeko','भइसकेको']]) assert.ok(run({op:'candidates',source}).includes(spelling));
});
test('shared pad preserves explicit corrections, undo/redo, emoji ranges and repeated-word safety',()=>{
  const session = new PadEngine();
  const pad=(source,extra={})=>JSON.parse(session.request(JSON.stringify({op:"pad",source,mode:0,caret:source.length,...extra})));
  let value=pad('ma pani');const token=value.active;
  assert.equal(value.rendered.text,'म पनि');
  value=pad('ma pani',{token,choice:'पानी'});assert.equal(value.rendered.text,'म पानी');
  assert.equal(pad('👋 ma pani').rendered.text,'👋 म पानी');
  assert.equal(pad('👋 ma pani',{operation:'undo'}).rendered.text,'म पानी');
  assert.equal(pad('ma pani',{operation:'undo'}).rendered.text,'म पनि');
  assert.equal(pad('ma pani',{operation:'redo'}).rendered.text,'म पानी');
  assert.equal(pad('ma pani pani').rendered.text,'म पनि पनि');
});
test('existing Roman input remains literal in English mode and protects typed identifiers',()=>{
  const source='HTTPS://example.com `ma` foo_bar fooBar me@example.com 😀 नेपाली';
  for(const mode of [0,1,2]) assert.equal(run({op:'render',source,mode}).text,source);
  assert.equal(run({op:'render',source:'Maile yo',mode:0}).text,'मैले यो');
});
