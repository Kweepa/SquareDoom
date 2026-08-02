/**
 * Emit compact interleaved blit: column-major colour + lighting FBs
 * → colour RAM ($D800) and screen ($0400).
 *
 * Column loop (X = col); 25 rows unrolled with (zp),y source and abs,x dest.
 * HUD is painted into the FB pre-blit, so all 1000 cells are copied.
 */
import { writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const COLS = 40;
const ROWS = 25;
const CRAM = 0xd800;
const SCREEN = 0x0400;

let asm = `; Auto-generated — compact interleaved colour RAM + screen blit\n`;
asm += `; Column loop; 25 rows unrolled. Source: col-major $e000 / $e400\n`;
asm += `!zone blit_fb\n\n`;
asm += `blit_fb\n`;
asm += `\tldx #0\n`;
asm += `.col\n`;
asm += `\tlda colbaselo,x\n`;
asm += `\tsta col_base_l\n`;
asm += `\tsta pat_base_l\n`;
asm += `\tlda colbasehi,x\n`;
asm += `\tsta col_base_h\n`;
asm += `\tclc\n`;
asm += `\tadc #4\n`;
asm += `\tsta pat_base_h\n`;
asm += `\tldy #0\n`;

for (let row = 0; row < ROWS; row++) {
  const dstC = CRAM + row * COLS;
  const dstP = SCREEN + row * COLS;
  asm += `\tlda (col_base_l),y\n`;
  asm += `\tsta $${dstC.toString(16)},x\n`;
  asm += `\tlda (pat_base_l),y\n`;
  asm += `\tsta $${dstP.toString(16)},x\n`;
  if (row < ROWS - 1) {
    asm += `\tiny\n`;
  }
}

asm += `\tinx\n`;
asm += `\tcpx #${COLS}\n`;
asm += `\tbeq .done\n`;
asm += `\tjmp .col\n`;
asm += `.done\n`;
asm += `\trts\n`;

writeFileSync(join(root, 'blit.asm'), asm);
console.log(
  'wrote blit.asm (compact column-loop interleaved)',
  COLS * ROWS,
  'cells'
);
