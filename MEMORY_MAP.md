# SquareDoom memory map (post–warm start, game running)

Snapshot of C64 RAM after `warmstart` has finished and the game is running (`$01 = $34`: BASIC and KERNAL out, I/O out — all 64K DRAM). Addresses from `squaredoom.asm`, `mem_vic.asm`, `zeropage.asm`, `warmstart.asm`, and `squaredoom.lbl` (rebuild refreshes labels).

**Warm-start effects that define this map**

| Step | Result |
|------|--------|
| `$01 ← $35` | I/O in for VIC/CIA init |
| `set_vic_bank3` | `$DD00` bits 0–1 = `%00` (bank `$C000`); `$d018 ← $16` (screen `$C400`, charset `$D800`) |
| `copy_kernal_blob` | `$9000` staging → `$F930` (**1717** bytes) |
| `$01 ← $34` | DRAM at `$D000–$DFFF`; copy sprite tail `$D000–$D7BF` + charset `$D800` |
| `init_sqtabs` | Judd SQTAB at `$BC00–$C3FF` (overwrites copy stubs at `$BC00`) |
| Colour RAM cleared | `$D800–$DBFF` colour SRAM (at `$35`; not charset DRAM) |
| `$01 ← $34` | Play default before `game_start` / `cli` |
| `input_irq_init` | Hardware IRQ `$FFFE` → `input_irq`; NMI `$FFFA` / soft `$0318` → `nmi_stub` |

IRQ/NMI save `$01`, set `$35`, **then** ack `$dc0d` / `$dd0d`. `LoadPrg` uses `$36` for KERNAL, restores bank 3 and `$01=$34`. Colour blit copies pattern at `$34` and colour RAM at `$35`, yielding `$34`+`cli` each column.

Disk loads during play (levels → `$9000` cooked blob, UI → `$E000`, menu → `$E250`) overwrite the noted windows. **`LoadPrg` banks `$01=$36` (KERNAL in)** and RESTOR stomps underlay **`$FD30–$FD4F`** — reserved as `kernal_vec_hole` (empty); do not place code there.

---

## Per-kilobyte map

Sizes are noted when a region does **not** fill the whole 1K page. Ranges are inclusive. Code entry addresses drift; prefer symbols in `squaredoom.lbl`.

