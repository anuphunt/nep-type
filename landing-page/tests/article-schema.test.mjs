import test from 'node:test';
import assert from 'node:assert/strict';
import {assertArticleSchema} from '../scripts/assert-article-schema.mjs';

const article = {published:'2026-11-09', en:{heading:'English heading'}, ne:{heading:'नेपाली शीर्षक'}};
for (const locale of ['en','ne']) {
  const url = `https://neptype.com/${locale === 'ne' ? 'ne/' : ''}articles/fixture/`;
  const entity = {'@type':'Article', '@id':url+'#article', url, inLanguage:locale,
    headline:article[locale].heading, datePublished:article.published, mainEntityOfPage:{'@id':url+'#page'}};
  test(`${locale}: accepts the emitted Article and optional revision date`, () => {
    assertArticleSchema([entity], article, locale, url);
    assertArticleSchema([{...entity,dateModified:'2026-11-10'}], {...article,modified:'2026-11-10'}, locale, url);
  });
  test(`${locale}: rejects missing, duplicate and obsolete article entities`, () => {
    for (const graph of [undefined, [], [entity,entity], [{...entity,'@type':'TechArticle'}]])
      assert.throws(() => assertArticleSchema(graph, article, locale, url), assert.AssertionError);
  });
  test(`${locale}: rejects incorrect identity, localization and dates`, () => {
    for (const field of ['@id','url','inLanguage','headline','datePublished','dateModified','mainEntityOfPage'])
      assert.throws(() => assertArticleSchema([{...entity,[field]:'incorrect'}], article, locale, url), assert.AssertionError, field);
  });
}
