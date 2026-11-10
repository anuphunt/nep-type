# Structured data audit — 2026-11-10

Audited all 38 sitemap URLs on https://neptype.com in English and Nepali. Existing JSON-LD parsed on every page; the Schema.org validator reported no errors or warnings for the original homepage. The changes address completeness and entity relationships rather than JSON syntax errors.

- Browser, Mac and available Windows apps declare their free price with an Offer. Native download pages also state the free price visibly.
- Windows pages link their mainEntity to the Windows app, as the browser and Mac pages already did.
- Tutorials use Google's documented Article type with a distinct WebPage, linked through mainEntity/mainEntityOfPage. Original publication and revision dates are preserved.
- Article authors and publishers share the NepType project Organization identity, linked to the existing About page and site logo.
- WebPage nodes explicitly reference their breadcrumb trails.

The website tests check every sitemap page for unique entity IDs, resolved graph references, sequential breadcrumbs, article/page relationships, free prices and visible download links. No ratings or reviews are invented.

## Remaining search appearance limitations

Google's documentation lists a rating or review as required, but the live Rich Results Test on 2026-11-10 reported the homepage software app as valid and classified its missing aggregateRating as optional. No real rating data is available, so the warning is retained. A missing optional currency warning was resolved by explicitly specifying USD for the zero-price offers.

The live article test reported a valid Article and BreadcrumbList. Optional article warnings remain for missing editorial images and date-only publication/revision values (datetime/timezone recommendations). Content records store calendar days, not verified publication times; these dates remain accurate rather than fabricating precision. No generic logo is substituted for an editorial image. Rich results and indexing are not guaranteed.

## Verification

All 29 website tests passed. A fresh crawl confirmed all 38 live pages matched the tested schema and allowed indexing. Schema.org validation of the deployed homepage and Windows page returned zero errors and warnings. Google tests:
- Article and breadcrumb: https://search.google.com/test/rich-results/result?id=oscXty5hQKF2bZZW2fr0tg
- Browser app: https://search.google.com/test/rich-results/result?id=bZzYKfn-quJC0Iauq1xGbA

References:
- https://developers.google.com/search/docs/appearance/structured-data/software-app
- https://developers.google.com/search/docs/appearance/structured-data/article
- https://developers.google.com/search/docs/appearance/structured-data/breadcrumb
- https://validator.schema.org/
