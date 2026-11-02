const activeDesign = document.documentElement.dataset.design;
document.querySelector(`[data-design-link="${activeDesign}"]`)?.classList.add('active');
const dialog = document.getElementById('info-dialog');
const title = document.getElementById('dialog-title');
const body = document.getElementById('dialog-body');
const projectLink = '<a href="https://github.com/anuphunt/nep-type" target="_blank" rel="noopener noreferrer">View project on GitHub ↗</a>';
const content = {
  faq: ['A few good questions.', '<details open><summary>How do I type in Nepali?</summary><p>Type familiar Roman letters in the NepType pad. The app suggests Nepali spellings and shows an editable preview. Choose an alternative when you need one, then copy the result.</p></details><details><summary>Can I mix English and Nepali?</summary><p>Yes. Nepali + EN keeps recognized English words in Roman letters. All Nepali offers a Devanagari-focused output. Ambiguous words and unfamiliar names may need a correction.</p></details><details><summary>Does it work without internet?</summary><p>The typing pad runs locally, with no account, telemetry, or network requests.</p></details><details><summary>Is it ready to download?</summary><p>NepType is a local prototype. The Mac pad is the working surface. Other platform integrations are experimental or in development. Public installers and store releases are not available here.</p></details><details><summary>Does it type in every app?</summary><p>The current Mac pad uses copy and paste. System keyboard integrations are experimental and have not been verified in real host apps.</p></details>'],
  changelog: ['Taking shape, one detail at a time.', '<span class="status-tag">CURRENT LOCAL PROTOTYPE</span><p><strong>A shared Graphite identity.</strong><br>Neutral surfaces, silver controls, and a focused typing workspace on Mac and iPhone.</p><p><strong>More control over your words.</strong><br>Nepali + EN and All Nepali modes, selectable suggestions, original text, and copy controls.</p><p><strong>Platform work in progress.</strong><br>Experimental keyboard integrations are being developed and tested separately.</p><p>This preview summarizes the repository’s current state. It is not a public release history.</p>'],
  privacy: ['Your words stay on your device.', '<p>The current NepType pad processes typing locally. There are no accounts, telemetry, network requests, or model downloads in the typing workflow.</p><p>The pad’s undo history stays in memory. Copy text you want to keep before quitting, because documents are not saved between launches.</p><p>This landing-page preview has no analytics, form submissions, or stored visitor data. Its fonts are loaded from Google Fonts.</p>'],
  about: ['Nepali, in your own words.', '<p>NepType is a native Nepali typing prototype with a working Mac pad and experimental platform integrations.</p><p>It combines local dictionaries, candidate choices, and deterministic phonetic rules. It is not translation or automatic AI language detection.</p><p>'+projectLink+'</p>']
};
const platforms = {
  macOS: ['macOS typing pad', 'The native Mac pad is a working local prototype. Type Roman letters, select Nepali suggestions, and copy the output into another app. Public signed installers are not available in this design preview.', 'Local prototype'],
  iOS: ['NepType for iPhone', 'The iPhone container pad and keyboard extension are experimental. The keyboard has not been verified as an enabled extension in third-party apps. There is no App Store or TestFlight download linked here.', 'Experimental'],
  Android: ['NepType for Android', 'An experimental Android keyboard is in development. It still needs an APK build and testing on a real device. No public download is available.', 'In development'],
  Windows: ['NepType for Windows', 'Windows input integration is an early TSF experiment. There is no working Windows keyboard release or public installer yet.', 'In development'],
  Linux: ['NepType for Linux', 'The experimental IBus adapter has local mock tests. Real Linux desktop installation and typing remain unverified. No public package is available.', 'Experimental']
};
function showDialog(heading, html) {
  title.textContent = heading;
  body.innerHTML = html;
  dialog.showModal();
}
document.querySelectorAll('[data-dialog]').forEach(button => button.addEventListener('click', () => showDialog(...content[button.dataset.dialog])));
document.querySelectorAll('[data-platform]').forEach(button => button.addEventListener('click', () => {
  const [heading, description, status] = platforms[button.dataset.platform];
  showDialog(heading, `<span class="status-tag">${status}</span><p>${description}</p><p>${projectLink}</p>`);
}));
document.querySelectorAll('a[href="#platforms"]').forEach(link => link.addEventListener('click', event => {
  event.preventDefault();
  showDialog('Find your platform.', '<p>Start with the Mac typing pad. Other platforms are being developed.</p>' + Object.entries(platforms).map(([name, data]) => `<details${name === 'macOS' ? ' open' : ''}><summary>${name} <span class="status-tag">${data[2]}</span></summary><p>${data[1]}</p></details>`).join('') + `<p>${projectLink}</p>`);
}));
document.querySelectorAll('.close-dialog,.dialog-done').forEach(button => button.addEventListener('click', () => dialog.close()));
dialog.addEventListener('click', event => {
  const bounds = dialog.getBoundingClientRect();
  if (event.target === dialog && (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom)) dialog.close();
});
const menu = document.querySelector('.mobile-menu');
menu.addEventListener('click', () => {
  const isOpen = menu.getAttribute('aria-expanded') !== 'true';
  menu.setAttribute('aria-expanded', String(isOpen));
  document.getElementById('nav-links').classList.toggle('open', isOpen);
});
document.querySelectorAll('.nav-links a,.nav-links button').forEach(link => link.addEventListener('click', () => {
  document.getElementById('nav-links').classList.remove('open');
  menu.setAttribute('aria-expanded', 'false');
}));
document.querySelectorAll('[data-word]').forEach(button => button.addEventListener('click', () => {
  document.getElementById('choice-output').textContent = button.dataset.word;
  document.querySelectorAll('[data-word]').forEach(option => {
    const selected = option === button;
    option.classList.toggle('selected', selected);
    option.setAttribute('aria-pressed', String(selected));
  });
}));
document.getElementById('copy-example').addEventListener('click', async () => {
  const status = document.querySelector('.copy-status');
  try {
    await navigator.clipboard.writeText('नमस्ते, भोलि meeting पछि भेटौँ।');
    status.textContent = 'Copied. Ready for your conversation.';
  } catch {
    status.textContent = 'Select and copy: नमस्ते, भोलि meeting पछि भेटौँ।';
  }
});
const nepaliCopy = {
  badge:'आफ्नै उपकरणमा। नेपालीका लागि।', headline:'तपाईंका विचार।<br>तपाईंको भाषा।', headlineAccent:'तपाईंको NepType।', description:'रोमन अक्षरमा टाइप गर्नुहोस्। नेपालीमा लेख्नुहोस्।<br>मनका कुरा आफ्नै भाषामा व्यक्त गर्नुहोस्।', cta:'Mac को पूर्वावलोकन हेर्नुहोस्', meta:'निर्माण हुँदैछ', offline:'अफलाइन चल्छ', source:'स्रोत हेर्नुहोस् ↗', featureEyebrow:'सहज लेखाइ। आफ्नै अभिव्यक्ति।', featuresTitle:'साना कुरामा ध्यान।<br>लेखाइमा सहजता।', featureIntro:'हामीले लेख्ने तरिकाका लागि।<br>अलिकति नेपाली। अलिकति English।', mixedTitle:'दुई भाषा। एउटै विचार।', mixedDescription:'Nepali + EN मोडमा परिचित अंग्रेजी शब्दहरू नेपालीसँगै राख्नुहोस्।', platformTitle:'तपाईंको उपकरणमा।', platformDescription:'Mac को typing pad बाट सुरु गर्नुहोस्। अन्य प्लेटफर्मको प्रगति हेर्नुहोस्।', privacyTitle:'तपाईंका शब्द, तपाईंसँगै।', privacyDescription:'लेखाइ तपाईंको उपकरणमै चल्छ। खाता वा क्लाउड प्रशोधन चाहिँदैन।', choiceTitle:'सही शब्द रोज्ने निर्णय तपाईंकै।', choiceDescription:'नाम, अर्थ वा हिज्जे। सुझाव रोज्नुहोस् वा आफ्नो मूल शब्द राख्नुहोस्।', flowTitle:'विचारबाट कुराकानीसम्म।', flowDescription:'प्याडमा लेख्नुहोस्, शब्द रोज्नुहोस् र नेपाली पाठ कपी गरेर कुराकानीमा लैजानुहोस्।', footerTagline:'घरको अलिक नजिक।'
};
const englishCopy = Object.fromEntries([...document.querySelectorAll('[data-copy]')].map(element => [element.dataset.copy, element.innerHTML]));
let language = 'en';
document.querySelector('.language').addEventListener('click', () => {
  language = language === 'en' ? 'ne' : 'en';
  document.documentElement.lang = language;
  const copy = language === 'ne' ? nepaliCopy : englishCopy;
  document.querySelectorAll('[data-copy]').forEach(element => { element.innerHTML = copy[element.dataset.copy]; });
  const toggle = document.querySelector('.language');
  toggle.innerHTML = language === 'ne' ? 'ने <span>⌄</span>' : 'EN <span>⌄</span>';
  toggle.setAttribute('aria-label', language === 'ne' ? 'Change language to English' : 'Change language to Nepali');
});