| KB | Range | Contents |
|----|-------|----------|
| 0 | `$0000`–`$03FF` | **`$0000`–`$0001`** (2): CPU port / DDR. **`$0002`–`$00FF`** (254): game zero page (see `zeropage.asm`). **`$0100`–`$0170`**: under-stack play BSS (`SCRAP_UNDER_END` `$0171`). **`$0171`–`$019F`** (**47**): free under-stack. Stack keeps `$01A0`–`$01FF`. **`$0200`–`$03FF`**: scrap; **`$02F8`/`$02F9`** = music `$D417`/`$D418` shadows. **`$0314`–`$0333`**: KERNAL soft-vector page. **`$033C`–`$0348`**: levelstats BSS. **`$0349`–`$0383`**: cassette scrap BSS (`SCRAP_CASS_END` `$0384`). **`$0384`–`$03C3`** (**64**): FX overlay (`FX_KIND/TX/TY/TIME`). **`$03C4`–`$03FB`** (**56**): free cassette. |
| 1 | `$0400`–`$07FF` | Free scrap (old bank-0 screen). Not displayed. |
| 2 | `$0800`–`$0BFF` | BASIC stub (`$0801` SYS → `warmstart` `$0810`), `init_sqtabs` `$0861`, util (`io_push` `$09BC`, `set_vic_bank3` `$09D3`). |
| 3 | `$0C00`–`$0FFF` | Code: `input_irq_init` `$0DAA`, `nmi_stub` `$0E1C`, `input_irq` `$0E2C`. |
| 4–31 | `$1000`–`$7DFF` | Merged play code (render, blit, weapons, loader, titleflow, enemy atlas). `wall_switch_tex` `$7D45`. **`end_code` `$7E45`**. |
| 32 | `$7E00`–`$81FF` | Sprite **tail** src (`vic_sprite_tail` `$7E45`, 1984 bytes → copied to `$D000`). Charset src starts `$8605`. |
| 33 | `$8200`–`$85FF` | Rest of sprite tail. |
| 34 | `$8600`–`$89FF` | **`charset_src` `$8605`–`$8954`** (848). **`$8955`–`$8FFF`** (**1707**): free to map. |
| 35 | `$8C00`–`$8FFF` | Free tail of code window. |
| 36–39 | `$9000`–`$9FFF` | **Level** (disk): `level_map` `$9000` (**1024**), `level_items` `$9400` (**1024**), sector tables from `SEC_FLOOR` `$9800`. Spawn/switch/stats through `$9D90`. **`angtab` `$9D91`**. |
| 40 | `$A000`–`$A3FF` | High tables: `fishtab` `$9DB9`, `sky_cols` `$A074`, `recip_lo` `$A254`. |
| 41 | `$A400`–`$A7FF` | Item mip headers / soft-sprites. |
| 42–43 | `$A800`–`$AFFF` | Item bitmaps. **`pcsfreq_lo` `$AE72`**, `pcsfreq_hi` `$AED2`. **`end_high` `$AF32`**; **`$AF32`–`$AFFF`** (**206**): free to `py_tab`. |
| 44–46 | `$B000`–`$BBFF` | `py_tab` (12 pages). |
| 47 | `$BC00`–`$BFFF` | **SQTAB1–2**. Load image has copy stubs (`copy_kernal_blob` `$BC00`, `copy_vic_gfx` `$BC30`) until `init_sqtabs`. |
| 48 | `$C000`–`$C3FF` | **SQTAB3–4** (`$C000`–`$C3FF`). Do not point `$d018` at screen block 0. |
| 49 | `$C400`–`$C7FF` | **VIC screen** (1K). Sprite pointers **`$C7F8`**. Always DRAM — blit dest every frame. |
| 50 | `$C800`–`$CBFF` | Weapon sprites (minigun B `$C800`, fist right `$C8C0`, punch `$CAC0`). First 2K loaded in place from the PRG. |
| 51 | `$CC00`–`$CFFF` | Chainsaw hi2 `$CC80` / body `$CCC0`, minigun A `$CEC0`. |
| 52 | `$D000`–`$D3FF` | Sprite **tail DRAM** (visible at `$01=$34` only): rocket `$D040`, shotgun `$D240`, pistol `$D3C0`. At `$35` these addresses are VIC registers — IRQ must not write sprite bytes here. |
| 53 | `$D400`–`$D7FF` | Muzzle `$D540`, cock `$D640`–`$D7BF`. |
| 54 | `$D800`–`$DBFF` | **Charset DRAM** `$D800`–`$DB4F` (848; init at `$34`). At `$35`, `$D800` is **colour SRAM** (blit target). Do not `sta` charset/sprite bytes at `$35`. Char codes ≥ 128 unused. |
| 55 | `$DC00`–`$DFFF` | CIA1/2 (at `$35`); DRAM at `$34`. |
| 56 | `$E000`–`$E3FF` | **`SCREENBUFFER`** (**1024**). UI loads use first **592** (`UI_LOAD_MAX`). **`MENU_BASE`** `$E250`. |
| 57 | `$E400`–`$E7FF` | **`PATTERNBUFFER`** (**1024**). MENU.PRG through `$E794`. |
| 58–59 | `$E800`–`$EFFF` | **`COL_CLIP_N`** `$E800` (**40**); **`COL_CLIP_ENTRIES`** `$E828` (40 × 56 = **2240**). |
| 60 | `$F000`–`$F3FF` | Clip stacks end `$F0E7`. **`$F0E8`–`$F277`** (**400**): ray cache. **`$F278`–`$F29E`** (**39**): profiler BSS. **`$F29F`–`$F2CE`** (**48**): door processes. **`$F2CF`–`$F396`** (**200**): `SEC_SEEN`. Item sort starts `$F397`. |
| 61 | `$F400`–`$F7FF` | Item sort through `$F4E6`. **`$F4E7`–`$F6D7`** (**497**): mobj SoA + aim. **`$F6D8`–**: `SEC_FLATGRP`. |
| 62 | `$F800`–`$FBFF` | `SEC_VISITED` `$F7A0` (**200**). **`SEC_WDARK`** `$F868` (**200**). **`$F930`–`$FBFF`**: relocated **dpsounds** (`dpclaw` `$F930`). |
| 63 | `$FC00`–`$FFFF` | `sound_table` `$FC48`, **levelstats** (`init_level_stats` `$FC6E`, `summary_screen` `$FEA8`). **`kernal_vec_hole`** `$FD30`–`$FD4F` (**32**, empty — RESTOR/LoadPrg clobber). Through **`end_kernal`** `$FFE5`. **`$FFE5`–`$FFF9`** (**21**): free kernal scrap. **`$FFFA`–`$FFFF`** (**6**): hardware vectors (IRQ → `input_irq`; NMI → `nmi_stub`). |

---

## Major regions (summary)

| Range | Size | Role |
|-------|------|------|
| `$0002`–`$00FF` | 254 | Zero page |
| `$0100`–`$0170` | 113 | Under-stack play BSS (`SCRAP_UNDER`) |
| `$0171`–`$019F` | 47 | Free under-stack |
| `$033C`–`$0348` | 13 | Levelstats BSS |
| `$0349`–`$0383` | 59 | Cassette scrap BSS (`SCRAP_CASS`) |
| `$0384`–`$03C3` | 64 | FX overlay (`FX_*`) |
| `$03C4`–`$03FB` | 56 | Free cassette |
| `$0400`–`$07FF` | 1K | Free (not VIC screen) |
| `$0801`–`$7E44` | ~30.1K | Play code |
| `$7E45`–`$8954` | 2832 | Sprite tail src + charset src |
| `$8955`–`$8FFF` | 1707 | Free to map |
| `$9000`–`$9D90` | 3473 | Level blob (disk) |
| `$9D91`–`$AF31` | ~4.5K | High tables / sky / recip / item bitmaps / pcsfreq |
| `$AF32`–`$AFFF` | 206 | Free high |
| `$B000`–`$BBFF` | 3K | `py_tab` |
| `$BC00`–`$C3FF` | 2K | SQTAB1–4 |
| `$C400`–`$C7FF` | 1K | VIC screen + sprite pointers |
| `$C800`–`$D7BF` | 4032 | Weapon sprites (contiguous, 64-aligned) |
| `$D800`–`$DB4F` | 848 | Charset DRAM (`$34`) / colour SRAM window (`$35`) |
| `$E000`–`$F92F` | ~6.3K | Play BSS (screen/pattern/clip/rays/procs/mobj/sector tables) |
| `$F930`–`$FFE4` | 1717 | dpsounds + levelstats (incl. `$FD30` hole) |
| `$FFE5`–`$FFF9` | 21 | Free kernal scrap |
| `$FFFA`–`$FFFF` | 6 | Vectors |

