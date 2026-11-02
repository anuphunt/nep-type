import {readFile, writeFile, mkdir, copyFile, rm} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import {homeDescription, labels, nepaliCopy, pages, repository} from './page-content.mjs';

const root = path.dirname(fileURLToPath(import.meta.url));
const output = path.join(root, 'dist');
const origin = new URL(process.env.SITE_URL || process.env.URL || 'http://127.0.0.1:4174').origin;
const production = origin.startsWith('https://') && (!process.env.CONTEXT || process.env.CONTEXT === 'production');
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
    .replaceAll('href="/mac/"', 'href="/ne/mac/"')
    .replaceAll('href="/faq/"', 'href="/ne/faq/"')
    .replaceAll('href="/about/"', 'href="/ne/about/"')
    .replaceAll('href="/privacy/"', 'href="/ne/privacy/"')
    .replaceAll('href="/changelog/"', 'href="/ne/changelog/"')
    .replaceAll('href="/"', 'href="/ne/"')
    .replaceAll('alt="NepType Mac app showing Roman input, Nepali spelling suggestions, and mixed Nepali and English output."', 'alt="NepType Mac एपमा रोमन इनपुट, नेपाली हिज्जे सुझाव र नेपाली तथा अंग्रेजी मिसिएको पाठ।"')
    .replaceAll('aria-label="Toggle navigation"', 'aria-label="नेभिगेसन खोल्नुहोस्"')
    .replaceAll('aria-label="Close dialog"', 'aria-label="बन्द गर्नुहोस्"')
    .replaceAll('Skip to content', 'मुख्य सामग्रीमा जानुहोस्');
  return html.replace('<!-- LANGUAGE_SWITCH -->', languageLink);
}

function metadata(locale, slug, title, description) {
  const url = canonical(locale, slug);
  const graph = [
    {'@type': 'WebSite', '@id': origin + '/#website', name: 'NepType', url: origin + '/', inLanguage: ['en', 'ne']},
    {'@type': 'SoftwareApplication', '@id': origin + '/#app', name: 'NepType', url: origin + '/', applicationCategory: 'UtilitiesApplication', operatingSystem: 'macOS', description: homeDescription, image: origin + '/assets/neptype-icon.png', screenshot: origin + '/assets/neptype-mac.png', license: repository + '/blob/main/LICENSE', sameAs: repository}
  ];
  return `<title>${escape(title)}</title>
  <meta name="description" content="${escape(description)}">
  <link rel="canonical" href="${url}">
  <link rel="alternate" hreflang="en" href="${canonical('en', slug)}">
  <link rel="alternate" hreflang="ne" href="${canonical('ne', slug)}">
  <link rel="alternate" hreflang="x-default" href="${canonical('en', slug)}">
  <meta name="robots" content="${production ? 'index,follow,max-image-preview:large' : 'noindex,follow'}">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="NepType">
  <meta property="og:title" content="${escape(title)}">
  <meta property="og:description" content="${escape(description)}">
  <meta property="og:url" content="${url}">
  <meta property="og:locale" content="${locale === 'ne' ? 'ne_NP' : 'en_US'}">
  <meta property="og:image" content="${origin}/assets/neptype-mac.png">
  <meta property="og:image:width" content="720">
  <meta property="og:image:height" content="540">
  <meta property="og:image:alt" content="${locale === 'ne' ? 'Mac मा NepType नेपाली टाइपिङ एप' : 'NepType Nepali typing app on Mac'}">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${escape(title)}">
  <meta name="twitter:description" content="${escape(description)}">
  <meta name="twitter:image" content="${origin}/assets/neptype-mac.png">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <script type="application/ld+json">${JSON.stringify({'@context': 'https://schema.org', '@graph': graph}).replaceAll('<', '\\u003c')}</script>`;
}

function finish(html, locale, slug, title, description) {
  html = html.replace(/<title>[\s\S]*?<\/title>/, '').replace(/\s*<meta name="description"[^>]*>/, '');
  html = html.replace('<html lang="en"', `<html lang="${locale}"`);
  return html.replace('</head>', metadata(locale, slug, title, description) + '\n</head>');
}

