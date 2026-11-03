// Best-effort presentation only. Every platform remains available on /download/.
export function detectPlatform(device = {}) {
  const ua = device.userAgent || '';
  const platform = device.userAgentData?.platform || device.platform || '';
  // iPadOS can identify as a desktop Mac; check touch before macOS.
  if (/iPhone|iPad|iPod/i.test(ua) || (/Mac/i.test(platform || ua) && device.maxTouchPoints > 1)) return 'iOS';
  if (/Android/i.test(ua + ' ' + platform)) return 'Android';
  if (/Windows|Win32|Win64/i.test(platform + ' ' + ua)) return 'Windows';
  if (/Mac/i.test(platform + ' ' + ua)) return 'macOS';
  if (/Linux|CrOS/i.test(platform + ' ' + ua)) return 'Linux';
  return 'unknown';
}

export function downloadAction(platform, locale, releases) {
  const ne = locale === 'ne';
  const prefix = ne ? '/ne' : '';
  if (platform === 'macOS' && releases.mac) return {
    href: releases.mac, label: ne ? 'Mac का लागि डाउनलोड गर्नुहोस्' : 'Download for Mac',
    event: 'neptype_download_clicked', platform, note: ne ? 'macOS 13 वा पछिल्लो · Apple silicon र Intel' : 'macOS 13 or later · Apple silicon & Intel'
  };
  if (platform === 'Windows' && releases.windows) return {
    href: releases.windows, label: ne ? 'Windows का लागि डाउनलोड गर्नुहोस्' : 'Download for Windows',
    event: 'neptype_download_clicked', platform,
    note: ne ? 'Windows 10 वा 11 · Intel वा AMD x64' : 'Windows 10 or 11 · Intel or AMD x64'
  };
  if (['iOS', 'Android', 'Linux'].includes(platform)) return {
    href: prefix + '/#try', label: ne ? 'अनलाइन नेपाली लेख्नुहोस्' : 'Type Nepali online',
    event: 'neptype_tool_cta_clicked', platform,
    note: ne ? 'यो उपकरणको एप आउँदैछ। अहिले ब्राउजरमा लेख्नुहोस्।' : 'The app for your device is coming soon. Try it in your browser.'
  };
  return {href: prefix + '/download/', label: ne ? 'NepType लिनुहोस्' : 'Get NepType', event: 'neptype_app_cta_clicked', platform: 'unknown', note: ne ? 'Mac र Windows एप उपलब्ध छन्।' : 'Available for Mac and Windows.'};
}

export function configureDownloads(document, device) {
  const platform = detectPlatform(device);
  const first = document.querySelector('[data-device-download]');
  if (first) {
    const action = downloadAction(platform, document.documentElement.lang, {mac:first.dataset.macUrl, windows:first.dataset.windowsUrl});
    document.querySelectorAll('[data-device-download]').forEach(link => {
      link.href = action.href;
      link.textContent = action.label;
      link.dataset.analyticsEvent = action.event;
      link.dataset.platform = action.platform;
    });
    document.querySelectorAll('[data-online-alternative]').forEach(link => { link.hidden = action.event === 'neptype_tool_cta_clicked'; });
    document.querySelectorAll('[data-device-note]').forEach(note => { note.textContent = action.note; });
  }
  document.querySelectorAll('[data-platform-card]').forEach(card => {
    const current = card.dataset.platformCard === platform;
    card.classList.toggle('is-current', current);
    const badge = card.querySelector('[data-current-device]');
    if (badge) badge.hidden = !current;
  });
}
