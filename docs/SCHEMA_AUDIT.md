# Structured data audit — 2026-11-10

Audited all 38 sitemap URLs on https://neptype.com in English and Nepali. Existing JSON-LD parsed on every page; the Schema.org validator reported no errors or warnings for the original homepage. The changes address completeness and entity relationships rather than JSON syntax errors.

- Browser, Mac and available Windows apps declare their free price with an Offer. Native download pages also state the free price visibly.
- Windows pages link their mainEntity to the Windows app, as the browser and Mac pages already did.
- Tutorials use Google's documented Article type with a distinct WebPage, linked through mainEntity/mainEntityOfPage. Original publication and revision dates are preserved.
- Article authors and publishers share the NepType project Organization identity, linked to the existing About page and site logo.
- WebPage nodes explicitly reference their breadcrumb trails.

The website tests check every sitemap page for unique entity IDs, resolved graph references, sequential breadcrumbs, article/page relationships, free prices and visible download links. No ratings or reviews are invented.

## Remaining search appearance limitations

Google requires a genuine rating or review for software app rich results. NepType currently has neither, so its valid software schema is not eligible for that feature. Article images are optional; no generic logo is substituted for a relevant editorial image. Rich results and indexing are not guaranteed.

References:
- https://developers.google.com/search/docs/appearance/structured-data/software-app
- https://developers.google.com/search/docs/appearance/structured-data/article
- https://developers.google.com/search/docs/appearance/structured-data/breadcrumb
- https://validator.schema.org/