await rm(output, {recursive: true, force: true});
await mkdir(path.join(output, 'assets'), {recursive: true});
for (const asset of ['neptype-icon.png', 'neptype-mac.png']) {
  await copyFile(path.join(root, 'assets', asset), path.join(output, 'assets', asset));
}
// Only production assets are published; design variations and evidence stay in the repo.
for (const asset of ['site.js', 'final.css']) await copyFile(path.join(root, asset), path.join(output, asset));
let styles = await readFile(path.join(root, 'styles.css'), 'utf8');
styles = styles.replace('&family=Playfair+Display:ital,wght@0,500;0,600;1,500', '');
await writeFile(path.join(output, 'styles.css'), styles);

const urls = [];
for (const locale of ['en', 'ne']) {
  const homeTitle = locale === 'en' ? 'NepType | Open-Source Nepali Typing for Mac' : 'NepType | Mac का लागि खुला स्रोत नेपाली टाइपिङ';
  const description = locale === 'en' ? homeDescription : 'NepType मा रोमन अक्षरबाट नेपाली लेख्नुहोस्। Mac का लागि खुला स्रोत एप अफलाइन चल्छ र नेपालीसँग अंग्रेजी शब्द पनि राख्न मिल्छ।';
  const home = finish(localize(template, locale), locale, '', homeTitle, description);
  const directory = path.join(output, route(locale));
  await mkdir(directory, {recursive: true});
  await writeFile(path.join(directory, 'index.html'), home);
  urls.push({slug: '', locale});
  for (const [slug, translated] of Object.entries(pages)) {
    const content = translated[locale];
    const sections = content.sections.map(([heading, text]) => `${heading ? `<h2>${escape(heading)}</h2>` : ''}<p>${escape(text)}</p>`).join('\n');
    const body = `<main id="main" class="document-page container"><a class="back-link" href="${route(locale)}">${locale === 'ne' ? 'NepType गृहपृष्ठ' : 'NepType home'}</a><h1>${escape(content.heading)}</h1>${sections}${content.link ? `<p><a class="button" href="${repository}" target="_blank" rel="noopener noreferrer">${escape(content.link)}</a></p>` : ''}</main>`;
    let html = `<!doctype html><html lang="en" data-design="graphite" class="final-site"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title></title><link rel="icon" href="/assets/neptype-icon.png"><link rel="stylesheet" href="/styles.css"><link rel="stylesheet" href="/final.css"><script src="/site.js" defer></script></head><body><a class="skip-link" href="#main">Skip to content</a>${header}${body}${footer}</body></html>`;
    html = localize(html, locale, slug).replaceAll('href="#features"', `href="${route(locale)}#features"`).replaceAll('href="#platforms"', `href="${route(locale)}#platforms"`);
    html = finish(html, locale, slug, content.title, content.description);
    const pageDirectory = path.join(output, route(locale, slug));
    await mkdir(pageDirectory, {recursive: true});
    await writeFile(path.join(pageDirectory, 'index.html'), html);
    urls.push({slug, locale});
  }
}

const sitemap = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls.map(({locale, slug}) => `  <url><loc>${canonical(locale, slug)}</loc></url>`).join('\n')}\n</urlset>\n`;
await writeFile(path.join(output, 'sitemap.xml'), sitemap);
await writeFile(path.join(output, 'robots.txt'), `User-agent: *\n${production ? 'Allow: /' : 'Disallow: /'}\nSitemap: ${origin}/sitemap.xml\n`);
const notFound = `<!doctype html><html lang="en" data-design="graphite" class="final-site"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Page not found | NepType</title><meta name="robots" content="noindex"><link rel="stylesheet" href="/styles.css"><link rel="stylesheet" href="/final.css"></head><body><main class="document-page container"><h1>Page not found.</h1><p><a href="/">Back to NepType</a></p></main></body></html>`;
await writeFile(path.join(output, '404.html'), notFound);
console.log(`Built ${urls.length} static pages for ${origin} (${production ? 'indexable production' : 'noindex preview'}).`);
