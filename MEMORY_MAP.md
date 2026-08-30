# SquareDoom memory map

Snapshot of C64 RAM after **boot → MENU → GFX copy → GAME** has finished and the game is running (`$01 = $34`: BASIC and KERNAL out, I/O out — all 64K DRAM). Addresses from `mem_vic.asm`, `zeropage.asm`, `boot.asm`, `menu.asm`, `squaredoom.asm`, and `squaredoom.lbl` (rebuild refreshes labels).

## Boot sequence

Autostart file name is **`squaredoom`** (`boot.prg`). Krill is not used; every load is KERNAL `SETNAM` / `SETLFS` / `LOAD` / `CLOSE`.

1. `IOINIT`, DEN off, CLI.
2. Load **`menu`** at `LOCODE_BASE` (`$0900`), `JSR $0900`. Selectors land in `$08FA`–`$08FF`.
3. Load **`gfx`** at `GFX_STAGING` (`$A000`). `JSR $0903` (`copy_vic`): `$01=$34`, copy sprite tail `$A000` → `$D000` and charset → `$D800`, then `$01=$36`.
4. Load **`game`** at `$0900` (overwrites MENU). `TXS $FF`, `JMP $0900` (`locode_entry`).
5. `locode_entry` installs `REBOOT_STUB` at `$08C0`, copies the kernal blob `$9000` → `$F930`, `init_sqtabs`, VIC bank 3, then `game_start` → `LoadLevel`.

In-game Run/Stop and E1M8 complete `JMP REBOOT_STUB`, which KERNAL-loads `SQUAREDOOM` and `JMP $080d`. `game_complete=1` makes the next MENU entry show the ending pages.

KERNAL cannot write `$D000–$DFFF` (I/O) or `$E000–$FFFF` (ROM). That is why GFX is copied **while MENU still owns `$0900`**. `game.prg` is not loaded into `$D000`; `$D000+` is under-I/O RAM (sprite tail + charset).

**Selectors that survive GAME load** (GAME starts at `$0900`):

| Addr | Symbol |
|------|--------|
| `$08C0` | `REBOOT_STUB` (3-byte `JMP reboot_game`) |
| `$08FA` | `episode` |
| `$08FB` | `music_vol` |
| `$08FC` | `level_num` |
| `$08FD` | `effects_vol` |
| `$08FE` | `game_complete` |
| `$08FF` | `difficulty` |

**Menu VIC** (while MENU.PRG is resident): hires bitmap, bank 1, matrix `$4000`, bitmap `$6000`. Split rasters mux skull cursor + WS/AD/RETURN hints. Game play uses charset bank 3 (`$C400` / `$D800`) as below.

---

**`locode_entry` effects that define the play map**

| Step | Result |
|------|--------|
| `$01 ← $35` | I/O in for VIC/CIA init |
| `set_vic_bank3` | `$DD00` bits 0–1 = `%00` (bank `$C000`); `$d018 ← $16` (screen `$C400`, charset `$D800`) |
| `copy_kernal_blob` | `$9000` staging → `$F930` |
| `$01 ← $34` | DRAM at `$D000–$DFFF` (sprite tail + charset already copied by MENU+3) |
| `init_sqtabs` | Judd SQTAB at `$BC00–$C3FF` (overwrites copy stub at `$BC00`) |
| Colour RAM cleared | `$D800–$DBFF` colour SRAM (at `$35`; not charset DRAM) |
| `$01 ← $34` | Play default before `game_start` |
| `input_irq_init` | Hardware IRQ `$FFFE` → `input_irq`; NMI `$FFFA` / soft `$0318` → `nmi_stub` |

IRQ/NMI save `$01`, set `$35`, **then** ack `$dc0d` / `$dd0d`. `LoadPrg` uses `$36` for KERNAL, restores bank 3 and `$01=$34`. Colour blit copies pattern at `$34` and colour RAM at `$35`, yielding `$34`+`cli` each column.

