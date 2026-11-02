import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile, mkdtemp, writeFile, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {pathToFileURL} from 'node:url';
import init, {query} from '../engine-build/neptype_engine.js';
import {loadAllArticles, loadArticles, validateArticle, validateCollection, selectNextTopic, pacificDate} from '../article-content.mjs';

await init({module_or_path:await readFile(new URL('../engine-build/neptype_engine_bg.wasm',import.meta.url))});
const articles = await loadAllArticles();
// Unit-test articles must not depend on live article order, prose or release dates.
const first = {
  slug: 'fixture-article', topicId: 'fixture-topic', status: 'published', published: '2020-01-01',
  primaryQuery: 'fixture typing question', searchIntent: 'Exercise article validation.',
  originalValue: 'Synthetic article used only by tests.', overlapReview: 'Independent test content.',
  research: [{url: 'https://example.com/reference', checked: '2020-01-01', note: 'Synthetic source for validation tests.'}],
  checks: [{request: {op: 'render', source: 'namaste', mode: 0}, expectedText: 'नमस्ते'}],
  ...Object.fromEntries(['en','ne'].map(locale => [locale, {
    title: `${locale} fixture title`, heading: `${locale} fixture heading`, description: `${locale} fixture description`,
    sections: [
      ['Start', 'Fixture introduction.', {links: [['Open the tool','/#try']]}],
      ['Example', 'Fixture example.', {examples: [['namaste','नमस्ते']]}],
      ['Guide', 'Fixture guidance.', {links: [['Read the guide','/typing-guide/']]}],
      ['Review', 'Fixture closing instructions.']
    ]
  }]))
};
const copy = () => structuredClone(first);

test('the varied everyday example bank matches the current shared engine', async () => {
  const bank = JSON.parse(await readFile(new URL('../content/example-bank.json',import.meta.url),'utf8'));
  assert.ok(new Set(bank.examples.map(example=>example.context)).size>3);
  for (const example of bank.examples) {
    const result = JSON.parse(query(JSON.stringify(example.request)));
    assert.equal(result.text,example.expectedText,example.request.source);
  }
});

test('every published or draft article example and candidate claim matches the shared engine', () => {
  assert.ok(articles.length);
  for (const article of articles) for (const check of article.checks) {
    const result = JSON.parse(query(JSON.stringify(check.request)));
    if (check.request.op === 'render') assert.equal(result.text,check.expectedText,article.slug+': '+check.request.source);
    else for (const spelling of check.includes) assert.ok(result.includes(spelling),article.slug+': '+spelling);
  }
});

test('publishing rejects duplicate topics/queries and multiple articles on one Pacific day', () => {
  const other = copy(); other.slug = 'another-article'; other.topicId = 'another-topic'; other.primaryQuery = 'a different reader need';
  assert.throws(() => validateCollection([first,other]), /at most one/);
  other.published = '2020-01-02'; other.topicId = first.topicId;
  assert.throws(() => validateCollection([first,other]), /Duplicate article topic/);
  other.topicId = 'another-topic'; other.primaryQuery = first.primaryQuery.toUpperCase()+'!';
  assert.throws(() => validateCollection([first,other]), /Duplicate article primary query/);
  other.primaryQuery = 'another distinct query'; other.slug = first.slug;
  assert.throws(() => validateCollection([first,other]), /Duplicate article slug/);
});

test('publishing requires source evidence, both languages, contextual links and executable examples', () => {
  let article = copy(); article.research = [];
  assert.throws(() => validateArticle(article), /research evidence/);
  article = copy(); delete article.ne;
  assert.throws(() => validateArticle(article), /both English and Nepali/);
  article = copy(); article.en.sections.find(([, , extra]) => extra?.links?.length)[2].links[0][1] = 'javascript:alert(1)';
  assert.throws(() => validateArticle(article), /Unsafe/);
  article = copy(); article.en.sections.find(([, , extra]) => extra?.examples?.length)[2].examples[0][1] = 'made-up output';
  assert.throws(() => validateArticle(article), /matching mixed-mode engine check/);
  article = copy(); delete article.overlapReview;
  assert.throws(() => validateArticle(article), /overlapReview/);
});

test('future articles and drafts are not exposed by the public content loader', async () => {
  const directory = await mkdtemp(join(tmpdir(),'neptype-article-fixtures-'));
  try {
    const future = copy(); future.slug = 'future-article'; future.topicId = 'future-topic'; future.primaryQuery = 'a future topic'; future.published = '2020-01-03';
    const draft = copy(); draft.status = 'draft'; draft.slug = 'draft-article'; draft.topicId = 'draft-topic'; draft.primaryQuery = 'a draft topic';
    for (const article of [first,future,draft]) await writeFile(join(directory,article.slug+'.json'),JSON.stringify(article));
    const options = {directory:pathToFileURL(directory+'/')};
    const visible = await loadArticles({...options,asOf:'2020-01-02'});
    assert.deepEqual(visible.map(article=>article.slug),[first.slug]);
    assert.deepEqual(await loadArticles({...options,asOf:'2019-12-31'}),[]);
    const later = await loadArticles({...options,asOf:future.published});
    assert.deepEqual(later.map(article=>article.slug),[future.slug,first.slug]);
  } finally { await rm(directory,{recursive:true,force:true}); }
});

test('daily selection is idempotent, respects Pacific dates and advances through unused topics', () => {
  const queue = {topics: [
    {id:first.topicId,status:'eligible'},
    {id:'held-topic',status:'research_needed'},
    {id:'next-topic',status:'eligible'},
    {id:'later-topic',status:'eligible'}
  ]};
  const published = [first];
  assert.equal(pacificDate(new Date('2026-11-02T00:30:00Z')),'2026-11-01');
  assert.equal(selectNextTopic(queue,published,first.published).action,'skip');
  const next = selectNextTopic(queue,published,'2020-01-02');
  assert.equal(next.action,'research');
  assert.equal(next.topic.id,'next-topic');
  const released = {...copy(),slug:'next-article',topicId:next.topic.id,primaryQuery:'next question',published:'2020-01-02'};
  assert.equal(selectNextTopic(queue,[...published,released],released.published).action,'skip');
  assert.equal(selectNextTopic(queue,[...published,released],'2020-01-03').topic.id,'later-topic');
  assert.equal(selectNextTopic({topics:[]},published,'2020-01-02').action,'skip');
});
