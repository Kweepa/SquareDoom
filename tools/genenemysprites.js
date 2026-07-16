/**
 * Read itemgraphics/multicolour/pos{walk,atk,pain}_mips.png → enemy_sprites.asm
 *
 * Source atlas per frame: 24×32
 *   left 16×32 = mip0
 *   right strip: mip1 8×16 (y0..15), mip2 4×8 (y16..23),
 *                mip3 2×4 (y24..27), mip4 1×2 (y28..29)
 *
 * Emits standalone column-major frames (gfx[x*H+y], 0=transparent)
 * plus lookup tables for mip W/H and base address [frame*5+mip].
 */
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { inflateSync } from 'zlib';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const gfxDir = join(root, 'itemgraphics', 'multicolour');

const FRAMES = [
  { file: 'poswalk_mips.png', prefix: 'enemy_spr_walk' },
  { file: 'posatk_mips.png', prefix: 'enemy_spr_atk' },
  { file: 'pospain_mips.png', prefix: 'enemy_spr_pain' },
];

const ATLAS_W = 24;
const ATLAS_H = 32;

const MIPS = [
  { name: 'm0', w: 16, h: 32, x0: 0, y0: 0 },
  { name: 'm1', w: 8, h: 16, x0: 16, y0: 0 },
  { name: 'm2', w: 4, h: 8, x0: 16, y0: 16 },
  { name: 'm3', w: 2, h: 4, x0: 16, y0: 24 },
  { name: 'm4', w: 1, h: 2, x0: 16, y0: 28 },
];

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
      let r, g, b, a = 255;
      if (colorType === 3 && bitDepth === 8) {
        const idx = row[x];
        r = palette[idx * 3];
        g = palette[idx * 3 + 1];
        b = palette[idx * 3 + 2];
      } else if (colorType === 3 && bitDepth === 4) {
        const byte = row[x >> 1];
        const idx = (x & 1) === 0 ? (byte >> 4) : (byte & 0x0f);
        r = palette[idx * 3];
        g = palette[idx * 3 + 1];
        b = palette[idx * 3 + 2];
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
  return { width, height, pixels };
}

function isTransparent(rgba) {
  if (rgba[3] !== undefined && rgba[3] < 128) return true;
  return rgba[0] === 0 && rgba[1] === 0 && rgba[2] === 0;
}

function dist2(a, b) {
  const dr = a[0] - b[0];
  const dg = a[1] - b[1];
  const db = a[2] - b[2];
  return dr * dr + dg * dg + db * db;
}

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

function extractMip(pixels, atlasW, mip) {
  const col = [];
  for (let x = 0; x < mip.w; x++) {
    for (let y = 0; y < mip.h; y++) {
      const rgba = pixels[(mip.y0 + y) * atlasW + (mip.x0 + x)];
      col.push(isTransparent(rgba) ? 0 : nearestC64(rgba));
    }
  }
  return col;
}

let asm = `; Auto-generated from itemgraphics/multicolour/pos*_mips.png — do not edit\n`;
asm += `; Standalone column-major mip frames: gfx[bmp_x*H+bmp_y], 0 = transparent\n`;
asm += `!zone enemy_sprites\n\n`;
asm += `ENEMY_MIP_COUNT = ${MIPS.length}\n`;
asm += `ENEMY_FRAME_COUNT = ${FRAMES.length}\n\n`;

asm += `; mip source width / height / log2 (index = mip 0..4)\n`;
asm += `enemy_mip_w\n`;
asm += `\t!byte ${MIPS.map((m) => m.w).join(',')}\n`;
asm += `enemy_mip_h\n`;
asm += `\t!byte ${MIPS.map((m) => m.h).join(',')}\n`;
asm += `enemy_mip_ushift\n`;
asm += `\t!byte ${MIPS.map((m) => Math.log2(m.w)).join(',')}\n`;
asm += `enemy_mip_vshift\n`;
asm += `\t!byte ${MIPS.map((m) => Math.log2(m.h)).join(',')}\n\n`;

const allLabels = [];
let totalBytes = 0;
const frameBlocks = [];

for (const frame of FRAMES) {
  const path = join(gfxDir, frame.file);
  if (!existsSync(path)) {
    console.error(`missing enemy graphic: ${path}`);
    process.exit(1);
  }
  const { width, height, pixels } = decodePngRgb(readFileSync(path));
  if (width !== ATLAS_W || height !== ATLAS_H) {
    console.error(`${frame.file}: expected ${ATLAS_W}×${ATLAS_H}, got ${width}×${height}`);
    process.exit(1);
  }
  const labels = [];
  for (const mip of MIPS) {
    const label = `${frame.prefix}_${mip.name}`;
    const bytes = extractMip(pixels, ATLAS_W, mip);
    labels.push({ label, bytes });
    allLabels.push(label);
    totalBytes += bytes.length;
  }
  frameBlocks.push({ frame, labels });
}

// Base address tables: index = frame*5 + mip
asm += `; Base address lo/hi: index = frame*ENEMY_MIP_COUNT + mip\n`;
asm += `; frame 0=walk 1=atk 2=pain\n`;
asm += `enemy_mip_base_lo\n`;
asm += `\t!byte ${allLabels.map((l) => `<${l}`).join(',')}\n`;
asm += `enemy_mip_base_hi\n`;
asm += `\t!byte ${allLabels.map((l) => `>${l}`).join(',')}\n\n`;

asm += `; Frame mip blobs (walk, atk, pain × m0..m4)\n`;
asm += `enemy_spr_base\n`;
for (const block of frameBlocks) {
  for (const { label, bytes } of block.labels) {
    asm += `${label}\n`;
    asm += fmtBytes(bytes);
    asm += `\n`;
  }
}

writeFileSync(join(root, 'enemy_sprites.asm'), asm);
console.log(
  `wrote enemy_sprites.asm (${FRAMES.length} frames × ${MIPS.length} mips = ${totalBytes} bytes)`,
);
