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

/** TheKeep fixcos[0..64] = round(255·cos(i·π/128)) — wall U from s×fixcos. */
function fixcosTable() {
  const out = [];
  for (let i = 0; i <= 64; i++) {
    out.push(Math.max(0, Math.min(255, Math.round(255 * Math.cos((i * Math.PI) / 128)))));
  }
  return out;
}

// Wall columns are spaced linearly in ANGLE (angtab: 2*HALF_FOV_256/COLS units
// per column), but sprites are projected as v = 32*lateral/depth = 32*tan(theta).
// sprcol maps v (signed byte, index = v & 255) to the screen column whose wall
// ray has the same bearing, so billboards line up with the wall columns.
// Screen centre = x 20.0 (edge between columns 19 and 20).
const COL_ANGLE_RAD = ((2 * HALF_FOV_256) / COLS) * (2 * Math.PI / 256);
const SPR_PROJ = 32; // must match mul_recip_z (v*32/z)
const SPR_REJECT_POS = 100; // saturated v (|v|>=127): off-screen, culled by item_draw_one
const SPR_REJECT_NEG = 156;
const SPR_W_MIN = -16; // sprwscale covers centre cols -16..55 (item_draw_one cull range)
const SPR_W_MAX = 55;

function spriteColTable() {
  const out = [];
  for (let i = 0; i < 256; i++) {
    const v = (i << 24) >> 24;
    if (v >= 127) out.push(SPR_REJECT_POS);
    else if (v <= -127) out.push(SPR_REJECT_NEG);
    else out.push(Math.round(COLS / 2 + Math.atan(v / SPR_PROJ) / COL_ANGLE_RAD) & 0xff);
  }
  return out;
}

// Local columns per unit tan relative to the constant 32 used for sprite size:
// d(col)/d(tan) = cos^2(theta) / COL_ANGLE_RAD.  8-bit, 256 = 1.0 (saturated 255).
// Indexed by (centre col + 16): centre -16..55 -> 0..71.
function spriteWidthScaleTable() {
  const out = [];
  for (let c = SPR_W_MIN; c <= SPR_W_MAX; c++) {
    const theta = (c - COLS / 2) * COL_ANGLE_RAD;
    const t = Math.tan(theta);
    const slope = 1 / (COL_ANGLE_RAD * (1 + t * t));
    out.push(Math.max(1, Math.min(255, Math.round((256 * slope) / SPR_PROJ))));
  }
  return out;
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

/** Signed 8-bit sin for dt-scaled walk (AMP=64 → 1 tile/sec with (sin*dt)>>5). */
function sinTable() {
  const AMP = 64;
  const out = [];
  for (let i = 0; i < 256; i++) {
    const s = Math.round(AMP * Math.sin((i * 2 * Math.PI) / 256));
    out.push(s & 0xff);
  }
  return out;
}

// Must match SCREENBUFFER in squaredoom.asm
const SCREENBUFFER = 0xe000;
// Must match squaredoom.asm: level_map first at MEM_LEVEL (32-byte aligned)
const LEVEL_MAP = 0x96e0;

const angles = anglesTable();
const fishes = fishesTable(angles);
const { lo: secl, hi: sech } = secantTable();
const fixcos = fixcosTable();
const { lo: cblo, hi: cbhi } = colBaseTable(SCREENBUFFER);
const { lo: mrlo, hi: mrhi } = mapRowTable(LEVEL_MAP);
const sins = sinTable();

let asm = `; Auto-generated — TheKeep DDA tables + sintab + col/map bases\n`;
asm += emitBytes('angtab', angles);
asm += emitBytes('fishtab', fishes);
asm += emitBytes('fixsecl', secl);
asm += emitBytes('fixsech', sech);
asm += emitBytes('fixcos', fixcos);
asm += emitBytes('colbaselo', cblo);
asm += emitBytes('colbasehi', cbhi);
asm += emitBytes('maprowlo', mrlo);
asm += emitBytes('maprowhi', mrhi);
asm += emitBytes('sintab', sins.concat(sins.slice(0, 64)));
asm += 'costab = sintab + 64\t; cos(a) = sin(a+64); wrap bytes appended above\n';

writeFileSync(new URL('../tables.asm', import.meta.url), asm);

// Sprite projection tables live in the lo-code region (sourced from
// render_items.asm): the high-data region under py_tab has no slack.
let spr = `; Auto-generated by tools/gentables.js — sprite column projection tables\n`;
spr += emitBytes('sprcol', spriteColTable());
spr += emitBytes('sprwscale', spriteWidthScaleTable());
writeFileSync(new URL('../sprtab.asm', import.meta.url), spr);

console.log('wrote TheKeep tables + sintab/costab + fixcos + colbase + maprow + sprtab');
