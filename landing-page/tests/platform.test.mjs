import test from 'node:test';
import assert from 'node:assert/strict';
import {detectPlatform, downloadAction} from '../platform.mjs';
import {renderDownloadPage, renderHomeDownloads} from '../download-page.mjs';

test('device detection handles desktop, mobile, reduced UA and iPad desktop mode', () => {
  const fixtures = [
    [{userAgent:'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}, 'Windows'],
    [{userAgent:'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'}, 'macOS'],
    [{userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)'}, 'iOS'],
    [{userAgent:'Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X)'}, 'iOS'],
    [{userAgent:'Mozilla/5.0 (Macintosh; Intel Mac OS X)', platform:'MacIntel', maxTouchPoints:5}, 'iOS'],
    [{userAgent:'Mozilla/5.0 (Linux; Android 14; Pixel 9)', platform:'Linux armv8l'}, 'Android'],
    [{userAgent:'Mozilla/5.0 (X11; Linux x86_64)'}, 'Linux'],
    [{userAgent:'Mozilla/5.0 (X11; CrOS x86_64)'}, 'Linux'],
    [{userAgent:'Mozilla/5.0', userAgentData:{platform:'Windows'}}, 'Windows'],
    [{platform:'Win32'}, 'Windows'],
    [{}, 'unknown'], [{userAgent:'Mozilla/5.0 (FreeBSD)'}, 'unknown']
  ];
  for (const [device, expected] of fixtures) assert.equal(detectPlatform(device), expected, JSON.stringify(device));
});

test('primary actions keep verified release URLs, honest Windows copy and localized fallbacks', () => {
  const releases = {mac:'https://example.com/neptype.dmg', windows:'https://example.com/neptype.exe'};
  for (const locale of ['en','ne']) {
    for (const [platform,key] of [['macOS','mac'], ['Windows','windows']]) {
      const action = downloadAction(platform, locale, releases);
      assert.equal(action.href, releases[key]);
      assert.equal(action.event, 'neptype_download_clicked');
      assert.equal(action.platform, platform);
    }
    const prefix = locale === 'ne' ? '/ne' : '';
    for (const platform of ['iOS','Android','Linux']) {
      const action = downloadAction(platform, locale, releases);
      assert.equal(action.href, prefix + '/#try');
      assert.equal(action.event, 'neptype_tool_cta_clicked');
    }
    for (const platform of ['unknown', 'Windows', 'macOS']) {
      const action = downloadAction(platform, locale, {});
      assert.equal(action.href, prefix + '/download/');
      assert.equal(action.event, 'neptype_app_cta_clicked');
    }
  }
  assert.match(downloadAction('Windows','en',releases).note, /Windows 10 or 11/);
});

test('all-platform cards expose only available installers; pending Windows remains gated', () => {
  const escape = text => String(text).replaceAll('&','&amp;').replaceAll('"','&quot;');
  for (const locale of ['en','ne']) {
    for (const windows of [undefined,'https://example.com/verified.exe']) {
      const html = renderDownloadPage(locale, {mac:'https://example.com/app.dmg',windows,macVersion:'1.0',windowsVersion:'1.0-preview.1'}, escape);
      assert.equal([...html.matchAll(/data-platform-card=/g)].length, 5);
      assert.equal([...html.matchAll(/class="button platform-download"/g)].length, windows ? 2 : 1);
      assert.ok(!html.includes('href="undefined"'));
      assert.ok(!html.includes('<button'));
      for (const platform of ['iOS','Android','Linux']) {
        const card = html.match(new RegExp(`<article[^>]*data-platform-card="${platform}"[\\s\\S]*?</article>`))[0];
        assert.ok(!card.includes('neptype_download_clicked'));
        assert.match(card, /class="coming-soon"/);
        assert.ok(card.includes(platform === 'iOS'
          ? (locale === 'ne' ? 'Apple को समीक्षामा' : 'Under Apple review')
          : (locale === 'ne' ? 'छिट्टै आउँदैछ' : 'Coming soon')));
        assert.ok(card.includes(`href="${locale === 'ne' ? '/ne' : ''}/#try"`));
      }
    }
  }
});

test('homepage embeds the complete download component with a valid heading hierarchy', () => {
  const escape = text => String(text).replaceAll('&','&amp;').replaceAll('"','&quot;');
  for (const locale of ['en','ne']) {
    const releases = {mac:'https://example.com/app.dmg', windows:'https://example.com/app.exe'};
    const page = renderDownloadPage(locale,releases,escape);
    const home = renderHomeDownloads(locale,releases,escape);
    assert.equal([...home.matchAll(/data-platform-card=/g)].length,5);
    assert.equal([...home.matchAll(/class="button platform-download"/g)].length,2);
    assert.match(home, /<section id="downloads"/);
    assert.match(home, /<h2 id="downloads-title">/);
    assert.equal([...home.matchAll(/<h3 id="platform-/g)].length,5);
    assert.ok(!home.includes('<main') && !home.includes('<h1'));
    assert.match(page, /<main id="main"/);
    assert.match(page, /<h1 id="downloads-title">/);
    const links = html => [...html.matchAll(/href="([^"]+)"/g)].map(match=>match[1]);
    assert.deepEqual(links(home),links(page),'homepage and downloads page use the same verified destinations');
  }
});
