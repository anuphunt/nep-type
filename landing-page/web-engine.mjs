// Browser implementation of NepType's deterministic phonetic and context rules.
// Uses the authored lexicon and English membership data; the desktop's larger
// Google/Aksharantar suggestion indexes are deliberately not downloaded here.
const consonants = {ksh:'क्ष',chh:'छ',gy:'ज्ञ',jn:'ज्ञ',kh:'ख',gh:'घ',ch:'च',jh:'झ',th:'थ',dh:'ध',ph:'फ',bh:'भ',sh:'श',ng:'ङ',ny:'ञ',k:'क',g:'ग',c:'च',j:'ज',t:'त',d:'द',n:'न',p:'प',b:'ब',m:'म',y:'य',r:'र',l:'ल',w:'व',v:'व',s:'स',h:'ह',f:'फ',q:'क',x:'क्स',z:'ज'};
const vowels = {aa:['आ','ा'],ai:['ऐ','ै'],au:['औ','ौ'],ee:['ई','ी'],ii:['ई','ी'],oo:['ऊ','ू'],uu:['ऊ','ू'],a:['अ',''],i:['इ','ि'],u:['उ','ु'],e:['ए','े'],o:['ओ','ो']};
const native = text => /[\u0900-\u097f]/u.test(text);
const unique = values => [...new Set(values.filter(Boolean))];
function match(table, text, index) {
  for (let length = Math.min(3, text.length - index); length > 0; length--) {
    const key = text.slice(index, index + length);
    if (Object.hasOwn(table, key)) return [table[key], length];
  }
  return null;
}
export function phonetic(input) {
  const text = input.toLowerCase();
  let result = '', index = 0;
  while (index < text.length) {
    const consonant = match(consonants, text, index);
    if (consonant) {
      result += consonant[0]; index += consonant[1];
      const vowel = match(vowels, text, index);
      if (vowel) { result += vowel[0][1]; index += vowel[1]; }
      else if (index < text.length && match(consonants, text, index)) result += '्';
    } else {
      const vowel = match(vowels, text, index);
      if (vowel) { result += vowel[0][0]; index += vowel[1]; }
      else result += text[index++];
    }
  }
  return result;
}

// Match protected content first. Offsets use UTF-16, as textarea selections do.
const tokenPattern = /```(?:[\s\S]*?```|[\s\S]*$)|[Hh][Tt][Tt][Pp][Ss]?:\/\/[^\s]+|[Ww][Ww][Ww]\.[^\s]+|[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}|`[^`\n]*(?:`|(?=\n|$))|(?:[A-Za-z0-9._~\-]+\/)+[A-Za-z0-9._~\-]+|[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)+|(?:[A-Za-z_][A-Za-z0-9_]*[0-9_][A-Za-z0-9_]*|[0-9]+[A-Za-z_][A-Za-z0-9_]*)|[a-z]+[A-Z][A-Za-z]*|[A-Za-z]+(?:['’_-][A-Za-z]+)+|[A-Za-z]+/g;
export function tokens(source) {
  return [...source.matchAll(tokenPattern)].map(item => ({
    text: item[0], start: item.index, end: item.index + item[0].length,
    literal: /[:/@`'’_.\d-]/.test(item[0]) || /^[a-z].*[A-Z]/.test(item[0])
  }));
}

