# SquareDoom memory map

Snapshot of C64 RAM after **boot → MENU → GFX copy → GAME** has finished and the game is running (`$01 = $34`: BASIC and KERNAL out, I/O out — all 64K DRAM). Addresses from `mem_vic.asm`, `zeropage.asm`, `boot.asm`, `menu.asm`, `squaredoom.asm`, and `squaredoom.lbl` (rebuild refreshes labels).

## Boot sequence

Autostart file name is **`squaredoom`** (`boot.prg`). Boot KERNAL-loads **`splashc`** then **`splash`** first (cover paints in colour, stays up during the slow INSTALL), then **`loader`** (`$8E00`) and **`install`** (`$2000`), `JSR $2000`, then every later load is Krill `loadraw` (CLC → dest from the PRG header). `UNINSTALL_API=0`: do **not** `IOINIT` while Krill is up (`$DD02=$3F` tears down the drive code).

1. `IOINIT`, CLI. KERNAL-load **`splashc`** at `$4000` (matrix in place, colour staging `$43E8`). Copy colour → `$D800`, clear bitmap, bank-1 MCM on. KERNAL-load **`splash`** at `$6000` (bitmap paints in already coloured).
2. KERNAL-load `LOADER` + `INSTALL` (splash stays; restore `$dd00` bank 1). `JSR install`. Absolute `$dd00=%00000010` again (Krill DDRA).
3. Copy a trampoline to `$02A0` (below the overlay). `loadraw` **`menu`** at `LOCODE_BASE` (`$0400`), `JMP $0400`. MENU `init_menu_vic` blanks DEN, then draws.
4. MENU UI. Selectors land in `$02FA`–`$02FF`. On start: `loadraw` **`gfx`** at `GFX_STAGING` (`$A000`), `copy_vic` (`$01=$34`, sprite tail → `$D000`, charset → `$D800`).
5. Trampoline `loadraw` **`game`** at `$0400` (code only, overwrites MENU). `TXS $FF`, `JMP $0400` (`locode_entry`).
6. `locode_entry` `loadraw` **`high`** at `$9000` (tables, `py_tab`, sprite head), copies the kernal blob `$9000` → `$F930`, `init_sqtabs`, then `game_start` → `LoadLevel`.

In-game Run/Stop and E1M8 complete `JMP reboot_game`, which `IOINIT`s (uninstalls Krill), KERNAL-loads `SQUAREDOOM`, and `JMP $080d`. `game_complete=1` makes the next MENU entry show the ending pages.

Krill was built with `LOAD_UNDER_D000_DFFF=0`, so GFX is still copied **while MENU owns `$0400`**. `game.prg` is code `$0400`–`end_code` only (must end before Krill `$8E00`). `high.prg` is `$9000`–`$D000`. `$D000+` is under-I/O RAM (sprite tail + charset). `loadraw` of MENU/GAME at `$0400` overwrites the caller, hence the `$02A0` trampoline.

**Selectors that survive GAME load** (GAME starts at `$0400`):

| Addr | Symbol |
|------|--------|
| `$02A0` | `KRILL_STUB` (transient trampoline; leftover after GAME load) |
| `$02F8` | `sid_filt_shadow` / `sid_vol_shadow` |
| `$02FA` | `episode` |
| `$02FB` | `music_vol` |
| `$02FC` | `level_num` |
| `$02FD` | `effects_vol` |
| `$02FE` | `game_complete` |
| `$02FF` | `difficulty` |

**Menu VIC** (while MENU.PRG is resident): hires bitmap, bank 1, matrix `$4000`, bitmap `$6000`. Boot first uses this bank for the Koala splash (MCM), still showing through Krill install and MENU load. Split rasters mux skull cursor + WS/AD/RETURN hints. Game play uses charset bank 3 (`$C400` / `$D800`) as below.

---

**`locode_entry` effects that define the play map**

