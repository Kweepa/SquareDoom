/**
 * Emit muzzle_flash.asm — shared pistol/shotgun/minigun flash A + B.
 *   A = existing pistol_flash_white/red (preserved across regenerations)
 *   B = cut from itemgraphics/multicolour/muzzleflash2.png (white + red)
 *
 * Run before genweaponhud.js so A can still be lifted from pistol_sprites.asm
 * on the first migration; afterward A is read back from muzzle_flash.asm.
 */
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { deflateSync, inflateSync } from 'zlib';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const imgDir = join(root, 'itemgraphics', 'multicolour');
const WIDTH = 24;
const HEIGHT = 21;

const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();
function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function extractLabel(asmPath, label) {
  const asm = readFileSync(asmPath, 'utf8');
  const re = new RegExp(`${label}\\r?\\n((?:\\t!byte[^\\n]+\\r?\\n){8})`);
  const m = asm.match(re);
  if (!m) throw new Error(`${asmPath} missing ${label}`);
  return m[1].replace(/\r\n/g, '\n');
}

function decodePngRgba(buf) {
  let off = 8;
  let width;
  let height;
  let bitDepth;
  let colorType;
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
    } else if (type === 'PLTE') palette = data;
    else if (type === 'tRNS') trns = data;
    else if (type === 'IDAT') idats.push(data);
    else if (type === 'IEND') break;
  }
  const inflated = inflateSync(Buffer.concat(idats));
  const samples = colorType === 3 ? 1 : colorType === 2 ? 3 : colorType === 6 ? 4 : 1;
  const bpp = Math.max(1, Math.ceil((samples * bitDepth) / 8));
  const rowBytes = Math.ceil((width * samples * bitDepth) / 8);
  const raw = Buffer.alloc(height * rowBytes);
  let src = 0;
  let prev = Buffer.alloc(rowBytes);
  for (let y = 0; y < height; y++) {
    const filter = inflated[src++];
    const row = inflated.subarray(src, src + rowBytes);
    src += rowBytes;
    const out = raw.subarray(y * rowBytes, (y + 1) * rowBytes);
    for (let i = 0; i < rowBytes; i++) {
      const x = row[i];
      let v = x;
      if (filter === 1) v = (x + out[i - bpp]) & 255;
      else if (filter === 2) v = (x + prev[i]) & 255;
      else if (filter === 3) {
        const a = i >= bpp ? out[i - bpp] : 0;
        v = (x + ((a + prev[i]) >> 1)) & 255;
      } else if (filter === 4) {
        const a = i >= bpp ? out[i - bpp] : 0;
        const b = prev[i];
        const c = i >= bpp ? prev[i - bpp] : 0;
        const p = a + b - c;
        const pa = Math.abs(p - a);
        const pb = Math.abs(p - b);
        const pc = Math.abs(p - c);
        v = (x + (pa <= pb && pa <= pc ? a : pb <= pc ? b : c)) & 255;
      }
      out[i] = v;
    }
    prev = Buffer.from(out);
  }
  const pixels = new Array(width * height);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      let r;
      let g;
      let b;
      let a = 255;
      if (colorType === 3) {
        const idx = raw[y * rowBytes + x];
        r = palette[idx * 3];
        g = palette[idx * 3 + 1];
        b = palette[idx * 3 + 2];
        if (trns && idx < trns.length) a = trns[idx];
      } else if (colorType === 2) {
        const o = y * rowBytes + x * 3;
        r = raw[o];
        g = raw[o + 1];
        b = raw[o + 2];
      } else if (colorType === 6) {
        const o = y * rowBytes + x * 4;
        r = raw[o];
        g = raw[o + 1];
        b = raw[o + 2];
        a = raw[o + 3];
      } else throw new Error(`unsupported PNG colorType ${colorType}`);
      pixels[y * width + x] = [r, g, b, a];
    }
  }
  return { width, height, pixels };
}

