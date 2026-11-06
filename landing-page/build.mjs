import {readFile, writeFile, mkdir, copyFile, cp, rm} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import process from 'node:process';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {gzipSync} from 'node:zlib';
import {build as bundle} from 'esbuild';
import {homeTitle, homeDescriptions, labels, nepaliCopy, pages, repository} from './page-content.mjs';
import {siteConfig} from './site-config.mjs';
import {windowsDownload, windowsPage} from './windows-release.mjs';
import {downloadPage, renderDownloadPage} from './download-page.mjs';
import {homeHelp, typingGuide} from './typing-guide.mjs';
import {loadArticles, articlePages} from './article-content.mjs';
const articles = await loadArticles();
Object.assign(pages, articlePages(articles));
pages['typing-guide'] = typingGuide;

const root = path.dirname(fileURLToPath(import.meta.url));
try { process.loadEnvFile(path.join(root, '.env.local')); } catch (error) { if (error.code !== 'ENOENT') throw error; }
const output = path.join(root, 'dist');
const {origin, production} = siteConfig();
const posthogKey = process.env.PUBLIC_POSTHOG_KEY || '';
const posthogHost = process.env.PUBLIC_POSTHOG_HOST || '';
const gaMeasurementId = process.env.PUBLIC_GA_MEASUREMENT_ID || '';
if (gaMeasurementId && !/^G-[A-Z0-9]{4,20}$/.test(gaMeasurementId)) throw Error('PUBLIC_GA_MEASUREMENT_ID must be a GA4 web measurement ID.');
if (Boolean(posthogKey) !== Boolean(posthogHost)) throw Error('Set PUBLIC_POSTHOG_KEY and PUBLIC_POSTHOG_HOST together.');
if (posthogHost && new URL(posthogHost).protocol !== 'https:') throw Error('PUBLIC_POSTHOG_HOST must use HTTPS.');
const macRelease = JSON.parse(await readFile(path.join(root, 'mac-release.json'), 'utf8'));
const windowsRelease = windowsDownload(JSON.parse(await readFile(path.join(root, 'windows-release.json'), 'utf8')));
pages.windows = {en: windowsPage(windowsRelease, 'en'), ne: windowsPage(windowsRelease, 'ne')};
pages.download = downloadPage;
const publicPaths = ['/', '/ne/', ...Object.keys(pages).flatMap(slug => ['/'+slug+'/', '/ne/'+slug+'/'])];
const downloadUrl = process.env.APP_DOWNLOAD_URL || macRelease.url;
if (downloadUrl && new URL(downloadUrl).protocol !== 'https:') throw Error('APP_DOWNLOAD_URL must use HTTPS.');
const escape = text => String(text).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const route = (locale, slug = '') => `${locale === 'ne' ? '/ne' : ''}/${slug ? slug + '/' : ''}`;
const canonical = (locale, slug) => origin + route(locale, slug);
const template = await readFile(path.join(root, 'index.html'), 'utf8');
const header = template.match(/<header class="site-header">[\s\S]*?<\/header>/)[0];
const footer = template.match(/<footer class="site-footer">[\s\S]*?<\/footer>/)[0];