Disk loads during play (levels → `$9000` cooked blob) overwrite the level window. **`LoadPrg` banks `$01=$36` (KERNAL in)** and RESTOR stomps underlay **`$FD30–$FD4F`** — reserved as `kernal_vec_hole` (empty); do not place code there.

---

## Per-kilobyte map (game running)

Sizes are noted when a region does **not** fill the whole 1K page. Ranges are inclusive. Code entry addresses drift; prefer symbols in `squaredoom.lbl`.

| KB | Range | Contents |
|----|-------|----------|
| 0 | `$0000`–`$03FF` | CPU port, game zero page, under-stack play BSS, cassette scrap, FX overlay. |
| 1 | `$0400`–`$07FF` | Free scrap (old bank-0 screen). Not displayed. |
| 2 | `$0800`–`$0BFF` | Leftover **boot** `$0801`–`REBOOT_STUB-1`. **`REBOOT_STUB`** `$08C0`. Selectors `$08FA`–`$08FF`. **`locode_entry`** `$0900` (`game.prg`). |
| 3–31 | `$0C00`–`$7FFF` | Play code (render, blit, weapons, loader, titleflow, enemy atlas). Must end before map `$9000`. |
| 32–35 | `$8000`–`$8FFF` | Rest of play code; free tail to `$8FFF`. |
| 36–39 | `$9000`–`$9FFF` | **Level** (disk): `level_map` `$9000`, items, sector tables, spawn/switch/stats. Then `angtab`. |
| 40–43 | `$A000`–`$AFFF` | High tables / sky / recip / item bitmaps / pcsfreq. Free to `py_tab` `$B000`. (GFX staging `$A000` is gone — overwritten by GAME.) |
| 44–46 | `$B000`–`$BBFF` | `py_tab` (12 pages). |
| 47 | `$BC00`–`$BFFF` | **SQTAB1–2**. Load image has `copy_kernal_blob` at `$BC00` until `init_sqtabs`. |
| 48 | `$C000`–`$C3FF` | **SQTAB3–4**. Do not point `$d018` at screen block 0. |
| 49 | `$C400`–`$C7FF` | **VIC screen** (1K). Sprite pointers **`$C7F8`**. |
| 50 | `$C800`–`$CBFF` | Weapon sprites (first 2K loaded in place from `game.prg`). |
| 51 | `$CC00`–`$CFFF` | Chainsaw / minigun A. |
| 52 | `$D000`–`$D3FF` | Sprite **tail DRAM** (from `gfx.prg`, copied at `$01=$34`): rocket / shotgun / pistol. At `$35` these addresses are VIC registers. |
| 53 | `$D400`–`$D7FF` | Muzzle / cock. |
| 54 | `$D800`–`$DBFF` | **Charset DRAM** `$D800`–`$DB4F` (from `gfx.prg`). At `$35`, `$D800` is **colour SRAM**. |
| 55 | `$DC00`–`$DFFF` | CIA1/2 (at `$35`); DRAM at `$34`. |
| 56 | `$E000`–`$E3FF` | **`SCREENBUFFER`** (**1024**). Play colour backbuffer (entering / summary / melt / mapscreen / HUD). No menu overlay. |
| 57 | `$E400`–`$E7FF` | **`PATTERNBUFFER`** (**1024**). |
| 58–59 | `$E800`–`$EFFF` | **`COL_CLIP_N`** / **`COL_CLIP_ENTRIES`**. |
| 60–61 | `$F000`–`$F7FF` | Ray cache, profiler, door processes, `SEC_SEEN`, item sort, mobj SoA, `SEC_FLATGRP`. |
| 62 | `$F800`–`$FBFF` | `SEC_VISITED` / `SEC_WDARK`. Relocated **dpsounds** from `$F930`. |
| 63 | `$FC00`–`$FFFF` | `sound_table`, **levelstats**. **`kernal_vec_hole`** `$FD30`–`$FD4F`. Hardware vectors `$FFFA`–`$FFFF`. |

