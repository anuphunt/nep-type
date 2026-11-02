import {WebEngine, retainChoices} from './web-engine.mjs';

const pad = document.getElementById('web-pad');
if (pad) {
  const input = pad.querySelector('#web-input');
  const output = pad.querySelector('#web-output');
  const status = pad.querySelector('#web-status');
  const suggestions = pad.querySelector('#web-suggestions');
  const copy = pad.querySelector('#web-copy');
  const mode = pad.querySelector('#web-mode');
  const ne = document.documentElement.lang === 'ne';
  const words = {
    ready: ne ? 'तपाईंको लेखाइ यही ब्राउजरमा रहन्छ।' : 'Your text stays in this browser.',
    loading: ne ? 'टाइपिङ तयार हुँदैछ…' : 'Getting the pad ready…',
    error: ne ? 'प्याड लोड भएन। फेरि प्रयास गर्नुहोस्।' : 'The pad couldn’t load. Please try again.',
    copied: ne ? 'कपी भयो।' : 'Copied.',
    copyFailed: ne ? 'पाठ छानेर कपी गर्नुहोस्।' : 'Select the output and copy it.',
    pick: ne ? 'शब्द छानेर हिज्जे रोज्नुहोस्।' : 'Select a word to see other spellings.'
  };
  let engine, loading, previous = '', overrides = new Map(), activeStart = null;
  let rendered = {text: '', words: []}, used = false, revision = 0;
  function track(name, properties = {}) { window.NepTypeAnalytics?.capture(name, {mode: mode.value, ...properties}); }
  function markUsed(entry) {
    if (!used && input.value.trim()) { used = true; track('neptype_tool_used', {entry_method: entry}); }
  }
  async function load() {
    if (engine) return engine;
    if (loading) return loading;
    status.textContent = words.loading;
    loading = fetch('/assets/web-dictionary.json').then(response => {
      if (!response.ok) throw Error('Dictionary unavailable');
      return response.json();
    }).then(data => {
      engine = new WebEngine(data); status.textContent = words.ready; return engine;
    }).catch(() => {
      loading = null; status.textContent = words.error; throw Error('Dictionary unavailable');
    });
    return loading;
  }
  function activeWord() {
    return rendered.words.find(word => word.start === activeStart && !word.literal);
  }
  function drawSuggestions() {
    suggestions.replaceChildren();
    const word = activeWord();
    if (!word) {
      const hint = document.createElement('span'); hint.textContent = words.pick;
      suggestions.append(hint); return;
    }
    const label = document.createElement('span'); label.textContent = word.text;
    label.className = 'suggestion-source'; suggestions.append(label);
    for (const value of engine.candidates(word.text)) {
      const button = document.createElement('button');
      button.type = 'button'; button.textContent = value;
      button.setAttribute('aria-pressed', String(value === word.value));
      if (/[\u0900-\u097f]/u.test(value)) button.lang = 'ne';
      button.addEventListener('click', () => {
        overrides.set(word.start, {word: word.text, value});
        render(); track('neptype_tool_word_selected');
      });
      suggestions.append(button);
    }
  }
  function render() {
    rendered = engine.render(input.value, mode.value, overrides);
    output.value = rendered.text;
    status.textContent = words.ready;
    copy.disabled = !output.value;
    drawSuggestions();
  }
  async function update(entry = 'typing') {
    const current = ++revision;
    try { await load(); } catch { return; }
    if (current !== revision) return;
    overrides = retainChoices(previous, input.value, overrides);
    previous = input.value;
    const caret = input.selectionStart;
    activeStart = engine.context(input.value, mode.value).find(word => !word.literal && caret >= word.start && caret <= word.end)?.start ?? null;
    render(); markUsed(entry);
  }
  input.addEventListener('focus', () => { load().catch(() => {}); });
  input.addEventListener('input', event => { if (!event.isComposing) update(); });
  input.addEventListener('compositionend', () => update());
  for (const event of ['click', 'keyup', 'select']) input.addEventListener(event, () => {
    if (!engine) return;
    const caret = input.selectionStart;
    activeStart = rendered.words.find(word => !word.literal && caret >= word.start && caret <= word.end)?.start ?? null;
    drawSuggestions();
  });
  output.addEventListener('click', () => {
    activeStart = rendered.words.find(word => !word.literal && output.selectionStart >= word.outputStart && output.selectionStart <= word.outputEnd)?.start ?? null;
    drawSuggestions();
  });
  mode.addEventListener('change', async () => {
    overrides.clear(); await update(); track('neptype_tool_mode_changed');
  });
  pad.querySelector('#web-example').addEventListener('click', () => {
    input.value = 'namaste! ma office janchu.\nbholi meeting pachi bhetau.';
    input.setSelectionRange(input.value.length - 1, input.value.length - 1);
    update('example');
  });
  pad.querySelector('#web-clear').addEventListener('click', () => {
    revision++; input.value = ''; output.value = ''; previous = ''; overrides.clear();
    activeStart = null; rendered = {text: '', words: []}; copy.disabled = true;
    suggestions.replaceChildren(); status.textContent = words.ready; input.focus();
  });
  copy.addEventListener('click', async () => {
    const copied = output.value;
    try {
      await navigator.clipboard.writeText(copied);
      status.textContent = words.copied;
      track('neptype_tool_output_copied');
    } catch {
      output.focus(); output.select(); status.textContent = words.copyFailed;
    }
  });
  // Load the compact dictionary only as the tool approaches the viewport.
  if ('IntersectionObserver' in window) {
    const observer = new IntersectionObserver(entries => {
      if (entries.some(entry => entry.isIntersecting)) { load().catch(() => {}); observer.disconnect(); }
    }, {rootMargin: '150px'});
    observer.observe(pad);
  }
}
