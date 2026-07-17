/**
 * Read itemgraphics/multicolour/shotgun_*.png → shotgun_weapon.asm
 *
 * Eight contiguous hi-res VIC sprites (low index = VIC front):
 *   flash white/red               → duplicated from pistol_sprites.asm (genpistol first)
 *   highlight                     → light grey (15), single-colour (over metal)
 *   barrel / bodyleft / bodyright → dark grey (11), single-colour
 *   hand                          → brown (9) + orange (8), Floyd–Steinberg
 *
 * Transparency: PNG alpha < 128 (or cyan chroma key).
 */
import { readFileSync, writeFileSync } from 'fs';
import { inflateSync } from 'zlib';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const imgDir = join(root, 'itemgraphics', 'multicolour');

const WIDTH = 24;
const HEIGHT = 21;
const MIN_SHARE = 0.30;

const BODY_LAYERS = [
  { label: 'shotgun_highlight', color: 15 },
  { label: 'shotgun_barrel', color: 11 },
  { label: 'shotgun_bodyleft', color: 11 },
  { label: 'shotgun_bodyright', color: 11 },
  { label: 'shotgun_brown', color: 9, rgb: [0x55, 0x3f, 0x00] },
  { label: 'shotgun_orange', color: 8, rgb: [0x8e, 0x50, 0x29] },
];

/** Pull a 64-byte sprite block from pistol_sprites.asm (flash duplicate). */
function extractPistolSprite(label) {
  const asm = readFileSync(join(root, 'pistol_sprites.asm'), 'utf8');
  const re = new RegExp(
    `${label}\\r?\\n((?:\\t!byte[^\\n]+\\r?\\n){8})`
  );
  const m = asm.match(re);
  if (!m) throw new Error(`pistol_sprites.asm missing ${label}`);
  return m[1].replace(/\r\n/g, '\n');
}

function decodePngRgba(buf) {
  if (buf[0] !== 0x89 || buf.toString('ascii', 1, 4) !== 'PNG') {
    throw new Error('not a PNG');
  }
  let off = 8;
  let width = 0;
  let height = 0;
  let bitDepth = 0;
  let colorType = 0;
  let palette = null;
  let trns = null;
  const idats = [];
  while (off + 8 <= buf.length) {
    const len = buf.readUInt32BE(off);
    const type = buf.toString('ascii', off + 4, off + 8);
    const data = buf.subarray(off + 8, off + 8 + len);
    off += 12 + len;
    if (type === 'IHDR') {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      bitDepth = data[8];
      colorType = data[9];
    } else if (type === 'PLTE') {
      palette = data;
    } else if (type === 'tRNS') {
      trns = data;
    } else if (type === 'IDAT') {
      idats.push(data);
    } else if (type === 'IEND') {
      break;
    }
  }
  const inflated = inflateSync(Buffer.concat(idats));

  const samples =
    colorType === 0 ? 1 :
    colorType === 2 ? 3 :
    colorType === 3 ? 1 :
    colorType === 4 ? 2 :
    colorType === 6 ? 4 :
    (() => { throw new Error(`unsupported colorType ${colorType}`); })();

  if (colorType === 3 && !palette) throw new Error('indexed PNG missing PLTE');

  const stride = Math.ceil((width * samples * bitDepth) / 8);
  const filterBpp = Math.max(1, Math.ceil((samples * bitDepth) / 8));

  const raw = Buffer.alloc(height * stride);
  let src = 0;
  let prev = Buffer.alloc(stride);
  for (let y = 0; y < height; y++) {
    const filter = inflated[src++];
    const row = inflated.subarray(src, src + stride);
    src += stride;
    const out = raw.subarray(y * stride, (y + 1) * stride);
    for (let i = 0; i < stride; i++) {
      const x = row[i];
      const a = i >= filterBpp ? out[i - filterBpp] : 0;
      const b = prev[i];
      const c = i >= filterBpp ? prev[i - filterBpp] : 0;
      let v;
      switch (filter) {
        case 0: v = x; break;
        case 1: v = (x + a) & 255; break;
        case 2: v = (x + b) & 255; break;
        case 3: v = (x + ((a + b) >> 1)) & 255; break;
        case 4: {
          const p = a + b - c;
          const pa = Math.abs(p - a);
          const pb = Math.abs(p - b);
          const pc = Math.abs(p - c);
          const pr = pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
          v = (x + pr) & 255;
          break;
        }
        default:
          throw new Error(`bad filter ${filter}`);
      }
      out[i] = v;
    }
    prev = Buffer.from(out);
  }

  const pixels = new Array(width * height);
  for (let y = 0; y < height; y++) {
    const row = raw.subarray(y * stride, (y + 1) * stride);
    for (let x = 0; x < width; x++) {
      let r, g, b, a = 255;
      if (colorType === 3 && bitDepth === 8) {
        const idx = row[x];
        r = palette[idx * 3];
        g = palette[idx * 3 + 1];
        b = palette[idx * 3 + 2];
        if (trns && idx < trns.length) a = trns[idx];
      } else if (colorType === 2 && bitDepth === 8) {
        const o = x * 3;
        r = row[o];
        g = row[o + 1];
        b = row[o + 2];
      } else if (colorType === 6 && bitDepth === 8) {
        const o = x * 4;
        r = row[o];
        g = row[o + 1];
        b = row[o + 2];
        a = row[o + 3];
      } else {
        throw new Error(`unsupported bitDepth ${bitDepth} colorType ${colorType}`);
      }
      pixels[y * width + x] = [r, g, b, a];
    }
  }
  return { width, height, pixels };
}

