import { createRequire } from 'module';
const require = createRequire(new URL('../shoot.mjs', import.meta.url));
const { chromium } = require('playwright');
import fs from 'fs';

const BASE = process.env.PARITY_MOCKUP_BASE || 'http://localhost:8756';
const PHONE_URL = `${BASE}/main-game-mockup.html`;
const TABLET_URL = `${BASE}/main-game-mockup-tablet.html`;
const OUT_DIR = process.env.PARITY_BASE;
if (!OUT_DIR) throw new Error('set PARITY_BASE to the output directory');

const DPR = 2;
const themes = ['paper', 'midnight', 'zen'];
const ratios = [
  { name: '9x16', width: 390, height: 693, url: PHONE_URL, kind: 'phone' },
  { name: '9x20', width: 393, height: 873, url: PHONE_URL, kind: 'phone' },
  { name: '3x4', width: 834, height: 1112, url: TABLET_URL, kind: 'tablet' },
];

const browser = await chromium.launch();
const results = [];

for (const theme of themes) {
  for (const ratio of ratios) {
    const page = await browser.newPage({
      deviceScaleFactor: DPR,
      viewport: { width: ratio.width, height: ratio.height },
    });
    await page.goto(ratio.url, { waitUntil: 'networkidle' });
    await page.evaluate((theme) => {
      document.body.setAttribute('data-theme', theme);
      document.body.classList.add('chrome-hidden');
      const toggle = document.querySelector('.chrome-toggle');
      if (toggle) toggle.style.display = 'none';
    }, theme);
    await page.waitForTimeout(300);

    const info = await page.evaluate(() => {
      const rectOf = (sel) => {
        const el = document.querySelector(sel);
        if (!el) return null;
        const r = el.getBoundingClientRect();
        return { left: r.left, right: r.right, top: r.top, bottom: r.bottom, width: r.width, height: r.height };
      };
      const styleLab = document.querySelector('.style-lab');
      return {
        chromeHidden: document.body.classList.contains('chrome-hidden'),
        styleLabVisible: styleLab ? getComputedStyle(styleLab).display !== 'none' : false,
        mistakesText: document.getElementById('mistakes')?.textContent?.trim(),
        hintText: document.querySelector('.action.hint .action-label')?.textContent?.replace(/\s+/g, ' ').trim(),
        themeAttr: document.body.getAttribute('data-theme'),
        errorCells: document.querySelectorAll('.cell.error').length,
        frame: rectOf('.phone') || rectOf('.tablet'),
        backButton: rectOf('#backButton'),
        mistakes: rectOf('.mistakes'),
        toolPanel: rectOf('.tool-panel'),
        board: rectOf('.board'),
        cells: rectOf('.cells'),
      };
    });

    const left = info.frame.left;
    const right = info.frame.right;
    const top = Math.min(info.backButton.top, info.mistakes.top);
    const bottom = info.toolPanel.bottom;

    const cropCss = { left, top, width: right - left, height: bottom - top };
    const cropPx = {
      x: Math.round(cropCss.left * DPR),
      y: Math.round(cropCss.top * DPR),
      w: Math.round(cropCss.width * DPR),
      h: Math.round(cropCss.height * DPR),
    };
    const relPx = (r) => ({
      x: Math.round((r.left - left) * DPR),
      y: Math.round((r.top - top) * DPR),
      w: Math.round(r.width * DPR),
      h: Math.round(r.height * DPR),
    });
    const boardPx = relPx(info.board);
    const cellsPx = relPx(info.cells);

    const outPath = `${OUT_DIR}/${theme}__${ratio.name}__mockup.png`;
    await page.screenshot({
      path: outPath,
      clip: { x: left, y: top, width: cropCss.width, height: cropCss.height },
    });

    results.push({
      theme, ratio: ratio.name, kind: ratio.kind, viewport: `${ratio.width}x${ratio.height}`,
      chromeHidden: info.chromeHidden, styleLabVisible: info.styleLabVisible,
      mistakesText: info.mistakesText, hintText: info.hintText, errorCells: info.errorCells,
      themeAttr: info.themeAttr, cropPx, boardPx, cellsPx, outPath,
    });

    await page.close();
  }
}

await browser.close();
console.log(JSON.stringify(results, null, 2));
