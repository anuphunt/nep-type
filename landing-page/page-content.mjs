export const repository = 'https://github.com/anuphunt/nep-type';
export const homeDescription = 'Type Nepali using Roman letters with NepType, an open-source Mac app. Write offline and keep English words in mixed sentences.';

export const nepaliCopy = {
  badge: 'नेपाली लेखौँ',
  headline: 'रोमनमा टाइप गर्नुहोस्।',
  headlineAccent: 'नेपालीमा लेख्नुहोस्।',
  description: 'Mac का लागि खुला स्रोत नेपाली टाइपिङ एप।',
  cta: 'Mac का लागि NepType',
  offline: 'खुला स्रोत',
  source: 'स्रोत हेर्नुहोस्',
  featuresTitle: 'दैनिक नेपाली लेखाइका लागि।',
  mixedTitle: 'English पनि राख्नुहोस्।',
  mixedDescription: 'दुवै भाषामा लेख्न Nepali + EN रोज्नुहोस्।',
  platformTitle: 'Mac बाट सुरु गर्नुहोस्।',
  platformDescription: 'अन्य प्लेटफर्मको काम हुँदैछ।',
  privacyTitle: 'अफलाइन चल्छ।',
  privacyDescription: 'तपाईंले लेखेका कुरा उपकरणमै रहन्छन्।',
  choiceTitle: 'सही शब्द रोज्नुहोस्।',
  choiceDescription: 'हिज्जे रोज्नुहोस् वा मूल शब्द राख्नुहोस्।',
  flowTitle: 'जहाँ चाहिन्छ, पेस्ट गर्नुहोस्।',
  flowDescription: 'नेपाली पाठ कपी गरेर आफ्नो एपमा लैजानुहोस्।',
  footerTagline: 'नेपाली लेख्ने प्याड।'
};

export const labels = {
  Features: 'सुविधाहरू', FAQ: 'प्रश्नहरू', Changelog: 'परिवर्तनहरू',
  'Get NepType': 'NepType लिनुहोस्', Home: 'गृहपृष्ठ', Platforms: 'प्लेटफर्महरू',
  Support: 'सहयोग', Feedback: 'प्रतिक्रिया', Privacy: 'गोपनीयता', Project: 'परियोजना',
  'About NepType': 'NepType बारे', 'Open source': 'खुला स्रोत', 'In progress': 'काम हुँदैछ',
  'Works offline': 'अफलाइन चल्छ', 'YOU TYPE': 'तपाईंको लेखाइ', NEPTYPE: 'NEPTYPE',
  'ON YOUR DEVICE': 'तपाईंकै उपकरणमा', 'No connection needed': 'इन्टरनेट चाहिँदैन',
  'Try another spelling': 'अर्को हिज्जे रोज्नुहोस्', 'Copy example': 'उदाहरण कपी गर्नुहोस्',
  MESSAGE: 'सन्देश', 'Got it': 'ठीक छ'
};

