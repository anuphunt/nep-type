# NepType website

The Graphite landing page keeps the product copy short and shows one actual Mac app screenshot. The homepage offers one device-specific download button, a small link to all platforms, and the free online typing pad. Supporting pages contain a bilingual typing guide, FAQ, Mac setup, project details, privacy information, and development updates.

## Build and preview

From the repository root:

```sh
npm --prefix landing-page ci
npm --prefix landing-page test
npm --prefix landing-page run build
python3 -m http.server 4174 --bind 127.0.0.1 --directory landing-page/dist
```

Open `http://127.0.0.1:4174/`. The English homepage is `/`, with Nepali at `/ne/`. Each supporting page has an equivalent Nepali URL. The all-platform download page is `/download/`, with Nepali at `/ne/download/`. All page content is present in the generated HTML, including when JavaScript is disabled.

`index.html` is the homepage template. `page-content.mjs` holds the supporting pages and Nepali copy. `typing-guide.mjs` holds the guide, tested input/output examples, and homepage instructions. `download-page.mjs` renders the platform cards and `platform.mjs` handles device detection. `build.mjs` generates the static site; `site.js` handles the mobile menu, platform-status dialogs, and word-choice/copy examples.

## Netlify continuous deployment

The repository-root `netlify.toml` sets:

