/**
 * Read itemgraphics/*.png → item_bitmaps.asm (column-major C64 colour mips).
 * Game build only — no editor imports. Fails if any ITEM_TYPES PNG is missing.
 *
 * Spawn and enemy types (soldier…baron) skip atlases — nodraw stub / enemy_sprites.
 * Other types require a 12×8 mip atlas PNG.
 */
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { inflateSync } from 'zlib';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const gfxDir = join(root, 'itemgraphics');

const ITEM_TYPES = [
  'spawn', 'soldier', 'imp', 'pinky', 'caco', 'baron', 'barrel',
  'health', 'shells', 'shotgun', 'chaingun', 'chainsaw', 'rocketlauncher',
  'greenarmor', 'bluearmor', 'backpack',
  'redcard', 'bluecard', 'yellowcard',
  'soulsphere',
  'radsuit',
  'poscorpse', 'impcorpse', 'demoncorpse', 'baroncorpse',
  'skullpile', 'techcolumn',
  'switch',
  'fireball',
  'plasmaball', 'rocket',
  'barexpl',
];

/** No item atlas: spawn/enemies use other paths; switch is wall_switch.asm. */
const SKIP_ITEM_ATLAS = new Set([
  'spawn', 'soldier', 'imp', 'pinky', 'caco', 'baron',
  'switch',
]);

const ATLAS_W = 12;
const ATLAS_H = 8;

const MIPS = [
  { name: 'm0', w: 8, h: 8, x0: 0, y0: 0 },
  { name: 'm1', w: 4, h: 4, x0: 8, y0: 0 },
  { name: 'm2', w: 2, h: 2, x0: 8, y0: 4 },
  { name: 'm3', w: 1, h: 1, x0: 8, y0: 6 },
];

/** Pepto C64 palette (duplicated — not from editor). */
const C64_RGB = [
  [0x00, 0x00, 0x00],
  [0xff, 0xff, 0xff],
  [0x81, 0x33, 0x38],
  [0x75, 0xce, 0xc8],
  [0x8e, 0x3c, 0x97],
  [0x56, 0xac, 0x4d],
  [0x40, 0x31, 0x8d],
  [0xbf, 0xce, 0x72],
  [0x8e, 0x50, 0x29],
  [0x55, 0x3f, 0x00],
  [0xc4, 0x6c, 0x71],
  [0x4a, 0x4a, 0x4a],
  [0x7b, 0x7b, 0x7b],
  [0xa9, 0xff, 0x9f],
  [0x70, 0x6d, 0xeb],
  [0xb2, 0xb2, 0xb2],
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
  const hasAlpha = colorType === 4 || colorType === 6 || trns != null;
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
        r = row[o]; g = row[o + 1]; b = row[o + 2];
      } else if (colorType === 6 && bitDepth === 8) {
        const o = x * 4;
        r = row[o]; g = row[o + 1]; b = row[o + 2]; a = row[o + 3];
      } else if (colorType === 0 && bitDepth === 8) {
        r = g = b = row[x];
      } else {
        throw new Error(`unsupported bitDepth ${bitDepth} colorType ${colorType}`);
      }
      pixels[y * width + x] = [r, g, b, a];
    }
  }
  return { width, height, pixels, hasAlpha };
}

/** Clear: alpha/tRNS when present; otherwise legacy black RGB. */
function isTransparent(rgba, hasAlpha) {
  if (hasAlpha) return rgba[3] < 128;
  return rgba[0] === 0 && rgba[1] === 0 && rgba[2] === 0;
}

