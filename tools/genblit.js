/**
 * Emit fully unrolled copy: column-major fb (40×25) → colour RAM ($D800).
 * Buffer layout: col0 rows0..24, col1 rows0..24, ...
 */
import { writeFileSync } from 'fs';

const COLS = 40;
const ROWS = 25;
const FB = 0xc800; // after Judd square tabs at $C000–$C7FF
const CRAM = 0xd800;

let asm = `; Auto-generated — unrolled transposed framebuffer → colour RAM\n`;
asm += `; Source: FRAMEBUFFER (col-major, ${COLS}×${ROWS}) at $${FB.toString(16)}\n`;
asm += `!zone blit\n\n`;
asm += `blit_fb_to_color\n`;

for (let col = 0; col < COLS; col++) {
  asm += `\t; column ${col}\n`;
  for (let row = 0; row < ROWS; row++) {
    const src = FB + col * ROWS + row;
    const dst = CRAM + row * COLS + col;
    asm += `\tlda $${src.toString(16)}\n`;
    asm += `\tsta $${dst.toString(16)}\n`;
  }
}

asm += `\trts\n`;

writeFileSync(new URL('../blit.asm', import.meta.url), asm);
console.log('wrote blit.asm', COLS * ROWS, 'pixel pairs');
