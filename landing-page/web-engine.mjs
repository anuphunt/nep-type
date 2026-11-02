// Transport only. All typing, ranking, correction and history decisions run in Rust.
export class WebEngine {
  constructor(worker) { this.worker = worker; this.pending = new Map(); this.sequence = 0; }
  static load(onProgress = () => {}) {
    return new Promise((resolve, reject) => {
      const worker = new Worker(new URL('./engine-worker.mjs', import.meta.url), {type: 'module'});
      const engine = new WebEngine(worker);
      const fail = () => { worker.terminate(); reject(Error('Typing engine unavailable')); for (const item of engine.pending.values()) item.reject(Error('Typing engine unavailable')); engine.pending.clear(); };
      worker.onerror = fail;
      worker.onmessage = ({data}) => {
        if (data.type === 'progress') onProgress(data.percent);
        else if (data.type === 'ready') { engine.dictionaryId = data.dictionaryId; resolve(engine); }
        else if (data.type === 'error' && !data.id) fail();
        else { const item = engine.pending.get(data.id); if (!item) return; engine.pending.delete(data.id); data.error ? item.reject(Error('Typing request failed')) : item.resolve(data.value); }
      };
      worker.postMessage({type: 'init'});
    });
  }
  compose(request) {
    return new Promise((resolve,reject) => { const id = ++this.sequence; this.pending.set(id,{resolve,reject}); this.worker.postMessage({type:'compose',id,request}); });
  }
}
