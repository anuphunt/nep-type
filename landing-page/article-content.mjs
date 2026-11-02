import {readFile, readdir} from 'node:fs/promises';

export const articleDirectory = new URL('./content/articles/', import.meta.url);
export const queueFile = new URL('./content/topic-queue.json', import.meta.url);
export const pacificDate = (date = new Date()) => new Intl.DateTimeFormat('en-CA', {timeZone:'America/Los_Angeles', year:'numeric', month:'2-digit', day:'2-digit'}).format(date);
const required = (value, label) => { if (typeof value !== 'string' || !value.trim()) throw Error(`Article needs ${label}.`); };
const validDate = value => /^\d{4}-\d{2}-\d{2}$/.test(value) && new Date(value+'T12:00:00Z').toISOString().slice(0,10) === value;
const normalize = text => text.toLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
const validLink = href => typeof href === 'string' && (/^\/(?!\/)/.test(href) || /^https:\/\//.test(href));

export function validateArticle(article) {
  for (const field of ['slug','topicId','primaryQuery','searchIntent','originalValue','overlapReview']) required(article[field], field);
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(article.slug)) throw Error('Invalid article slug.');
  if (!['draft','published'].includes(article.status)) throw Error('Article status must be draft or published.');
  if (!validDate(article.published)) throw Error('Article needs a real publication date.');
  if (article.modified && (!validDate(article.modified) || article.modified < article.published)) throw Error('Invalid substantive revision date.');
  if (!Array.isArray(article.research) || !article.research.length) throw Error('Article needs research evidence.');
  for (const source of article.research) {
    if (!/^https:\/\//.test(source.url)) throw Error('Research needs HTTPS source URLs.');
    required(source.note, 'source relevance');
    if (!validDate(source.checked)) throw Error('Research needs a checked date.');
  }
  if (!Array.isArray(article.checks) || !article.checks.length) throw Error('Article needs executable product checks.');
  for (const check of article.checks) {
    if (!['render','candidates'].includes(check.request?.op)) throw Error('Unsupported article check.');
    required(check.request.source, 'check input');
    if (check.request.op === 'render' && typeof check.expectedText !== 'string') throw Error('Render check needs expected text.');
    if (check.request.op === 'candidates' && (!Array.isArray(check.includes) || !check.includes.length)) throw Error('Candidate check needs expected choices.');
  }
  for (const locale of ['en','ne']) {
    const content = article[locale];
    if (!content) throw Error('Articles need both English and Nepali versions.');
    for (const field of ['title','heading','description']) required(content[field], `${locale} ${field}`);
    if (!Array.isArray(content.sections) || content.sections.length < 4) throw Error('Article must answer the question with a worked explanation.');
    let linkedTool = false, linkedGuide = false, workedExample = false;
    for (const [heading, text, extra = {}] of content.sections) {
      required(heading, 'section heading'); required(text, 'section text');
      for (const [label, href] of extra.links || []) {
        required(label, 'link label'); if (!validLink(href)) throw Error('Unsafe article link.');
        linkedTool ||= href === '/#try'; linkedGuide ||= href === '/typing-guide/';
      }
      for (const [input, output] of extra.examples || []) {
        workedExample = true;
        if (!article.checks.some(check => check.request.op === 'render' && (check.request.mode ?? 0) === 0 && check.request.source === input && check.expectedText === output)) throw Error('Every visible example needs a matching mixed-mode engine check.');
      }
    }
    if (!linkedTool || !linkedGuide) throw Error('Article needs contextual links to the tool and typing guide.');
    if (!workedExample) throw Error('Each language version needs a worked, engine-checked example.');
  }
  return article;
}

export function validateCollection(articles) {
  const slugs = new Set(), queries = new Set(), topics = new Set(), dates = new Set();
  for (const article of articles) {
    validateArticle(article);
    for (const [value, seen, label] of [[article.slug,slugs,'slug'],[normalize(article.primaryQuery),queries,'primary query'],[article.topicId,topics,'topic']]) {
      if (seen.has(value)) throw Error(`Duplicate article ${label}: ${value}`);
      seen.add(value);
    }
    if (article.status === 'published') {
      if (dates.has(article.published)) throw Error('Publish at most one article per Pacific calendar day.');
      dates.add(article.published);
    }
  }
  return articles;
}

export async function loadAllArticles(directory = articleDirectory) {
  const files = (await readdir(directory)).filter(name => name.endsWith('.json')).sort();
  return validateCollection(await Promise.all(files.map(name => readFile(new URL(name, directory), 'utf8').then(JSON.parse))));
}

export async function loadArticles({asOf = pacificDate(), directory = articleDirectory} = {}) {
  return (await loadAllArticles(directory)).filter(article => article.status === 'published' && article.published <= asOf).sort((a,b) => b.published.localeCompare(a.published));
}

export function selectNextTopic(queue, articles, today = pacificDate()) {
  if (articles.some(article => article.status === 'published' && article.published === today)) return {action:'skip', reason:'An article has already been published today.'};
  const used = new Set(articles.map(article => article.topicId));
  const topic = queue.topics.find(topic => topic.status === 'eligible' && !used.has(topic.id));
  return topic ? {action:'research', topic} : {action:'skip', reason:'No unused eligible topics. Research a useful new question before extending the queue.'};
}

export function articlePages(articles) {
  const pages = {};
  for (const article of articles) pages['articles/'+article.slug] = Object.fromEntries(['en','ne'].map(locale => [locale, {...article[locale],kind:'article',published:article.published,modified:article.modified}]));
  const hubCopy = {
    en: {title:'Nepali Typing Articles and Practical Tips | NepType', heading:'Nepali typing articles and practical tips', description:'Practical Nepali typing tutorials with tested examples: mixed English sentences, spelling choices, Unicode text, and the NepType browser pad.', intro:'Solve a specific typing problem with worked examples from NepType. For a first introduction, start with the Roman-to-Nepali typing guide.'},
    ne: {title:'नेपाली टाइपिङका लेख र उपयोगी सुझाव | NepType', heading:'नेपाली टाइपिङका लेख र उपयोगी सुझाव', description:'उदाहरणसहित नेपाली टाइपिङ सिक्नुहोस्। अंग्रेजी मिसिएका वाक्य, हिज्जेका विकल्प, युनिकोड र NepType ब्राउजर प्याडका उपयोगी तरिका।', intro:'NepType का उदाहरणबाट आफ्नो टाइपिङ समस्या समाधान गर्नुहोस्। सुरु गर्दै हुनुहुन्छ भने रोमनबाट नेपाली लेख्ने गाइड पढ्नुहोस्।'}
  };
  pages.articles = Object.fromEntries(['en','ne'].map(locale => [locale, {...hubCopy[locale],kind:'collection', sections:[['',hubCopy[locale].intro,{links:[ [locale==='ne'?'रोमनबाट नेपाली लेख्ने तरिका':'Start with the Roman-to-Nepali typing guide','/typing-guide/'] ]}]], articleList:articles.map(article => ({slug:article.slug,published:article.published,...article[locale]}))}]));
  return pages;
}
