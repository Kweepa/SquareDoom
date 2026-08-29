/**
 * project_y offset table: py_tab[(dh-1)*256 + texstep_l] for dh 1..12.
 * Entry = min(ceil(dh*256/ts), 13) — identical to the old walk loops
 * (carry count / acc_h compare both stop at n = ceil(|dh|*256/texstep)),
 * clamped at 13 (the old CPX #25 / CPX #0 screen-edge stops).
 * For texstep_h=0 any |dh| >= 13 is always >= 14 rows → offscreen constant,
 * so 12 pages cover the whole lo path. ts=0 never occurs (calc_wallz).
 */
import { writeFileSync } from 'fs';

const DH_MAX = 12;
const CLAMP = 13;

let asm = `; Auto-generated — project_y screen-row offsets (see tools/genpytab.js)\n`;
asm += `; Placed at PY_TAB ($b000) by squaredoom.asm — page-aligned, flush to SQTAB $bc00\n`;
asm += `py_tab\n`;
for (let dh = 1; dh <= DH_MAX; dh++) {
  asm += `; dh = ${dh}\n`;
  const page = [];
  for (let ts = 0; ts < 256; ts++) {
    const n = ts === 0 ? CLAMP : Math.min(CLAMP, Math.ceil((dh * 256) / ts));
    page.push(n);
  }
  for (let i = 0; i < 256; i += 16) {
    const slice = page.slice(i, i + 16).map((b) => '$' + b.toString(16).padStart(2, '0'));
    asm += `\t!byte ${slice.join(',')}\n`;
  }
}

writeFileSync(new URL('../pytab.asm', import.meta.url), asm);
console.log('wrote py_tab (12 pages, dh 1..12)');