---

## Major regions (summary)

| Range | Role |
|-------|------|
| `$0002`–`$00FF` | Zero page |
| `$0100`–`$0170` | Under-stack play BSS (`SCRAP_UNDER`) |
| `$0801`–`$08BF` | Disposable boot (RAM leftover after GAME load) |
| `$08C0` | `REBOOT_STUB` |
| `$08FA`–`$08FF` | Menu/game selectors |
| `$0900`–`$8FFF` | Play code (`game.prg`) |
| `$9000`–`$9D90` | Level blob (disk) |
| `$9D91`–`$AFFF` | High tables / sky / recip / items / pcsfreq |
| `$B000`–`$BBFF` | `py_tab` |
| `$BC00`–`$C3FF` | SQTAB1–4 |
| `$C400`–`$C7FF` | VIC screen + sprite pointers |
| `$C800`–`$D7BF` | Weapon sprites (head in `game.prg`, tail from `gfx.prg`) |
| `$D800`–`$DB4F` | Charset DRAM (`$34`) / colour SRAM window (`$35`) |
| `$E000`–`$F92F` | Play BSS (screen/pattern/clip/rays/procs/mobj/sector tables) |
| `$F930`–`$FFE4` | dpsounds + levelstats (incl. `$FD30` hole) |
| `$FFFA`–`$FFFF` | Vectors |

---

## Disk files

| DOS name | PRG | Load |
|----------|-----|------|
| `squaredoom` | `boot.prg` | `$0801` (SYS 2061) |
| `menu` | `menu.prg` | `$0900` (must end before `$4000`) |
| `gfx` | `gfx.prg` | `$A000` (sprite tail + charset; copied under I/O) |
| `game` | `game.prg` | `$0900` |
| `e1mN` | cooked level | `$9000` |

---

## Level layout at `$9000` (3473 bytes)

Unchanged: `level_map`, `level_items`, sector tables, spawn, switch faces, stats, then `angtab`.

---

## Under-KERNAL play BSS (`$E000`+)

| Addr | Size | Symbol |
|------|------|--------|
| `$E000` | 1024 | `SCREENBUFFER` |
| `$E400` | 1024 | `PATTERNBUFFER` |
| `$E800` | 40 | `COL_CLIP_N` |
| `$E828` | 2240 | `COL_CLIP_ENTRIES` |
| `$F0E8` | 400 | column ray cache |
| `$F278` | 39 | `PROF_BSS` |
| `$F29F` | 48 | `PROC_*` |
| `$F2CF` | 200 | `SEC_SEEN` |
| `$F397` | 336 | `ITEM_SORT_*` |
| `$F4E7` | 497 | `MOBJ_*` + aim |
| `$F6D8` | 200 | `SEC_FLATGRP` |
| `$F7A0` | 200 | `SEC_VISITED` |
| `$F868` | 200 | `SEC_WDARK` |
| `$F930` | — | dpsounds + levelstats through `end_kernal` |
| `$FD30` | 32 | `kernal_vec_hole` (RESTOR clobber; keep empty) |

---

## VIC graphics (bank 3, play)

`$d018 = $16`. `$DD00` bits 0–1 = `%00`. Re-apply after `LoadPrg` / `IOINIT`.

| Resource | Address |
|----------|---------|
| Screen RAM | `$C400` |
| Sprite pointers | `$C7F8`–`$C7FF` |
| Sprites (contiguous) | `$C800`–`$D7BF` (4032) |
| Charset | `$D800`–`$DB4F` |
| Colour RAM | `$D800`–`$DBFF` (I/O in only) |

---

## Free scrap (tracked at assemble)

See `mem:` ACME warnings: code window to `$9000`, high to `py_tab`, kernal scrap before `$FFFA`.

Sources: `squaredoom.asm`, `mem_vic.asm`, `zeropage.asm`, `boot.asm`, `menu.asm`, `warmstart.asm`, `loader.asm`, `squaredoom.lbl`.