---

## Level layout at `$9000` (3473 bytes, no angtab pad)

| Addr | Size | Field |
|------|------|-------|
| `$9000` | 1024 | `level_map` 32×32 |
| `$9400` | 1024 | `level_items` (type \| skill<<5, or 0) |
| `$9800` | 200 | `SEC_FLOOR` |
| `$98C8` | 200 | `SEC_CEIL` |
| `$9990` | 200 | `SEC_TYPE` |
| `$9A58` | 200 | `SEC_TARGET` |
| `$9B20` | 200 | `SEC_FCOL` |
| `$9BE8` | 200 | `SEC_CCOL` |
| `$9CB0` | 200 | `SEC_BRIGHT` |
| `$9D78` | 3 | spawn x, y, angle |
| `$9D7B` | 17 | switch faces |
| `$9D8C` | 5 | sector_max, enemies, items, secrets, par |
| `$9D91` | — | `angtab` (first high table) |

---

## Under-KERNAL play BSS (`$E000`+)

| Addr | Size | Symbol |
|------|------|--------|
| `$E000` | 1024 | `SCREENBUFFER` |
| `$E250` | — | `MENU_BASE` (overlay; budget to `$F0E8`) |
| `$E400` | 1024 | `PATTERNBUFFER` |
| `$E800` | 40 | `COL_CLIP_N` |
| `$E828` | 2240 | `COL_CLIP_ENTRIES` |
| `$F0E8` | 400 | column ray cache |
| `$F278` | 39 | `PROF_BSS` |
| `$F29F` | 48 | `PROC_*` |
| `$F2CF` | 200 | `SEC_SEEN` |
| `$F397` | 336 | `ITEM_SORT_*` |
| `$F4E7` | 497 | `MOBJ_*` + aim (`MOBJ_X/Y`, corpses per mobj) |
| `$F6D8` | 200 | `SEC_FLATGRP` |
| `$F7A0` | 200 | `SEC_VISITED` |
| `$F868` | 200 | `SEC_WDARK` |
| `$F930` | 1717 | dpsounds + levelstats through `end_kernal` (`SEC_WDARK_END`) |
| `$FD30` | 32 | `kernal_vec_hole` (RESTOR clobber; keep empty) |

---

## VIC graphics (bank 3)

`$d018 = $16`. `$DD00` bits 0–1 = `%00`. Re-apply after `LoadPrg` / `IOINIT`.

| Resource | Address |
|----------|---------|
| Screen RAM | `$C400` |
| Sprite pointers | `$C7F8`–`$C7FF` |
| Sprites (contiguous) | `$C800`–`$D7BF` (4032) |
| Charset | `$D800`–`$DB4F` |
| Colour RAM | `$D800`–`$DBFF` (I/O in only) |
| Minigun B | `$C800` (192) |
| Fist right | `$C8C0` (512) |
| Fist punch | `$CAC0` |
| Chainsaw | `$CC80` / `$CCC0` |
| Minigun A | `$CEC0` (384) |
| Rocket | `$D040` (512) |
| Shotgun | `$D240` (384) |
| Pistol | `$D3C0` (384) |
| Muzzle flash | `$D540` (256) |
| Shotgun cock | `$D640` (384) |

---

## Free scrap (tracked at assemble)

| Region | Bytes | Notes |
|--------|------:|-------|
| Under-stack (`$0171`–`$019F`) | 47 | After play BSS |
| Cassette (`$03C4`–`$03FB`) | 56 | After FX overlay |
| Code window (`$8955`–`$8FFF`) | 1707 | After charset src, before map |
| High (`$AF32`–`$AFFF`) | 206 | Before `py_tab` |
| Kernal scrap (`$FFE5`–`$FFF9`) | 21 | After levelstats; before `$FFFA` |
| Menu budget (`$E250`–`$F0E7`) | 3736 | When MENU.PRG loaded (overlay uses `$E250`–`$E793`) |

Sources: `squaredoom.asm`, `mem_vic.asm`, `zeropage.asm`, `warmstart.asm`, `loader.asm`, `levelstats.asm`, `squaredoom.lbl`.
