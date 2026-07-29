/**
 * Read itemgraphics/multicolour/sky1.png (40×12 greyscale) and emit sky.asm:
 * column-major C64 colour bytes for cyan ceiling/ledge sky fills.
 * After changing sky art, run: node tools/gensky.js
 */
import { readFileSync, writeFileSync } from 'fs';
import { inflateSync } from 'zlib';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const WIDTH = 40;
const HEIGHT = 12;

/** PNG greys → C64 colour (weapon-hud greys + black / light grey). */
const RGB_TO_C64 = new Map([
  ['0,0,0', 0],
  ['98,98,98', 11],
  ['137,137,137', 12],
  ['173,173,173', 15],
]);

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
      let r; let g; let b;
      if (colorType === 3) {
        r = palette[sample * 3];
        g = palette[sample * 3 + 1];
        b = palette[sample * 3 + 2];
      } else if (colorType === 2 || colorType === 6) {
        r = row[x * samples];
        g = row[x * samples + 1];
        b = row[x * samples + 2];
      } else if (colorType === 0) {
        r = g = b = sample;
      } else {
        throw new Error(`unsupported colorType ${colorType} for RGB`);
      }
      const key = `${r},${g},${b}`;
      const c64 = RGB_TO_C64.get(key);
      if (c64 === undefined) {
        throw new Error(`sky1.png unknown RGB (${key}) at ${x},${y}`);
      }
      pixels[y * width + x] = c64;
    }
  }
  return { width, height, pixels };
}

const pngPath = join(root, 'itemgraphics', 'multicolour', 'sky1.png');
const { width, height, pixels } = decodePng(readFileSync(pngPath));
if (width !== WIDTH || height !== HEIGHT) {
  throw new Error(`sky1.png: expected ${WIDTH}×${HEIGHT}, got ${width}×${height}`);
}

// Column-major: sky_cols + col*12 + row
const cols = [];
for (let x = 0; x < WIDTH; x++) {
  const strip = [];
  for (let y = 0; y < HEIGHT; y++) {
    strip.push(pixels[y * WIDTH + x]);
  }
  cols.push(strip);
}

let asm = `; Auto-generated from itemgraphics/multicolour/sky1.png — do not edit\n`;
asm += `; ${WIDTH}×${HEIGHT} column-major C64 colours (black/grey) for cyan sky fills\n`;
asm += `sky_cols\n`;
for (let x = 0; x < WIDTH; x++) {
  asm += `\t!byte ${cols[x].map((c) => '$' + c.toString(16).padStart(2, '0')).join(',')}\n`;
}

const outPath = join(root, 'sky.asm');
writeFileSync(outPath, asm);
console.log(`Wrote ${outPath} (${WIDTH * HEIGHT} bytes)`);
