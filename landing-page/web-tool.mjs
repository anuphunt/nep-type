import {WebEngine} from './web-engine.mjs';
import {usesNumberSuggestions, candidateIndex} from './suggestion-shortcuts.mjs';

const pad = document.getElementById('web-pad');
if (pad) {
  const input = pad.querySelector('#web-input'), output = pad.querySelector('#web-output');
  const status = pad.querySelector('#web-status'), suggestions = pad.querySelector('#web-suggestions');
  const copy = pad.querySelector('#web-copy'), mode = pad.querySelector('#web-mode');
  const ne = document.documentElement.lang === 'ne';
  const mac = /Mac|iPhone|iPad/i.test(navigator.userAgentData?.platform || navigator.platform);
  const numberSuggestions = usesNumberSuggestions(navigator, window.matchMedia('(pointer: coarse)').matches);
  const shortcut = number => numberSuggestions ? String(number) : mac ? `⌥${number}` : `Alt+${number}`;
  const shortcutHelp = document.getElementById('web-shortcut-help');
  if (numberSuggestions && shortcutHelp) shortcutHelp.textContent = ne
    ? 'शब्द छानेर सुझाव थिच्नुहोस् वा त्यसको नम्बर टाइप गर्नुहोस्। अङ्क नै लेख्न पहिले स्पेस थिच्नुहोस्।'
    : 'Tap a suggestion or type its number for the active word. To enter a number as text, type a space first.';
  const words = {
    ready: ne ? 'तयार छ — नेपाली लेख्न सुरु गर्नुहोस्।' : 'Ready to type — start writing in Nepali.',
    loading: ne ? 'टाइपिङ तयार हुँदैछ…' : 'Getting the editor ready…',
    loadingHint: ne ? 'अहिले लेख्न सक्नुहुन्छ; तयार भएपछि नेपाली पाठ देखिनेछ।' : 'You can type now; Nepali output will appear when it’s ready.',
    error: ne ? 'प्याड लोड भएन। फेरि प्रयास गर्न यहाँ क्लिक गर्नुहोस्।' : 'The pad couldn’t load. Click here to retry.',
    copied: ne ? 'कपी भयो।' : 'Copied.',
    copyFailed: ne ? 'पाठ छानेर कपी गर्नुहोस्।' : 'Select the output and copy it.',
    pick: ne ? 'शब्द छानेर हिज्जे रोज्नुहोस्।' : 'Select a word to see other spellings.'
  };
  let engine, loading, used = false, revision = 0, page = 0, pageWord = '', lastKey = '';
  let current = {source:'', rendered:{text:'',words:[]}, active:null, candidates:[]};
  const track = (name, properties = {}) => window.NepTypeAnalytics?.capture(name, {mode:mode.value,...properties});
  function setStatus(state, text) {
    status.dataset.state = state;
    status.textContent = text;
  }
  function showLoading(percent) {
    setStatus('loading', `${words.loading}${Number.isFinite(percent) ? ` ${percent}%` : ''} ${words.loadingHint}`);
  }
  async function load() {
    if (engine) return engine;
    if (loading) return loading;
    showLoading();
    loading = WebEngine.load(showLoading).then(value => {
      engine = value; pad.dataset.dictionaryId = value.dictionaryId; setStatus('ready', words.ready); return value;
    }).catch(error => { loading = null; setStatus('error', words.error); throw error; });
    return loading;
  }
  function visibleCandidates() {
    if (!current.active) return [];
    const alternatives = current.candidates.filter(value => value !== current.active.text);
    return [...alternatives.slice(page*4,page*4+4),current.active.text];
  }
  function drawSuggestions() {
    suggestions.replaceChildren();
    if (!current.active || current.source !== input.value) { const hint = document.createElement('span'); hint.textContent = words.pick; suggestions.append(hint); return; }
    const word = current.active, identity = `${word.start}:${word.text}`;
    if (identity !== pageWord) { pageWord = identity; page = 0; }
    const pages = Math.max(1,Math.ceil(current.candidates.filter(v=>v!==word.text).length/4)); page = Math.min(page,pages-1);
    const label = document.createElement('span'); label.textContent = word.text; label.className = 'suggestion-source'; suggestions.append(label);
    const selected = current.rendered.words.find(value=>value.start===word.start)?.value;
    for (const [index,value] of visibleCandidates().entries()) {
      const button = document.createElement('button'); button.type = 'button'; button.textContent = value;
      const hint = document.createElement('kbd'); hint.textContent = shortcut(index+1); hint.setAttribute('aria-hidden','true');
      if (numberSuggestions) { hint.className = 'suggestion-number'; button.prepend(hint); } else button.append(hint);
      button.setAttribute('aria-pressed',String(value===selected)); button.setAttribute('aria-keyshortcuts',numberSuggestions ? String(index+1) : `Alt+${index+1}`);
      button.title = numberSuggestions ? `${index+1} · ${value}` : `${value} · ${mac?'Option':'Alt'} + ${index+1}`; button.setAttribute('aria-label',button.title);
      if (/[\u0900-\u097f]/u.test(value)) button.lang = 'ne';
      button.addEventListener('mousedown',event=>event.preventDefault()); button.addEventListener('click',()=>choose(value)); suggestions.append(button);
    }
    if (pages>1) {
      for (const [delta,text] of [[-1,ne?'अघिल्लो':'Previous'],[1,ne?'अर्को':'Next']]) {
        const button = document.createElement('button'); button.type='button'; button.textContent=text;
        button.disabled=page+delta<0||page+delta>=pages; button.setAttribute('aria-label',`${text} ${ne?'सुझाव':'suggestions'}`);
        button.addEventListener('mousedown',event=>event.preventDefault()); button.addEventListener('click',()=>{page+=delta;drawSuggestions();}); suggestions.append(button);
      }
      const counter=document.createElement('span'); counter.textContent=`${page+1} / ${pages}`; suggestions.append(counter);
    }
  }
  function sourceCaret(editor = document.activeElement) {
    if (editor !== output) return input.selectionStart;
    const word = current.rendered.words.find(w=>output.selectionStart>=w.outputStart&&output.selectionStart<=w.outputEnd);
    return word ? word.start : input.value.length+1;
  }
  async function update(entry = 'typing', extra = {}, beforeApply = () => {}) {
    const source = input.value, caret = extra.caret ?? sourceCaret();
    const key = JSON.stringify([source,mode.value,caret]);
    if (key===lastKey&&!extra.choice&&!extra.operation) return;
    lastKey=key; const generation=++revision;
    try {
      await load(); if (generation!==revision) return;
      const value = await engine.compose({source,caret,mode:mode.value==='all'?2:0,...extra});
      if (generation!==revision || input.value!==source) return;
      current=value;
      if (extra.operation) { input.value=value.source; mode.value=value.mode===2?'all':'mixed'; input.setSelectionRange(Math.min(caret,input.value.length),Math.min(caret,input.value.length)); lastKey=JSON.stringify([input.value,mode.value,input.selectionStart]); }
      beforeApply();
      output.value=value.rendered.text; copy.disabled=!output.value; setStatus('ready', words.ready); drawSuggestions();
      if (!used&&input.value.trim()) { used=true;track('neptype_tool_used',{entry_method:entry}); }
      return true;
    } catch { if (generation===revision) {lastKey='';setStatus('error', words.error);} }
  }
  async function choose(value) {
    if (!current.active || current.source!==input.value || !current.candidates.includes(value)) return;
    const editor=document.activeElement===output?output:input, start=editor.selectionStart, end=editor.selectionEnd;
    const selected=current.active, focused=document.activeElement;
    let restoreSelection = false;
    const applied = await update('typing',{choice:value,token:selected,caret:selected.start},()=>{
      restoreSelection = document.activeElement === focused && editor.selectionStart === start && editor.selectionEnd === end;
    });
    if (applied && restoreSelection) { editor.focus({preventScroll:true});editor.setSelectionRange(start,end); }
    if (applied) track('neptype_tool_word_selected');
  }
  function chooseNumber(digit, editor) {
    const index = candidateIndex(digit);
    if (index < 0 || !numberSuggestions || !current.active || current.source !== input.value ||
        editor.selectionStart !== editor.selectionEnd) return false;
    const caret = sourceCaret(editor), word = current.active;
    // Never eat a digit after whitespace, during pending composition, or on a stale word.
    if (word.literal || caret < word.start || caret > word.end) return false;
    const value = visibleCandidates()[index];
    if (value === undefined) return false;
    choose(value);
    return true;
  }
  input.addEventListener('beforeinput', event => {
    // Soft keyboards often provide no useful keydown.code. Paste, replacement text,
    // IME composition and non-cancelable input must keep their normal behavior.
    if (event.cancelable && !event.isComposing && event.inputType === 'insertText' && chooseNumber(event.data, input)) event.preventDefault();
  });
  input.addEventListener('focus',()=>load().catch(()=>{}));
  input.addEventListener('input',event=>{if(!event.isComposing)update();}); input.addEventListener('compositionend',()=>update());
  for (const editor of [input,output]) {
    for (const event of ['click','keyup','select']) editor.addEventListener(event,()=>{if(engine)update('typing',{caret:sourceCaret(editor)});});
    editor.addEventListener('keydown',event=>{
      if (event.isComposing || event.getModifierState('AltGraph')) return;
      if ((event.metaKey||event.ctrlKey)&&!event.altKey&&(event.code==='KeyZ'||event.code==='KeyY')) {
        event.preventDefault(); update('typing',{operation:event.shiftKey||event.code==='KeyY'?'redo':'undo'}); return;
      }
      if ((event.metaKey||event.ctrlKey)&&event.altKey&&!event.shiftKey&&['BracketLeft','BracketRight'].includes(event.code)) {
        event.preventDefault();const pages=Math.max(1,Math.ceil(current.candidates.filter(v=>v!==current.active?.text).length/4));page=Math.max(0,Math.min(pages-1,page+(event.code==='BracketLeft'?-1:1)));drawSuggestions();return;
      }
      if (!event.altKey && !event.ctrlKey && !event.metaKey && !event.shiftKey && chooseNumber(event.key, editor)) {
        event.preventDefault(); return;
      }
      if (!event.altKey||event.ctrlKey||event.metaKey||event.shiftKey) return;
      const match=/^Digit([1-9])$/.exec(event.code), value=match&&visibleCandidates()[Number(match[1])-1];
      if (value!==undefined&&current.source===input.value) {event.preventDefault();choose(value);}
    });
  }
  mode.addEventListener('change',async()=>{await update();track('neptype_tool_mode_changed');});
  pad.querySelector('#web-example').addEventListener('click',()=>{input.value=input.placeholder;input.setSelectionRange(input.value.length-1,input.value.length-1);update('example');});
  pad.querySelector('#web-clear').addEventListener('click',()=>{input.value='';output.value='';copy.disabled=true;page=0;pageWord='';suggestions.replaceChildren();lastKey='';input.focus();update();});
  copy.addEventListener('click',async()=>{
    try {await navigator.clipboard.writeText(output.value);setStatus('ready', words.copied);track('neptype_tool_output_copied');}
    catch {output.focus();output.select();setStatus('error', words.copyFailed);}
  });
  status.addEventListener('click',()=>{if(!engine){lastKey='';update();}});
  if ('IntersectionObserver' in window) {const observer=new IntersectionObserver(entries=>{if(entries.some(entry=>entry.isIntersecting)){load().catch(()=>{});observer.disconnect();}},{rootMargin:'150px'});observer.observe(pad);}
}
