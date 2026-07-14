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

function colBaseTable(fb) {
  const lo = [];
  const hi = [];
  for (let col = 0; col < COLS; col++) {
    const addr = fb + col * 25;
    lo.push(addr & 0xff);
    hi.push(addr >> 8);
  }
  return { lo, hi };
}

function mapRowTable(levelMap) {
  const lo = [];
  const hi = [];
  for (let y = 0; y < 32; y++) {
    const addr = levelMap + y * 32;
    lo.push(addr & 0xff);
    hi.push(addr >> 8);
  }
  return { lo, hi };
}

/** Signed 8-bit sin for walk/strafe (amp fits comfy step in 8.8 world). */
function sinTable() {
  const AMP = 40;
  const out = [];
  for (let i = 0; i < 256; i++) {
    const s = Math.round(AMP * Math.sin((i * 2 * Math.PI) / 256));
    out.push(s & 0xff);
  }
  return out;
}

// Must match FRAMEBUFFER in squaredoom.asm / genblit.js
const FRAMEBUFFER = 0xc800;
// Must match squaredoom.asm: level_data=$a000, 7×256 SoA tables then map
const LEVEL_MAP = 0xa000 + 7 * 256;

const angles = anglesTable();
const fishes = fishesTable(angles);
const { lo: secl, hi: sech } = secantTable();
const { lo: cblo, hi: cbhi } = colBaseTable(FRAMEBUFFER);
const { lo: mrlo, hi: mrhi } = mapRowTable(LEVEL_MAP);
const sins = sinTable();

let asm = `; Auto-generated — TheKeep DDA tables + sintab + col/map bases\n`;
asm += emitBytes('angtab', angles);
asm += emitBytes('fishtab', fishes);
asm += emitBytes('fixsecl', secl);
asm += emitBytes('fixsech', sech);
asm += emitBytes('colbaselo', cblo);
asm += emitBytes('colbasehi', cbhi);
asm += emitBytes('maprowlo', mrlo);
asm += emitBytes('maprowhi', mrhi);
asm += emitBytes('sintab', sins);

writeFileSync(new URL('../tables.asm', import.meta.url), asm);
console.log('wrote Keep tables + sintab + colbase + maprow');
