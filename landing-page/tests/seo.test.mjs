import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile, access} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {siteConfig} from '../site-config.mjs';
import {examples} from '../typing-guide.mjs';
import {loadArticles} from '../article-content.mjs';
import initRust, {query} from '../engine-build/neptype_engine.js';
await initRust({module_or_path:await readFile(new URL('../engine-build/neptype_engine_bg.wasm',import.meta.url))});

const root = fileURLToPath(new URL('../', import.meta.url));
const dist = new URL('../dist/', import.meta.url);
const read = name => readFile(new URL(name, dist), 'utf8');
function build(context) {
  const env = {...process.env, SITE_URL: 'https://neptype.com', CONTEXT: context, PUBLIC_POSTHOG_KEY: '', PUBLIC_POSTHOG_HOST: '', APP_DOWNLOAD_URL: ''};
  execFileSync(process.execPath, ['build.mjs'], {cwd: root, env, stdio: 'pipe'});
}
const matches = (html, pattern) => [...html.matchAll(pattern)];
const graph = html => JSON.parse(html.match(/<script type="application\/ld\+json">(.*?)<\/script>/s)[1])['@graph'];

test('indexing requires explicit production context and a safe canonical origin', () => {
  for (const context of ['', 'dev', 'deploy-preview', 'branch-deploy', 'preview-server']) {
    assert.equal(siteConfig({CONTEXT: context, SITE_URL: 'https://neptype.com'}).production, false);
  }
  assert.deepEqual(siteConfig({CONTEXT: 'production'}), {origin: 'https://neptype.com', production: true});
  assert.equal(siteConfig({URL: 'https://deploy-preview-8--neptype.netlify.app'}).origin, 'https://neptype.com');
  for (const value of ['http://neptype.com', 'https://localhost', 'https://127.0.0.1', 'https://example.com/path', 'https://example.com?x=1', 'https://user:pass@example.com', 'https://branch--neptype.netlify.app', 'javascript:alert(1)']) {
    assert.throws(() => siteConfig({SITE_URL: value, CONTEXT: 'production'}), undefined, value);
  }
});

