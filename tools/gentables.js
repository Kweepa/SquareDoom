/**
 * TheKeep-style DDA tables: angles, fishes, fixsec (40 columns).
 */
import { writeFileSync } from 'fs';

const COLS = 40;
const HALF_FOV_256 = 30;

function emitBytes(label, arr, perLine = 16) {
  let s = `${label}\n`;
  for (let i = 0; i < arr.length; i += perLine) {
    const slice = arr.slice(i, i + perLine).map((b) => '$' + (b & 0xff).toString(16).padStart(2, '0'));
    s += `\t!byte ${slice.join(',')}\n`;
  }
  return s;
}

function anglesTable() {
  const out = [];
  for (let col = 0; col < COLS; col++) {
    const t = (col + 0.5) / COLS - 0.5;
    out.push((Math.round(t * 2 * HALF_FOV_256) + 256) & 0xff);
  }
  return out;
}

function fishesTable(angles) {
  return angles.map((a) => {
    const signed = (a << 24) >> 24;
    const rad = (signed * 2 * Math.PI) / 256;
    return Math.max(1, Math.min(255, Math.round(255 * Math.cos(rad))));
  });
}

function secantTable() {
  const lo = [];
  const hi = [];
  for (let i = 0; i <= 64; i++) {
    const ang = (i * Math.PI) / 128;
    const c = Math.abs(Math.cos(ang));
    const sec = Math.min(0x4000, Math.round(256 / Math.max(c, 0.004)));
    lo.push(sec & 0xff);
    hi.push((sec >> 8) & 0xff);
  }
  return { lo, hi };
}

function row40() {
  const lo = [];
  const hi = [];
  for (let r = 0; r < 25; r++) {
    const v = r * 40;
    lo.push(v & 0xff);
    hi.push(v >> 8);
  }
  return { lo, hi };
}

const angles = anglesTable();
const fishes = fishesTable(angles);
const { lo: secl, hi: sech } = secantTable();
const { lo: r40lo, hi: r40hi } = row40();

let asm = `; Auto-generated — TheKeep DDA tables\n`;
asm += emitBytes('angtab', angles);
asm += emitBytes('fishtab', fishes);
asm += emitBytes('fixsecl', secl);
asm += emitBytes('fixsech', sech);
asm += emitBytes('row40lo', r40lo);
asm += emitBytes('row40hi', r40hi);

writeFileSync(new URL('../tables.asm', import.meta.url), asm);
console.log('wrote Keep tables');
