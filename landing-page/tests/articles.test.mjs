import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile, mkdtemp, writeFile, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {pathToFileURL} from 'node:url';
import init, {query} from '../engine-build/neptype_engine.js';
import {loadAllArticles, loadArticles, validateArticle, validateCollection, selectNextTopic, pacificDate, queueFile} from '../article-content.mjs';

await init({module_or_path:await readFile(new URL('../engine-build/neptype_engine_bg.wasm',import.meta.url))});
const articles = await loadAllArticles();
const first = articles[0];
const copy = () => structuredClone(first);
const queue = JSON.parse(await readFile(queueFile,'utf8'));

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
  other.published = '2026-11-02'; other.topicId = first.topicId;
  assert.throws(() => validateCollection([first,other]), /Duplicate article topic/);
  other.topicId = 'another-topic'; other.primaryQuery = first.primaryQuery.toUpperCase()+'!';
  assert.throws(() => validateCollection([first,other]), /Duplicate article primary query/);
});

test('publishing requires source evidence, both languages, contextual links and executable examples', () => {
  let article = copy(); article.research = [];
  assert.throws(() => validateArticle(article), /research evidence/);
  article = copy(); delete article.ne;
  assert.throws(() => validateArticle(article), /both English and Nepali/);
  article = copy(); article.en.sections[0][2].links[0][1] = 'javascript:alert(1)';
  assert.throws(() => validateArticle(article), /Unsafe/);
  article = copy(); article.en.sections[1][2].examples[0][1] = 'made-up output';
  assert.throws(() => validateArticle(article), /matching mixed-mode engine check/);
  article = copy(); delete article.overlapReview;
  assert.throws(() => validateArticle(article), /overlapReview/);
});

test('future articles and drafts are not exposed by the public content loader', async () => {
  const directory = await mkdtemp(join(tmpdir(),'neptype-article-fixtures-'));
  try {
    const future = copy(); future.slug = 'future-article'; future.topicId = 'future-topic'; future.primaryQuery = 'a future topic'; future.published = '2099-01-01';
    const draft = copy(); draft.status = 'draft'; draft.slug = 'draft-article'; draft.topicId = 'draft-topic'; draft.primaryQuery = 'a draft topic';
    for (const article of [first,future,draft]) await writeFile(join(directory,article.slug+'.json'),JSON.stringify(article));
    const visible = await loadArticles({asOf:'2026-11-01',directory:pathToFileURL(directory+'/')});
    assert.deepEqual(visible.map(article=>article.slug),[first.slug]);
  } finally { await rm(directory,{recursive:true,force:true}); }
});

test('daily selection is idempotent, respects Pacific dates and advances through unused topics', () => {
  assert.equal(pacificDate(new Date('2026-11-02T00:30:00Z')),'2026-11-01');
  assert.equal(selectNextTopic(queue,articles,first.published).action,'skip');
  const next = selectNextTopic(queue,articles,'2026-11-02');
  assert.equal(next.action,'research');
  assert.notEqual(next.topic.id,first.topicId);
  assert.equal(selectNextTopic({topics:[]},articles,'2026-11-02').action,'skip');
});