test('production pages expose unique crawlable content, correct locales and valid links', async () => {
  build('production');
  const sitemap = await read('sitemap.xml');
  const urls = matches(sitemap, /<loc>(.*?)<\/loc>/g).map(match => match[1]);
  assert.equal(urls.length, 22 + 2 * (await loadArticles()).length);
  assert.equal(new Set(urls).size, urls.length);
  const titles = new Set(), descriptions = new Set(), documents = new Map();
  for (const url of urls) {
    const pathname = new URL(url).pathname;
    documents.set(pathname, await read(pathname.slice(1) + 'index.html'));
  }
  for (const [pathname, html] of documents) {
    const ne = pathname.startsWith('/ne/');
    assert.match(html, new RegExp(`<html lang="${ne ? 'ne' : 'en'}"`), pathname);
    assert.match(html, /name="robots" content="index,follow,max-image-preview:large"/);
    assert.equal(matches(html, /<h1\b/g).length, 1, pathname);
    assert.equal(matches(html, /<title>/g).length, 1, pathname);
    const title = html.match(/<title>(.*?)<\/title>/s)[1];
    const description = html.match(/name="description" content="([^"]+)"/)[1];
    assert.ok(!titles.has(title), `duplicate title: ${title}`); titles.add(title);
    assert.ok(!descriptions.has(description), `duplicate description: ${description}`); descriptions.add(description);
    assert.match(html, new RegExp(`rel="canonical" href="https://neptype.com${pathname}"`));
    const slug = pathname.replace(/^\/ne\//, '/');
    for (const [language, target] of [['en', slug], ['ne', '/ne' + (slug === '/' ? '/' : slug)], ['x-default', slug]]) {
      assert.ok(html.includes(`hreflang="${language}" href="https://neptype.com${target}"`), `${pathname}: ${language}`);
    }
    assert.equal(graph(html).filter(entity => entity['@type'] === 'WebSite').length, 1);
    assert.ok(graph(html).some(entity => entity.inLanguage === (ne ? 'ne' : 'en')));
    assert.ok(!html.includes('<!-- HOME_HELP -->'));
    assert.ok(html.includes(`href="${ne ? '/ne' : ''}/privacy/"`), `${pathname}: privacy footer link`);
    assert.ok(html.includes(`href="${ne ? '/ne' : ''}/terms/"`), `${pathname}: terms footer link`);
    assert.ok(!html.includes('Playfair'));
    assert.ok(!html.includes('fonts.googleapis.com'));
    assert.ok(html.includes('rel="preload" href="/assets/fonts/'));
    assert.ok(!html.includes('fonts.gstatic.com'));
    for (const [, kind, raw] of matches(html, /\b(href|src)="([^"]+)"/g)) {
      if (raw.startsWith('http') || raw.startsWith('mailto:')) continue;
      const target = new URL(raw.replaceAll('&amp;', '&'), 'https://neptype.com' + pathname);
      if (kind === 'href' && !target.pathname.split('/').at(-1).includes('.')) {
        const page = documents.get(target.pathname);
        assert.ok(page, `${pathname}: broken link ${raw}`);
        if (target.hash) assert.ok(page.includes(`id="${target.hash.slice(1)}"`), `${pathname}: missing fragment ${raw}`);
      } else {
        await assert.doesNotReject(access(new URL(target.pathname.slice(1), dist)), `${pathname}: missing asset ${raw}`);
      }
    }
    assert.ok(html.includes(`href="${pathname === '/' || pathname === '/ne/' ? '' : ne ? '/ne/' : '/'}#try"`), `${pathname}: tool is reachable`);
  }
  assert.ok(!urls.some(url => /\/(?:ne\/)?app\//.test(url)), 'no duplicate editor route');
  for (const file of ['app/index.html','ne/app/index.html']) await assert.rejects(access(new URL(file,dist)));
  for (const pathname of ['/','/ne/']) {
    const html = documents.get(pathname), locale = pathname === '/' ? 'en' : 'ne';
    assert.equal(matches(html, /id="web-input"/g).length,1);
    assert.ok(html.indexOf('id="web-pad"') < html.indexOf('id="downloads"'));
    assert.ok(!html.includes('class="hero-visual"'));
    assert.ok(!html.includes('<!-- HOME_DOWNLOADS -->'));
    assert.equal(matches(html, /data-platform-card=/g).length,5);
    assert.match(html, /<section id="downloads"[^>]*>[\s\S]*<h2 id="downloads-title">/);
    assert.ok(!html.includes('class="desktop-downloads'));
    assert.equal(matches(html, /<main\b/g).length,1);
    assert.ok(!html.includes('No connection needed') && !html.includes('Works offline'));
    assert.ok(html.includes(`property="og:image" content="https://neptype.com/assets/neptype-web-${locale}.png"`));
    assert.ok(html.includes('property="og:image:width" content="1200"'));
    assert.ok(!html.includes('href="/app/') && !html.includes('href="/ne/app/'));
  }
  assert.match(documents.get('/mac/'), /property="og:image" content="https:\/\/neptype.com\/assets\/neptype-mac.png"/);
  const home = documents.get('/');
  assert.match(home, /Type Nepali online/);
  assert.match(home, /How to type Nepali with English letters/);
  assert.ok(graph(home).some(entity => entity['@type'] === 'WebApplication'));
  assert.ok(!graph(documents.get('/privacy/')).some(entity => /Application$/.test(entity['@type'])));
  assert.ok(graph(documents.get('/mac/')).some(entity => entity['@type'] === 'SoftwareApplication' && entity.operatingSystem === 'macOS'));
  for (const path of ['/typing-guide/', '/ne/typing-guide/']) {
    const article = graph(documents.get(path)).find(entity => entity['@type'] === 'TechArticle');
    assert.equal(article.datePublished, '2026-11-01');
    assert.ok(documents.get(path).includes('datetime="2026-11-01"'));
    assert.ok(!JSON.stringify(article).includes('aggregateRating'));
  }
  assert.match(await read('robots.txt'), /Sitemap: https:\/\/neptype.com\/sitemap.xml/);
  assert.match(await read('404.html'), /name="robots" content="noindex"/);
  assert.ok(!(await read('styles.css')).includes('@import'));
  for (const path of ['/articles/','/ne/articles/','/articles/type-nepali-and-english-together/','/ne/articles/type-nepali-and-english-together/']) assert.ok(documents.has(path), path);
  const article = graph(documents.get('/articles/type-nepali-and-english-together/')).find(entity => entity['@type'] === 'TechArticle');
  assert.equal(article.datePublished, '2026-11-01');
  assert.equal(graph(documents.get('/articles/type-nepali-and-english-together/')).find(entity => entity['@type'] === 'BreadcrumbList').itemListElement.length, 3);
  assert.match(await read('articles/feed.xml'), /type-nepali-and-english-together/);
  assert.match(await read('ne/articles/feed.xml'), /https:\/\/neptype.com\/ne\/articles\/type-nepali-and-english-together\//);
  assert.ok(!urls.some(url => url.endsWith('.xml')));
  assert.ok(!(await read('styles.css')).includes('fonts.gstatic.com'));
  for (const file of ['dmsans-OFL.txt','notosansdevanagari-OFL.txt','NOTICE.txt']) assert.ok((await read('assets/fonts/' + file)).length > 100);
  await assert.rejects(access(new URL('_headers', dist)));
});

test('published typing examples match the actual browser dictionary', async () => {
  const engine = {render:source=>JSON.parse(query(JSON.stringify({op:'render',source}))),candidates:source=>JSON.parse(query(JSON.stringify({op:'candidates',source})))};
  for (const [input, output] of examples) assert.equal(engine.render(input, 'mixed').text, output, input);
  for (const word of ['पानी', 'पनि', 'pani']) assert.ok(engine.candidates('pani').includes(word));
});

test('preview and local builds stay noindex with production canonicals', async () => {
  for (const context of ['deploy-preview', '']) {
    build(context);
    for (const file of ['index.html', 'ne/index.html', 'typing-guide/index.html', 'ne/typing-guide/index.html', 'mac/index.html']) {
      const html = await read(file);
      assert.match(html, /name="robots" content="noindex,follow"/);
      assert.match(html, /rel="canonical" href="https:\/\/neptype.com\//);
      assert.ok(!html.includes('127.0.0.1'));
    }
    assert.match(await read('_headers'), /X-Robots-Tag: noindex, follow/);
    assert.ok(!(await read('robots.txt')).includes('Disallow: /'), 'crawlers can see noindex');
    assert.ok(!(await read('robots.txt')).includes('Sitemap:'));
  }
});
