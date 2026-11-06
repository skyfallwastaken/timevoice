// The server renders data-theme/data-mode on <html>; these keep the browser
// chrome color in step and switch themes without a reload.

export function syncThemeColor() {
  const color = getComputedStyle(document.documentElement)
    .getPropertyValue("--color-bg-secondary")
    .trim();
  document
    .querySelector('meta[name="theme-color"]')
    ?.setAttribute("content", color);
}

export function applyTheme(key: string, mode: string) {
  const root = document.documentElement;
  // Swap every color at once instead of letting transition-colors fade some of them.
  root.classList.add("theme-switching");
  root.dataset.theme = key;
  root.dataset.mode = mode;
  syncThemeColor();
  requestAnimationFrame(() =>
    requestAnimationFrame(() => root.classList.remove("theme-switching")),
  );
}
