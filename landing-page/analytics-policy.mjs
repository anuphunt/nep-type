export const consentKey = 'neptype-analytics-consent-v1';
export const legacyOptOutKey = 'neptype-analytics-opt-out';
export function readConsent(storage) {
  try {
    if (storage.getItem(legacyOptOutKey) === 'true') return 'denied';
    const value = storage.getItem(consentKey);
    return ['granted','denied'].includes(value) ? value : 'unset';
  } catch { return 'unset'; }
}
// Only generated public paths; never an arbitrary user-provided path/query/hash.
export function analyticsPage(href, paths) {
  try { const url = new URL(href); return 'https://neptype.com' + (paths.includes(url.pathname) ? url.pathname : '/404/'); }
  catch { return 'https://neptype.com/404/'; }
}
// Preserve reviewed search-engine origins, without search terms or other paths.
export function analyticsReferrer(referrer) {
  try {
    const url = new URL(referrer), host = url.hostname.replace(/^www\./, '');
    const origins = new Set(['google.com','google.com.np','google.co.uk','google.com.au','google.co.in','bing.com','duckduckgo.com','search.yahoo.com','search.brave.com','ecosia.org']);
    return ['http:','https:'].includes(url.protocol) && origins.has(host) ? 'https://' + host + '/' : '';
  } catch { return ''; }
}
export const safeEvents = new Set(['neptype_pageview','neptype_app_cta_clicked','neptype_download_clicked','neptype_source_opened','neptype_tool_cta_clicked','neptype_tool_used','neptype_tool_word_selected','neptype_tool_mode_changed','neptype_tool_output_copied']);
const values = {
  mode:new Set(['mixed','all']), entry_method:new Set(['typing','paste','example']),
  placement:new Set(['navigation','hero','page','mac','windows','download','articles','faq','typing-guide','footer','other-platforms']),
  platform:new Set(['web','macOS','Windows','iOS','Android','Linux','unknown'])
};
export function coarseProperties(input = {}) {
  if (!input || typeof input !== 'object') return {};
  return Object.fromEntries(Object.entries(values).filter(([name, allowed]) => allowed.has(input[name])).map(([name]) => [name,input[name]]));
}
