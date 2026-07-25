/**
 * Cut itemgraphics/multicolour/{pistol,minigun,rocketlauncher}.png into
 * 24×21 hi-res VIC layers, write crop PNGs, and emit:
 *   pistol_sprites.asm  — 6 sprites (gun×3 + hand×3; flash shared)
 *   minigun_weapon.asm  — 6 sprites (2 hi + 2 light + 2 dark; flash shared)
 *   rocket_weapon.asm   — 8 sprites (hi + detail + 4 dark + pink flash behind)
 *
 * Layout (sprite pixels; ×2 on screen with XY expand):
 *   Pistol  24×32: gun @y=0 (white/grey/black); hand @y=11 (orange/brown/black)
 *   Minigun 48×28: dark@y=7 side-by-side, light@y=0 (+7), hi centered @y=0/7
 *   Rocket  48×44: pink flash L/R @y=0; dark 2×2 @y=9; white hi + grey detail
 *
 * Shared muzzle flash A/B is emitted by tools/genmuzzle.js (muzzle_flash.asm).
 * Opaque black is a real layer; only alpha clears.
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

function emitWeaponAsm(name, zone, layers, comment, { outFile = null } = {}) {
  let asm = `; Auto-generated from itemgraphics/multicolour/${name}.png - do not edit\n`;
  asm += comment;
  asm += `!zone ${zone}\n\n`;
  for (const layer of layers) {
    const packed = packSprite(layer.mask);
    if (packed.length !== 64) throw new Error('sprite must be 64 bytes');
    asm += `${layer.label}\n`;
    asm += fmtBytes(packed);
    asm += `\n`;
  }
  const dest = outFile || `${zone}_weapon.asm`;
  writeFileSync(join(root, dest), asm);
}

function processCrops(file, expectW, expectH, crops) {
  const { width, height, pixels } = decodePngRgba(readFileSync(join(imgDir, file)));
  if (width !== expectW || height !== expectH) {
    throw new Error(`${file}: expected ${expectW}×${expectH}, got ${width}×${height}`);
  }
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
  return { layers, info };
}

// --- Pistol: 24×32 (gun @y=0; hand @y=11) — body only; flash in muzzle_flash.asm ---
{
  const WHITE = [255, 255, 255];
  const GREY = [98, 98, 98];
  const BLACK = [0, 0, 0];
  const BROWN = [109, 84, 18];
  const ORANGE = [161, 104, 60];
  const { layers, info } = processCrops('pistol.png', 24, 32, [
    { label: 'pistol_hi', x: 0, y: 0, rgb: WHITE },
    { label: 'pistol_mid', x: 0, y: 0, rgb: GREY },
    { label: 'pistol_dark', x: 0, y: 0, rgb: BLACK },
    { label: 'pistol_orange', x: 0, y: 11, rgb: ORANGE },
    { label: 'pistol_brown', x: 0, y: 11, rgb: BROWN },
    { label: 'pistol_hand_dark', x: 0, y: 11, rgb: BLACK },
  ]);
  let asm = `; Auto-generated from itemgraphics/multicolour/pistol.png - do not edit\n`;
  asm += `; Six body layers (low VIC # = front): gun hi/mid/dark, hand orange/brown/dark.\n`;
  asm += `;   Gun @y=0 white/grey/black; hand @y=11 orange/brown/black.\n`;
  asm += `;   Shared muzzle flash: muzzle_flash.asm (sprites 6–7).\n`;
  asm += `!zone pistol_sprites\n\n`;
  for (const layer of layers) {
    asm += `${layer.label}\n`;
    asm += fmtBytes(packSprite(layer.mask));
    asm += `\n`;
  }
  writeFileSync(join(root, 'pistol_sprites.asm'), asm);
  console.log('wrote pistol_sprites.asm (6×64) + 6 crop PNGs');
  for (const line of info) console.log(' ', line);
}

// --- Minigun: 48×28 ---
{
  const { layers, info } = processCrops('minigun.png', 48, 28, [
    { label: 'minigun_hi_top', x: 12, y: 0, rgb: [255, 255, 255] },
    { label: 'minigun_hi_bot', x: 12, y: 7, rgb: [255, 255, 255] },
    { label: 'minigun_light_left', x: 0, y: 0, rgb: [137, 137, 137] },
    { label: 'minigun_light_right', x: 24, y: 0, rgb: [137, 137, 137] },
    { label: 'minigun_dark_left', x: 0, y: 7, rgb: [0, 0, 0] },
    { label: 'minigun_dark_right', x: 24, y: 7, rgb: [0, 0, 0] },
  ]);
  emitWeaponAsm(
    'minigun',
    'minigun',
    layers,
    `; Six body layers (low VIC # = front): hi×2, light×2, dark×2.\n` +
      `;   PNG: white hi, grey(137) light, opaque black dark (alpha = clear).\n` +
      `;   Layout: dark side-by-side; light +7px; hi centered stacked.\n` +
      `;   Shared muzzle flash: muzzle_flash.asm (sprites 6–7).\n`
  );
  console.log('wrote minigun_weapon.asm (6×64) + 6 crop PNGs');
  for (const line of info) console.log(' ', line);
}

// --- Rocket launcher: 48×44 (pink flash @y=0; body @y=9) ---
{
  const PINK = [203, 126, 117];	// Pepto light red
  const HI = [255, 255, 255];
  const DETAIL = [173, 173, 173];
  const DARK = [0, 0, 0];
  const { layers, info } = processCrops('rocketlauncher.png', 48, 44, [
    { label: 'rocket_hi', x: 12, y: 9, rgb: HI },
    { label: 'rocket_detail', x: 12, y: 23, rgb: DETAIL },
    { label: 'rocket_dark_tl', x: 0, y: 9, rgb: DARK },
    { label: 'rocket_dark_tr', x: 24, y: 9, rgb: DARK },
    { label: 'rocket_dark_bl', x: 0, y: 23, rgb: DARK },
    { label: 'rocket_dark_br', x: 24, y: 23, rgb: DARK },
    { label: 'rocket_flash_left', x: 0, y: 0, rgb: PINK },
    { label: 'rocket_flash_right', x: 24, y: 0, rgb: PINK },
  ]);
  emitWeaponAsm(
    'rocketlauncher',
    'rocket',
    layers,
    `; Eight contiguous layers (low VIC # = front): hi, detail, dark 2×2, pink flash×2.\n` +
      `;   PNG: white hi @y=9, grey(173) detail @y=23, opaque black dark; pink flash behind.\n` +
      `;   Flash side-by-side @y=0 (+9 above body).\n`
  );
  console.log('wrote rocket_weapon.asm (8×64) + 8 crop PNGs');
  for (const line of info) console.log(' ', line);
}

// --- Chainsaw: 72×41 (3×24), no flash ---
{
  const WHITE = [255, 255, 255];
  const BLACK = [0, 0, 0];
  const GREY = [98, 98, 98];
  const BROWN = [109, 84, 18];
  const ORANGE = [161, 104, 60];
  // Blade crop left enough for all black/white (was x=48, clipped at 45–47).
  // Detail one row higher (was y=20, grey exists at y=19).
  const BLADE_X = 31;
  const DETAIL_Y = 19;
  // VIC front→back: blade hi, detail, hands, blade dark, body×3
  const { layers, info } = processCrops('chainsaw.png', 72, 41, [
    { label: 'chainsaw_blade_hi', x: BLADE_X, y: 0, rgb: WHITE },
    { label: 'chainsaw_detail', x: 35, y: DETAIL_Y, rgb: GREY },
    { label: 'chainsaw_hand_orange', x: 0, y: 20, rgb: ORANGE },
    { label: 'chainsaw_hand_brown', x: 0, y: 20, rgb: BROWN },
    { label: 'chainsaw_blade_dark', x: BLADE_X, y: 0, rgb: BLACK },
    { label: 'chainsaw_body_left', x: 0, y: 20, rgb: BLACK },
    { label: 'chainsaw_body_mid', x: 24, y: 20, rgb: BLACK },
    { label: 'chainsaw_body_right', x: 48, y: 20, rgb: BLACK },
  ]);
  // Alternate blade highlight — pack user PNG as-is (do not rewrite it)
  {
    const hi2Path = join(imgDir, 'chainsaw_blade_hi2.png');
    const { width: w2, height: h2, pixels: p2 } = decodePngRgba(readFileSync(hi2Path));
    if (w2 !== WIDTH || h2 !== HEIGHT) {
      throw new Error(`chainsaw_blade_hi2.png: expected ${WIDTH}×${HEIGHT}, got ${w2}×${h2}`);
    }
    const mask = new Array(WIDTH * HEIGHT).fill(false);
    let n = 0;
    for (let y = 0; y < HEIGHT; y++) {
      for (let x = 0; x < WIDTH; x++) {
        const [r, g, b, a] = p2[y * WIDTH + x];
        if (a < 128) continue;
        if (r === 0 && g === 0 && b === 0) continue; // clear / tRNS black
        mask[y * WIDTH + x] = true;
        n++;
      }
    }
    if (n === 0) throw new Error('chainsaw_blade_hi2: no opaque pixels');
    // hi2 first so *= CHAINSAW_SPRITES-64 places it in the punch pad slot
    layers.unshift({ label: 'chainsaw_blade_hi2', mask });
    info.push(`chainsaw_blade_hi2.png: opaque=${n}`);
  }
  emitWeaponAsm(
    'chainsaw',
    'chainsaw',
    layers,
    `; Nine blobs: blade_hi2 then 8 VIC layers (low # = front), no flash:\n` +
      `;   Place at CHAINSAW_SPRITES-64 so hi2 sits in fist-punch pad.\n` +
      `;   blade hi/dark @x=${BLADE_X}; detail @y=${DETAIL_Y}; body @y=20.\n`,
    { outFile: 'chainsaw_weapon.asm' }
  );
  console.log('wrote chainsaw_weapon.asm (hi2 + 8×64) + crop PNGs');
  for (const line of info) console.log(' ', line);
}

// --- Fist right hand / punch: 57×21, 7 layers (3 black + 3 pink + 1 grey) + empty ---
{
  const BLACK = [0, 0, 0];
  const PINK = [203, 126, 117];	// Pepto light red
  const GREY = [173, 173, 173];
  const XS = [0, 16, 33];		// overlapping 24-wide tiles across 57

  function fistCrops(prefix) {
    return [
      { label: `${prefix}_hi`, x: 33, y: 0, rgb: GREY },
      { label: `${prefix}_pink_l`, x: XS[0], y: 0, rgb: PINK },
      { label: `${prefix}_pink_m`, x: XS[1], y: 0, rgb: PINK },
      { label: `${prefix}_pink_r`, x: XS[2], y: 0, rgb: PINK },
      { label: `${prefix}_dark_l`, x: XS[0], y: 0, rgb: BLACK },
      { label: `${prefix}_dark_m`, x: XS[1], y: 0, rgb: BLACK },
      { label: `${prefix}_dark_r`, x: XS[2], y: 0, rgb: BLACK },
    ];
  }

  function emitFist(file, prefix, outFile) {
    const { layers, info } = processCrops(file, 57, 21, fistCrops(prefix));
    // pad to 8 sprites (unused slot 7)
    const empty = new Array(WIDTH * HEIGHT).fill(false);
    layers.push({ label: `${prefix}_pad`, mask: empty });
    emitWeaponAsm(
      file.replace(/\.png$/, ''),
      prefix,
      layers,
      `; Seven layers + pad (low VIC # = front), no flash:\n` +
        `;   grey hi, pink L/M/R, black L/M/R. PNG 57×21 crops @x=0,16,33.\n`,
      { outFile }
    );
    console.log(`wrote ${outFile} (8×64) + 7 crop PNGs`);
    for (const line of info) console.log(' ', line);
  }

  emitFist('righthand.png', 'fist_right', 'fist_righthand.asm');
  emitFist('punch.png', 'fist_punch', 'fist_punch.asm');
}
