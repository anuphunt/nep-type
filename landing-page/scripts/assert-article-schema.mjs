import assert from 'node:assert/strict';

export function assertArticleSchema(entities, article, locale, url) {
  assert.ok(Array.isArray(entities), 'Article JSON-LD must contain an @graph.');
  const matches = entities.filter(entity => entity['@type'] === 'Article');
  assert.equal(matches.length, 1, 'Expected exactly one Article entity.');
  const entity = matches[0];
  for (const [field, expected] of Object.entries({
    '@id': url + '#article', url, inLanguage: locale,
    headline: article[locale].heading, datePublished: article.published,
    dateModified: article.modified
  })) assert.equal(entity[field], expected, `Article ${field}: ${url}`);
  assert.deepEqual(entity.mainEntityOfPage, {'@id': url + '#page'});
}
