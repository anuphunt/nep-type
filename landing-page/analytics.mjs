import posthog from 'posthog-js';

const key = __POSTHOG_KEY__;
const host = __POSTHOG_HOST__;
const production = __PRODUCTION__;
const safeEvents = new Set(['neptype_pageview','neptype_app_cta_clicked','neptype_download_clicked','neptype_source_opened','neptype_tool_cta_clicked','neptype_tool_used','neptype_tool_word_selected','neptype_tool_mode_changed','neptype_tool_output_copied']);
const safeProperties = new Set(['mode','entry_method','placement','platform']);
const test = new URLSearchParams(location.search).get('analytics_test') === '1';
const optOutKey = 'neptype-analytics-opt-out';
function isOptedOut() {
  try { return localStorage.getItem(optOutKey) === 'true'; } catch { return false; }
}
const privacySignal = navigator.doNotTrack === '1' || navigator.globalPrivacyControl === true;
let ready = false;
if (production && key && host && !privacySignal && !isOptedOut()) {
  posthog.init(key, {
    api_host: host,
    autocapture: false,
    capture_pageview: false,
    capture_pageleave: false,
    capture_dead_clicks: false,
    capture_performance: false,
    disable_session_recording: true,
    disable_surveys: true,
    advanced_disable_flags: true,
    person_profiles: 'identified_only',
    persistence: 'localStorage',
    respect_dnt: true,
    ip: false,
    before_send(event) {
      if (!event || !safeEvents.has(event.event)) return null;
      // No tool input, output, selected words, URL query strings, or fragments.
      event.properties.$current_url = location.origin + location.pathname;
      for (const property of ['$initial_current_url','$referrer','$initial_referrer']) {
        const value = event.properties[property];
        if (typeof value === 'string' && value.startsWith('http')) {
          try { const url = new URL(value); event.properties[property] = url.origin + url.pathname; } catch { delete event.properties[property]; }
        }
      }
      delete event.properties.$set;
      delete event.properties.$set_once;
      return event;
    }
  });
  ready = true;
}
function capture(event, values = {}) {
  if (!ready || !safeEvents.has(event) || isOptedOut()) return;
  const properties = {app: 'neptype', language: document.documentElement.lang, is_test: test};
  for (const [name, value] of Object.entries(values)) if (safeProperties.has(name) && typeof value === 'string') properties[name] = value;
  posthog.capture(event, properties, {transport: 'sendBeacon', send_instantly: true});
}
window.NepTypeAnalytics = {capture};
capture('neptype_pageview');
document.addEventListener('click', event => {
  const link = event.target.closest('a[data-analytics-event]');
  if (link) capture(link.dataset.analyticsEvent, {placement: link.dataset.placement || 'page', platform: link.dataset.platform || 'macOS'});
});
const toggle = document.getElementById('analytics-toggle');
function updateToggle() {
  if (!toggle) return;
  const disabled = isOptedOut() || privacySignal || !key;
  toggle.textContent = document.documentElement.lang === 'ne' ? (disabled ? 'एनालिटिक्स बन्द छ' : 'यो ब्राउजरमा एनालिटिक्स बन्द गर्नुहोस्') : (disabled ? 'Analytics is off in this browser' : 'Turn off analytics in this browser');
  toggle.disabled = disabled;
}
toggle?.addEventListener('click', () => {
  try { localStorage.setItem(optOutKey, 'true'); } catch { /* The SDK opt-out still applies in memory. */ }
  if (ready) posthog.opt_out_capturing();
  ready = false; updateToggle();
});
updateToggle();
