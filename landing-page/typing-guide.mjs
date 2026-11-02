// Examples are checked against the published browser dictionary in seo.test.mjs.
export const examples = [
  ['namaste', 'नमस्ते'],
  ['malai momo man parcha.', 'मलाई मोमो मन पर्छ।'],
  ['aaja class cha.', 'आज class छ।'],
  ['mero phone naya cha.', 'मेरो phone नयाँ छ।']
];

export const homeHelp = {
  en: {
    heading: 'How to type Nepali with English letters',
    intro: 'NepType converts Romanized Nepali into Unicode Devanagari. Write a Nepali word by sound, choose the spelling you mean, and copy the result into a message or document.',
    steps: [
      ['1. Type a Nepali word', 'Enter namaste in the Roman input box to get नमस्ते. Try the example button for a complete mixed-language sentence.'],
      ['2. Choose your spelling', 'Click a word in either editor to see alternatives. For pani, choose पानी or पनि to match your meaning.'],
      ['3. Copy your Nepali text', 'Use Copy text and paste into your app. Save a copy before closing or reloading; the pad does not save drafts.']
    ],
    note: 'Nepali + EN keeps recognized English words. All Nepali writes English words in Nepali letters too. This is transliteration, so it changes the script rather than translating English sentences.',
    guide: 'Read the Roman-to-Nepali typing guide', faq: 'More typing questions', mac: 'Set up offline Nepali typing on Mac'
  },
  ne: {
    heading: 'अंग्रेजी अक्षरबाट नेपाली कसरी लेख्ने?',
    intro: 'NepType ले रोमनमा लेखेका नेपाली शब्दलाई युनिकोड देवनागरीमा बदल्छ। शब्दको उच्चारणअनुसार लेख्नुहोस्, चाहिएको हिज्जे रोज्नुहोस् र तयार पाठ सन्देश वा कागजातमा कपी गर्नुहोस्।',
    steps: [
      ['१. नेपाली शब्द लेख्नुहोस्', 'रोमन लेखाइमा namaste लेख्दा नमस्ते आउँछ। पूरा वाक्य हेर्न उदाहरण बटन थिच्नुहोस्।'],
      ['२. हिज्जे रोज्नुहोस्', 'कुनै पनि सम्पादकमा शब्द छानेर विकल्प हेर्नुहोस्। pani का लागि अर्थअनुसार पानी वा पनि रोज्नुहोस्।'],
      ['३. नेपाली पाठ कपी गर्नुहोस्', 'पाठ कपी गर्नुहोस् बटन थिचेर आफ्नो एपमा पेस्ट गर्नुहोस्। पृष्ठ बन्द गर्नुअघि कपी गर्नुहोस्। प्याडले मस्यौदा सुरक्षित राख्दैन।']
    ],
    note: 'Nepali + EN ले चिनेका अंग्रेजी शब्द उस्तै राख्छ। All Nepali ले अंग्रेजी शब्दलाई पनि नेपाली अक्षरमा लेख्छ। यसले लिपि बदल्छ, अंग्रेजी वाक्यको अर्थ अनुवाद गर्दैन।',
    guide: 'रोमनबाट नेपाली लेख्ने तरिका पढ्नुहोस्', faq: 'टाइपिङका थप प्रश्नहरू', mac: 'Mac मा अफलाइन नेपाली लेख्ने तरिका'
  }
};

