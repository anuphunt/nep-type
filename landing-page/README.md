# NepType landing-page directions

Three responsive, buildless design previews. Run from this directory:

```sh
python3 -m http.server 4173 --bind 127.0.0.1
```

Open `http://127.0.0.1:4173/` for the comparison gallery. Each direction has a full page, a design switcher, mobile navigation, FAQ and platform dialogs, a language preview, selectable word suggestions, and a copy example.

- **Graphite**: the app's exact palette, dark surfaces and native window styling.
- **Silver**: a light inversion of the same neutral palette with dark product windows.
- **Editorial**: silver hero, Graphite framing, serif type and crisp feature-grid borders.

All preserve the reference's sequence: navigation → split hero with overlapping product windows → platform links → five-card feature grid → multi-column footer. Layout reference: https://vikey.app/en/ (reviewed November 1, 2026). Product copy and branding are NepType's, based on the repository. Product windows are HTML illustrations, not app screenshots. They show fixed examples; the landing page does not run the transliteration engine. The word-choice interaction is an illustrative example.

Colors from `Sources/NepaliKeyboard/main.swift`: background `#1e1e1e`, surface `#272727`, ink `#e8e8e8`, secondary `#aaaaaa`, accent `#d7d7d7`, accent ink `#222222`, line `#3d3d3d`. Additional neutral shades support each direction. The original app icon is copied from the iOS asset catalog.

The pages are design previews, not a distribution channel. Platform controls explain actual development status instead of offering nonexistent installers. GitHub links point to the configured project remote. Primary text has an English/Nepali preview toggle; secondary navigation, dialogs, and illustrative app chrome remain in English. Google Fonts provides DM Sans, Noto Sans Devanagari and Playfair Display with system fallbacks. No application files are changed and no site is published.
