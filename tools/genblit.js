/**
 * Emit compact interleaved blit: column-major colour + lighting FBs
 * → colour RAM ($D800) and screen ($C000, VIC bank 3).
 *
 * Pattern dest is always DRAM at $C000 (no $01 dependency). Colour needs
 * I/O ($35). Per column: $35 once, interleaved colour+pattern rows, then
 * $34 + cli so Timer B can run. Do not SEI the whole blit.
 *
 * Column loop (X = col); 25 rows unrolled with (zp),y source and abs,x dest.
 * Row 24 always copied — HUD side cells stay correct in the FB when
 * hud_dirty=0, so skipping them costs more (per-col tests) than copying.
 * Source pointers start at col 0 and add 25 each column (pat hi = col hi+4).
 */
import { writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const COLS = 40;
const ROWS = 25;
const CRAM = 0xd800;
const SCREEN = 0xc000;

let asm = `; Auto-generated — compact interleaved colour RAM + screen blit\n`;
asm += `; Column loop; 25 rows unrolled. Source: col-major $e000 / $e400\n`;
asm += `; Dest: pattern $C000 + colour $D800 at $35; yield $34+cli/col\n`;
asm += `; Row 24 always blit (FB keeps HUD sides); src ptrs +${ROWS}/col\n`;
asm += `!zone blit_fb\n\n`;
asm += `blit_fb\n`;
asm += `\tldx #0\n`;
asm += `\tlda colbaselo\n`;
asm += `\tsta col_base_l\n`;
asm += `\tsta pat_base_l\n`;
asm += `\tlda colbasehi\n`;
asm += `\tsta col_base_h\n`;
asm += `\tclc\n`;
asm += `\tadc #4\n`;
asm += `\tsta pat_base_h\n`;
asm += `.col\n`;
asm += `\tlda #$35\n`;
asm += `\tsta $01\n`;
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

asm += `\tlda #$34\n`;
asm += `\tsta $01\n`;
asm += `\tcli\n`;
asm += `\tinx\n`;
asm += `\tcpx #${COLS}\n`;
asm += `\tbeq .done\n`;
asm += `\tclc\n`;
asm += `\tlda col_base_l\n`;
asm += `\tadc #${ROWS}\n`;
asm += `\tsta col_base_l\n`;
asm += `\tsta pat_base_l\n`;
asm += `\tbcc .adv_ok\n`;
asm += `\tinc col_base_h\n`;
asm += `\tinc pat_base_h\n`;
asm += `.adv_ok\n`;
asm += `\tjmp .col\n`;
asm += `.done\n`;
asm += `\tlda #0\n`;
asm += `\tsta hud_dirty\n`;
asm += `\trts\n`;

writeFileSync(join(root, 'blit.asm'), asm);
console.log(
  'wrote blit.asm (always row24 + induct src +25)',
  COLS * ROWS,
  'cells'
);