| Step | Result |
|------|--------|
| `$01 ← $35` | I/O in for VIC/CIA init |
| `set_vic_bank3` | `$DD00` bits 0–1 = `%00` (bank `$C000`); `$d018 ← $16` (screen `$C400`, charset `$D800`) |
| `loadraw HIGH` | Tables / py_tab / sprite head at `$9000`–`$D000` |
| `copy_kernal_blob` | `$9000` staging → `$F930` |
| `$01 ← $34` | DRAM at `$D000–$DFFF` (sprite tail + charset already copied by MENU `copy_vic`) |
| `init_sqtabs` | Judd SQTAB at `$BC00–$C3FF` (overwrites copy stub at `$BC00`) |
| Colour RAM cleared | `$D800–$DBFF` colour SRAM (at `$35`; not charset DRAM) |
| `$01 ← $34` | Play default before `game_start` |
| `input_irq_init` | Hardware IRQ `$FFFE` → `input_irq`; NMI `$FFFA` / soft `$0318` → `nmi_stub` |

IRQ/NMI save `$01`, set `$35`, **then** ack `$dc0d` / `$dd0d`. `LoadPrg` sets `$01=$35` (`BANK_LOADER`) around `jsr loadraw`, restores bank 3 and `$01=$34`. Colour blit copies pattern at `$34` and colour RAM at `$35`, yielding `$34`+`cli` each column.

Disk loads during play (levels → `$9000` cooked blob) overwrite the level window. **Never `IOINIT`/`RESTOR` on that path.** Krill ZP is `$60`–`$64` (render `last_near_*` scratch; dead across a load).

---

## Per-kilobyte map (game running)

Sizes are noted when a region does **not** fill the whole 1K page. Ranges are inclusive. Code entry addresses drift; prefer symbols in `squaredoom.lbl`.

| KB | Range | Contents |
|----|-------|----------|
| 0 | `$0000`–`$03FF` | CPU port, game zero page, under-stack play BSS, cassette scrap, FX overlay. **`KRILL_STUB`** `$02A0`. Selectors `$02FA`–`$02FF`. |
| 1–31 | `$0400`–`$7FFF` | Play code (`game.prg` from `LOCODE_BASE`). Must end before Krill `$8E00`. |
| 32–35 | `$8000`–`$8FFF` | Rest of play code; **Krill resident** `$8E00`–`$8EEC`; gap then map `$9000`. |
| 36–39 | `$9000`–`$9FFF` | **Level** (disk) after `LoadLevel`; HIGH first stages kernal blob + tables here. |
| 40–43 | `$A000`–`$AFFF` | High tables / sky / recip / item bitmaps / pcsfreq (`high.prg`). Free to `py_tab` `$B000`. |
| 44–46 | `$B000`–`$BBFF` | `py_tab` (12 pages, `high.prg`). |
| 47 | `$BC00`–`$BFFF` | **SQTAB1–2**. HIGH has `copy_kernal_blob` at `$BC00` until `init_sqtabs`. |
| 48 | `$C000`–`$C3FF` | **SQTAB3–4**. Do not point `$d018` at screen block 0. |
| 49 | `$C400`–`$C7FF` | **VIC screen** (1K). Sprite pointers **`$C7F8`**. |
| 50 | `$C800`–`$CBFF` | Weapon sprites (first 2K from `high.prg`). |
| 51 | `$CC00`–`$CFFF` | Chainsaw / minigun A. |
| 52 | `$D000`–`$D3FF` | Sprite **tail DRAM** (from `gfx.prg`, copied at `$01=$34`): rocket / shotgun / pistol. At `$35` these addresses are VIC registers. |
| 53 | `$D400`–`$D7FF` | Muzzle / cock. |
| 54 | `$D800`–`$DBFF` | **Charset DRAM** `$D800`–`$DB4F` (from `gfx.prg`). At `$35`, `$D800` is **colour SRAM**. |
| 55 | `$DC00`–`$DFFF` | CIA1/2 (at `$35`); DRAM at `$34`. |
| 56 | `$E000`–`$E3FF` | **`SCREENBUFFER`** (**1024**). Play colour backbuffer (entering / summary / melt / mapscreen / HUD). No menu overlay. |
| 57 | `$E400`–`$E7FF` | **`PATTERNBUFFER`** (**1024**). |
| 58–59 | `$E800`–`$EFFF` | **`COL_CLIP_N`**, contiguous clip columns, then ray cache from `$F0E8`. |
| 60–61 | `$F000`–`$F7FF` | Ray cache, profiler, door processes, `SEC_SEEN`, item sort, mobj SoA, `SEC_FLATGRP`. |
| 62 | `$F800`–`$FBFF` | `SEC_VISITED` / `SEC_WDARK`. Relocated **dpsounds** from `$F930`. |
| 63 | `$FC00`–`$FFFF` | `sound_table`, **levelstats**. Hardware vectors `$FFFA`–`$FFFF`. |

