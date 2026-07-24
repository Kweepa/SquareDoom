/**
 * Cut itemgraphics/multicolour/minigun.png + rocketlauncher.png into
 * 24×21 hi-res VIC layers, write crop PNGs, and emit:
 *   minigun_weapon.asm  — 8 sprites (flash + 2 hi + 2 light + 2 dark)
 *   rocket_weapon.asm   — 8 sprites (flash + 2 hi + 4 dark)
 *
 * Layout (sprite pixels; ×2 on screen with XY expand):
 *   Minigun 48×28: dark@y=7 side-by-side, light@y=0 (+7), hi centered @y=0/7
 *   Rocket  48×44: pink flash L/R @y=0; body square + hi @y=9 (dy=14)
 *
 * Flash duplicated from pistol_sprites.asm (run genpistol first).
 * Black / alpha = body vs clear — opaque black is a real layer; only alpha clears.
 */
import { readFileSync, writeFileSync } from 'fs';
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
        r = row[o]; g = row[o + 1]; b = row[o + 2];
      } else if (colorType === 6 && bitDepth === 8) {
        const o = x * 4;
        r = row[o]; g = row[o + 1]; b = row[o + 2]; a = row[o + 3];
      } else {
        throw new Error(`unsupported bitDepth ${bitDepth} colorType ${colorType}`);
      }
      pixels[y * width + x] = [r, g, b, a];
    }
  }
  return { width, height, pixels };
}

function chunk(type, data) {
  const typeBuf = Buffer.from(type, 'ascii');
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const crcBuf = Buffer.alloc(4);
  crcBuf.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])) >>> 0);
  return Buffer.concat([len, typeBuf, data, crcBuf]);
}