/** sRGB 0–255 → CIE Lab (D65). RGB Euclidean mis-maps warm reds to orange. */
function rgb2lab(r, g, b) {
  r /= 255;
  g /= 255;
  b /= 255;
  r = r > 0.04045 ? ((r + 0.055) / 1.055) ** 2.4 : r / 12.92;
  g = g > 0.04045 ? ((g + 0.055) / 1.055) ** 2.4 : g / 12.92;
  b = b > 0.04045 ? ((b + 0.055) / 1.055) ** 2.4 : b / 12.92;
  let x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047;
  let y = (r * 0.2126 + g * 0.7152 + b * 0.0722) / 1.0;
  let z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883;
  x = x > 0.008856 ? x ** (1 / 3) : 7.787 * x + 16 / 116;
  y = y > 0.008856 ? y ** (1 / 3) : 7.787 * y + 16 / 116;
  z = z > 0.008856 ? z ** (1 / 3) : 7.787 * z + 16 / 116;
  return [116 * y - 16, 500 * (x - y), 200 * (y - z)];
}

const C64_LAB = C64_RGB.map(([r, g, b]) => rgb2lab(r, g, b));

/** Near-achromatic: Lab is nearly equidistant between dark/medium grey for
 *  source tones like #626262 and picks medium; RGB Euclidean picks dark. */
function isNearGrey(rgb) {
  return Math.max(rgb[0], rgb[1], rgb[2]) - Math.min(rgb[0], rgb[1], rgb[2]) <= 16;
}