function localize(html, locale, slug = '') {
  const languageLink = `<a class="language" href="${route(locale === 'ne' ? 'en' : 'ne', slug)}" lang="${locale === 'ne' ? 'en' : 'ne'}" hreflang="${locale === 'ne' ? 'en' : 'ne'}" aria-label="${locale === 'ne' ? 'Read in English' : 'नेपालीमा पढ्नुहोस्'}">${locale === 'ne' ? 'ने' : 'EN'} <span>⌄</span></a>`;
  html = html.replace(/<a class="language"[^>]*>[\s\S]*?<\/a>/, '<!-- LANGUAGE_SWITCH -->');
  if (locale !== 'ne') return html.replace('<!-- LANGUAGE_SWITCH -->', languageLink);
  html = html.replace(/(<([a-z0-9]+)\b[^>]*data-copy="([^"]+)"[^>]*>)[\s\S]*?(<\/\2>)/g,
    (match, start, tag, key, end) => nepaliCopy[key] ? start + nepaliCopy[key] + end : match);
  for (const [english, nepali] of Object.entries(labels)) {
    html = html.replaceAll(`>${english}<`, `>${nepali}<`);
  }
  html = html.replaceAll('Works offline</span>', 'अफलाइन चल्छ</span>')
    .replaceAll('No connection needed</span>', 'इन्टरनेट चाहिँदैन</span>')
    .replaceAll('Copy example <span>', 'उदाहरण कपी गर्नुहोस् <span>')
    .replaceAll('Try another spelling</div>', 'अर्को हिज्जे रोज्नुहोस्</div>')
    .replaceAll('href="/articles/"', 'href="/ne/articles/"')
    .replaceAll('href="/typing-guide/"', 'href="/ne/typing-guide/"')
    .replaceAll('href="/mac/"', 'href="/ne/mac/"')
    .replaceAll('href="/windows/"', 'href="/ne/windows/"')
    .replaceAll('href="/download/"', 'href="/ne/download/"')
    .replaceAll('href="/faq/"', 'href="/ne/faq/"')
    .replaceAll('href="/about/"', 'href="/ne/about/"')
    .replaceAll('href="/privacy/"', 'href="/ne/privacy/"')
    .replaceAll('href="/terms/"', 'href="/ne/terms/"')
    .replaceAll('href="/changelog/"', 'href="/ne/changelog/"')
    .replaceAll('href="/"', 'href="/ne/"')
    .replaceAll('alt="NepType Mac app showing Roman input, Nepali spelling suggestions, and mixed Nepali and English output."', 'alt="NepType Mac एपमा रोमन इनपुट, नेपाली हिज्जे सुझाव र नेपाली तथा अंग्रेजी मिसिएको पाठ।"')
    .replaceAll('aria-label="Toggle navigation"', 'aria-label="नेभिगेसन खोल्नुहोस्"')
    .replaceAll('aria-label="Close dialog"', 'aria-label="बन्द गर्नुहोस्"')
    .replaceAll('Skip to content', 'मुख्य सामग्रीमा जानुहोस्')
    .replaceAll('aria-label="Main navigation"', 'aria-label="मुख्य नेभिगेसन"')
    .replaceAll('aria-label="Spelling suggestions"', 'aria-label="हिज्जेका सुझाव"')
    .replaceAll('aria-label="Platform availability"', 'aria-label="प्लेटफर्मको उपलब्धता"')
    .replaceAll('aria-label="NepType on Mac"', 'aria-label="Mac मा NepType"')
    .replaceAll('aria-label="Choose the meaning of pani"', 'aria-label="pani को हिज्जे रोज्नुहोस्"')
    .replaceAll('>All Nepali</option>', '>सबै नेपाली</option>')
    .replaceAll('This typing pad needs JavaScript. The app and instructions are available on', 'यो टाइपिङ प्याडलाई JavaScript चाहिन्छ। एप र निर्देशन यहाँ उपलब्ध छन्:');
  return html.replace('<!-- LANGUAGE_SWITCH -->', languageLink);
}