export const typingGuide = {
  en: {
    title: 'How to Type Nepali with Roman Letters — Typing Guide | NepType',
    heading: 'How to type Nepali with Roman letters',
    description: 'Learn Roman-to-Nepali typing with tested examples, spelling choices, mixed English sentences, and Unicode copy-and-paste tips for NepType.',
    kind: 'article', published: '2026-11-01',
    sections: [
      ['Start with a word you already know', 'You do not need to learn a new keyboard layout to use NepType. Open the free browser typing pad and type a Nepali word using Roman letters, such as namaste. The output appears in Devanagari as नमस्ते. You are writing the sound of a Nepali word, rather than translating an English word.', {links: [['Open the Nepali typing pad', '/#try']]}],
      ['Type, choose, and copy', 'The browser pad has two boxes: Roman input on the left and Nepali output on the right. On a small screen, the output appears below the input.', {steps: ['Type in Roman input. The output updates as you write.', 'Choose Nepali + EN to keep recognized English words, or All Nepali to write those words in Nepali letters too.', 'Select a word in either box to see spelling suggestions. Click the spelling you want.', 'Use Copy text and paste the result into your message, document, or social post. Keep a copy before closing or reloading the page.']}],
      ['Examples you can try in NepType', 'These examples use Nepali + EN mode in the browser tool. The food example becomes Nepali, while class and phone stay in English in the other messages. A sentence-ending period becomes the Nepali punctuation mark ।.', {examples}],
      ['Choose between पानी and पनि', 'Roman spelling can be ambiguous. The input pani has both पानी and पनि among its suggestions. Click the word, then choose the spelling that fits your sentence. The choice applies to that occurrence, so you can use different spellings of pani in the same paragraph. You can also keep the original Roman word. Names and unfamiliar words may need correction.'],
      ['Use spelling shortcuts', 'With either editor focused, use Option plus the displayed number on Mac, or Alt plus the number on Windows or Linux, to choose a suggestion. The numbers shown beside the suggestions tell you which key to press. The output box is read-only; edit the Roman input or pick another suggestion to change it.'],
      ['English to Nepali typing versus translation', 'People sometimes call Roman-to-Nepali typing “English to Nepali typing” because they use an English keyboard. NepType transliterates Nepali words written with Roman letters. It does not turn the meaning of an English sentence into Nepali. All Nepali mode changes how English words are written; it does not translate them.'],
      ['Copy Unicode text, rather than changing a font', 'The output contains Unicode Devanagari characters. Copying नमस्ते preserves the Nepali letters themselves. The receiving app still needs a font that can display Devanagari. Legacy Preeti text uses a different workflow; pasting a Preeti document into this pad is not a Preeti-to-Unicode conversion.'],
      ['What happens to your text?', 'The website needs a connection to load the page and dictionary. After that, conversion runs on your device without sending your typing to a conversion server. Reloading requires a connection. The pad keeps your draft only in memory; it is lost when you close or reload the page. Website analytics does not collect your input, output, or chosen spellings.', {links: [['Read the privacy details', '/privacy/']]}],
      ['Need an offline Mac typing pad?', 'The native NepType Mac app works offline and also uses Roman input, spelling suggestions, and copy-and-paste output. It currently requires building from source. The browser and native apps use the same shared engine and dictionary pack; their controls can differ. Native keyboards for other platforms are still in development.', {links: [['Mac setup instructions', '/mac/'], ['Answers to common typing questions', '/faq/'], ['Try your own sentence', '/#try']]}]
    ]
  },
  ne: {
    title: 'रोमन अक्षरबाट नेपाली कसरी लेख्ने? | NepType टाइपिङ गाइड',
    heading: 'रोमन अक्षरबाट नेपाली लेख्ने तरिका',
    description: 'NepType मा रोमनबाट नेपाली लेख्न सिक्नुहोस्। उदाहरण, हिज्जे विकल्प, अंग्रेजी मिसिएका वाक्य र युनिकोड पाठ कपी गर्ने तरिका।',
    kind: 'article', published: '2026-11-01',
    sections: [
      ['चिनेको शब्दबाट सुरु गर्नुहोस्', 'NepType प्रयोग गर्न नयाँ किबोर्ड लेआउट सिक्नु पर्दैन। निःशुल्क ब्राउजर प्याड खोल्नुहोस् र नेपाली शब्द रोमन अक्षरमा लेख्नुहोस्। जस्तै, namaste लेख्दा नमस्ते आउँछ। तपाईं नेपाली शब्दको उच्चारण लेख्दै हुनुहुन्छ, अंग्रेजी शब्दको अर्थ अनुवाद गर्दै हुनुहुन्न।', {links: [['नेपाली टाइपिङ प्याड खोल्नुहोस्', '/#try']]}],
      ['लेख्नुहोस्, हिज्जे रोज्नुहोस् र कपी गर्नुहोस्', 'प्याडमा रोमन लेखाइ र नेपाली लेखाइका दुई बाकस छन्। सानो स्क्रिनमा नेपाली पाठ रोमन बाकसको तल देखिन्छ।', {steps: ['रोमन लेखाइमा शब्द लेख्नुहोस्। तयार नेपाली पाठ सँगसँगै देखिन्छ।', 'चिनेका अंग्रेजी शब्द उस्तै राख्न Nepali + EN रोज्नुहोस्। तिनलाई पनि नेपाली अक्षरमा लेख्न All Nepali रोज्नुहोस्।', 'कुनै पनि बाकसमा शब्द छानेर हिज्जेका विकल्प हेर्नुहोस्। चाहिएको हिज्जे थिच्नुहोस्।', 'पाठ कपी गर्नुहोस् बटन थिचेर सन्देश वा कागजातमा पेस्ट गर्नुहोस्। पृष्ठ बन्द गर्नुअघि आवश्यक पाठ कपी गर्नुहोस्।']}],
      ['आफैँ लेखेर हेर्ने उदाहरण', 'यी उदाहरण ब्राउजरको Nepali + EN मोडका हुन्। खानाबारेको वाक्य नेपालीमा बन्छ। अरू सन्देशमा class र phone अंग्रेजीमै रहन्छन्। वाक्यको अन्त्यमा लेखेको बिन्दु नेपाली पूर्णविराम । बन्छ।', {examples}],
      ['पानी वा पनि कसरी रोज्ने?', 'एउटै रोमन हिज्जेले फरक नेपाली शब्द जनाउन सक्छ। pani लेख्दा सुझावमा पानी र पनि दुवै आउँछन्। शब्द छानेर वाक्यमा मिल्ने हिज्जे रोज्नुहोस्। यो छनोट त्यही ठाउँको शब्दमा मात्र लागू हुन्छ। त्यसैले एउटै अनुच्छेदमा pani का फरक हिज्जे राख्न सकिन्छ। मूल रोमन शब्द पनि राख्न मिल्छ। नाम र अपरिचित शब्द सच्याउनुपर्ने हुन सक्छ।'],
      ['हिज्जे रोज्ने सर्टकट', 'कुनै पनि सम्पादकमा कर्सर राखेर Mac मा Option र देखाइएको नम्बर थिच्नुहोस्। Windows वा Linux मा Alt र नम्बर थिच्नुहोस्। सुझावसँगै देखिने नम्बरले कुन कुञ्जी प्रयोग गर्ने बताउँछ। नेपाली नतिजाको बाकस सिधै सम्पादन हुँदैन। बदल्न रोमन लेखाइ सच्याउनुहोस् वा अर्को सुझाव रोज्नुहोस्।'],
      ['टाइपिङ र अनुवादको फरक', 'अंग्रेजी किबोर्ड प्रयोग हुने भएकाले रोमनबाट नेपाली लेखाइलाई कहिलेकाहीँ “English to Nepali typing” भनिन्छ। NepType ले रोमनमा लेखेका नेपाली शब्दको लिपि बदल्छ। अंग्रेजी वाक्यको अर्थ नेपालीमा अनुवाद गर्दैन। All Nepali मोडले पनि अंग्रेजी शब्द नेपाली अक्षरमा लेख्छ, तिनको अर्थ अनुवाद गर्दैन।'],
      ['युनिकोड पाठ कपी गर्नुहोस्', 'तयार पाठ युनिकोड देवनागरीमा हुन्छ। नमस्ते कपी गर्दा नेपाली अक्षर नै कपी हुन्छन्। पेस्ट गर्ने एपमा देवनागरी देखाउन सक्ने फन्ट चाहिन्छ। पुराना प्रीति कागजातको तरिका फरक हुन्छ। प्रीति पाठ यस प्याडमा पेस्ट गर्दैमा युनिकोडमा बदलिँदैन।'],
      ['तपाईंको पाठ कहाँ रहन्छ?', 'पृष्ठ र शब्दकोश लोड गर्न इन्टरनेट चाहिन्छ। त्यसपछि टाइपिङ यही उपकरणमा हुन्छ। लेखेको पाठ रूपान्तरण सर्भरमा पठाइँदैन। पृष्ठ फेरि खोल्न इन्टरनेट चाहिन्छ। मस्यौदा मेमोरीमा मात्र रहन्छ र पृष्ठ बन्द गर्दा वा फेरि लोड गर्दा हराउँछ। वेबसाइट एनालिटिक्सले लेखेको पाठ, तयार पाठ वा रोजेको हिज्जे सङ्कलन गर्दैन।', {links: [['गोपनीयताबारे पढ्नुहोस्', '/privacy/']]}],
      ['Mac मा अफलाइन लेख्न चाहनुहुन्छ?', 'NepType को Mac एप अफलाइन चल्छ। यसमा पनि रोमन लेखाइ, हिज्जेका सुझाव र पाठ कपी गर्ने सुविधा छन्। अहिले एप स्रोतबाट बिल्ड गर्नुपर्छ। ब्राउजर र नेटिभ एपमा एउटै साझा इन्जिन र शब्दकोश प्रयोग हुन्छ। तिनका नियन्त्रण फरक हुन सक्छन्। अन्य प्लेटफर्मका छुट्टै किबोर्डको काम हुँदैछ।', {links: [['Mac मा चलाउने निर्देशन', '/mac/'], ['टाइपिङका सामान्य प्रश्न', '/faq/'], ['आफ्नो वाक्य लेखेर हेर्नुहोस्', '/#try']]}]
    ]
  }
};