---

## Major regions (summary)

| Range | Role |
|-------|------|
| `$0002`–`$00FF` | Zero page |
| `$0100`–`$0170` | Under-stack play BSS (`SCRAP_UNDER`) |
| `$02A0` | `KRILL_STUB` (boot/MENU trampoline) |
| `$02FA`–`$02FF` | Menu/game selectors |
| `$0400`–`$8DFF` | Play code (`game.prg`); must end before `loadraw` `$8E00` |
| `$8E00`–`$8EEC` | Krill resident (`loadraw`) |
| `$9000`–`$9D90` | Level blob (disk) |
| `$9D91`–`$AFFF` | High tables / sky / recip / items / pcsfreq |
| `$B000`–`$BBFF` | `py_tab` |
| `$BC00`–`$C3FF` | SQTAB1–4 |
| `$C400`–`$C7FF` | VIC screen + sprite pointers |
| `$C800`–`$D7BF` | Weapon sprites (head in `high.prg`, tail from `gfx.prg`) |
| `$D800`–`$DB4F` | Charset DRAM (`$34`) / colour SRAM window (`$35`) |
| `$E000`–`$F92F` | Play BSS (screen/pattern/clip/rays/procs/mobj/sector tables) |
| `$F930`–`$FF8B` | dpsounds + levelstats |
| `$FFFA`–`$FFFF` | Vectors |

---

## Disk files

| DOS name | PRG | Load |
|----------|-----|------|
| `squaredoom` | `boot.prg` | `$0801` (SYS 2061) |
| `loader` | `krill/loader.prg` | `$8E00` (resident; KERNAL-loaded once) |
| `install` | `krill/install.prg` | `$2000` (transient installer) |
| `splashc` | `splashc.prg` | `$4000` (MCM matrix + colour staging `$43E8`; copied to `$D800`) |
| `splash` | `splash.prg` | `$6000` (8000-byte MCM bitmap; paints in after colour) |
| `menu` | `menu.prg` | `$0400` (must end before `$4000`) |
| `gfx` | `gfx.prg` | `$A000` (sprite tail + charset; copied under I/O) |
| `game` | `game.prg` | `$0400`–`end_code` |
| `high` | `high.prg` | `$9000`–`$D000` |
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
| `$E828` | 2240 | clip (40 × 56, contiguous) |
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

---

## VIC graphics (bank 3, play)

`$d018 = $16`. `$DD00` bits 0–1 = `%00`. Re-apply after `LoadPrg` (Krill may touch CIA2 PRA).

| Resource | Address |
|----------|---------|
| Screen RAM | `$C400` |
| Sprite pointers | `$C7F8`–`$C7FF` |
| Sprites (contiguous) | `$C800`–`$D7BF` (4032) |
| Charset | `$D800`–`$DB4F` |
| Colour RAM | `$D800`–`$DBFF` (I/O in only) |

---

## Free scrap (tracked at assemble)

See `mem:` ACME warnings: code window to Krill `$8E00`, high to `py_tab`, kernal scrap before `$FFFA`.

Sources: `squaredoom.asm`, `mem_vic.asm`, `zeropage.asm`, `boot.asm`, `menu.asm`, `warmstart.asm`, `loader.asm`, `squaredoom.lbl`.
