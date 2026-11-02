# NepType landing page

The selected Graphite landing page is `index.html`. It uses the app's palette, one actual Mac screenshot, and short product copy edited with the humanizer skill. Run from this directory:

```sh
python3 -m http.server 4173 --bind 127.0.0.1
```

Open `http://127.0.0.1:4173/` for the final page. It has mobile navigation, FAQ and platform dialogs, an English/Nepali copy toggle, selectable word suggestions, and a copy example. `site.js` owns its interactions and copy, with `final.css` refining the shared `styles.css`.

Earlier design directions remain at `designs.html` and `concept.html`:

- **Graphite**: the app's exact palette, dark surfaces and native window styling.
- **Silver**: a light inversion of the same neutral palette with dark product windows.
- **Editorial**: silver hero, Graphite framing, serif type and crisp feature-grid borders.

The final page preserves the reference's sequence: navigation → split hero → platform links → five-card feature grid → multi-column footer. Layout reference: https://vikey.app/en/ (reviewed November 1, 2026). The hero uses `assets/neptype-mac.png`, copied from the current app evidence at `evidence/neptype/prototype.png`. The earlier concepts retain their HTML illustrations. The word-choice interaction is an illustrative example; the landing page does not run the transliteration engine.

Colors from `Sources/NepaliKeyboard/main.swift`: background `#1e1e1e`, surface `#272727`, ink `#e8e8e8`, secondary `#aaaaaa`, accent `#d7d7d7`, accent ink `#222222`, line `#3d3d3d`. Additional neutral shades support each direction. The approved blue NT icon is exported from `branding/assets/neptype-icon-master.png` by `scripts/export-brand-assets.py`; native app icons and these previews share the same artwork.

Platform controls explain development status and link to the repository. There are no public installers linked here. Primary copy has an English/Nepali toggle; navigation and dialogs remain in English. Shared styles load DM Sans, Noto Sans Devanagari and Playfair Display from Google Fonts, with system fallbacks. No application files are changed and no site is published.
