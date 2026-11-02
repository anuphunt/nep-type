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
  if (locale === 'ne') return {
    title: 'Windows का लागि नेपाली टाइपिङ प्याड | NepType',
    heading: 'Windows मा अफलाइन नेपाली लेख्नुहोस्।',
    description: 'Windows का लागि NepType टाइपिङ प्याडको प्रिभ्यु। रोमन अक्षरबाट नेपाली लेख्नुहोस् र तयार पाठ अन्य एपमा कपी गर्नुहोस्।',
    sections: [
      [ready ? 'Windows प्रिभ्यु डाउनलोड गर्नुहोस्' : 'Windows प्रिभ्युको तयारी हुँदैछ', ready ? 'Windows 10 वा 11 चल्ने Intel वा AMD 64-bit (x64) कम्प्युटरका लागि .exe इन्स्टलर। ARM64 मा परीक्षण गरिएको छैन।' : 'इन्स्टलरको बिल्ड र इन्स्टल, टाइपिङ तथा अनइन्स्टल जाँच पूरा भएपछि यहाँ डाउनलोड राखिनेछ। अहिले ब्राउजर प्याड प्रयोग गर्न सक्नुहुन्छ।', {links: [['ब्राउजरमा नेपाली लेख्नुहोस्', '/#try']]}],
      ['टाइपिङ प्याड', 'Roman input मा namaste लेख्दा नमस्ते आउँछ। हिज्जे रोजेर Copy text थिच्नुहोस् र आफ्नो एपमा पेस्ट गर्नुहोस्। यसले सिस्टम किबोर्ड इन्स्टल गर्दैन र अरू एपमा सिधै टाइप गर्दैन।'],
      ['हस्ताक्षर नभएको प्रिभ्यु', 'यो प्रिभ्युमा डिजिटल हस्ताक्षर छैन। Windows वा ब्राउजरले अपरिचित प्रकाशक वा SmartScreen चेतावनी देखाउन सक्छ।'],
      ['इन्स्टल र हटाउने तरिका', 'इन्स्टलर खोल्नुहोस्। एप तपाईंको प्रयोगकर्ता खातामा इन्स्टल हुन्छ। त्यसपछि Start बाट NepType खोल्नुहोस्। हटाउन Windows Settings > Apps > Installed apps > NepType > Uninstall रोज्नुहोस्।'],
      ['आफ्नो पाठ राख्नुहोस्', 'टाइपिङ अफलाइन हुन्छ। प्याडले कागजात सुरक्षित राख्दैन। बन्द गर्नुअघि राख्नुपर्ने पाठ कपी गर्नुहोस्।'],
      ['परीक्षणको सीमा', 'स्वचालित जाँचका लागि Windows Server 2022 को रनर प्रयोग गर्ने व्यवस्था छ। प्रयोगकर्ताको Windows 10/11 कम्प्युटर, उच्च DPI र पहुँचयोग्यताको म्यानुअल परीक्षण बाँकी छ।']
    ], link: 'Windows को स्रोत हेर्नुहोस्'
  };
  return {
    title: 'Nepali Typing for Windows — Offline Pad Preview | NepType',
    heading: 'Type Nepali offline on Windows.',
    description: 'NepType Windows typing-pad preview. Write Roman letters, choose a Nepali spelling, and copy your text into another app.',
    sections: [
      [ready ? 'Download the Windows preview' : 'Windows preview in preparation', ready ? 'An .exe installer for Windows 10 or 11 on Intel or AMD 64-bit (x64) computers. ARM64 has not been tested.' : 'The download will appear here after the installer passes build, installation, typing, and removal checks. You can use the browser pad now.', {links: [['Type Nepali in your browser', '/#try']]}],
      ['A standalone typing pad', 'Type namaste in Roman input to get नमस्ते. Choose a spelling, click Copy text, and paste into your app. This package does not install a system keyboard or type directly in other apps.'],
      ['Unsigned preview', 'This preview has no digital signature. Windows or your browser may display an unknown-publisher or SmartScreen warning.'],
      ['Install and remove', 'Open the installer to install for your user account, then open NepType from Start. To remove it, use Windows Settings > Apps > Installed apps > NepType > Uninstall.'],
      ['Keep your text', 'Typing works offline. The pad does not save documents. Copy any text you want to keep before closing it.'],
      ['Testing limits', 'Automated verification is configured for a Windows Server 2022 runner. Manual testing on consumer Windows 10/11 computers, high-DPI displays, and assistive technology is still needed.']
    ], link: 'View Windows source'
  };
}