function cropMask(pixels, srcW, x0, y0, rgb) {
  const [tr, tg, tb] = rgb;
  const mask = new Array(WIDTH * HEIGHT).fill(false);
  let n = 0;
  for (let y = 0; y < HEIGHT; y++) {
    for (let x = 0; x < WIDTH; x++) {
      const [r, g, b, a] = pixels[(y0 + y) * srcW + (x0 + x)];
      if (a < 128) continue;
      if (r === tr && g === tg && b === tb) {
        mask[y * WIDTH + x] = true;
        n++;
      }
    }
  }
  return { mask, n };
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

function chunk(type, data) {
  const typeBuf = Buffer.from(type, 'ascii');
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const crcBuf = Buffer.alloc(4);
  crcBuf.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])) >>> 0);
  return Buffer.concat([len, typeBuf, data, crcBuf]);
}

function writeCropPng(path, mask, rgb) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(WIDTH, 0);
  ihdr.writeUInt32BE(HEIGHT, 4);
  ihdr[8] = 8;
  ihdr[9] = 3;
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;
  const plte = Buffer.from([0, 0, 0, rgb[0], rgb[1], rgb[2]]);
  const trns = Buffer.from([0]);
  const raw = Buffer.alloc(HEIGHT * (1 + WIDTH));
  for (let y = 0; y < HEIGHT; y++) {
    raw[y * (1 + WIDTH)] = 0;
    for (let x = 0; x < WIDTH; x++) {
      raw[y * (1 + WIDTH) + 1 + x] = mask[y * WIDTH + x] ? 1 : 0;
    }
  }
  const idat = deflateSync(raw);
  const png = Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('PLTE', plte),
    chunk('tRNS', trns),
    chunk('IDAT', idat),
    chunk('IEND', Buffer.alloc(0)),
  ]);
  writeFileSync(path, png);
}

// --- Flash A: prefer pistol_sprites (migration), else preserve muzzle_flash.asm ---
let aWhite;
let aRed;
const pistolAsm = join(root, 'pistol_sprites.asm');
const muzzleAsm = join(root, 'muzzle_flash.asm');
try {
  aWhite = extractLabel(pistolAsm, 'pistol_flash_white');
  aRed = extractLabel(pistolAsm, 'pistol_flash_red');
  console.log('flash A: lifted from pistol_sprites.asm');
} catch {
  aWhite = extractLabel(muzzleAsm, 'muzzle_a_white');
  aRed = extractLabel(muzzleAsm, 'muzzle_a_red');
  console.log('flash A: preserved from muzzle_flash.asm');
}

// --- Flash B: muzzleflash2.png ---
const WHITE = [255, 255, 255];
const RED = [159, 78, 68];
const { width, height, pixels } = decodePngRgba(readFileSync(join(imgDir, 'muzzleflash2.png')));
if (width !== WIDTH || height !== HEIGHT) {
  throw new Error(`muzzleflash2.png: expected ${WIDTH}×${HEIGHT}, got ${width}×${height}`);
}
const bWhite = cropMask(pixels, width, 0, 0, WHITE);
const bRed = cropMask(pixels, width, 0, 0, RED);
if (bWhite.n === 0) throw new Error('muzzleflash2: no white pixels');
if (bRed.n === 0) throw new Error('muzzleflash2: no red pixels');
writeCropPng(join(imgDir, 'muzzle_b_white.png'), bWhite.mask, WHITE);
writeCropPng(join(imgDir, 'muzzle_b_red.png'), bRed.mask, RED);

let asm = `; Auto-generated shared muzzle flash A/B — do not edit\n`;
asm += `; A = legacy pistol white/red; B = muzzleflash2.png white/red.\n`;
asm += `; VIC sprites 6–7 for pistol / shotgun / minigun (rocket has own pink).\n`;
asm += `!zone muzzle_flash\n\n`;
asm += `muzzle_a_white\n`;
asm += aWhite;
asm += `muzzle_a_red\n`;
asm += aRed;
asm += `muzzle_b_white\n`;
asm += fmtBytes(packSprite(bWhite.mask));
asm += `\n`;
asm += `muzzle_b_red\n`;
asm += fmtBytes(packSprite(bRed.mask));
asm += `\n`;

writeFileSync(muzzleAsm, asm);
console.log(`wrote muzzle_flash.asm (4×64); B white=${bWhite.n} red=${bRed.n}`);