/** Indexed PNG: 0=black transparent, 1=layer grey. */
function writeCropPng(path, mask, rgb) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(WIDTH, 0);
  ihdr.writeUInt32BE(HEIGHT, 4);
  ihdr[8] = 8;  // bit depth
  ihdr[9] = 3;  // indexed
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;
  const plte = Buffer.from([0, 0, 0, rgb[0], rgb[1], rgb[2]]);
  const trns = Buffer.from([0]); // index 0 fully transparent
  const raw = Buffer.alloc(HEIGHT * (1 + WIDTH));
  for (let y = 0; y < HEIGHT; y++) {
    raw[y * (1 + WIDTH)] = 0; // filter None
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

/** Opaque pixel matching exact RGB. Alpha < 128 = transparent (black body OK). */
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

function emitWeaponAsm(name, zone, layers, comment, { pistolFlash = true } = {}) {
  let asm = `; Auto-generated from itemgraphics/multicolour/${name}.png - do not edit\n`;
  asm += comment;
  asm += `!zone ${zone}\n\n`;
  if (pistolFlash) {
    asm += `${zone}_flash_white\n`;
    asm += extractPistolSprite('pistol_flash_white');
    asm += `${zone}_flash_red\n`;
    asm += extractPistolSprite('pistol_flash_red');
  }
  for (const layer of layers) {
    const packed = packSprite(layer.mask);
    if (packed.length !== 64) throw new Error('sprite must be 64 bytes');
    asm += `${layer.label}\n`;
    asm += fmtBytes(packed);
    asm += `\n`;
  }
  writeFileSync(join(root, `${zone}_weapon.asm`), asm);
}

// --- Minigun: 48×28 ---
{
  const file = 'minigun.png';
  const { width, height, pixels } = decodePngRgba(readFileSync(join(imgDir, file)));
  if (width !== 48 || height !== 28) {
    throw new Error(`${file}: expected 48×28, got ${width}×${height}`);
  }
  // PNG layers: opaque black body, mid grey, white highlights (alpha = clear)
  const crops = [
    { label: 'minigun_hi_top', x: 12, y: 0, rgb: [255, 255, 255] },
    { label: 'minigun_hi_bot', x: 12, y: 7, rgb: [255, 255, 255] },
    { label: 'minigun_light_left', x: 0, y: 0, rgb: [137, 137, 137] },
    { label: 'minigun_light_right', x: 24, y: 0, rgb: [137, 137, 137] },
    { label: 'minigun_dark_left', x: 0, y: 7, rgb: [0, 0, 0] },
    { label: 'minigun_dark_right', x: 24, y: 7, rgb: [0, 0, 0] },
  ];
  const layers = [];
  const info = [];
  for (const c of crops) {
    const { mask, n } = cropMask(pixels, width, c.x, c.y, c.rgb);
    if (n === 0) throw new Error(`${c.label}: no pixels matched RGB ${c.rgb}`);
    // Preview crop: show black body as dark grey so it isn't invisible on black bg
    const previewRgb = c.rgb[0] || c.rgb[1] || c.rgb[2] ? c.rgb : [0x4a, 0x4a, 0x4a];
    writeCropPng(join(imgDir, `${c.label}.png`), mask, previewRgb);
    layers.push({ label: c.label, mask });
    info.push(`${c.label}.png: opaque=${n}`);
  }
  emitWeaponAsm(
    'minigun',
    'minigun',
    layers,
    `; Eight contiguous layers (low VIC # = front): flash, hi×2, light×2, dark×2.\n` +
      `;   PNG: white hi, grey(137) light, opaque black dark (alpha = clear).\n` +
      `;   Layout: dark side-by-side; light +7px; hi centered stacked.\n`
  );
  console.log('wrote minigun_weapon.asm (8×64) + 6 crop PNGs');
  for (const line of info) console.log(' ', line);
}

// --- Rocket launcher: 48×44 (pink flash @y=0; body @y=9) ---
{
  const file = 'rocketlauncher.png';
  const { width, height, pixels } = decodePngRgba(readFileSync(join(imgDir, file)));
  if (width !== 48 || height !== 44) {
    throw new Error(`${file}: expected 48×44, got ${width}×${height}`);
  }
  const PINK = [203, 126, 117];	// Pepto light red
  const HI = [173, 173, 173];
  const DARK = [0, 0, 0];
  // flash side-by-side @y=0; body square shifted +9 (dy=14 within body)
  const crops = [
    { label: 'rocket_flash_left', x: 0, y: 0, rgb: PINK },
    { label: 'rocket_flash_right', x: 24, y: 0, rgb: PINK },
    { label: 'rocket_hi_top', x: 12, y: 9, rgb: HI },
    { label: 'rocket_hi_bot', x: 12, y: 23, rgb: HI },
    { label: 'rocket_dark_tl', x: 0, y: 9, rgb: DARK },
    { label: 'rocket_dark_tr', x: 24, y: 9, rgb: DARK },
    { label: 'rocket_dark_bl', x: 0, y: 23, rgb: DARK },
    { label: 'rocket_dark_br', x: 24, y: 23, rgb: DARK },
  ];
  const layers = [];
  const info = [];
  for (const c of crops) {
    const { mask, n } = cropMask(pixels, width, c.x, c.y, c.rgb);
    if (n === 0) throw new Error(`${c.label}: no pixels matched RGB ${c.rgb}`);
    const previewRgb = c.rgb[0] || c.rgb[1] || c.rgb[2] ? c.rgb : [0x4a, 0x4a, 0x4a];
    writeCropPng(join(imgDir, `${c.label}.png`), mask, previewRgb);
    layers.push({ label: c.label, mask });
    info.push(`${c.label}.png: opaque=${n}`);
  }
  emitWeaponAsm(
    'rocketlauncher',
    'rocket',
    layers,
    `; Eight contiguous layers (low VIC # = front): pink flash×2, hi×2, dark 2×2.\n` +
      `;   PNG: pink(203,126,117) flash side-by-side @y=0 (+9 above body);\n` +
      `;   grey(173) hi over opaque black dark (alpha = clear).\n`,
    { pistolFlash: false }
  );
  console.log('wrote rocket_weapon.asm (8×64) + 8 crop PNGs');
  for (const line of info) console.log(' ', line);
}