function isTransparent(rgba) {
  if (rgba[3] < 128) return true;
  // cyan chroma key (legacy pistol style)
  if (rgba[0] < 40 && rgba[1] > 200 && rgba[2] > 200) return true;
  return false;
}

function luminance(rgb) {
  return 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2];
}

function requireSize(name, width, height) {
  if (width !== WIDTH || height !== HEIGHT) {
    throw new Error(`${name}: expected ${WIDTH}×${HEIGHT}, got ${width}×${height}`);
  }
}

/** Single-colour: every opaque pixel → bit set. */
function maskSingle(pixels) {
  const mask = new Array(WIDTH * HEIGHT).fill(false);
  let n = 0;
  for (let i = 0; i < pixels.length; i++) {
    if (isTransparent(pixels[i])) continue;
    mask[i] = true;
    n++;
  }
  return { mask, n };
}

/** Floyd–Steinberg pair (brown/orange) on opaque pixels. */
function maskHandPair(pixels) {
  const opaque = [];
  let minL = Infinity;
  let maxL = -Infinity;
  for (let y = 0; y < HEIGHT; y++) {
    for (let x = 0; x < WIDTH; x++) {
      const rgba = pixels[y * WIDTH + x];
      if (isTransparent(rgba)) continue;
      const lum = luminance(rgba);
      opaque.push({ x, y, lum });
      if (lum < minL) minL = lum;
      if (lum > maxL) maxL = lum;
    }
  }
  const brown = new Array(WIDTH * HEIGHT).fill(false);
  const orange = new Array(WIDTH * HEIGHT).fill(false);
  if (opaque.length === 0) return { brown, orange, dark: 0, light: 0, bias: 0.5 };

  const span = Math.max(1e-6, maxL - minL);

  function classify(bias) {
    const err = new Float64Array(WIDTH * HEIGHT);
    const grid = new Array(WIDTH * HEIGHT).fill(-1);
    let light = 0;
    let dark = 0;
    const addErr = (x, y, e) => {
      if (x < 0 || x >= WIDTH || y < 0 || y >= HEIGHT) return;
      if (isTransparent(pixels[y * WIDTH + x])) return;
      err[y * WIDTH + x] += e;
    };
    for (let y = 0; y < HEIGHT; y++) {
      const ltr = (y & 1) === 0;
      for (let xi = 0; xi < WIDTH; xi++) {
        const x = ltr ? xi : WIDTH - 1 - xi;
        const pi = y * WIDTH + x;
        if (isTransparent(pixels[pi])) continue;
        const n = (luminance(pixels[pi]) - minL) / span + err[pi];
        const isLight = n > bias;
        grid[pi] = isLight ? 1 : 0;
        if (isLight) light++;
        else dark++;
        const quant = isLight ? 1 : 0;
        const e = n - quant;
        if (ltr) {
          addErr(x + 1, y, (e * 7) / 16);
          addErr(x - 1, y + 1, (e * 3) / 16);
          addErr(x, y + 1, (e * 5) / 16);
          addErr(x + 1, y + 1, (e * 1) / 16);
        } else {
          addErr(x - 1, y, (e * 7) / 16);
          addErr(x + 1, y + 1, (e * 3) / 16);
          addErr(x, y + 1, (e * 5) / 16);
          addErr(x - 1, y + 1, (e * 1) / 16);
        }
      }
    }
    return { grid, light, dark };
  }

  let best = null;
  let bestScore = -Infinity;
  for (let bias = 0.2; bias <= 0.8; bias += 0.005) {
    const r = classify(bias);
    const n = opaque.length;
    const shareL = r.light / n;
    const shareD = r.dark / n;
    const ok = shareL >= MIN_SHARE && shareD >= MIN_SHARE;
    const score = ok ? 1000 - Math.abs(shareL - 0.45) : Math.min(shareL, shareD);
    if (score > bestScore) {
      bestScore = score;
      best = { bias, ...r, ok };
    }
  }

  if (!best.ok) {
    const r = classify(best.bias);
    const n = opaque.length;
    const needLight = Math.ceil(MIN_SHARE * n) - r.light;
    const needDark = Math.ceil(MIN_SHARE * n) - r.dark;
    const ranked = opaque
      .map((s) => ({ ...s, n: (s.lum - minL) / span, pi: s.y * WIDTH + s.x }))
      .sort((a, b) => a.n - b.n);
    if (needLight > 0) {
      for (let k = ranked.length - 1, flipped = 0; k >= 0 && flipped < needLight; k--) {
        if (r.grid[ranked[k].pi] === 0) {
          r.grid[ranked[k].pi] = 1;
          r.light++;
          r.dark--;
          flipped++;
        }
      }
    } else if (needDark > 0) {
      for (let k = 0, flipped = 0; k < ranked.length && flipped < needDark; k++) {
        if (r.grid[ranked[k].pi] === 1) {
          r.grid[ranked[k].pi] = 0;
          r.dark++;
          r.light--;
          flipped++;
        }
      }
    }
    best = { bias: best.bias, ...r, ok: true };
  }

  for (let pi = 0; pi < WIDTH * HEIGHT; pi++) {
    if (best.grid[pi] === 0) brown[pi] = true;
    else if (best.grid[pi] === 1) orange[pi] = true;
  }
  return { brown, orange, dark: best.dark, light: best.light, bias: best.bias };
}