function metadata(locale, slug, title, description) {
  const url = canonical(locale, slug);
  const content = pages[slug]?.[locale];
  const webappId = origin + '/#browser-tool';
  const appId = origin + '/#mac-app';
  const graph = [
    {'@type': 'WebSite', '@id': origin + '/#website', name: 'NepType', url: origin + '/', inLanguage: ['en', 'ne']},
    {'@type': content?.kind === 'article' ? 'TechArticle' : content?.kind === 'collection' ? 'CollectionPage' : 'WebPage', '@id': url + '#page', url, name: title, description, inLanguage: locale, isPartOf: {'@id': origin + '/#website'},
      ...(!slug || slug === 'mac' ? {mainEntity: {'@id': slug === 'mac' ? appId : webappId}} : {}),
      ...(content?.kind === 'article' ? {headline: content.heading, datePublished: content.published, ...(content.modified ? {dateModified:content.modified} : {}), author: {'@type': 'Organization', name: 'NepType', url: origin + '/about/'}} : {})}
  ];
  if (!slug) graph.push({'@type': 'WebApplication', '@id': webappId, name: 'NepType Online Typing Pad', url: canonical(locale, '') + '#try', applicationCategory: 'UtilitiesApplication', operatingSystem: 'Any', browserRequirements: 'Requires JavaScript and an initial network connection', isAccessibleForFree: true, description: homeDescriptions[locale], inLanguage: ['en', 'ne'], sameAs: repository});
  if (slug === 'mac') graph.push({'@type': 'SoftwareApplication', '@id': appId, name: 'NepType for Mac', url, applicationCategory: 'UtilitiesApplication', operatingSystem: 'macOS', description, image: origin + '/assets/neptype-icon.png', screenshot: origin + '/assets/neptype-mac.png', sameAs: repository, ...(downloadUrl ? {downloadUrl, softwareVersion:macRelease.version, softwareRequirements:'macOS 13 or later; Apple silicon or Intel'} : {})});
  if (slug === 'windows' && windowsRelease) graph.push({'@type':'SoftwareApplication', '@id':origin+'/#windows-app', name:'NepType for Windows', url, applicationCategory:'UtilitiesApplication', operatingSystem:'Windows 10 or 11 (x64)', description, downloadUrl:windowsRelease.url, softwareVersion:windowsRelease.version, sameAs:repository});
  if (slug) graph.push({'@type': 'BreadcrumbList', '@id': url + '#breadcrumb', itemListElement: [
    {'@type': 'ListItem', position: 1, name: 'NepType', item: canonical(locale, '')},
    ...(slug.startsWith('articles/') ? [{'@type':'ListItem',position:2,name:locale === 'ne' ? 'लेखहरू' : 'Articles',item:canonical(locale,'articles')}] : []),
    {'@type': 'ListItem', position: slug.startsWith('articles/') ? 3 : 2, name: content.heading, item: url}
  ]});
  return `<title>${escape(title)}</title>
  <meta name="description" content="${escape(description)}">
  <link rel="canonical" href="${url}">
  <link rel="alternate" hreflang="en" href="${canonical('en', slug)}">
  <link rel="alternate" hreflang="ne" href="${canonical('ne', slug)}">
  <link rel="alternate" hreflang="x-default" href="${canonical('en', slug)}">
  <meta name="robots" content="${production ? 'index,follow,max-image-preview:large' : 'noindex,follow'}">
  <link rel="alternate" type="application/rss+xml" title="NepType articles" href="${canonical(locale, 'articles')}feed.xml">
  <meta property="og:type" content="${content?.kind === 'article' ? 'article' : 'website'}">
  <meta property="og:site_name" content="NepType">
  <meta property="og:title" content="${escape(title)}">
  <meta property="og:description" content="${escape(description)}">
  <meta property="og:url" content="${url}">
  <meta property="og:locale" content="${locale === 'ne' ? 'ne_NP' : 'en_US'}">
  <meta property="og:locale:alternate" content="${locale === 'ne' ? 'en_US' : 'ne_NP'}">
  <meta property="og:image" content="${origin}/assets/neptype-mac.png">
  <meta property="og:image:width" content="720">
  <meta property="og:image:height" content="540">
  <meta property="og:image:alt" content="${locale === 'ne' ? 'Mac मा NepType नेपाली टाइपिङ एप' : 'NepType Nepali typing app on Mac'}">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${escape(title)}">
  <meta name="twitter:description" content="${escape(description)}">
  <meta name="twitter:image" content="${origin}/assets/neptype-mac.png">
  <meta name="twitter:image:alt" content="${locale === 'ne' ? 'Mac मा NepType नेपाली टाइपिङ एप' : 'NepType Nepali typing app on Mac'}">
  <link rel="preload" href="/assets/fonts/${locale === 'ne' ? 'noto-sans-devanagari' : 'dm-sans-latin'}.woff2" as="font" type="font/woff2" crossorigin>
  <script type="application/ld+json">${JSON.stringify({'@context': 'https://schema.org', '@graph': graph}).replaceAll('<', '\\u003c')}</script>`;
}

