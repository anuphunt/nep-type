# NepType website

The Graphite landing page keeps the product copy short and shows one actual Mac app screenshot. The homepage leads with the free online typing pad. Supporting pages contain a bilingual typing guide, FAQ, Mac setup, project details, privacy information, and development updates.

## Build and preview

From the repository root:

```sh
npm --prefix landing-page ci
npm --prefix landing-page test
npm --prefix landing-page run build
python3 -m http.server 4174 --bind 127.0.0.1 --directory landing-page/dist
```

Open `http://127.0.0.1:4174/`. The English homepage is `/`, with Nepali at `/ne/`. Each supporting page has an equivalent Nepali URL. All page content is present in the generated HTML, including when JavaScript is disabled.

`index.html` is the homepage template. `page-content.mjs` holds the supporting pages and Nepali copy. `typing-guide.mjs` holds the guide, tested input/output examples, and homepage instructions. `build.mjs` generates the static site; `site.js` handles the mobile menu, platform-status dialogs, and word-choice/copy examples.

## Netlify continuous deployment

The repository-root `netlify.toml` sets:

- Production branch: `main` (configured in Netlify's Git integration).
- Base directory: `landing-page` (isolates website dependencies from the native apps).
- Build command: `npm test && node build.mjs` (engine and SEO checks must pass before publishing).
- Publish directory: `dist`, relative to that base.
- Node.js: 22.

The Netlify project is `neptype-app` in the PNW Devs team, linked to `anuphunt/nep-type`. Its primary public URL is `https://neptype.com/` (`www.neptype.com` redirects to the primary domain), and its dashboard is `https://app.netlify.com/projects/neptype-app/overview`. Pushes to `main` trigger production builds. `.netlify/` and the generated `dist/` are ignored in Git.

Canonical URLs, Open Graph metadata, and the sitemap default to `https://neptype.com`, independently of preview URLs. Set `SITE_URL` to override the public HTTPS canonical origin. Preview hostnames, credentials, paths, and localhost origins are rejected. Only an explicit `CONTEXT=production` build is indexable; setting `SITE_URL` alone does not enable indexing. Local and preview builds emit HTML `noindex` plus an `_headers` rule. Their robots.txt allows crawling so crawlers can read the noindex directive, and advertises no sitemap. Production robots.txt advertises the sitemap. For a local production audit, run `CONTEXT=production npm --prefix landing-page run build`. There is no catch-all SPA rewrite, so missing pages return a real 404.

Only production pages, styles, scripts, product images, and the browser dictionary are published. Design variations and review screenshots stay in the repository.

## Browser typing pad

The homepages include a working local transliterator with mixed Nepali/English and All Nepali modes, spelling choices, and clipboard copy. Use Option/Alt + the displayed number to choose a spelling while either editor has focus. Candidate pages use Previous/Next or Command/Control + Alt + brackets; original spelling stays available on every page. Command/Control + Z and Shift + Z undo/redo both typing and spelling choices. Input is held in memory and is never sent to a server. The full engine and dictionary load as the pad approaches the viewport, then typing runs locally. The engine is cached where browser storage is available; loading the website itself still requires a connection.

`web-engine.mjs` is a worker transport for the shared Rust WebAssembly engine. It embeds the identical full dictionary pack as every native app. The worker verifies the asset and dictionary fingerprints, caches the engine locally where supported, and keeps typing off the UI thread. All dictionary attributions are published alongside the engine. `web-tool.mjs` handles the editors and word choices. Run `npm --prefix landing-page test` for engine and generated-site checks. The SEO tests build production, preview, and local variants; run the build command afterward to select the variant you want to preview.

## Analytics

Set `PUBLIC_POSTHOG_KEY` and `PUBLIC_POSTHOG_HOST` in Netlify's build environment, or in a gitignored `landing-page/.env.local` for local production builds. These are the public project token and ingestion host, never a personal API key. Both must be set together. Analytics runs only on production builds and respects Do Not Track, Global Privacy Control, and the browser opt-out on the privacy page.

The [NepType website dashboard](https://us.posthog.com/project/329288/dashboard/2290502) uses dedicated `neptype_` events in the existing PostHog project. Automatic pageviews, autocapture, session recording, surveys, and feature-flag requests are disabled. Events include `neptype_pageview`, `neptype_tool_used`, `neptype_tool_output_copied`, `neptype_app_cta_clicked`, and `neptype_source_opened`. Only fixed mode, placement, platform, and entry-method values are attached; typing and output are never captured. Browser identity is stored locally for anonymous unique visitor counts. URL queries and fragments are stripped.

Add `?analytics_test=1` when checking the deployed site; these events are excluded from the dashboard. Counts represent browsers and clicks, not verified installations. Set `APP_DOWNLOAD_URL` to an actual HTTPS installer URL when one is published; only that link emits `neptype_download_clicked`.

## SEO and content

The build includes unique titles and descriptions, self-referencing canonical URLs, reciprocal English/Nepali `hreflang` links, social cards, page-specific JSON-LD, and `sitemap.xml`. Homepage markup describes the browser `WebApplication`; the Mac page describes the native `SoftwareApplication`. Supporting pages have breadcrumbs and the bilingual guide has `TechArticle` markup matching its visible project byline and publication date. App markup uses actual product details without invented offers, reviews, or ratings. Search Console verification and sitemap submission require the production site and an authorized Google account.

The Mac page links to source build instructions; there is no public installer linked here. Other platform controls show development status.

### Search intent and follow-up measurement

The November 1, 2026 audit found a working indexable site whose homepage metadata emphasized the Mac app despite a usable online pad. Search-result samples showed online tools for Roman-to-Nepali and English-to-Nepali typing, and setup/download intent for Mac queries. These are qualitative intent observations, not keyword-volume or difficulty measurements.

| Page | Primary intent | Supporting topics |
| --- | --- | --- |
| `/` and `/ne/` | Nepali typing online / अनलाइन नेपाली टाइपिङ | Roman to Nepali, Nepali Unicode typing, mixed English |
| `/typing-guide/` and `/ne/typing-guide/` | How to type Nepali with Roman letters | Spelling choices, shortcuts, typing versus translation, Unicode copy/paste |
| `/mac/` and `/ne/mac/` | Offline Nepali typing for Mac | Source setup, typing pad versus system input source |
| `/faq/` and `/ne/faq/` | Questions about NepType | Browser loading, privacy, drafts, platform availability |

Changes include browser-first homepage titles/headings/actions, original bilingual instructions and a guide with engine-verified examples, clearer offline/translation limits, contextual links, and page-specific structured data. Font stylesheets are discovered directly in HTML rather than through a CSS import; label contrast and icon dimensions are corrected. Metadata is not a guarantee of rich results. The native-app markup deliberately has no invented reviews, ratings, or offers.

After deployment, verify ownership of `neptype.com` in Google Search Console, submit `https://neptype.com/sitemap.xml`, and inspect the English/Nepali homepages and guides. Use an authorized owner account for these steps. Do not use the Google Indexing API for these ordinary pages or repeatedly request indexing. Compare 28-day periods for impressions, clicks, CTR, page/query coverage, and browser-pad usage/copy events. Search Console and PostHog measure different things: query-level conversions are not available by joining anonymous visitors. No ranking gains or field Core Web Vitals have been established by this release.

References: [Google helpful content](https://developers.google.com/search/docs/fundamentals/creating-helpful-content), [localized versions](https://developers.google.com/search/docs/specialty/international/localized-versions), and [spam policies](https://developers.google.com/search/docs/essentials/spam-policies).

### Proposed automations (not scheduled)

| Priority | Automation | Cadence | Output and boundaries |
| --- | --- | --- | --- |
| 1 | Search health monitor | Daily and after deploys | Check the live sitemap, canonical/indexability, alternate languages, HTTP errors, and browser typing flow. Alert on a new failure or meaningful change; stay quiet when unchanged. |
| 1 | Search Console opportunity report | Weekly, after owner access is connected | Compare pages/queries against the preceding 28 days, highlight substantial drops, high-impression/low-CTR pages, and relevant emerging queries. Suggest specific changes; use official exports/API rather than scraping rank results. |
| 2 | Useful article pipeline | Research/draft daily; publish at most one per day from an approved queue | Each article answers a distinct real typing question, includes original tested examples, honest platform claims, natural English/Nepali, source references where needed, related links, and a working tool CTA. Check for overlap with existing pages. Build and browser checks must pass. Skip publication when nothing meets the quality bar. Publish only after a publishing schedule and topic queue are approved. |
| 2 | Community question finder | Daily | Find recent Nepali typing questions on Reddit/X, check community rules and whether someone has already answered, and prepare a specific helpful reply. Disclose the maker relationship when recommending NepType. Track thread URLs to avoid repeated outreach. Drafts for review; no unsolicited automated comments, DMs, or repeated promotional links. |
| 2 | Original demo distribution | Two or three times a week | Turn an actual tip or release into a short screenshot/video and a platform-specific post on the owner's account. Link to the useful page where appropriate. Configure posting access and approve the schedule before publishing. |
| 3 | Content maintenance | Weekly | Recheck examples against the browser engine, fix stale setup instructions and broken links, identify overlapping pages, and improve contextual internal links. Update visible dates only for substantive revisions. |
| 3 | Performance regression monitor | Weekly and after deploys | Run repeatable mobile Lighthouse checks, examine Search Console/CrUX field data when available, and alert on material regressions. Keep lab scores distinct from real-user measurements. |
| 3 | Resource and partnership discovery | Weekly | Find relevant Nepali language, education, accessibility, and open-source resource lists. Prepare personalized suggestions backed by actual fit. Review before outreach; no paid-link schemes, bulk directory submissions, or automated messages. |

Initial article backlog: correcting ambiguous Nepali spellings; keeping English words in a Nepali paragraph; writing Nepali messages on a phone through the browser; troubleshooting copied Devanagari text; choosing between a browser pad and a native keyboard; offline Mac setup; and a worked privacy explanation of local transliteration. Consolidate topics into the existing guide when a separate page would add little value.

Daily publication is a maximum cadence, not a Google ranking signal. Automated article volume and repeated promotional replies can harm the project. See [Google's scaled-content policy](https://developers.google.com/search/docs/essentials/spam-policies#scaled-content), [Reddit's spam policy](https://support.reddithelp.com/hc/en-us/articles/360043504051-Spam), and [X automation rules](https://help.x.com/en/rules-and-policies/x-automation). Community activity should earn relevant readers and feedback; do not assume social links provide ranking credit.

The hero asset is copied from `evidence/neptype/prototype.png`. The Graphite colors come from `Sources/NepaliKeyboard/main.swift`. Original design references remain at `designs.html` and `concept.html` for local review. Layout reference: https://vikey.app/en/ (reviewed November 1, 2026).
