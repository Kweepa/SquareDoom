/**
 * Read itemgraphics/*.png → item_bitmaps.asm (column-major C64 colour pixels).
 * Game build only — no editor imports. Fails if any ITEM_TYPES PNG is missing.
 *
 * Layout per type: gfx[bmp_x * 8 + bmp_y], byte = C64 colour, 0 = transparent.
 */
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { inflateSync } from 'zlib';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const gfxDir = join(root, 'itemgraphics');

const ITEM_TYPES = [
  'spawn', 'soldier', 'imp', 'pinky', 'caco', 'baron', 'barrel',
  'health', 'shells', 'shotgun', 'chaingun', 'chainsaw',
  'greenarmor', 'bluearmor', 'backpack',
  'redcard', 'bluecard', 'yellowcard',
  'skullpile', 'techcolumn',
  'switch_opendoor', 'switch_endlevel', 'switch_lowerlift',
];

/** Pepto C64 palette (duplicated — not from editor). */
const C64_RGB = [
  [0x00, 0x00, 0x00], // 0 black
  [0xff, 0xff, 0xff], // 1 white
  [0x81, 0x33, 0x38], // 2 red
  [0x75, 0xce, 0xc8], // 3 cyan
  [0x8e, 0x3c, 0x97], // 4 purple
  [0x56, 0xac, 0x4d], // 5 green
  [0x40, 0x31, 0x8d], // 6 blue
  [0xbf, 0xce, 0x72], // 7 yellow
  [0x8e, 0x50, 0x29], // 8 orange
  [0x55, 0x3f, 0x00], // 9 brown
  [0xc4, 0x6c, 0x71], // 10 light red
  [0x4a, 0x4a, 0x4a], // 11 dark grey
  [0x7b, 0x7b, 0x7b], // 12 grey
  [0xa9, 0xff, 0x9f], // 13 light green
  [0x70, 0x6d, 0xeb], // 14 light blue
  [0xb2, 0xb2, 0xb2], // 15 light grey
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
        r = row[o]; g = row[o + 1]; b = row[o + 2];
      } else if (colorType === 6 && bitDepth === 8) {
        const o = x * 4;
        r = row[o]; g = row[o + 1]; b = row[o + 2];
      } else if (colorType === 0 && bitDepth === 8) {
        r = g = b = row[x];
      } else {
        throw new Error(`unsupported bitDepth ${bitDepth} colorType ${colorType}`);
      }
      pixels[y * width + x] = [r, g, b];
    }
  }
  return { width, height, pixels };
}

function isTransparent(rgb) {
  return rgb[0] === 0 && rgb[1] === 0 && rgb[2] === 0;
}

function dist2(a, b) {
  const dr = a[0] - b[0];
  const dg = a[1] - b[1];
  const db = a[2] - b[2];
  return dr * dr + dg * dg + db * db;
}

/** Nearest opaque C64 colour (1–15); 0 reserved for transparent. */
function nearestC64(rgb) {
  let best = 1;
  let bestD = Infinity;
  for (let i = 1; i < 16; i++) {
    const d = dist2(rgb, C64_RGB[i]);
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

if (!existsSync(gfxDir)) {
  console.error(`missing ${gfxDir} — place item PNGs there (game build does not use editor/)`);
  process.exit(1);
}

const allGfx = []; // concatenated column-major strips

for (const type of ITEM_TYPES) {
  let path = join(gfxDir, `${type}.png`);
  // Switch actions share one graphic under multicolour/ (not editor/).
  if (!existsSync(path) && type.startsWith('switch_')) {
    path = join(gfxDir, 'multicolour', 'switch.png');
  }
  if (!existsSync(path)) {
    console.error(`missing item graphic: ${path}`);
    process.exit(1);
  }
  const { width, height, pixels } = decodePngRgb(readFileSync(path));
  if (width !== 8 || height !== 8) {
    console.error(`${type} (${path}): expected 8×8, got ${width}×${height}`);
    process.exit(1);
  }
  // Column-major: for x in 0..7, for y in 0..7 → gfx[x*8+y]
  const col = [];
  for (let x = 0; x < 8; x++) {
    for (let y = 0; y < 8; y++) {
      const rgb = pixels[y * 8 + x];
      col.push(isTransparent(rgb) ? 0 : nearestC64(rgb));
    }
  }
  allGfx.push(...col);
}

let asm = `; Auto-generated from itemgraphics/*.png — do not edit\n`;
asm += `; Column-major 8×8: gfx[type][bmp_x*8+bmp_y], byte = C64 colour, 0 = transparent\n`;
asm += `!zone item_bitmaps\n\n`;
asm += `ITEM_TYPE_COUNT = ${ITEM_TYPES.length}\n`;
asm += `ITEM_BMP_W = 8\n`;
asm += `ITEM_BMP_H = 8\n`;
asm += `ITEM_BMP_BYTES = 64\n\n`;
asm += `; Index = typeId * 64; column strips of 8 row pixels\n`;
asm += `item_gfx\n`;
asm += fmtBytes(allGfx);
asm += `\n`;

writeFileSync(join(root, 'item_bitmaps.asm'), asm);
console.log(`wrote item_bitmaps.asm (${ITEM_TYPES.length} types × 64 bytes = ${allGfx.length})`);
