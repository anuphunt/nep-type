# NepType website

The Graphite landing page keeps the product copy short and shows one actual Mac app screenshot. Supporting pages contain the FAQ, Mac setup, project details, privacy information, and development updates.

## Build and preview

No package installation is required. From the repository root:

```sh
node landing-page/build.mjs
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

Only the final pages, styles, script, and two product assets are copied to the publish directory. Design variations, screenshots used for review, source files, and app code are not published.

## SEO and content

The build includes unique titles and descriptions, self-referencing canonical URLs, reciprocal English/Nepali `hreflang` links, social cards, `WebSite` and `SoftwareApplication` JSON-LD, and `sitemap.xml`. App markup uses actual product details without invented offers, reviews, or ratings. Search Console verification and sitemap submission require the production site and an authorized Google account.

The Mac page links to source build instructions; there is no public installer linked here. Other platform controls show development status. The illustrative word-choice interaction does not run the transliteration engine.

The hero asset is copied from `evidence/neptype/prototype.png`. The Graphite colors come from `Sources/NepaliKeyboard/main.swift`. Original design references remain at `designs.html` and `concept.html` for local review. Layout reference: https://vikey.app/en/ (reviewed November 1, 2026).
