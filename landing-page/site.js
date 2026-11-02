const dialog = document.getElementById('info-dialog');
const dialogTitle = document.getElementById('dialog-title');
const dialogBody = document.getElementById('dialog-body');
const projectLink = '<a href="https://github.com/anuphunt/nep-type" target="_blank" rel="noopener noreferrer">View on GitHub ↗</a>';
const content = {
  faq: ['FAQ', '<details open><summary>How does it work?</summary><p>Type Roman letters in the pad. NepType suggests Nepali spellings, then you copy the result.</p></details><details><summary>Can I keep English words?</summary><p>Yes. Nepali + EN keeps recognized English words. You can also choose the original spelling.</p></details><details><summary>Do I need an internet connection?</summary><p>No. Typing runs on your device, without an account.</p></details><details><summary>Can I type directly in other apps?</summary><p>The Mac pad uses copy and paste. System keyboard support is still in development.</p></details>'],
  changelog: ['What’s new', '<p>The current Mac prototype has Nepali + EN and All Nepali modes, spelling suggestions, and copy controls.</p><p>Other platforms are in development.</p><p>' + projectLink + '</p>'],
  privacy: ['Privacy', '<p>The typing pad works offline. It has no accounts or telemetry.</p><p>Documents and undo history stay in memory. Copy what you need before quitting.</p><p>This website has no analytics. Fonts load from Google Fonts.</p>'],
  about: ['About NepType', '<p>NepType is an offline Nepali typing pad for Mac. It uses local dictionaries and phonetic rules to turn Roman letters into Nepali.</p><p>' + projectLink + '</p>']
};
const platforms = {
  macOS: ['NepType for Mac', 'The Mac typing pad is a local prototype. Build it from source to try it. A public installer isn’t available yet.', 'Prototype'],
  iOS: ['NepType for iPhone', 'The iPhone pad and keyboard are experimental. An App Store release isn’t available yet.', 'In progress'],
  Android: ['NepType for Android', 'The Android keyboard is in development. A download isn’t available yet.', 'In progress'],
  Windows: ['NepType for Windows', 'Windows support is in development. An installer isn’t available yet.', 'In progress'],
  Linux: ['NepType for Linux', 'Linux support is experimental. A public package isn’t available yet.', 'In progress']
};
function showDialog(heading, html) {
  dialogTitle.textContent = heading;
  dialogBody.innerHTML = html;
  dialog.showModal();
}
document.querySelectorAll('[data-dialog]').forEach(button => {
  button.addEventListener('click', () => showDialog(...content[button.dataset.dialog]));
});
document.querySelectorAll('[data-platform]').forEach(button => {
  button.addEventListener('click', () => {
    const [heading, description, status] = platforms[button.dataset.platform];
    showDialog(heading, `<span class="status-tag">${status}</span><p>${description}</p><p>${projectLink}</p>`);
  });
});
document.querySelectorAll('a[href="#platforms"]').forEach(link => {
  link.addEventListener('click', event => {
    event.preventDefault();
    const [heading, description, status] = platforms.macOS;
    showDialog(heading, `<span class="status-tag">${status}</span><p>${description}</p><p>${projectLink}</p>`);
  });
});
document.querySelectorAll('.close-dialog,.dialog-done').forEach(button => {
  button.addEventListener('click', () => dialog.close());
});
dialog.addEventListener('click', event => {
  const bounds = dialog.getBoundingClientRect();
  if (event.target === dialog && (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom)) dialog.close();
});
const menu = document.querySelector('.mobile-menu');
const navigation = document.getElementById('nav-links');
menu.addEventListener('click', () => {
  const isOpen = menu.getAttribute('aria-expanded') !== 'true';
  menu.setAttribute('aria-expanded', String(isOpen));
  navigation.classList.toggle('open', isOpen);
});
document.querySelectorAll('.nav-links a,.nav-links button').forEach(link => {
  link.addEventListener('click', () => {
    navigation.classList.remove('open');
    menu.setAttribute('aria-expanded', 'false');
  });
});
document.addEventListener('keydown', event => {
  if (event.key === 'Escape' && navigation.classList.contains('open')) {
    navigation.classList.remove('open');
    menu.setAttribute('aria-expanded', 'false');
    menu.focus();
  }
});
document.querySelectorAll('[data-word]').forEach(button => {
  button.addEventListener('click', () => {
    document.getElementById('choice-output').textContent = button.dataset.word;
    document.querySelectorAll('[data-word]').forEach(option => {
      const selected = option === button;
      option.classList.toggle('selected', selected);
      option.setAttribute('aria-pressed', String(selected));
    });
  });
});
document.getElementById('copy-example').addEventListener('click', async () => {
  const status = document.querySelector('.copy-status');
  try {
    await navigator.clipboard.writeText('नमस्ते, भोलि meeting पछि भेटौँ।');
    status.textContent = 'Copied.';
  } catch {
    status.textContent = 'Select to copy: नमस्ते, भोलि meeting पछि भेटौँ।';
  }
});
const nepaliCopy = {
  badge: 'नेपाली लेखौँ',
  headline: 'रोमनमा टाइप गर्नुहोस्।',
  headlineAccent: 'नेपालीमा लेख्नुहोस्।',
  description: 'नेपाली र English एउटै वाक्यमा लेख्नुहोस्।',
  cta: 'Mac का लागि NepType',
  offline: 'Mac प्रोटोटाइप',
  source: 'स्रोत हेर्नुहोस् ↗',
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
const englishCopy = Object.fromEntries([...document.querySelectorAll('[data-copy]')].map(element => [element.dataset.copy, element.innerHTML]));
let language = 'en';
document.querySelector('.language').addEventListener('click', () => {
  language = language === 'en' ? 'ne' : 'en';
  document.documentElement.lang = language;
  const copy = language === 'ne' ? nepaliCopy : englishCopy;
  document.querySelectorAll('[data-copy]').forEach(element => {
    element.innerHTML = copy[element.dataset.copy];
  });
  const toggle = document.querySelector('.language');
  toggle.innerHTML = language === 'ne' ? 'ने <span>⌄</span>' : 'EN <span>⌄</span>';
  toggle.setAttribute('aria-label', language === 'ne' ? 'Change language to English' : 'Change language to Nepali');
});
