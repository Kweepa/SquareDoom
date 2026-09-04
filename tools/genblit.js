/**
 * Emit compact interleaved blit: column-major colour + lighting FBs
 * → colour RAM ($D800) and screen ($C000, VIC bank 3).
 *
 * Pattern dest is DRAM (copy at $01=$34). Colour dest needs I/O ($35).
 * Per column: copy 25 pattern cells, $35 + 25 colour cells, $34 + cli
 * so Timer B can run. Do not SEI the whole blit.
 *
 * Column loop (X = col); 25 rows unrolled with (zp),y source and abs,x dest.
 * Row 24 is 3D view in cols 8–31 (always copy). HUD lives in cols 0–7 and
 * 32–39 only; those cells are copied when draw_hud leaves hud_dirty set.
 */
import { writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const COLS = 40;
const ROWS = 25;
const CRAM = 0xd800;
const SCREEN = 0xc000;
const HUD_LEFT = 8; // cols 0..7
const HUD_RIGHT = 32; // cols 32..39

function emitRows(kind) {
  const isPat = kind === 'pat';
  const src = isPat ? 'pat_base_l' : 'col_base_l';
  const dstBase = isPat ? SCREEN : CRAM;
  const suf = isPat ? 'p' : 'c';
  let s = `\tldy #0\n`;
  for (let row = 0; row < ROWS; row++) {
    const dst = dstBase + row * COLS;
    if (row === ROWS - 1) {
      s += `\tcpx #${HUD_LEFT}\n`;
      s += `\tbcc .hud_side_${suf}\n`;
      s += `\tcpx #${HUD_RIGHT}\n`;
      s += `\tbcc .blit_r24_${suf}\n`;
      s += `.hud_side_${suf}\n`;
      s += `\tlda hud_dirty\n`;
      s += `\tbeq .hud_clean_${suf}\n`;
      s += `.blit_r24_${suf}\n`;
    }
    s += `\tlda (${src}),y\n`;
    s += `\tsta $${dst.toString(16)},x\n`;
    if (row === ROWS - 1) {
      s += `.hud_clean_${suf}\n`;
    }
    if (row < ROWS - 1) {
      s += `\tiny\n`;
    }
  }
  return s;
}

let asm = `; Auto-generated — compact interleaved colour RAM + screen blit\n`;
asm += `; Column loop; 25 rows unrolled. Source: col-major $e000 / $e400\n`;
asm += `; Dest: pattern $C000 (RAM, $34), colour $D800 (I/O, $35); yield $34+cli/col\n`;
asm += `; Row 24: always blit cols 8–31 (view); HUD cols 0–7/32–39 if hud_dirty\n`;
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
asm += emitRows('pat');
asm += `\tlda #$35\n`;
asm += `\tsta $01\n`;
asm += emitRows('col');
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

writeFileSync(join(root, 'blit.asm'), asm);
console.log(
  'wrote blit.asm (column-loop, $C000 + colour yield)',
  COLS * ROWS,
  'cells'
);
