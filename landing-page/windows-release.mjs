// A pending build must never become a public installer link or download schema.
export function windowsDownload(release) {
  if (release.verified !== true) return null;
  if (!/^\d+\.\d+\.\d+-preview\.\d+$/.test(release.version) ||
      !/^[a-f0-9]{64}$/.test(release.sha256) ||
      !/^[a-f0-9]{40}$/.test(release.sourceCommit) ||
      !Number.isSafeInteger(release.bytes) || release.bytes <= 0 ||
      release.signing !== 'unsigned' || release.systemKeyboard !== false) {
    throw Error('Windows release requires verified preview metadata.');
  }
  const expected = `https://github.com/anuphunt/nep-type/releases/download/windows-v${release.version}/NepType-${release.version}-windows-x64-setup.exe`;
  if (release.url !== expected || !/^https:\/\/github\.com\/anuphunt\/nep-type\/actions\/runs\/\d+$/.test(release.verificationUrl)) {
    throw Error('Windows release must link the immutable installer and its verification run.');
  }
  return release;
}

export function windowsPage(release, locale) {
  const ready = Boolean(release);
  const source = 'https://github.com/anuphunt/nep-type/tree/main/platforms/windows';
  if (locale === 'ne') return {
    title: 'Windows मा नेपाली टाइपिङ | NepType लिनुहोस्',
    heading: 'Windows का लागि NepType।',
    description: 'Windows 10 वा 11 चल्ने Intel वा AMD x64 कम्प्युटरमा अफलाइन नेपाली लेख्न NepType डाउनलोड गर्नुहोस्।',
    sections: [
      [ready ? 'NepType इन्स्टल गर्नुहोस्' : 'Windows डाउनलोडको तयारी हुँदैछ', ready ? 'Windows 10 वा 11 चल्ने Intel वा AMD 64-bit (x64) कम्प्युटरका लागि। ARM64 मा परीक्षण गरिएको छैन।' : 'इन्स्टलरको जाँच पूरा भएपछि डाउनलोड उपलब्ध हुनेछ। अहिले ब्राउजर प्याड प्रयोग गर्न सक्नुहुन्छ।', ready ? {
        steps: ['NepType को .exe इन्स्टलर डाउनलोड गरेर खोल्नुहोस्।', 'इन्स्टल गर्ने निर्देशन पालना गर्नुहोस्। एप तपाईंको प्रयोगकर्ता खातामा इन्स्टल हुन्छ।', 'Start बाट NepType खोल्नुहोस्।'],
        note: 'इन्स्टलरमा डिजिटल हस्ताक्षर छैन। Windows वा ब्राउजरले SmartScreen वा अपरिचित प्रकाशकको चेतावनी देखाउन सक्छ।'
      } : {links: [['ब्राउजरमा नेपाली लेख्नुहोस्', '/#try']]}],
      ['नेपालीमा लेख्नुहोस्', 'Roman input मा namaste लेख्दा नमस्ते आउँछ। चिनेका अंग्रेजी शब्द राख्न Nepali + EN वा नेपाली अक्षरका लागि All Nepali रोज्नुहोस्।'],
      ['पाठ प्रयोग गर्नुहोस्', 'हिज्जे रोजेर तयार पाठ आफ्नो एपमा कपी गर्नुहोस्। प्याड अफलाइन चल्छ। यसले सिस्टम किबोर्ड इन्स्टल गर्दैन। बन्द गर्नुअघि आवश्यक पाठ कपी गर्नुहोस्; एपले कागजात सुरक्षित राख्दैन।'],
      ['NepType हटाउनुहोस्', 'Windows Settings > Apps > Installed apps > NepType > Uninstall रोज्नुहोस्।'],
      ['स्रोतबाट बिल्ड गर्ने तरिका', 'डेभलपरले खुला स्रोत रिपोजिटरीबाट पनि एप बिल्ड गर्न सक्छन्।', {links: [['स्रोत र बिल्ड गर्ने निर्देशन', source], ...(ready ? [['चेकसम फाइल', release.url + '.sha256']] : [])]}]
    ], link: 'Windows को स्रोत हेर्नुहोस्'
  };
  return {
    title: 'Nepali Typing for Windows — Offline Typing Pad | NepType',
    heading: 'Type Nepali offline on Windows.',
    description: 'Download NepType for Windows. Type Nepali offline on Windows 10 or 11, on Intel or AMD x64 computers.',
    sections: [
      [ready ? 'Install NepType' : 'Windows download in preparation', ready ? 'For Windows 10 or 11 on Intel or AMD 64-bit (x64) computers. ARM64 has not been tested.' : 'The download will appear after installer checks pass. You can use the browser pad now.', ready ? {
        steps: ['Download and open the NepType .exe installer.', 'Follow the installer steps to install for your user account.', 'Open NepType from Start.'],
        note: 'The installer is not digitally signed. Windows or your browser may show a SmartScreen or unknown-publisher warning.'
      } : {links: [['Type Nepali in your browser', '/#try']]}],
      ['Write in Nepali', 'Type namaste in the Roman input field to get नमस्ते. Use Nepali + EN to keep recognized English words, or choose All Nepali.'],
      ['Use your text', 'Choose a spelling and copy the output into your app. The pad works offline and does not install a system keyboard. Copy text before closing; documents are not saved between launches.'],
      ['Remove NepType', 'Use Windows Settings > Apps > Installed apps > NepType > Uninstall.'],
      ['Build from source', 'Developers can also build the app from its open-source repository.', {links: [['Source and build instructions', source], ...(ready ? [['Checksum file', release.url + '.sha256']] : [])]}]
    ], link: 'View Windows source'
  };
}