// allowBlack only for PNGs with alpha/tRNS (opaque black ≠ clear).
// Chromatic: CIE Lab (RGB Euclidean mis-maps warm reds to orange).
// Near-grey: RGB Euclidean (Lab mis-maps dark↔medium).
function nearestC64(rgb, allowBlack) {
  const start = allowBlack ? 0 : 1;
  let best = start;
  let bestD = Infinity;
  if (isNearGrey(rgb)) {
    for (let i = start; i < 16; i++) {
      const c = C64_RGB[i];
      const d =
        (rgb[0] - c[0]) ** 2 + (rgb[1] - c[1]) ** 2 + (rgb[2] - c[2]) ** 2;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }
  const lab = rgb2lab(rgb[0], rgb[1], rgb[2]);
  for (let i = start; i < 16; i++) {
    const c = C64_LAB[i];
    const d =
      (lab[0] - c[0]) ** 2 + (lab[1] - c[1]) ** 2 + (lab[2] - c[2]) ** 2;
    if (d < bestD) {
      bestD = d;
      best = i;
    }
  }
  return best;
}

function fmtBytes(bytes) {
  const lines = [];
  for (let i = 0; i < bytes.length; i += 16) {
    const chunk = bytes.slice(i, i + 16);
    lines.push(`\t!byte ${chunk.map((b) => `$${b.toString(16).padStart(2, '0')}`).join(',')}`);
  }
  return lines.join('\n');
}

// $ff = clear (so C64 black $00 can be opaque when PNG has alpha); see .id_skip
const ITEM_CLEAR = 0xff;

function extractMip(pixels, atlasW, mip, hasAlpha) {
  const col = [];
  for (let x = 0; x < mip.w; x++) {
    for (let y = 0; y < mip.h; y++) {
      const rgba = pixels[(mip.y0 + y) * atlasW + (mip.x0 + x)];
      col.push(
        isTransparent(rgba, hasAlpha) ? ITEM_CLEAR : nearestC64(rgba, hasAlpha),
      );
    }
  }
  return col;
}

if (!existsSync(gfxDir)) {
  console.error(`missing ${gfxDir} — place item PNGs there (game build does not use editor/)`);
  process.exit(1);
}

const allLabels = [];
const typeBlocks = [];
let totalBytes = 0;
const missingMips = [];
let needNodrawStub = false;

for (const type of ITEM_TYPES) {
  if (SKIP_ITEM_ATLAS.has(type)) {
    // Keep typeId*4+mip indexing; point at shared transparent stub.
    needNodrawStub = true;
    for (let i = 0; i < MIPS.length; i++) {
      allLabels.push('item_spr_nodraw');
    }
    continue;
  }
  let path = join(gfxDir, `${type}.png`);
  if (!existsSync(path)) {
    path = join(gfxDir, 'multicolour', `${type}.png`);
  }
  if (!existsSync(path)) {
    missingMips.push(`${type}: missing file ${type}.png (itemgraphics/ or multicolour/)`);
    continue;
  }
  const { width, height, pixels, hasAlpha } = decodePngRgb(readFileSync(path));
  if (width !== ATLAS_W || height !== ATLAS_H) {
    missingMips.push(
      `${type}: need 12×8 mip atlas (${path} is ${width}×${height})`,
    );
    continue;
  }
  const labels = [];
  for (const mip of MIPS) {
    const label = `item_spr_${type}_${mip.name}`;
    const bytes = extractMip(pixels, ATLAS_W, mip, hasAlpha);
    labels.push({ label, bytes });
    allLabels.push(label);
    totalBytes += bytes.length;
  }
  typeBlocks.push({ type, labels });
}

if (missingMips.length) {
  console.error('missing item mips (expected 12×8: mip0 8×8 left, mips 1–3 on right):');
  for (const line of missingMips) {
    console.error(`  ${line}`);
  }
  process.exit(1);
}

let asm = `; Auto-generated from itemgraphics/*.png — do not edit\n`;
asm += `; 12×8 atlases: mip0 8×8 left; mips 1–3 on right. Column-major, $ff = clear\n`;
asm += `; Clear = PNG alpha/tRNS if present, else black RGB. Opaque black only with alpha.\n`;
asm += `; spawn/enemies/switch skip atlases (nodraw stub / enemy_sprites / wall_switch).\n`;
asm += `!zone item_bitmaps\n\n`;
asm += `ITEM_TYPE_COUNT = ${ITEM_TYPES.length}\n`;
asm += `ITEM_MIP_COUNT = ${MIPS.length}\n\n`;

asm += `; mip source width / height / log2 (index = mip 0..3)\n`;
asm += `item_mip_w\n`;
asm += `\t!byte ${MIPS.map((m) => m.w).join(',')}\n`;
asm += `item_mip_h\n`;
asm += `\t!byte ${MIPS.map((m) => m.h).join(',')}\n`;
asm += `item_mip_ushift\n`;
asm += `\t!byte ${MIPS.map((m) => Math.log2(m.w)).join(',')}\n`;
asm += `item_mip_vshift\n`;
asm += `\t!byte ${MIPS.map((m) => Math.log2(m.h)).join(',')}\n\n`;

asm += `; Base address lo/hi: index = typeId * ITEM_MIP_COUNT + mip\n`;
asm += `item_mip_base_lo\n`;
asm += `\t!byte ${allLabels.map((l) => `<${l}`).join(',')}\n`;
asm += `item_mip_base_hi\n`;
asm += `\t!byte ${allLabels.map((l) => `>${l}`).join(',')}\n\n`;

// Shared column offsets for item/enemy mip heights 1,2,4,8,16,32.
// Index = log2(height)*16 + bmp_x; unused bmp_x entries are harmless.
const mipColOffsets = [];
for (let shift = 0; shift <= 5; shift++) {
  for (let x = 0; x < 16; x++) mipColOffsets.push(x << shift);
}
asm += `; bmp_x * mip_height; index = vshift*16 + bmp_x\n`;
asm += `mip_col_off_lo\n${fmtBytes(mipColOffsets.map((v) => v & 0xff))}\n`;
asm += `mip_col_off_hi\n${fmtBytes(mipColOffsets.map((v) => v >> 8))}\n\n`;

if (needNodrawStub) {
  asm += `; Transparent stub for spawn / enemy typeIds (never drawn as items)\n`;
  asm += `item_spr_nodraw\n`;
  asm += `\t!byte $ff\n\n`;
}

asm += `; Per-type mip blobs\n`;
for (const block of typeBlocks) {
  for (const { label, bytes } of block.labels) {
    asm += `${label}\n`;
    asm += fmtBytes(bytes);
    asm += `\n`;
  }
}

writeFileSync(join(root, 'item_bitmaps.asm'), asm);
console.log(
  `wrote item_bitmaps.asm (${typeBlocks.length} atlas types × ${MIPS.length} mips = ${totalBytes} bytes; ${SKIP_ITEM_ATLAS.size} skipped)`,
);