function renderSections(sections, locale) {
  const href = value => locale === 'ne' && value.startsWith('/') && !value.startsWith('/ne/') ? '/ne' + value : value;
  return sections.map(([heading, text, extra = {}]) => `${heading ? `<h2>${escape(heading)}</h2>` : ''}<p>${escape(text)}</p>
    ${extra.steps ? `<ol>${extra.steps.map(step => `<li>${escape(step)}</li>`).join('')}</ol>` : ''}
    ${extra.note ? `<p class="setup-note">${escape(extra.note)}</p>` : ''}
    ${extra.code ? `<pre><code>${escape(extra.code)}</code></pre>` : ''}
    ${extra.examples ? `<div class="table-scroll"><table><caption>${locale === 'ne' ? 'Nepali + EN का उदाहरण' : 'Nepali + EN examples'}</caption><thead><tr><th scope="col">${locale === 'ne' ? 'रोमन लेखाइ' : 'Roman input'}</th><th scope="col">${locale === 'ne' ? 'नेपाली पाठ' : 'Nepali output'}</th></tr></thead><tbody>${extra.examples.map(([roman, output]) => `<tr><td><code>${escape(roman)}</code></td><td lang="ne">${escape(output)}</td></tr>`).join('')}</tbody></table></div>` : ''}
    ${extra.links ? `<ul class="related-links">${extra.links.map(([label, target]) => `<li><a href="${escape(href(target))}">${escape(label)}</a></li>`).join('')}</ul>` : ''}`).join('\n');
}

function renderHomeHelp(locale) {
  const copy = homeHelp[locale];
  return `<section class="typing-help container" aria-labelledby="how-to-title"><h2 id="how-to-title">${escape(copy.heading)}</h2><p>${escape(copy.intro)}</p><div class="typing-steps">${copy.steps.map(([heading, text]) => `<div><h3>${escape(heading)}</h3><p>${escape(text)}</p></div>`).join('')}</div><p>${escape(copy.note)}</p><ul class="related-links"><li><a href="${route(locale, 'typing-guide')}">${escape(copy.guide)}</a></li><li><a href="${route(locale, 'faq')}">${escape(copy.faq)}</a></li><li><a href="${route(locale, 'mac')}">${escape(copy.mac)}</a></li><li><a href="${route(locale, 'articles')}">${locale === 'ne' ? 'टाइपिङका लेख र सुझाव' : 'More typing articles and tips'}</a></li>${articles.slice(0,2).map(article => `<li><a href="${route(locale, 'articles/'+article.slug)}">${escape(article[locale].heading)}</a></li>`).join('')}</ul></section>`;
}

function displayDate(value, locale) {
  return new Intl.DateTimeFormat(locale === 'ne' ? 'ne-NP' : 'en-US', {year:'numeric',month:'long',day:'numeric',timeZone:'UTC'}).format(new Date(value+'T12:00:00Z'));
}

function renderArticleList(content, locale) {
  if (!content.articleList) return '';
  return `<div class="article-list">${content.articleList.map(article => `<article><p class="article-date"><time datetime="${article.published}">${escape(displayDate(article.published,locale))}</time></p><h2><a href="${route(locale,'articles/'+article.slug)}">${escape(article.heading)}</a></h2><p>${escape(article.description)}</p></article>`).join('')}</div>`;
}

