export const downloadPage = {
  en: {title:'Download NepType for Mac & Windows | All Platforms', heading:'Download NepType.', description:'Download NepType for Mac or Windows. The iPhone app is currently under review by Apple. Android and Linux apps are coming soon.', sections:[]},
  ne: {title:'Mac र Windows का लागि NepType डाउनलोड | सबै प्लेटफर्म', heading:'NepType डाउनलोड गर्नुहोस्।', description:'Mac वा Windows का लागि NepType डाउनलोड गर्नुहोस्। iPhone एप हाल Apple को समीक्षामा छ। Android र Linux एप आउँदैछन्।', sections:[]}
};

const icons = {
  macOS:'<path d="M15.7 5.2c.9-1 1.4-2.3 1.3-3.2-1.2.1-2.6.8-3.4 1.7-.8.8-1.4 2.1-1.3 3.2 1.3.1 2.5-.6 3.4-1.7ZM19 12.7c0-2 1.7-3 1.8-3.1-1-1.5-2.6-1.7-3.2-1.7-1.4-.1-2.7.8-3.4.8-.7 0-1.8-.8-2.9-.8-1.5 0-2.9.9-3.7 2.2-1.6 2.8-.4 6.9 1.1 9.1.7 1.1 1.5 2.2 2.7 2.1 1.1-.1 1.5-.7 2.9-.7 1.4 0 1.8.7 3 .6 1.2 0 1.9-1 2.6-2.1.8-1.2 1.1-2.3 1.2-2.4-.1 0-2.1-.8-2.1-4Z" fill="currentColor"/>',
  Windows:'<path fill="currentColor" d="M2 4.5 10.5 3v8H2zm10.5-1.9L22 1v10h-9.5zM2 13h8.5v8L2 19.5zm10.5 0H22v10l-9.5-1.6z"/>',
  iOS:'<rect x="6" y="1.5" width="12" height="21" rx="3" fill="none" stroke="currentColor" stroke-width="1.5"/><path d="M10 4h4m-3 15.5h2" fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="1.5"/>',
  Android:'<path d="m7 4 2 3m8-3-2 3M5 14a7 7 0 0 1 14 0v4H5v-4Z" fill="none" stroke="currentColor" stroke-width="1.6"/><circle cx="9" cy="12" r="1" fill="currentColor"/><circle cx="15" cy="12" r="1" fill="currentColor"/>',
  Linux:'<path d="M7 11V7a5 5 0 0 1 10 0v4l3 7-4 2H8l-4-2 3-7Z" fill="currentColor"/><ellipse cx="12" cy="14" rx="4.6" ry="6" fill="#252525"/><ellipse cx="10.3" cy="7.2" rx="1.1" ry="1.5" fill="#252525"/><ellipse cx="13.7" cy="7.2" rx="1.1" ry="1.5" fill="#252525"/><path d="m9.5 10 2.5 1.5 2.5-1.5L12 8.7zM8 18l-5 2v2h7zm8 0 5 2v2h-7z" fill="currentColor"/>'
};
const icon = platform => `<svg viewBox="0 0 24 24" aria-hidden="true">${icons[platform]}</svg>`;
const arrow = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3v12m-5-5 5 5 5-5M5 16v5h14v-5" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></svg>';

export function renderDownloadPage(locale, releases, escape) {
  return renderDownloads(locale, releases, escape);
}

export function renderHomeDownloads(locale, releases, escape) {
  return renderDownloads(locale, releases, escape, true);
}

function renderDownloads(locale, {mac, windows}, escape, embedded = false) {
  const ne = locale === 'ne';
  const prefix = ne ? '/ne' : '';
  const titleTag = embedded ? 'h2' : 'h1';
  const cardTitleTag = embedded ? 'h3' : 'h2';
  const platforms = [
    {id:'macOS', name:'Mac', requirement:ne ? 'macOS 13 वा पछिल्लो' : 'macOS 13 or later', architecture:'Apple silicon · Intel', url:mac, slug:'mac', label:ne ? 'Mac का लागि डाउनलोड' : 'Download for Mac', file:'.dmg'},
    {id:'Windows', name:'Windows', requirement:'Windows 10 / 11', architecture:ne ? 'Intel वा AMD · x64' : 'Intel or AMD · x64', url:windows, slug:'windows', label:ne ? 'Windows का लागि डाउनलोड गर्नुहोस्' : 'Download for Windows', file:'.exe'},
    {id:'iOS', name:'iPhone', requirement:ne ? 'iPhone का लागि' : 'For iPhone', architecture:ne ? 'हाल Apple को समीक्षामा छ' : 'Currently under review by Apple', status:ne ? 'Apple को समीक्षामा' : 'Under Apple review'},
    {id:'Android', name:'Android', requirement:ne ? 'Android का लागि' : 'For Android', architecture:ne ? 'सार्वजनिक डाउनलोड आउन बाँकी छ' : 'Public release on the way'},
    {id:'Linux', name:'Linux', requirement:ne ? 'Linux का लागि' : 'For Linux', architecture:ne ? 'प्याकेजको विवरण आउन बाँकी छ' : 'Package details to come'}
  ];
  const cards = platforms.map(p => `<article class="download-card${p.url ? '' : ' download-card-pending'}" data-platform-card="${p.id}" aria-labelledby="platform-${p.id}">
    <div class="download-card-top"><div class="platform-logo logo-${p.id}">${icon(p.id)}</div><span class="device-badge" data-current-device hidden>${ne ? 'तपाईंको उपकरण' : 'Your device'}</span></div>
    <span class="release-status">${p.url ? (ne ? 'उपलब्ध छ' : 'Available now') : (p.status || (ne ? 'छिट्टै आउँदैछ' : 'Coming soon'))}</span>
    <${cardTitleTag} id="platform-${p.id}">${p.name}</${cardTitleTag}>
    <div class="platform-requirements"><p>${p.requirement}</p><p>${p.architecture}</p>${p.url ? `<p class="installer-format">${p.file}</p>` : ''}</div>
    <div class="download-card-action">${p.url ? `<a class="button platform-download" href="${escape(p.url)}" data-platform="${p.id}" data-analytics-event="neptype_download_clicked" data-placement="download-card">${arrow}<span>${p.label}</span></a><a class="setup-link" href="${prefix}/${p.slug}/">${ne ? 'इन्स्टल गर्ने तरिका र विवरण' : 'Setup guide & details'} <span aria-hidden="true">↗</span></a>` : `<span class="coming-soon">${p.status || (ne ? 'छिट्टै आउँदैछ' : 'Coming soon')}</span><a class="setup-link" href="${prefix}/#try">${ne ? 'अहिले ब्राउजरमा लेख्नुहोस्' : 'Use the browser pad'} <span aria-hidden="true">↗</span></a>`}</div>
  </article>`).join('');
  const opening = embedded ? '<section id="downloads" class="downloads-page homepage-downloads container" aria-labelledby="downloads-title">' : '<main id="main" class="downloads-page container">';
  return `${opening}
    <div class="download-intro"><${titleTag} id="downloads-title">${downloadPage[locale].heading}</${titleTag}></div>
    <section class="download-grid" aria-label="${ne ? 'प्लेटफर्मअनुसार डाउनलोड' : 'Downloads by platform'}">${cards}</section>
    <a class="download-browser-link" href="${prefix}/#try" data-analytics-event="neptype_tool_cta_clicked" data-placement="download-browser" data-platform="web">${ne ? 'अनलाइन नेपाली लेख्नुहोस्' : 'Type Nepali online'} <span aria-hidden="true">→</span></a>
  </${embedded ? 'section' : 'main'}>`;
}
