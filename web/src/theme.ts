/** 主题三态：auto=跟随系统 / light=浅色 / dark=深色（存 localStorage，设置页可改）
 *  独立模块避免 main.ts ↔ App.vue 循环导入 */
export type KhTheme = 'auto' | 'light' | 'dark';
const THEME_KEY = 'kh_theme';
const mq = window.matchMedia('(prefers-color-scheme: dark)');

export function getSavedTheme(): KhTheme {
  const v = localStorage.getItem(THEME_KEY);
  return v === 'light' || v === 'dark' ? v : 'auto';
}

export function applyTheme() {
  const saved = getSavedTheme();
  const dark = saved === 'dark' || (saved === 'auto' && mq.matches);
  document.documentElement.classList.toggle('dark', dark);
}

export function setTheme(t: KhTheme) {
  localStorage.setItem(THEME_KEY, t);
  applyTheme();
  // 通知各视图（图谱等画布类）重渲染
  window.dispatchEvent(new CustomEvent('kh-theme-change'));
}

// 模块加载即应用主题；系统深浅色变化时仅在"跟随系统"模式下自动切换
applyTheme();
mq.addEventListener('change', () => {
  if (getSavedTheme() === 'auto') {
    applyTheme();
    window.dispatchEvent(new CustomEvent('kh-theme-change'));
  }
});
