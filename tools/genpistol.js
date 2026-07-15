/**
 * Read pistol_weapon.png + pistol_hand.png (24×21, cyan transparent) and emit
 * pistol_sprites.asm: four dithered hi-res VIC sprite layers.
 *   weapon → black (0) + dark grey (11)
 *   hand   → brown (9) + orange (8)
 *
 * Luminance Bayer dither; brightness bias tuned so each pair is ≥30% / colour.
 */
import { readFileSync, writeFileSync } from 'fs';
import { inflateSync } from 'zlib';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

const WIDTH = 24;
const HEIGHT = 21;
const MIN_SHARE = 0.30;

// Project C64_HEX RGB (output order = sprite pointers 0–3)
const LAYERS = [
  { label: 'pistol_dark', color: 0, rgb: [0x00, 0x00, 0x00] },  // black
  { label: 'pistol_light', color: 11, rgb: [0x4a, 0x4a, 0x4a] }, // dark grey (bright half)
  { label: 'pistol_brown', color: 9, rgb: [0x55, 0x3f, 0x00] },
  { label: 'pistol_orange', color: 8, rgb: [0x8e, 0x50, 0x29] },
];

const SOURCES = [
  { file: 'pistol_weapon.png', darkIdx: 0, lightIdx: 1 },
  { file: 'pistol_hand.png', darkIdx: 2, lightIdx: 3 },
];

function decodePngRgb(buf) {
  if (buf[0] !== 0x89 || buf.toString('ascii', 1, 4) !== 'PNG') {
    throw new Error('not a PNG');
  }
  let off = 8;
  let width = 0;
  let height = 0;
  let bitDepth = 0;
  let colorType = 0;
  let palette = null;
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
      let r, g, b;
      if (colorType === 3 && bitDepth === 8) {
        const idx = row[x];
        r = palette[idx * 3];
        g = palette[idx * 3 + 1];
        b = palette[idx * 3 + 2];
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
      } else {
        throw new Error(`unsupported bitDepth ${bitDepth} colorType ${colorType}`);
      }
      pixels[y * width + x] = [r, g, b];
    }
  }
  return { width, height, pixels };
}

function isCyan(rgb) {
  if (rgb[0] === 0 && rgb[1] === 255 && rgb[2] === 255) return true;
  return rgb[0] < 40 && rgb[1] > 200 && rgb[2] > 200;
}

function luminance(rgb) {
  return 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2];
}

/**
 * Floyd–Steinberg to two colours on luminance.
 * Fine-grained (pixel-level) so X/Y expand doesn't bloom into Bayer blotches.
 * Searches threshold bias so each colour gets ≥ MIN_SHARE.
 *
 * Returns dense Width×Height layer indices (−1 = transparent).
 */
