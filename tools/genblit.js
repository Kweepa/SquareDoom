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
 * patbasehi (below) replaces clc/adc #4 per column.
 */
import { writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const COLS = 40;
const ROWS = 25;
const CRAM = 0xd800;
const SCREEN = 0xc000;
// Must match SCREENBUFFER / gentables colBaseTable
const SCREENBUFFER = 0xe000;

let asm = `; Auto-generated — compact interleaved colour RAM + screen blit\n`;
asm += `; Column loop; 25 rows unrolled. Source: col-major $e000 / $e400\n`;
asm += `; Dest: pattern $C000 + colour $D800 at $35; yield $34+cli/col\n`;
asm += `; Row 24 always blit (FB keeps HUD sides); patbasehi = colbasehi+4\n`;
asm += `!zone blit_fb\n\n`;
asm += `blit_fb\n`;
asm += `\tldx #0\n`;
asm += `.col\n`;
asm += `\tlda colbaselo,x\n`;
asm += `\tsta col_base_l\n`;
asm += `\tsta pat_base_l\n`;
asm += `\tlda colbasehi,x\n`;
asm += `\tsta col_base_h\n`;
asm += `\tlda patbasehi,x\n`;
asm += `\tsta pat_base_h\n`;
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
asm += `\tjmp .col\n`;
asm += `.done\n`;
asm += `\tlda #0\n`;
asm += `\tsta hud_dirty\n`;
asm += `\trts\n`;

// Keep patbasehi with blit (low) — high tables are flush against py_tab.
asm += `\npatbasehi\n`;
for (let c = 0; c < COLS; c++) {
  const addr = SCREENBUFFER + c * 25;
  const patHi = ((addr >> 8) + 4) & 0xff;
  if (c % 16 === 0) asm += `\t!byte `;
  else asm += `,`;
  asm += `$${patHi.toString(16).padStart(2, '0')}`;
  if (c % 16 === 15) asm += `\n`;
}
if (COLS % 16 !== 0) asm += `\n`;

writeFileSync(join(root, 'blit.asm'), asm);
console.log(
  'wrote blit.asm (always row24 + patbasehi)',
  COLS * ROWS,
  'cells'
);
