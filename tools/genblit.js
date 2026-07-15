/**
 * Emit fully unrolled copy: column-major fb (40×25) → colour RAM ($D800)
 * and lighting fb → screen ($0400).
 * Buffer layout: col0 rows0..24, col1 rows0..24, ...
 */
import { writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const COLS = 40;
const ROWS = 25;
const FB = 0xc800; // after Judd square tabs at $C000–$C7FF
const LIGHT = 0xcc00;
const CRAM = 0xd800;
const SCREEN = 0x0400;

function emitBlit(name, srcBase, dstBase, comment) {
  let asm = `; Auto-generated — unrolled transposed framebuffer → ${comment}\n`;
  asm += `; Source: col-major ${COLS}×${ROWS} at $${srcBase.toString(16)}\n`;
  asm += `!zone ${name}\n\n`;
  asm += `${name}\n`;

  for (let col = 0; col < COLS; col++) {
    asm += `\t; column ${col}\n`;
    for (let row = 0; row < ROWS; row++) {
      const src = srcBase + col * ROWS + row;
      const dst = dstBase + row * COLS + col;
      asm += `\tlda $${src.toString(16)}\n`;
      asm += `\tsta $${dst.toString(16)}\n`;
    }
  }

  asm += `\trts\n`;
  return asm;
}

writeFileSync(
  join(root, 'blit.asm'),
  emitBlit('blit_fb_to_color', FB, CRAM, 'colour RAM')
);
writeFileSync(
  join(root, 'blit_chars.asm'),
  emitBlit('blit_fb_to_chars', LIGHT, SCREEN, 'screen')
);
console.log('wrote blit.asm + blit_chars.asm', COLS * ROWS, 'pixel pairs each');