function assignPairFS(pixels, darkIdx, lightIdx) {
  const opaque = [];
  let minL = Infinity;
  let maxL = -Infinity;
  for (let y = 0; y < HEIGHT; y++) {
    for (let x = 0; x < WIDTH; x++) {
      const rgb = pixels[y * WIDTH + x];
      if (isCyan(rgb)) continue;
      const lum = luminance(rgb);
      opaque.push({ x, y, lum });
      if (lum < minL) minL = lum;
      if (lum > maxL) maxL = lum;
    }
  }
  if (opaque.length === 0) {
    return { bias: 0.5, dark: 0, light: 0, grid: new Array(WIDTH * HEIGHT).fill(-1) };
  }
  const span = Math.max(1e-6, maxL - minL);

  function classify(bias) {
    const err = new Float64Array(WIDTH * HEIGHT);
    const grid = new Array(WIDTH * HEIGHT).fill(-1);
    let light = 0;
    let dark = 0;

    const addErr = (x, y, e) => {
      if (x < 0 || x >= WIDTH || y < 0 || y >= HEIGHT) return;
      if (isCyan(pixels[y * WIDTH + x])) return;
      err[y * WIDTH + x] += e;
    };

    for (let y = 0; y < HEIGHT; y++) {
      // Serpentine: alternate scan direction to avoid directional striping
      const ltr = (y & 1) === 0;
      for (let xi = 0; xi < WIDTH; xi++) {
        const x = ltr ? xi : WIDTH - 1 - xi;
        const pi = y * WIDTH + x;
        if (isCyan(pixels[pi])) continue;

        const n = (luminance(pixels[pi]) - minL) / span + err[pi];
        const isLight = n > bias;
        grid[pi] = isLight ? lightIdx : darkIdx;
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
    // Prefer midtones split near 40–60%; don't force exact 50%
    const score = ok
      ? 1000 - Math.abs(shareL - 0.45)
      : Math.min(shareL, shareD);
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
        if (r.grid[ranked[k].pi] === darkIdx) {
          r.grid[ranked[k].pi] = lightIdx;
          r.light++;
          r.dark--;
          flipped++;
        }
      }
    } else if (needDark > 0) {
      for (let k = 0, flipped = 0; k < ranked.length && flipped < needDark; k++) {
        if (r.grid[ranked[k].pi] === lightIdx) {
          r.grid[ranked[k].pi] = darkIdx;
          r.dark++;
          r.light--;
          flipped++;
        }
      }
    }
    best = { bias: best.bias, ...r, ok: true };
  }

  return best;
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

const masks = LAYERS.map(() => new Array(WIDTH * HEIGHT).fill(false));
const counts = [0, 0, 0, 0];
const srcInfo = [];

for (const src of SOURCES) {
  const png = readFileSync(join(root, src.file));
  const { width, height, pixels } = decodePngRgb(png);
  if (width !== WIDTH || height !== HEIGHT) {
    throw new Error(`${src.file}: expected ${WIDTH}×${HEIGHT}, got ${width}×${height}`);
  }

  let opaqueCount = 0;
  for (let y = 0; y < HEIGHT; y++) {
    for (let x = 0; x < WIDTH; x++) {
      if (!isCyan(pixels[y * WIDTH + x])) opaqueCount++;
    }
  }

  const result = assignPairFS(pixels, src.darkIdx, src.lightIdx);
  for (let pi = 0; pi < WIDTH * HEIGHT; pi++) {
    const layer = result.grid[pi];
    if (layer < 0) continue;
    for (let li = 0; li < LAYERS.length; li++) {
      if (masks[li][pi]) {
        masks[li][pi] = false;
        counts[li]--;
      }
    }
    masks[layer][pi] = true;
    counts[layer]++;
  }

  const n = opaqueCount;
  srcInfo.push(
    `${src.file}: n=${n} bias=${result.bias.toFixed(3)} ` +
    `dark=${result.dark} (${((100 * result.dark) / n).toFixed(0)}%) ` +
    `light=${result.light} (${((100 * result.light) / n).toFixed(0)}%)`
  );
}

let asm = `; Auto-generated from pistol_weapon.png + pistol_hand.png — do not edit\n`;
asm += `; Overlays: black(0)+dark grey(11) weapon, brown(9)+orange(8) hand; cyan transparent\n`;
asm += `; Serpentine Floyd–Steinberg dither, ≥${(MIN_SHARE * 100) | 0}% each colour per pair\n`;
asm += `!zone pistol_sprites\n\n`;

for (let i = 0; i < LAYERS.length; i++) {
  const packed = packSprite(masks[i]);
  if (packed.length !== 64) throw new Error('sprite must be 64 bytes');
  asm += `${LAYERS[i].label}\n`;
  asm += fmtBytes(packed);
  asm += `\n`;
}

writeFileSync(join(root, 'pistol_sprites.asm'), asm);
console.log('wrote pistol_sprites.asm');
for (const line of srcInfo) console.log(' ', line);
console.log(
  `  totals: dark(0)=${counts[0]} light(11)=${counts[1]} brown(9)=${counts[2]} orange(8)=${counts[3]}`
);
