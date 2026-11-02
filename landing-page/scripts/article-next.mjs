import {readFile} from 'node:fs/promises';
import {loadAllArticles, queueFile, selectNextTopic} from '../article-content.mjs';
const queue = JSON.parse(await readFile(queueFile,'utf8'));
console.log(JSON.stringify(selectNextTopic(queue, await loadAllArticles()),null,2));
