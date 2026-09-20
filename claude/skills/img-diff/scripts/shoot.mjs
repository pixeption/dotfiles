#!/usr/bin/env node
// img-diff skill — screenshot one element from one page at a controlled, reproducible size.
//
// The whole point of this script is to make two renders comparable WITHOUT resizing either
// image afterwards — resizing to align mismatched sizes blurs edges and inflates the apparent
// difference (this is the #1 way an image-diff comparison lies to you). Two ways to get
// matching sizes:
//   1. Pass the same --width to both targets when they're both responsive to viewport width.
//   2. Pass --match-width <px> on the second shot: the script binary-searches the viewport
//      width until the target element's own rendered width converges on that px value, so two
//      pages with different internal chrome/padding still come out pixel-width-identical.
//
// Usage:
//   node shoot.mjs --url <url> --selector <css> --out <file.png> [options]
//
// Options:
//   --width <px>          viewport width (default 500)
//   --height <px>         viewport height (default 900)
//   --dpr <n>              deviceScaleFactor — supersampling, reduces antialiasing noise in the
//                          diff (default 2; use the same value for both shots)
//   --match-width <px>     binary-search the viewport width so the selector's own boundingBox()
//                          width lands within 0.5px of this value, instead of using --width verbatim
//   --eval <js>            page.evaluate() this snippet after load, before the screenshot (e.g. to
//                          flip a data-attribute: "document.querySelector('.phone').dataset.control='trackpad'")
//   --wait <ms>            extra wait after load/eval, for transitions/fonts to settle (default 150)
//   --full-page             screenshot the whole page instead of one selector (omit --selector)
//   --print-box             print the resolved element's boundingBox() to stderr (for sanity checks)
//
// Exactly one of --selector or --full-page is required.

import { chromium } from 'playwright';

function flag(name, fallback = null) {
  const i = process.argv.indexOf('--' + name);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}
function has(name) {
  return process.argv.includes('--' + name);
}

const url = flag('url');
const selector = flag('selector');
const out = flag('out');
const width = Number(flag('width', 500));
const height = Number(flag('height', 900));
const dpr = Number(flag('dpr', 2));
const matchWidth = flag('match-width') ? Number(flag('match-width')) : null;
const evalJs = flag('eval');
const waitMs = Number(flag('wait', 150));
const fullPage = has('full-page');
const printBox = has('print-box');

if (!url || !out || (!selector && !fullPage)) {
  console.error('usage: node shoot.mjs --url <url> --selector <css> --out <file.png> [--width px] [--match-width px] [--dpr n] [--eval "js"] [--wait ms]');
  console.error('       node shoot.mjs --url <url> --full-page --out <file.png> [...]');
  process.exit(2);
}

async function renderAt(browser, viewportWidth) {
  const page = await browser.newPage({ deviceScaleFactor: dpr, viewport: { width: viewportWidth, height } });
  await page.goto(url, { waitUntil: 'networkidle' });
  if (evalJs) await page.evaluate(evalJs);
  if (waitMs) await page.waitForTimeout(waitMs);
  return page;
}

const browser = await chromium.launch();

let page = await renderAt(browser, width);

if (matchWidth !== null) {
  if (!selector) {
    console.error('--match-width requires --selector (nothing to measure against on a --full-page shot)');
    process.exit(2);
  }
  // Binary search viewport width so the element's own rendered width converges on matchWidth.
  // Most layouts are monotonic in viewport width (wider viewport -> wider or equal element), so
  // this converges in a handful of iterations; if a layout has snap breakpoints it may not
  // converge exactly — check the printed box width against what you asked for.
  let lo = 100, hi = 3000;
  for (let i = 0; i < 20; i++) {
    const mid = Math.round((lo + hi) / 2);
    await page.close();
    page = await renderAt(browser, mid);
    const box = await page.$eval(selector, (el) => el.getBoundingClientRect().width);
    if (Math.abs(box - matchWidth) < 0.5) break;
    if (box < matchWidth) lo = mid; else hi = mid;
    if (hi - lo <= 1) { await page.close(); page = await renderAt(browser, hi); break; }
  }
}

let target;
if (fullPage) {
  await page.screenshot({ path: out, fullPage: true });
} else {
  target = await page.$(selector);
  if (!target) {
    console.error(`selector not found: ${selector}`);
    process.exit(1);
  }
  await target.screenshot({ path: out });
}

if (printBox && target) {
  const box = await target.boundingBox();
  console.error(`box: ${JSON.stringify(box)}  viewport: ${page.viewportSize().width}x${page.viewportSize().height}  dpr: ${dpr}`);
}

await browser.close();
