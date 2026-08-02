/**
 * itemgraphics/switch.png (16×16) → wall_switch.asm
 * Column-major C64 colours; $ff = clear (PNG alpha < 128, or magenta #ff00ff).
 * Black maps to C64 colour 0 (not clear — clear used to show as wall brown).
 */
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { inflateSync, deflateSync } from 'zlib';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const TEX_W = 16;
const TEX_H = 16;
const CLEAR = 0xff;

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

function nearestC64(rgba, hasAlpha) {
  let [r, g, b, a] = rgba;
  if (hasAlpha && a < 128) return CLEAR;
  // Magenta key for clear when the PNG has no alpha
  if (r === 255 && g === 0 && b === 255) return CLEAR;
  let best = 0;
  let bestD = Infinity;
  for (let i = 0; i < 16; i++) {
    const [cr, cg, cb] = C64_RGB[i];
    const d = (r - cr) ** 2 + (g - cg) ** 2 + (b - cb) ** 2;
    if (d < bestD) {
      bestD = d;
      best = i;
    }
  }
  return best;
}

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
  const inflated = inflateSync(Buffer.concat(idats));
  const samples =
    colorType === 0 ? 1 :
    colorType === 2 ? 3 :
    colorType === 3 ? 1 :
    colorType === 4 ? 2 :
    colorType === 6 ? 4 :
    (() => { throw new Error(`unsupported colorType ${colorType}`); })();
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
  const hasAlpha = colorType === 4 || colorType === 6 || (colorType === 3 && trns);
  const pixels = new Array(width * height);
  for (let y = 0; y < height; y++) {
    const row = raw.subarray(y * stride, (y + 1) * stride);
    for (let x = 0; x < width; x++) {
      let r, g, b, a = 255;
      if (colorType === 2) {
        const i = x * 3;
        r = row[i]; g = row[i + 1]; b = row[i + 2];
      } else if (colorType === 6) {
        const i = x * 4;
        r = row[i]; g = row[i + 1]; b = row[i + 2]; a = row[i + 3];
      } else if (colorType === 3) {
        const idx = row[x];
        r = palette[idx * 3];
        g = palette[idx * 3 + 1];
        b = palette[idx * 3 + 2];
        if (trns && idx < trns.length) a = trns[idx];
      } else {
        throw new Error(`decode colorType ${colorType}`);
      }
      pixels[y * width + x] = [r, g, b, a];
    }
  }
  return { width, height, pixels, hasAlpha };
}

/** Minimal RGB PNG writer (no filter). */
function writePngRgb(path, width, height, rgb) {
  const crcTable = (() => {
    const t = new Uint32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      t[n] = c;
    }
    return t;
  })();
  const crc = (buf) => {
    let c = 0xffffffff;
    for (let i = 0; i < buf.length; i++) c = crcTable[(c ^ buf[i]) & 255] ^ (c >>> 8);
    return (c ^ 0xffffffff) >>> 0;
  };
  const chunk = (type, data) => {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length);
    const typeB = Buffer.from(type, 'ascii');
    const crcB = Buffer.alloc(4);
    crcB.writeUInt32BE(crc(Buffer.concat([typeB, data])));
    return Buffer.concat([len, typeB, data, crcB]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;
  ihdr[9] = 2;
  const raw = Buffer.alloc(height * (1 + width * 3));
  for (let y = 0; y < height; y++) {
    raw[y * (1 + width * 3)] = 0;
    for (let x = 0; x < width; x++) {
      const i = (y * width + x) * 3;
      const o = y * (1 + width * 3) + 1 + x * 3;
      raw[o] = rgb[i];
      raw[o + 1] = rgb[i + 1];
      raw[o + 2] = rgb[i + 2];
    }
  }
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  writeFileSync(path, Buffer.concat([
    sig,
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw)),
    chunk('IEND', Buffer.alloc(0)),
  ]));
}

function ensureSwitchPng(path) {
  if (existsSync(path)) {
    const { width, height } = decodePngRgb(readFileSync(path));
    if (width === TEX_W && height === TEX_H) return;
  }
  // Placeholder panel: grey frame, dark inset, yellow toggle nub
  const rgb = Buffer.alloc(TEX_W * TEX_H * 3);
  const set = (x, y, hex) => {
    const i = (y * TEX_W + x) * 3;
    rgb[i] = (hex >> 16) & 255;
    rgb[i + 1] = (hex >> 8) & 255;
    rgb[i + 2] = hex & 255;
  };
  for (let y = 0; y < TEX_H; y++) {
    for (let x = 0; x < TEX_W; x++) {
      const edge = x === 0 || y === 0 || x === TEX_W - 1 || y === TEX_H - 1;
      const inset = x >= 3 && x <= 12 && y >= 3 && y <= 12;
      if (edge) set(x, y, 0xb2b2b2);
      else if (inset) set(x, y, 0x4a4a4a);
      else set(x, y, 0x7b7b7b);
    }
  }
  for (let y = 6; y <= 9; y++) {
    for (let x = 6; x <= 9; x++) set(x, y, 0xbfce72);
  }
  writePngRgb(path, TEX_W, TEX_H, rgb);
  console.log(`wrote placeholder ${path}`);
}

const path = join(root, 'itemgraphics', 'switch.png');
ensureSwitchPng(path);
const { width, height, pixels, hasAlpha } = decodePngRgb(readFileSync(path));
if (width !== TEX_W || height !== TEX_H) {
  console.error(`switch.png must be ${TEX_W}×${TEX_H}, got ${width}×${height}`);
  process.exit(1);
}

const bytes = [];
for (let u = 0; u < TEX_W; u++) {
  for (let v = 0; v < TEX_H; v++) {
    // V=0 is bottom of texture (aligns with wall bottom in paint_switch_col)
    const y = TEX_H - 1 - v;
    bytes.push(nearestC64(pixels[y * TEX_W + u], hasAlpha));
  }
}

let asm = `; Auto-generated from itemgraphics/switch.png — do not edit\n`;
asm += `; 16×16 wall-face switch, column-major gfx[u*16+v], v=0 at bottom, $ff=clear\n`;
asm += `!zone wall_switch\n\n`;
asm += `wall_switch_tex\n`;
for (let i = 0; i < bytes.length; i += 16) {
  const chunk = bytes.slice(i, i + 16).map((b) => `$${b.toString(16).padStart(2, '0')}`);
  asm += `\t!byte ${chunk.join(',')}\n`;
}

writeFileSync(join(root, 'wall_switch.asm'), asm);
console.log(`wrote wall_switch.asm (${bytes.length} bytes)`);