export class WebEngine {
  constructor({lexicon, englishWords = [], commonEnglish = []}) {
    this.lexicon = lexicon;
    this.english = new Set(englishWords);
    this.common = new Set(commonEnglish);
  }
  candidates(word) {
    const key = word.toLowerCase();
    const authored = this.lexicon[key] || [];
    const preserve = this.common.has(key) || (word.length > 1 && word === word.toUpperCase()) || (!authored.length && this.english.has(key));
    return unique([...(preserve ? [word] : []), ...authored, phonetic(word), word]);
  }
  context(source, mode = 'mixed') {
    const words = tokens(source);
    const evidence = words.map(word => {
      const key = word.text.toLowerCase(), authored = this.lexicon[key];
      const common = this.common.has(key), known = common || this.english.has(key);
      return {english: common ? 5 : known ? (authored ? 1 : 3) : 0, nepali: authored ? 5 : 0, englishAnchor: common && !authored, nepaliAnchor: !!authored && !common, preferred: authored?.[0]};
    });
    const contiguous = (a, b) => a >= 0 && b < words.length && !words[a].literal && !words[b].literal && /^[ \t]+$/.test(source.slice(words[a].end, words[b].start));
    return words.map((word, index) => {
      const key = word.text.toLowerCase(), item = evidence[index];
      let preferred = word.text;
      if (!word.literal && mode !== 'english') {
        if (mode === 'all') preferred = this.candidates(word.text).find(native) || phonetic(word.text);
        else if (!(word.text.length > 1 && word.text === word.text.toUpperCase()) && !(this.common.has(key) && this.lexicon[key])) {
          let e = item.english, n = item.nepali;
          for (const neighbor of [index - 1, index + 1]) {
            if (contiguous(Math.min(index, neighbor), Math.max(index, neighbor))) {
              if (evidence[neighbor].englishAnchor) e += 3;
              if (evidence[neighbor].nepaliAnchor) n += 3;
            }
          }
          if (contiguous(index - 1, index) && ['the','a','an'].includes(words[index - 1].text.toLowerCase()) && item.english > 0) e += 4;
          if (!item.english && !item.nepali) preferred = phonetic(word.text);
          else if (e >= n + 2 && item.english > 0) preferred = word.text;
          else if ((n >= e + 2 || (this.lexicon[key] && n > e)) && item.preferred) preferred = item.preferred;
        }
      }
      return {...word, preferred};
    });
  }
  render(source, mode = 'mixed', overrides = new Map()) {
    const choices = this.context(source, mode);
    const replacements = choices.map(word => {
      const choice = overrides.get(word.start);
      return {...word, value: mode !== 'english' && !word.literal && choice?.word === word.text ? choice.value : word.preferred};
    });
    const stops = new Set();
    if (mode !== 'english') {
      let index = 0, wordIndex = 0, hasNepali = false, previous;
      const abbreviations = new Set(['mr','mrs','ms','dr','prof','sr','jr','st','vs','etc']);
      while (index < source.length) {
        const word = replacements[wordIndex];
        if (word?.start === index) {
          if (!word.literal) hasNepali ||= native(word.value);
          previous = word; index = word.end; wordIndex++; continue;
        }
        const char = source[index];
        hasNepali ||= native(char);
        if (char === '.' && source[index - 1] !== '.' && source[index + 1] !== '.') {
          let end = index + 1;
          while (end < source.length && /["')\]}’”]/u.test(source[end])) end++;
          const boundary = end === source.length || /\s/u.test(source[end]);
          const abbreviation = previous?.end === index && (previous.literal || abbreviations.has(previous.text.toLowerCase()));
          if (boundary && !abbreviation) { if (hasNepali) stops.add(index); hasNepali = false; }
        } else if (/[!?\n।]/u.test(char)) hasNepali = false;
        index++;
      }
    }
    let text = '', cursor = 0;
    const mapping = [];
    function gap(end) {
      while (cursor < end) { text += stops.has(cursor) ? '।' : source[cursor]; cursor++; }
    }
    for (const word of replacements) {
      gap(word.start);
      mapping.push({...word, outputStart: text.length, outputEnd: text.length + word.value.length});
      text += word.value; cursor = word.end;
    }
    gap(source.length);
    return {text, words: mapping};
  }
}

export function retainChoices(previous, next, overrides) {
  let change = 0;
  while (change < previous.length && change < next.length && previous[change] === next[change]) change++;
  const nextWords = tokens(next);
  return new Map([...overrides].filter(([start, choice]) => start < change && nextWords.some(word => word.start === start && word.end <= change && word.text === choice.word)));
}
