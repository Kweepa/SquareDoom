/**
 * Read lightingdither.png (8×8 tiles, closest→furthest) and emit
 * ditherchars.asm: wall glyphs $00–$07 + floor glyph $08 (tile 2 @ 90° CW).
 */
import { readFileSync, writeFileSync } from 'fs';
import { inflateSync } from 'zlib';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

function decodePng(buf) {
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

  // Samples per pixel (before bit-packing)
  const samples =
    colorType === 0 ? 1 :
    colorType === 2 ? 3 :
    colorType === 3 ? 1 :
    colorType === 4 ? 2 :
    colorType === 6 ? 4 :
    (() => { throw new Error(`unsupported colorType ${colorType}`); })();

  if (colorType === 3 && !palette) throw new Error('indexed PNG missing PLTE');

  // Bytes per scanline (excluding filter byte)
  const stride = Math.ceil((width * samples * bitDepth) / 8);
  // Filter bpp = bytes per pixel, min 1 (PNG spec for sub-byte depths)
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

  // Unpack to one brightness byte per pixel
  const pixels = Buffer.alloc(width * height);
  for (let y = 0; y < height; y++) {
    const row = raw.subarray(y * stride, (y + 1) * stride);
    for (let x = 0; x < width; x++) {
      let sample;
      if (bitDepth === 8) {
        sample = row[x * samples];
      } else if (bitDepth === 4 && samples === 1) {
        const byte = row[x >> 1];
        sample = (x & 1) === 0 ? (byte >> 4) : (byte & 0x0f);
      } else if (bitDepth === 2 && samples === 1) {
        const byte = row[x >> 2];
        const shift = 6 - ((x & 3) * 2);
        sample = (byte >> shift) & 3;
      } else if (bitDepth === 1 && samples === 1) {
        const byte = row[x >> 3];
        sample = (byte >> (7 - (x & 7))) & 1;
      } else {
        throw new Error(`unsupported bitDepth ${bitDepth} colorType ${colorType}`);
      }

      let bright;
      if (colorType === 3) {
        bright = palette[sample * 3];
      } else if (bitDepth < 8) {
        // Scale max sample to 0..255
        const max = (1 << bitDepth) - 1;
        bright = Math.round((sample / max) * 255);
      } else {
        bright = sample;
      }
      pixels[y * width + x] = bright;
    }
  }
  return { width, height, pixels };
}

function tileBytes(pixels, width, tile) {
  const bytes = [];
  for (let y = 0; y < 8; y++) {
    let b = 0;
    for (let x = 0; x < 8; x++) {
      if (pixels[y * width + tile * 8 + x] > 128) {
        b |= 0x80 >> x;
      }
    }
    bytes.push(b);
  }
  return bytes;
}

/** 90° CW: dest(nx,ny) ← src(ny, 7-nx) */
function rotateCw(src) {
  const grid = Array.from({ length: 8 }, (_, y) =>
    Array.from({ length: 8 }, (_, x) => (src[y] >> (7 - x)) & 1));
  const out = [];
  for (let ny = 0; ny < 8; ny++) {
    let b = 0;
    for (let nx = 0; nx < 8; nx++) {
      const sx = ny;
      const sy = 7 - nx;
      if (grid[sy][sx]) b |= 0x80 >> nx;
    }
    out.push(b);
  }
  return out;
}

function fmtBytes(bytes) {
  return bytes.map((b) => `$${b.toString(16).padStart(2, '0')}`).join(',');
}

const png = readFileSync(join(root, 'lightingdither.png'));
const { width, height, pixels } = decodePng(png);
if (width !== 64 || height !== 8) {
  throw new Error(`expected 64×8, got ${width}×${height}`);
}

const walls = [];
for (let t = 0; t < 8; t++) {
  walls.push(tileBytes(pixels, width, t));
}
const floor = rotateCw(walls[2]);

let asm = `; Auto-generated from lightingdither.png — do not edit\n`;
asm += `; Wall UDGs $00–$07 (closest→furthest), floor UDG $08 (tile 2 rot90 CW)\n`;
asm += `!zone ditherchars\n\n`;
asm += `dither_wall_glyphs\n`;
for (let t = 0; t < 8; t++) {
  asm += `\t!byte ${fmtBytes(walls[t])}\t; light ${t}\n`;
}
asm += `dither_floor_glyph\n`;
asm += `\t!byte ${fmtBytes(floor)}\n`;

writeFileSync(join(root, 'ditherchars.asm'), asm);
console.log('wrote ditherchars.asm (8 wall + 1 floor glyphs)');
console.log('walls:', walls.map(fmtBytes).join(' | '));
console.log('floor:', fmtBytes(floor));
