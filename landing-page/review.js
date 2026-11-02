const previews = document.querySelectorAll('.preview');
const resizePreview = new ResizeObserver(entries => {
  entries.forEach(entry => {
    entry.target.querySelector('iframe').style.transform = `scale(${entry.contentRect.width / 1300})`;
  });
});
previews.forEach(preview => resizePreview.observe(preview));
