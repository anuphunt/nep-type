// Runs the compiled Rust library locally. Messages and document state never leave this worker.
let rust, padEngine, chain = Promise.resolve();
async function initialize() {
  const response = await fetch('/engine-config.json', {cache:'no-cache'});
  if (!response.ok) throw Error('Engine configuration unavailable');
  const config = await response.json();
  rust = await import(config.module);
  const compressed = typeof DecompressionStream !== 'undefined';
  const url = compressed ? config.compressed : config.wasm;
  let cache;
  try { cache = await caches.open('neptype-engine-v2'); } catch { /* Private mode may disable persistent cache. */ }
  let resource = await cache?.match(url);
  if (!resource) {
    resource = await fetch(url);
    if (!resource.ok) throw Error('Engine download failed');
    try { await cache?.put(url, resource.clone()); } catch { /* Typing works with memory-only caching too. */ }
  }
  const total = Number(resource.headers.get('Content-Length')) || (compressed ? config.compressedBytes : config.wasmBytes);
  const reader = resource.body.getReader(), chunks = []; let received = 0;
  while (true) { const {value,done} = await reader.read(); if (done) break; chunks.push(value); received += value.byteLength; self.postMessage({type:'progress',percent:Math.min(99,Math.round(received/total*100))}); }
  const bytes = new Uint8Array(received); let at = 0; for (const chunk of chunks) { bytes.set(chunk,at); at += chunk.byteLength; }
  const digest = [...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(b=>b.toString(16).padStart(2,'0')).join('');
  if (digest !== (compressed ? config.compressedSha256 : config.wasmSha256)) { try { await cache?.delete(url); } catch {} throw Error('Engine integrity check failed'); }
  const body = compressed ? new Response(bytes).body.pipeThrough(new DecompressionStream('gzip')) : bytes;
  await rust.default({module_or_path:new Response(body,{headers:{'Content-Type':'application/wasm'}})});
  if (rust.dictionaryId() !== config.dictionaryId) throw Error('Dictionary version mismatch');
  padEngine = new rust.PadEngine();
  self.postMessage({type:'ready',dictionaryId:config.dictionaryId});
}
self.onmessage = ({data}) => {
  chain = chain.then(async () => {
    if (data.type === 'init') await initialize();
    else if (data.type === 'compose') {
      const value = JSON.parse(padEngine.request(JSON.stringify({op:'pad',...data.request})));
      delete value.state;
      self.postMessage({id:data.id,value});
    }
  }).catch(() => self.postMessage({type:'error',id:data.id,error:true}));
};
