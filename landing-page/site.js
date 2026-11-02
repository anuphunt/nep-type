import {configureDownloads} from './platform.mjs';
configureDownloads(document, navigator);

const dialog = document.getElementById('info-dialog');
const dialogTitle = document.getElementById('dialog-title');
const dialogBody = document.getElementById('dialog-body');
const isNepali = document.documentElement.lang === 'ne';
const projectLink = `<a href="https://github.com/anuphunt/nep-type" target="_blank" rel="noopener noreferrer">${isNepali ? 'GitHub मा हेर्नुहोस्' : 'View on GitHub'}</a>`;
const platforms = {
  macOS: ['NepType for Mac', 'Build NepType for Mac from source. A public installer isn’t available yet.', 'Open source'],
  iOS: ['NepType for iPhone', 'The iPhone pad and keyboard are experimental. An App Store release isn’t available yet.', 'In progress'],
  Android: ['NepType for Android', 'The Android keyboard is in development. A download isn’t available yet.', 'In progress'],
  Linux: ['NepType for Linux', 'Linux support is experimental. A public package isn’t available yet.', 'In progress']
};
const nepaliPlatforms = {
  iOS: ['iPhone का लागि NepType', 'iPhone प्याड र किबोर्ड परीक्षणको चरणमा छन्। App Store संस्करण उपलब्ध भइसकेको छैन।', 'काम हुँदैछ'],
  Android: ['Android का लागि NepType', 'Android किबोर्डको काम हुँदैछ। डाउनलोड उपलब्ध भइसकेको छैन।', 'काम हुँदैछ'],
  Linux: ['Linux का लागि NepType', 'Linux संस्करण परीक्षणको चरणमा छ। सार्वजनिक प्याकेज उपलब्ध भइसकेको छैन।', 'काम हुँदैछ']
};
function showDialog(heading, html) {
  dialogTitle.textContent = heading;
  dialogBody.innerHTML = html;
  dialog.showModal();
}
document.querySelectorAll('button[data-platform]').forEach(button => {
  button.addEventListener('click', () => {
    const [heading, description, status] = (isNepali ? nepaliPlatforms : platforms)[button.dataset.platform];
    showDialog(heading, `<span class="status-tag">${status}</span><p>${description}</p><p>${projectLink}</p>`);
  });
});
document.querySelectorAll('.close-dialog,.dialog-done').forEach(button => {
  button.addEventListener('click', () => dialog.close());
});
dialog?.addEventListener('click', event => {
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
document.getElementById('copy-example')?.addEventListener('click', async () => {
  const status = document.querySelector('.copy-status');
  try {
    await navigator.clipboard.writeText('नमस्ते, आज class छ।');
    status.textContent = isNepali ? 'कपी भयो।' : 'Copied.';
  } catch {
    status.textContent = isNepali ? 'कपी गर्न छान्नुहोस्: नमस्ते, आज class छ।' : 'Select to copy: नमस्ते, आज class छ।';
  }
});
