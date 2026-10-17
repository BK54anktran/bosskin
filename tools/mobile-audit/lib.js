const { chromium } = require(process.env.NODE_PATH + '/playwright');
const BASE = process.env.BASE || 'http://127.0.0.1:3000';
const W = +(process.env.VW || 390), H = +(process.env.VH || 844);
async function launch() {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium', args: ['--no-sandbox'] });
  const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2, locale: 'vi-VN' });
  await ctx.route(/\/v\d+\/(assets|canvaskit|icons|fonts)\//, r => r.continue({ url: r.request().url().replace(/\/v\d+\//, '/') }));
  const page = await ctx.newPage();
  const logs = [];
  page.on('console', m => { const t = m.text(); logs.push(t); });
  page.on('pageerror', e => logs.push('PAGEERROR ' + e.message));
  return { browser, ctx, page, logs };
}
async function waitApp(page, ms = 90000) {
  await page.waitForSelector('flt-glass-pane, flutter-view, flt-scene-host', { timeout: ms, state: 'attached' });
  await page.waitForTimeout(2500);
  await page.evaluate(() => { const p = document.querySelector('flt-semantics-placeholder'); if (p) p.click(); });
  await page.waitForTimeout(1200);
}
async function labels(page) {
  return page.evaluate(() => Array.from(document.querySelectorAll('flt-semantics')).map(e => {
    const r = e.getBoundingClientRect();
    return { role: e.getAttribute('role') || '', label: (e.getAttribute('aria-label') || e.textContent || '').trim().slice(0, 60), x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) };
  }).filter(e => e.w > 1 && e.h > 1 && e.label));
}
module.exports = { launch, waitApp, labels, BASE, W, H };