function finish(html, locale, slug, title, description) {
  html = html.replaceAll('data-device-download', `data-device-download data-mac-url="${escape(downloadUrl || '')}" data-windows-url="${escape(windowsRelease?.url || '')}"`);
  if (downloadUrl) html = html.replace(/<a\b[^>]*data-mac-download[^>]*>/g, tag => tag.replace(/href="[^"]*"/, `href="${escape(downloadUrl)}"`).replace('neptype_app_cta_clicked','neptype_download_clicked'));
  html = html.replace(/<title>[\s\S]*?<\/title>/, '').replace(/\s*<meta name="description"[^>]*>/, '');
  html = html.replace('<html lang="en"', `<html lang="${locale}"`);
  return html.replace('</head>', metadata(locale, slug, title, description) + '\n</head>');
}

await rm(output, {recursive: true, force: true});
await mkdir(path.join(output, 'assets'), {recursive: true});
for (const asset of ['neptype-icon.png', 'neptype-mac.png']) {
  await copyFile(path.join(root, 'assets', asset), path.join(output, 'assets', asset));
}
await cp(path.join(root, 'assets/fonts'), path.join(output, 'assets/fonts'), {recursive: true});
// Only production assets are published; design variations and evidence stay in the repo.
for (const asset of ['site.js', 'platform.mjs', 'final.css', 'web-engine.mjs', 'web-tool.mjs', 'engine-worker.mjs']) await copyFile(path.join(root, asset), path.join(output, asset));
// Build the same Rust engine and embedded dictionary used by native adapters.
execFileSync('bash', [path.join(root, '../scripts/build-web-engine.sh')], {stdio:'inherit'});
const wasm = await readFile(path.join(root, 'engine-build/neptype_engine_bg.wasm'));
const wasmSha256 = createHash('sha256').update(wasm).digest('hex');
const compressed = gzipSync(wasm, {level:9});
const assetPath = `/engine/${wasmSha256}`;
await mkdir(path.join(output, assetPath), {recursive:true});
await copyFile(path.join(root, 'engine-build/neptype_engine.js'), path.join(output, assetPath, 'neptype_engine.js'));
await writeFile(path.join(output, assetPath, 'neptype_engine_bg.wasm'), wasm);
await writeFile(path.join(output, assetPath, 'neptype_engine_bg.wasm.bin'), compressed);
const dictionary = JSON.parse(await readFile(path.join(root, '../engine/data/manifest.json'), 'utf8'));
await writeFile(path.join(output, 'engine-config.json'), JSON.stringify({module:assetPath+'/neptype_engine.js',wasm:assetPath+'/neptype_engine_bg.wasm',compressed:assetPath+'/neptype_engine_bg.wasm.bin',wasmSha256,wasmBytes:wasm.length,compressedBytes:compressed.length,compressedSha256:createHash('sha256').update(compressed).digest('hex'),dictionaryId:dictionary.id}));
await writeFile(path.join(output, 'assets/neptype-dictionaries.json'), JSON.stringify(dictionary));
await copyFile(path.join(root, '../engine/data/RUST-LICENSES.txt'), path.join(output, 'assets/RUST-LICENSES.txt'));
for (const license of ['CMUDICT-LICENSE.txt','GOOGLE-NE-ATTRIBUTION.txt','AKSHARANTAR-ATTRIBUTION.txt']) await copyFile(path.join(root, '../data/sources', license), path.join(output, 'assets', license));
await bundle({entryPoints:[path.join(root, 'analytics.mjs')], outfile:path.join(output, 'analytics.js'), bundle:true, minify:true, target:['es2020'], format:'iife', define:{__POSTHOG_KEY__:JSON.stringify(posthogKey), __POSTHOG_HOST__:JSON.stringify(posthogHost), __PRODUCTION__:JSON.stringify(production), __GA_MEASUREMENT_ID__:JSON.stringify(gaMeasurementId), __PUBLIC_PATHS__:JSON.stringify(publicPaths)}});
let styles = await readFile(path.join(root, 'styles.css'), 'utf8');
// Self-host licensed fonts to avoid the external stylesheet and connection chain.
styles = await readFile(path.join(root, 'fonts.css'), 'utf8') + '\n' + styles.replace(/^@import url\([^\n]+\);\n/, '');
await writeFile(path.join(output, 'styles.css'), styles);

const urls = [];
for (const locale of ['en', 'ne']) {
  const description = homeDescriptions[locale];
  const home = finish(localize(template, locale).replace('<!-- HOME_HELP -->', renderHomeHelp(locale)), locale, '', homeTitle[locale], description);
  const directory = path.join(output, route(locale));
  await mkdir(directory, {recursive: true});
  await writeFile(path.join(directory, 'index.html'), home);
  urls.push({slug: '', locale});
  for (const [slug, translated] of Object.entries(pages)) {
    const content = translated[locale];
    const sections = renderSections(content.sections, locale);
    const byline = content.kind === 'article' ? `<p class="article-byline">${locale === 'ne' ? 'लेखन: ' : 'By '}<a href="${route(locale, 'about')}">${locale === 'ne' ? 'NepType परियोजना' : 'NepType project'}</a> · <time datetime="${content.published}">${escape(displayDate(content.published,locale))}</time></p>` : '';
    const related = `<p class="page-tool-link"><a href="${route(locale)}#try">${locale === 'ne' ? 'अनलाइन नेपाली टाइपिङ प्याड खोल्नुहोस्' : 'Open the online Nepali typing pad'} →</a></p>`;
    const nativeDownload = slug === 'mac' ? downloadUrl : slug === 'windows' ? windowsRelease?.url : null;
    const linkUrl = nativeDownload || repository;
    const linkText = nativeDownload ? (slug === 'windows' ? (locale === 'ne' ? 'Windows का लागि डाउनलोड गर्नुहोस्' : 'Download for Windows') : (locale === 'ne' ? 'Mac का लागि डाउनलोड गर्नुहोस् (.dmg)' : 'Download for Mac (.dmg)')) : content.link;
    const linkEvent = nativeDownload ? 'neptype_download_clicked' : 'neptype_source_opened';
    const privacyControl = slug === 'privacy' ? `<p id="analytics"><button class="button" id="analytics-toggle" type="button" hidden>${locale === 'ne' ? 'एनालिटिक्स सेटिङ' : 'Analytics settings'}</button></p>` : '';
    const pageAction = (linkText ? `<p><a class="button" href="${escape(linkUrl)}" data-analytics-event="${linkEvent}" data-placement="${slug}"${slug === 'windows' ? ' data-platform="Windows"' : ''}${nativeDownload ? '' : ' target="_blank" rel="noopener noreferrer"'}>${escape(linkText)}</a></p>` : '');
    const nativePage = slug === 'mac' || slug === 'windows';
    const body = slug === 'download' ? renderDownloadPage(locale, {mac:downloadUrl, windows:windowsRelease?.url}, escape) : `<main id="main" class="document-page container"><a class="back-link" href="${route(locale)}">${locale === 'ne' ? 'NepType गृहपृष्ठ' : 'NepType home'}</a><h1>${escape(content.heading)}</h1>${byline}${nativePage ? pageAction : ''}${sections}${renderArticleList(content,locale)}${related}${nativePage ? '' : pageAction}${privacyControl}</main>`;
    let html = `<!doctype html><html lang="en" data-design="graphite" class="final-site"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title></title><link rel="icon" href="/assets/neptype-icon.png"><link rel="stylesheet" href="/styles.css"><link rel="stylesheet" href="/final.css"><script src="/analytics.js" defer></script><script type="module" src="/site.js"></script></head><body><a class="skip-link" href="#main">Skip to content</a>${header}${body}${footer}</body></html>`;
    html = localize(html, locale, slug).replaceAll('href="#features"', `href="${route(locale)}#features"`).replaceAll('href="#platforms"', `href="${route(locale)}#platforms"`).replaceAll('href="#try"', `href="${route(locale)}#try"`);
    html = finish(html, locale, slug, content.title, content.description);
    const pageDirectory = path.join(output, route(locale, slug));
    await mkdir(pageDirectory, {recursive: true});
    await writeFile(path.join(pageDirectory, 'index.html'), html);
    urls.push({slug, locale});
  }
}

const sitemap = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls.map(({locale, slug}) => `  <url><loc>${canonical(locale, slug)}</loc>${pages[slug]?.[locale]?.published ? `<lastmod>${pages[slug][locale].modified || pages[slug][locale].published}</lastmod>` : ''}</url>`).join('\n')}\n</urlset>\n`;
await writeFile(path.join(output, 'sitemap.xml'), sitemap);
for (const locale of ['en','ne']) {
  const feed = `<?xml version="1.0" encoding="UTF-8"?><rss version="2.0"><channel><title>NepType ${locale === 'ne' ? 'लेखहरू' : 'typing articles'}</title><link>${canonical(locale,'articles')}</link><description>${escape(pages.articles[locale].description)}</description><language>${locale}</language>${articles.slice(0,20).map(article => `<item><title>${escape(article[locale].heading)}</title><link>${canonical(locale,'articles/'+article.slug)}</link><guid isPermaLink="true">${canonical(locale,'articles/'+article.slug)}</guid><description>${escape(article[locale].description)}</description></item>`).join('')}</channel></rss>`;
  await writeFile(path.join(output,route(locale,'articles'),'feed.xml'),feed);
}
// Crawlers must be allowed to fetch previews to see their noindex directive.
await writeFile(path.join(output, 'robots.txt'), `User-agent: *\nAllow: /\n${production ? `Sitemap: ${origin}/sitemap.xml\n` : ''}`);
if (!production) await writeFile(path.join(output, '_headers'), '/*\n  X-Robots-Tag: noindex, follow\n');
const notFound = `<!doctype html><html lang="en" data-design="graphite" class="final-site"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Page not found | NepType</title><meta name="robots" content="noindex"><link rel="stylesheet" href="/styles.css"><link rel="stylesheet" href="/final.css"></head><body><main class="document-page container"><h1>Page not found.</h1><p><a href="/">Back to NepType</a></p></main></body></html>`;
await writeFile(path.join(output, '404.html'), notFound);
console.log(`Built ${urls.length} static pages for ${origin} (${production ? 'indexable production' : 'noindex preview'}).`);