- Production branch: `main` (configured in Netlify's Git integration).
- Base directory: `landing-page` (isolates website dependencies from the native apps).
- Build command: `npm test && node build.mjs` (engine and SEO checks must pass before publishing).
- Publish directory: `dist`, relative to that base.
- Node.js: 22.

The Netlify project is `neptype-app` in the PNW Devs team, linked to `anuphunt/nep-type`. Its primary public URL is `https://neptype.com/` (`www.neptype.com` redirects to the primary domain), and its dashboard is `https://app.netlify.com/projects/neptype-app/overview`. Pushes to `main` trigger production builds. `.netlify/` and the generated `dist/` are ignored in Git.

Canonical URLs, Open Graph metadata, and the sitemap default to `https://neptype.com`, independently of preview URLs. Set `SITE_URL` to override the public HTTPS canonical origin. Preview hostnames, credentials, paths, and localhost origins are rejected. Only an explicit `CONTEXT=production` build is indexable; setting `SITE_URL` alone does not enable indexing. Local and preview builds emit HTML `noindex` plus an `_headers` rule. Their robots.txt allows crawling so crawlers can read the noindex directive, and advertises no sitemap. Production robots.txt advertises the sitemap. For a local production audit, run `CONTEXT=production npm --prefix landing-page run build`. There is no catch-all SPA rewrite, so missing pages return a real 404.

Only production pages, styles, scripts, product images, licensed fonts, and the browser dictionary are published. `fonts.css` defines the local variable font subsets; source URLs and SIL Open Font License texts are included in `assets/fonts/`. Design variations and review screenshots stay in the repository.

## Browser typing pad

The homepages include a working local transliterator with mixed Nepali/English and All Nepali modes, spelling choices, and clipboard copy. Use Option/Alt + the displayed number to choose a spelling while either editor has focus. Candidate pages use Previous/Next or Command/Control + Alt + brackets; original spelling stays available on every page. Command/Control + Z and Shift + Z undo/redo both typing and spelling choices. Input is held in memory and is never sent to a server. The full engine and dictionary load as the pad approaches the viewport, then typing runs locally. The engine is cached where browser storage is available; loading the website itself still requires a connection.

`web-engine.mjs` is a worker transport for the shared Rust WebAssembly engine. It embeds the identical full dictionary pack as every native app. The worker verifies the asset and dictionary fingerprints, caches the engine locally where supported, and keeps typing off the UI thread. All dictionary attributions are published alongside the engine. `web-tool.mjs` handles the editors and word choices. Run `npm --prefix landing-page test` for engine and generated-site checks. The SEO tests build production, preview, and local variants; run the build command afterward to select the variant you want to preview.

## Analytics

Set `PUBLIC_POSTHOG_KEY` and `PUBLIC_POSTHOG_HOST` in Netlify's build environment, or in a gitignored `landing-page/.env.local` for local production builds. These are the public project token and ingestion host, never a personal API key. Both must be set together. Analytics runs only on production builds and respects Do Not Track, Global Privacy Control, and the browser opt-out on the privacy page.

The [NepType website dashboard](https://us.posthog.com/project/329288/dashboard/2290502) uses dedicated `neptype_` events in the existing PostHog project. Automatic pageviews, autocapture, session recording, surveys, and feature-flag requests are disabled. Events include `neptype_pageview`, `neptype_tool_used`, `neptype_tool_output_copied`, `neptype_app_cta_clicked`, and `neptype_source_opened`. Only fixed mode, placement, platform, and entry-method values are attached; typing and output are never captured. Browser identity is stored locally for anonymous unique visitor counts. URL queries and fragments are stripped.

Add `?analytics_test=1` when checking the deployed site; these events are excluded from the dashboard. Counts represent browsers and clicks, not verified installations. `mac-release.json` selects the verified Mac DMG. `APP_DOWNLOAD_URL` can override its HTTPS URL. The homepage download and Mac page button emit `neptype_download_clicked`.

## SEO and content

The build includes unique titles and descriptions, self-referencing canonical URLs, reciprocal English/Nepali `hreflang` links, social cards, page-specific JSON-LD, and `sitemap.xml`. Homepage markup describes the browser `WebApplication`; the Mac page describes the native `SoftwareApplication`. Supporting pages have breadcrumbs and the bilingual guide has `TechArticle` markup matching its visible project byline and publication date. App markup uses actual product details without invented offers, reviews, or ratings. Search Console verification and sitemap submission require the production site and an authorized Google account.

The Mac page offers the signed, notarized universal DMG and drag-to-Applications instructions, with source builds as an alternative. The all-platform page also lists the unsigned Windows preview and marks iPhone and Linux as coming soon.

### Download page and device detection

`/download/` and `/ne/download/` show Mac, Windows, iPhone, and Linux cards. Mac and Windows use the existing release metadata; iPhone and Linux have coming-soon labels and browser-pad links without fake download controls. Both setup pages remain available.

`platform.mjs` selects the Mac or Windows installer when available, checking iPad desktop mode before Mac. iPhone, iPad, Android, Linux, and ChromeOS visitors get the browser pad. Unknown devices and browsers without JavaScript get the all-platform page. Detection is a convenience; the all-platform link and footer remain available.

`windows-release.mjs` exposes the Windows installer only when `windows-release.json` has verified preview metadata. The homepage, platform card, and setup page disclose that the Windows preview is unsigned. No installer link or download schema is emitted for a pending release. Follow [the Windows release runbook](../docs/WINDOWS_RELEASE.md).

After building, verify the download experience with installed Google Chrome:

```sh
npm --prefix landing-page run downloads:verify-browser
# Also re-download both public installers and check their size and SHA-256, without executing them:
npm --prefix landing-page run downloads:verify-browser -- --verify-downloads
# Optional WCAG A/AA audit using an existing axe-core installation:
AXE_CORE_PATH=/path/to/axe-core/axe.min.js npm --prefix landing-page run downloads:verify-browser
```

The check covers both languages at 320, 390, 768, 1024, and 1440 pixels, eight device profiles, coming-soon states, setup links, keyboard access, mobile menus, no-JavaScript fallback, and the browser engine/clipboard. Screenshots and a JSON report go to the ignored `landing-page/reports/downloads/` directory.

### Mac download releases

Run `bash scripts/package-mac.sh` from the repository root with `NEPTYPE_MAC_SIGNING_IDENTITY` set to an existing Developer ID Application identity and `NEPTYPE_MAC_NOTARY_PROFILE` set to an existing notarytool Keychain profile. `NEPTYPE_MAC_VERSION` and `NEPTYPE_MAC_BUILD` default to 0.1.0 and 1. The script builds both macOS 13 architectures, signs and notarizes the app, creates a DMG with an Applications shortcut, then signs, notarizes, staples and verifies the DMG. It does not create credentials or change Keychain permissions.

Keep signed app staging in the temporary directory, outside synced folders. The release folder under `build/releases/` includes the DMG, checksum, notarization results and release manifest. Check the mounted app and drag/copy installation before publishing the immutable DMG and checksum as GitHub release assets. Re-download and compare the published SHA-256 before changing `mac-release.json`. Installer binaries stay out of Git.

### Search intent and follow-up measurement

The November 1, 2026 audit found a working indexable site whose homepage metadata emphasized the Mac app despite a usable online pad. Search-result samples showed online tools for Roman-to-Nepali and English-to-Nepali typing, and setup/download intent for Mac queries. These are qualitative intent observations, not keyword-volume or difficulty measurements.

| Page | Primary intent | Supporting topics |
| --- | --- | --- |
| `/` and `/ne/` | Nepali typing online / अनलाइन नेपाली टाइपिङ | Roman to Nepali, Nepali Unicode typing, mixed English |
| `/typing-guide/` and `/ne/typing-guide/` | How to type Nepali with Roman letters | Spelling choices, shortcuts, typing versus translation, Unicode copy/paste |
| `/mac/` and `/ne/mac/` | Offline Nepali typing for Mac | Source setup, typing pad versus system input source |
| `/faq/` and `/ne/faq/` | Questions about NepType | Browser loading, privacy, drafts, platform availability |

Changes include browser-first homepage titles/headings/actions, original bilingual instructions and a guide with engine-verified examples, clearer offline/translation limits, contextual links, and page-specific structured data. Licensed variable fonts are hosted with the website, with a locale-specific font preload and no Google Fonts stylesheet/connection chain; label contrast and icon dimensions are corrected. Metadata is not a guarantee of rich results. The native-app markup deliberately has no invented reviews, ratings, or offers.

After deployment, verify ownership of `neptype.com` in Google Search Console, submit `https://neptype.com/sitemap.xml`, and inspect the English/Nepali homepages and guides. Use an authorized owner account for these steps. Do not use the Google Indexing API for these ordinary pages or repeatedly request indexing. Compare 28-day periods for impressions, clicks, CTR, page/query coverage, and browser-pad usage/copy events. Search Console and PostHog measure different things: query-level conversions are not available by joining anonymous visitors. No ranking gains or field Core Web Vitals have been established by this release.

References: [Google helpful content](https://developers.google.com/search/docs/fundamentals/creating-helpful-content), [localized versions](https://developers.google.com/search/docs/specialty/international/localized-versions), and [spam policies](https://developers.google.com/search/docs/essentials/spam-policies).

### Automations

| Priority | Automation | Cadence | Output and boundaries |
| --- | --- | --- | --- |
| 1 | Search health monitor | Daily and after deploys | Check the live sitemap, canonical/indexability, alternate languages, HTTP errors, and browser typing flow. Alert on a new failure or meaningful change; stay quiet when unchanged. |
| 1 | Search Console opportunity report | Weekly, after owner access is connected | Compare pages/queries against the preceding 28 days, highlight substantial drops, high-impression/low-CTR pages, and relevant emerging queries. Suggest specific changes; use official exports/API rather than scraping rank results. |
| 2 | Useful article pipeline | Daily at 9:00 a.m. Pacific; at most one article pair per day | Authorized automatic publishing with original bilingual content, source evidence, overlap review, executable engine examples, and browser/SEO checks. See [the publishing runbook](content/README.md). All other automations in this table remain proposals. |
| 2 | Community question finder | Daily | Find recent Nepali typing questions on Reddit/X, check community rules and whether someone has already answered, and prepare a specific helpful reply. Disclose the maker relationship when recommending NepType. Track thread URLs to avoid repeated outreach. Drafts for review; no unsolicited automated comments, DMs, or repeated promotional links. |
| 2 | Original demo distribution | Two or three times a week | Turn an actual tip or release into a short screenshot/video and a platform-specific post on the owner's account. Link to the useful page where appropriate. Configure posting access and approve the schedule before publishing. |
| 3 | Content maintenance | Weekly | Recheck examples against the browser engine, fix stale setup instructions and broken links, identify overlapping pages, and improve contextual internal links. Update visible dates only for substantive revisions. |
| 3 | Performance regression monitor | Weekly and after deploys | Run repeatable mobile Lighthouse checks, examine Search Console/CrUX field data when available, and alert on material regressions. Keep lab scores distinct from real-user measurements. |
| 3 | Resource and partnership discovery | Weekly | Find relevant Nepali language, education, accessibility, and open-source resource lists. Prepare personalized suggestions backed by actual fit. Review before outreach; no paid-link schemes, bulk directory submissions, or automated messages. |

Initial article backlog (the active queue is `content/topic-queue.json`): correcting ambiguous Nepali spellings; keeping English words in a Nepali paragraph; writing Nepali messages on a phone through the browser; troubleshooting copied Devanagari text; choosing between a browser pad and a native keyboard; offline Mac setup; and a worked privacy explanation of local transliteration. Consolidate topics into the existing guide when a separate page would add little value.

Daily publication is a maximum cadence, not a Google ranking signal. Automated article volume and repeated promotional replies can harm the project. See [Google's scaled-content policy](https://developers.google.com/search/docs/essentials/spam-policies#scaled-content), [Reddit's spam policy](https://support.reddithelp.com/hc/en-us/articles/360043504051-Spam), and [X automation rules](https://help.x.com/en/rules-and-policies/x-automation). Community activity should earn relevant readers and feedback; do not assume social links provide ranking credit.

The hero asset is copied from `evidence/neptype/prototype.png`. The Graphite colors come from `Sources/NepaliKeyboard/main.swift`. Original design references remain at `designs.html` and `concept.html` for local review. Layout reference: https://vikey.app/en/ (reviewed November 1, 2026).

### Article authoring and verification

Article JSON lives in `content/articles/`. Run `npm --prefix landing-page run articles:next` to inspect the daily publication guard and next unused candidate. The build generates localized article pages, the article library, feeds and sitemap entries. `npm --prefix landing-page run articles:verify-browser` serves the built site on a temporary local port and verifies the latest article pair, mobile layouts and the typing/copy destination using installed Chrome. Add `-- --base-url=https://neptype.com` to verify the live site. Screenshots and results are saved under ignored `reports/articles/`. Run the normal tests and production build first. The detailed recurring workflow and publishing authorization are in [content/README.md](content/README.md).
