/**
 * Extract Doom picture lumps from ref/DOOM1.WAD as RGBA PNGs (PLAYPAL 0).
 * Optional; not part of make.bat — ref/ is gitignored.
 *
 *   node tools/extract_wad_gfx.js              # M_SKULL1, M_SKULL2
 *   node tools/extract_wad_gfx.js M_DOOM
 */
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { deflateSync } from 'zlib';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const outDir = join(root, 'itemgraphics', 'multicolour');
const DEFAULT_LUMPS = ['M_SKULL1', 'M_SKULL2'];

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

function chunk(type, data) {
  const typeBuf = Buffer.from(type, 'ascii');
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const crcBuf = Buffer.alloc(4);
  crcBuf.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])) >>> 0);
  return Buffer.concat([len, typeBuf, data, crcBuf]);
}

function writePngRgba(path, width, height, rgba) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;
  ihdr[9] = 6; // RGBA
  const stride = 1 + width * 4;
  const raw = Buffer.alloc(height * stride);
  for (let y = 0; y < height; y++) {
    raw[y * stride] = 0;
    rgba.copy(raw, y * stride + 1, y * width * 4, (y + 1) * width * 4);
  }
  writeFileSync(path, Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw)),
    chunk('IEND', Buffer.alloc(0)),
  ]));
}

function wadPath() {
  for (const name of ['DOOM1.WAD', 'doom1.wad']) {
    const p = join(root, 'ref', name);
    if (existsSync(p)) return p;
  }
  throw new Error('missing ref/DOOM1.WAD');
}

function lumpNameAt(dir, i) {
  const off = i * 16 + 8;
  let s = dir.toString('ascii', off, off + 8);
  const z = s.indexOf('\0');
  if (z >= 0) s = s.slice(0, z);
  return s.toUpperCase();
}

function parseWad(buf) {
  const id = buf.toString('ascii', 0, 4);
  if (id !== 'IWAD' && id !== 'PWAD') throw new Error(`not a WAD (${id})`);
  const numlumps = buf.readUInt32LE(4);
  const infotableofs = buf.readUInt32LE(8);
  const dir = buf.subarray(infotableofs, infotableofs + numlumps * 16);
  const lumps = new Map();
  for (let i = 0; i < numlumps; i++) {
    const name = lumpNameAt(dir, i);
    if (!lumps.has(name)) {
      lumps.set(name, {
        filepos: dir.readUInt32LE(i * 16),
        size: dir.readUInt32LE(i * 16 + 4),
      });
    }
  }
  return lumps;
}

function playpal0(buf, lumps) {
  const pal = lumps.get('PLAYPAL');
  if (!pal || pal.size < 768) throw new Error('missing PLAYPAL');
  return buf.subarray(pal.filepos, pal.filepos + 768);
}

/** Decode a Doom picture lump. rgba is width*height*4, alpha 0 where empty. */
function decodePatch(lump, pal) {
  const width = lump.readInt16LE(0);
  const height = lump.readInt16LE(2);
  if (width <= 0 || height <= 0) throw new Error(`bad patch size ${width}x${height}`);
  const rgba = Buffer.alloc(width * height * 4);
  for (let x = 0; x < width; x++) {
    let o = lump.readUInt32LE(8 + x * 4);
    while (true) {
      const topdelta = lump[o++];
      if (topdelta === 0xff) break;
      const length = lump[o++];
      o++; // unused
      for (let i = 0; i < length; i++) {
        const pix = lump[o++];
        const y = topdelta + i;
        if (y < 0 || y >= height) continue;
        const d = (y * width + x) * 4;
        rgba[d] = pal[pix * 3];
        rgba[d + 1] = pal[pix * 3 + 1];
        rgba[d + 2] = pal[pix * 3 + 2];
        rgba[d + 3] = 255;
      }
      o++; // unused
    }
  }
  return { width, height, rgba };
}

const names = process.argv.slice(2).map((n) => n.toUpperCase());
const wanted = names.length ? names : DEFAULT_LUMPS;

const wadFile = wadPath();
const buf = readFileSync(wadFile);
const lumps = parseWad(buf);
const pal = playpal0(buf, lumps);

for (const name of wanted) {
  const loc = lumps.get(name);
  if (!loc) throw new Error(`lump ${name} not in ${wadFile}`);
  const { width, height, rgba } = decodePatch(
    buf.subarray(loc.filepos, loc.filepos + loc.size),
    pal,
  );
  const out = join(outDir, `${name.toLowerCase()}.png`);
  writePngRgba(out, width, height, rgba);
  console.log(`wrote ${out} (${width}x${height})`);
}
