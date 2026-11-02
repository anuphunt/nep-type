import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {WebEngine, tokens, retainChoices, phonetic} from '../web-engine.mjs';

const lexicon = JSON.parse(await readFile(new URL('../../data/sources/nepali-authored-v1.json', import.meta.url), 'utf8'));
const engine = new WebEngine({lexicon, englishWords:['office','meeting','hello','world','the','an','a','i','test','please'], commonEnglish:['office','meeting','hello','world','the','an','a','test','please']});

test('real mixed-language typing and Nepali sentence endings', () => {
  assert.equal(engine.render('ma office janchu.').text, 'म office जान्छु।');
  assert.equal(engine.render('bholi meeting pachi bhetau.').text, 'भोलि meeting पछि भेटौँ।');
  assert.equal(engine.render('namaste!').text, 'नमस्ते!');
});
test('protect URLs, email, code, identifiers, numbers, emoji and existing Nepali', () => {
  const literal = 'https://example.com/a?x=1 me@example.com `namaste` foo_bar fooBar hello-world x1 config.json src/main.swift 3.14 😀 नेपाली';
  assert.equal(engine.render(literal).text, literal);
  assert.equal(engine.render(literal, 'all').text, literal);
  assert.equal(tokens('hello-world')[0].literal, true);
  assert.equal(engine.render('```\nnamaste\nma\n```').text, '```\nnamaste\nma\n```');
});
test('All Nepali converts English; English mode preserves the entire source', () => {
  assert.equal(engine.render('office', 'mixed').text, 'office');
  assert.match(engine.render('office', 'all').text, /[\u0900-\u097f]/);
  assert.equal(engine.render('namaste. ma office janchu.', 'english').text, 'namaste. ma office janchu.');
});
test('spelling choices apply to one occurrence with UTF-16 positions', () => {
  const source = '😀 pani pani';
  const choices = new Map([[3,{word:'pani',value:'पनि'}]]);
  const rendered = engine.render(source, 'mixed', choices);
  assert.equal(rendered.words[0].start, 3);
  assert.equal(rendered.words[0].value, 'पनि');
  assert.equal(rendered.words[1].value, lexicon.pani[0]);
  assert.equal(engine.render(source,'english',choices).text,source);
  assert.ok(engine.candidates('pani').includes('पानी'));
  assert.ok(engine.candidates('pani').includes('पनि'));
  assert.ok(engine.candidates('pani').includes('pani'));
});
test('editing a word invalidates its saved choice and later choices', () => {
  const choices = new Map([[0,{word:'pani',value:'पनि'}],[5,{word:'pani',value:'पानी'}]]);
  assert.equal(retainChoices('pani pani','paani pani',choices).size,0);
  const kept = retainChoices('pani pani','pani paani',choices);
  assert.equal(kept.size,1);
  assert.equal(kept.get(0).value,'पनि');
  assert.equal(retainChoices('pani','pani next',new Map([[0,{word:'pani',value:'पनि'}]])).size,1);
});
test('phonetic fallback handles unseen input and preserves safe punctuation', () => {
  assert.equal(phonetic('ksh'), 'क्ष');
  assert.equal(phonetic('chha'), 'छ');
  assert.equal(engine.render('hello world.').text,'hello world.');
  assert.equal(engine.render('namaste...').text,'नमस्ते...');
  assert.equal(engine.render('namaste 3.14.').text,'नमस्ते 3.14।');
});