export const pages = {
  faq: {
    en: {
      title: 'Nepali Typing FAQ | NepType', heading: 'A few common questions.',
      description: 'How NepType converts Roman letters to Nepali, keeps English words, and works offline on Mac.',
      sections: [
        ['How does NepType work?', 'Type Roman letters in the pad. NepType suggests Nepali spellings, then you copy the result.'],
        ['Can I keep English words?', 'Yes. Nepali + EN keeps recognized English words. You can also choose the original spelling.'],
        ['Does it work offline?', 'Yes. Typing runs on your device, without an account.'],
        ['Can I type directly in other apps?', 'The Mac pad uses copy and paste. System keyboard support is still in development.'],
        ['What if a word is wrong?', 'Select another spelling from the suggestions, or keep your original word. Names and ambiguous words may need a correction.']
      ]
    },
    ne: {
      title: 'नेपाली टाइपिङका प्रश्नहरू | NepType', heading: 'केही सामान्य प्रश्नहरू।',
      description: 'NepType मा रोमनबाट नेपाली लेख्ने, अंग्रेजी शब्द राख्ने र अफलाइन प्रयोग गर्नेबारे जानकारी।',
      sections: [
        ['NepType कसरी चल्छ?', 'प्याडमा रोमन अक्षर टाइप गर्नुहोस्। NepType ले नेपाली हिज्जे सुझाउँछ। तयार भएको पाठ कपी गर्नुहोस्।'],
        ['अंग्रेजी शब्द राख्न मिल्छ?', 'मिल्छ। Nepali + EN ले चिनेका अंग्रेजी शब्द राख्छ। तपाईं मूल हिज्जे पनि रोज्न सक्नुहुन्छ।'],
        ['अफलाइन चल्छ?', 'चल्छ। लेखाइ उपकरणमै प्रशोधन हुन्छ। खाता चाहिँदैन।'],
        ['अरू एपमा सिधै टाइप गर्न मिल्छ?', 'Mac प्याडबाट पाठ कपी गरेर पेस्ट गर्नुपर्छ। सिस्टम किबोर्डको काम हुँदैछ।'],
        ['शब्द गलत भए के गर्ने?', 'सुझावबाट अर्को हिज्जे रोज्नुहोस् वा मूल शब्द राख्नुहोस्। नाम र अस्पष्ट शब्द सच्याउनुपर्ने हुन सक्छ।']
      ]
    }
  },
  mac: {
    en: {
      title: 'Nepali Typing for Mac | Get NepType', heading: 'NepType for Mac.',
      description: 'Get the open-source NepType Mac typing pad. Learn how to write Nepali using Roman letters and copy it into your apps.',
      sections: [
        ['Get the app', 'Build NepType from the instructions in the GitHub README. A public installer isn’t available yet.'],
        ['Write in Nepali', 'Type namaste in the Roman input field to get नमस्ते. Use Nepali + EN to keep recognized English words, or choose All Nepali.'],
        ['Use your text', 'Choose a spelling from the suggestions, then copy the output into your app. The pad works offline.']
      ], link: 'Get NepType on GitHub'
    },
    ne: {
      title: 'Mac मा नेपाली टाइपिङ | NepType लिनुहोस्', heading: 'Mac का लागि NepType।',
      description: 'Mac मा रोमन अक्षरबाट नेपाली लेख्न खुला स्रोत NepType प्रयोग गर्नुहोस्। तयार पाठ आफ्नो एपमा कपी गर्नुहोस्।',
      sections: [
        ['एप लिनुहोस्', 'GitHub README को निर्देशनअनुसार NepType बिल्ड गर्नुहोस्। सार्वजनिक इन्स्टलर उपलब्ध भइसकेको छैन।'],
        ['नेपालीमा लेख्नुहोस्', 'रोमन इनपुटमा namaste लेख्दा नमस्ते आउँछ। चिनेका अंग्रेजी शब्द राख्न Nepali + EN वा नेपाली अक्षरका लागि All Nepali रोज्नुहोस्।'],
        ['पाठ प्रयोग गर्नुहोस्', 'सुझावबाट हिज्जे रोजेर तयार पाठ आफ्नो एपमा कपी गर्नुहोस्। प्याड अफलाइन चल्छ।']
      ], link: 'GitHub मा NepType लिनुहोस्'
    }
  },
  about: {
    en: {title: 'About NepType | Open-Source Nepali Typing', heading: 'About NepType.', description: 'NepType is an open-source Nepali typing app for Mac, built by Anup Dhakal and contributors.', sections: [['', 'NepType is an open-source Nepali typing pad for Mac, built by Anup Dhakal and contributors. It uses local dictionaries and phonetic rules to turn Roman letters into Nepali.'], ['', 'The project’s original code is available under the MIT license. Third-party data has separate terms documented in the repository.']], link: 'View the project'},
    ne: {title: 'NepType बारे | खुला स्रोत नेपाली टाइपिङ', heading: 'NepType बारे।', description: 'अनुप ढकाल र योगदानकर्ताहरूले बनाएको Mac का लागि खुला स्रोत नेपाली टाइपिङ एप।', sections: [['', 'NepType अनुप ढकाल र योगदानकर्ताहरूले बनाएको Mac का लागि खुला स्रोत नेपाली टाइपिङ प्याड हो। यसले स्थानीय शब्दकोश र ध्वनिसम्बन्धी नियमबाट रोमन अक्षरलाई नेपालीमा बदल्छ।'], ['', 'परियोजनाको मूल कोड MIT लाइसेन्समा उपलब्ध छ। बाह्य डेटाका छुट्टै सर्तहरू रिपोजिटरीमा छन्।']], link: 'परियोजना हेर्नुहोस्'}
  },
  privacy: {
    en: {title: 'Privacy | NepType', heading: 'Your typing stays on your device.', description: 'NepType processes typing offline without accounts or telemetry. Learn how the app and this website handle data.', sections: [['The app', 'Typing runs locally. The pad has no accounts, telemetry, or network requests. Documents and undo history stay in memory. Copy what you need before quitting.'], ['This website', 'This website has no analytics or account forms. Netlify hosts it and processes requests to serve the pages. Fonts load from Google Fonts.']]},
    ne: {title: 'गोपनीयता | NepType', heading: 'तपाईंको लेखाइ उपकरणमै रहन्छ।', description: 'NepType ले खाता वा टेलिमेट्रीबिना अफलाइन लेखाइ प्रशोधन गर्छ। एप र वेबसाइटको गोपनीयताबारे जानकारी।', sections: [['एप', 'लेखाइ स्थानीय रूपमा प्रशोधन हुन्छ। प्याडमा खाता, टेलिमेट्री वा नेटवर्क अनुरोध छैनन्। कागजात र अन्डु इतिहास मेमोरीमा रहन्छन्। बन्द गर्नुअघि आवश्यक पाठ कपी गर्नुहोस्।'], ['वेबसाइट', 'यो वेबसाइटमा एनालिटिक्स वा खाता फारम छैनन्। Netlify ले पृष्ठ उपलब्ध गराउन अनुरोध प्रशोधन गर्छ। फन्टहरू Google Fonts बाट आउँछन्।']]}
  },
  changelog: {
    en: {title: 'What’s New | NepType', heading: 'What’s new.', description: 'Current NepType features and development updates for the open-source Nepali typing app.', sections: [['Mac typing pad', 'Nepali + EN and All Nepali modes, spelling suggestions, and copy controls.'], ['Other platforms', 'Work is underway on iPhone, Android, Windows, and Linux integrations.']], link: 'Follow development on GitHub'},
    ne: {title: 'नयाँ परिवर्तनहरू | NepType', heading: 'नयाँ परिवर्तनहरू।', description: 'खुला स्रोत नेपाली टाइपिङ एप NepType का वर्तमान सुविधा र विकाससम्बन्धी जानकारी।', sections: [['Mac टाइपिङ प्याड', 'Nepali + EN र All Nepali मोड, हिज्जे सुझाव र कपी सुविधा।'], ['अन्य प्लेटफर्महरू', 'iPhone, Android, Windows र Linux का लागि काम हुँदैछ।']], link: 'GitHub मा प्रगति हेर्नुहोस्'}
  }
};
