# NepType website

The Graphite landing page keeps the product copy short and shows one actual Mac app screenshot. Supporting pages contain the FAQ, Mac setup, project details, privacy information, and development updates.

## Build and preview

From the repository root:

```sh
npm --prefix landing-page ci
npm --prefix landing-page test
npm --prefix landing-page run build
python3 -m http.server 4174 --bind 127.0.0.1 --directory landing-page/dist
```

Open `http://127.0.0.1:4174/`. The English homepage is `/`, with Nepali at `/ne/`. Each supporting page has an equivalent Nepali URL. All page content is present in the generated HTML, including when JavaScript is disabled.

`index.html` is the homepage template. `page-content.mjs` holds the supporting pages and Nepali copy. `build.mjs` generates the static site; `site.js` handles the mobile menu, platform-status dialogs, and word-choice/copy examples.

## Netlify continuous deployment

The repository-root `netlify.toml` sets:

- Production branch: `main` (configured in Netlify's Git integration).
- Base directory: `landing-page` (isolates website dependencies from the native apps).
- Build command: `node build.mjs`.
- Publish directory: `dist`, relative to that base.
- Node.js: 22.

The Netlify project is `neptype-app` in the PNW Devs team, linked to `anuphunt/nep-type`. Its public URL is `https://neptype-app.netlify.app/`, and its dashboard is `https://app.netlify.com/projects/neptype-app/overview`. Pushes to `main` trigger production builds. `.netlify/` and the generated `dist/` are ignored in Git.

Canonical URLs, Open Graph metadata, and the sitemap use Netlify's production `URL` environment variable. Set `SITE_URL` to the primary HTTPS origin if a custom domain needs to override it. Local builds and Netlify preview contexts generate `noindex` pages; production builds are indexable. `robots.txt` follows the same distinction. There is no catch-all SPA rewrite, so missing pages return a real 404.

Only production pages, styles, scripts, product images, and the browser dictionary are published. Design variations and review screenshots stay in the repository.

## Browser typing pad

The homepages include a working local transliterator with mixed Nepali/English and All Nepali modes, spelling choices, and clipboard copy. Input is held in memory and is never sent to a server. The dictionary is loaded as the pad approaches the viewport; typing then runs locally. Reloading requires a connection.

`web-engine.mjs` implements deterministic phonetic/context rules with the authored Nepali lexicon and CMU English membership data. It uses a smaller dictionary than the desktop app, so spelling suggestions can differ. The CMU license is published alongside that data. `web-tool.mjs` handles the editors and word choices. Run `npm --prefix landing-page test` for engine checks.

## Analytics

Set `PUBLIC_POSTHOG_KEY` and `PUBLIC_POSTHOG_HOST` in Netlify's build environment, or in a gitignored `landing-page/.env.local` for local production builds. These are the public project token and ingestion host, never a personal API key. Both must be set together. Analytics runs only on production builds and respects Do Not Track, Global Privacy Control, and the browser opt-out on the privacy page.

The [NepType website dashboard](https://us.posthog.com/project/329288/dashboard/2290502) uses dedicated `neptype_` events in the existing PostHog project. Automatic pageviews, autocapture, session recording, surveys, and feature-flag requests are disabled. Events include `neptype_pageview`, `neptype_tool_used`, `neptype_tool_output_copied`, `neptype_app_cta_clicked`, and `neptype_source_opened`. Only fixed mode, placement, platform, and entry-method values are attached; typing and output are never captured. Browser identity is stored locally for anonymous unique visitor counts. URL queries and fragments are stripped.

Add `?analytics_test=1` when checking the deployed site; these events are excluded from the dashboard. Counts represent browsers and clicks, not verified installations. Set `APP_DOWNLOAD_URL` to an actual HTTPS installer URL when one is published; only that link emits `neptype_download_clicked`.

## SEO and content

The build includes unique titles and descriptions, self-referencing canonical URLs, reciprocal English/Nepali `hreflang` links, social cards, `WebSite` and `SoftwareApplication` JSON-LD, and `sitemap.xml`. App markup uses actual product details without invented offers, reviews, or ratings. Search Console verification and sitemap submission require the production site and an authorized Google account.

The Mac page links to source build instructions; there is no public installer linked here. Other platform controls show development status.

The hero asset is copied from `evidence/neptype/prototype.png`. The Graphite colors come from `Sources/NepaliKeyboard/main.swift`. Original design references remain at `designs.html` and `concept.html` for local review. Layout reference: https://vikey.app/en/ (reviewed November 1, 2026).