function packSprite(mask) {
  const bytes = [];
  for (let y = 0; y < HEIGHT; y++) {
    for (let byte = 0; byte < 3; byte++) {
      let b = 0;
      for (let bit = 0; bit < 8; bit++) {
        const x = byte * 8 + bit;
        if (mask[y * WIDTH + x]) b |= 0x80 >> bit;
      }
      bytes.push(b);
    }
  }
  bytes.push(0);
  return bytes;
}

function fmtBytes(bytes) {
  const lines = [];
  for (let i = 0; i < bytes.length; i += 8) {
    const chunk = bytes.slice(i, i + 8);
    lines.push(`\t!byte ${chunk.map((b) => `$${b.toString(16).padStart(2, '0')}`).join(',')}`);
  }
  return lines.join('\n');
}

function loadPng(file) {
  const { width, height, pixels } = decodePngRgba(readFileSync(join(imgDir, file)));
  requireSize(file, width, height);
  return pixels;
}

const masks = [];
const info = [];

// Single-colour metal parts (highlight first = over barrel/body)
for (const [file, idx] of [
  ['shotgun_highlight.png', 0],
  ['shotgun_barrel.png', 1],
  ['shotgun_bodyleft.png', 2],
  ['shotgun_bodyright.png', 3],
]) {
  const pixels = loadPng(file);
  const { mask, n } = maskSingle(pixels);
  masks[idx] = mask;
  info.push(`${file}: opaque=${n} → ${BODY_LAYERS[idx].label} colour ${BODY_LAYERS[idx].color}`);
}

// Hand → brown + orange
{
  const pixels = loadPng('shotgun_hand.png');
  const { brown, orange, dark, light, bias } = maskHandPair(pixels);
  masks[4] = brown;
  masks[5] = orange;
  info.push(
    `shotgun_hand.png: bias=${bias.toFixed(3)} brown=${dark} orange=${light}`
  );
}

const flashWhite = extractPistolSprite('pistol_flash_white');
const flashRed = extractPistolSprite('pistol_flash_red');
info.push('flash: duplicated from pistol_flash_white/red');

let asm = `; Auto-generated from itemgraphics/multicolour/shotgun_*.png - do not edit\n`;
asm += `; Eight contiguous layers (low VIC # = front): flash, highlight, metal, hand:\n`;
asm += `;   highlight = light grey(15) over barrel/bodyleft/bodyright dark grey(11),\n`;
asm += `;   hand = brown(9)+orange(8) Floyd-Steinberg. Alpha/cyan = transparent.\n`;
asm += `!zone shotgun_weapon\n\n`;

asm += `shotgun_flash_white\n`;
asm += flashWhite;
asm += `shotgun_flash_red\n`;
asm += flashRed;

for (let i = 0; i < BODY_LAYERS.length; i++) {
  const packed = packSprite(masks[i]);
  if (packed.length !== 64) throw new Error('sprite must be 64 bytes');
  asm += `${BODY_LAYERS[i].label}\n`;
  asm += fmtBytes(packed);
  asm += `\n`;
}

writeFileSync(join(root, 'shotgun_weapon.asm'), asm);
console.log('wrote shotgun_weapon.asm (8×64 bytes; flash duplicated from pistol)');
for (const line of info) console.log(' ', line);
