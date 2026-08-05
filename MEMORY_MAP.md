# SquareDoom memory map (post–warm start, game running)

Snapshot of C64 RAM after `warmstart` has finished and the game is running (`$01 = $35`: BASIC and KERNAL ROMs out, I/O in at `$D000`). Addresses from `squaredoom.asm`, `zeropage.asm`, `warmstart.asm`, and `squaredoom.lbl` (rebuild refreshes labels).

**Warm-start effects that define this map**

| Step | Result |
|------|--------|
| `$01 ← $35` | RAM under `$A000` and `$E000`; I/O visible at `$D000` |
| `$d018 ← $1e` | VIC bank 0: screen `$0400`, charset `$3800` |
| `copy_kernal_blob` | `$C800` load image → `$F950` (**1673** bytes) |
| `init_sqtabs` | Judd SQTAB rebuilt over `$C800`–`$CFFF` (blob destroyed there) |
| Colour RAM cleared | `$D800`–`$DBFF` |
| `input_irq_init` | Hardware IRQ `$FFFE` → `input_irq`; NMI `$FFFA` / soft `$0318` → `nmi_stub` |

Disk loads during play (levels → `$9000` SID + `$A000` map in one PRG, UI → `$E000`, menu → `$E250`) overwrite the noted windows. **`LoadPrg` banks `$01=$36` (KERNAL in)** and RESTOR stomps underlay **`$FD30–$FD4F`** — reserved as `kernal_vec_hole` (empty); do not place code there.

---

## Per-kilobyte map

Sizes are noted when a region does **not** fill the whole 1K page. Ranges are inclusive. Code entry addresses drift; prefer symbols in `squaredoom.lbl`.

| KB | Range | Contents |
|----|-------|----------|
| 0 | `$0000`–`$03FF` | **`$0000`–`$0001`** (2): CPU port / DDR. **`$0002`–`$00FF`** (254): game zero page (see `zeropage.asm`). **`$0100`–`$016E`**: under-stack play BSS (`missile_*`…`map_pl_*`; `SCRAP_UNDER_END` `$016F`). **`$016F`–`$019F`** (**49**): free under-stack. Stack keeps `$01A0`–`$01FF`. **`$0200`–`$03FF`**: scrap; **`$02F8`/`$02F9`** = music `$D417`/`$D418` shadows (SidTracker). **`$0314`–`$0333`**: KERNAL soft-vector page (rewritten when KERNAL is in). **`$033C`–`$0348`**: levelstats BSS. **`$0349`–`$0383`**: cassette scrap BSS (input/cheats/menu/load/`item_slot`; `SCRAP_CASS_END` `$0384`). **`$0384`–`$03FB`** (**120**): free cassette. |
| 1 | `$0400`–`$07FF` | **`$0400`–`$07E7`** (1000): VIC screen RAM (blit target). **`$07E8`–`$07F7`** (16): unused under screen. **`$07F8`–`$07FF`** (8): sprite pointers. |
| 2 | `$0800`–`$0BFF` | BASIC stub (`$0801` SYS `$080D` → `warmstart` `$0810`), `copy_kernal_blob`, `init_sqtabs`, maths helpers. |
| 3 | `$0C00`–`$0FFF` | Low code: util / messages; `input_irq_init` `$0D82`, `nmi_stub` `$0DF4`, `input_irq` `$0DFA`. |
| 4 | `$1000`–`$13FF` | Low code: profiler (`prof_init` `$1366`), early render setup. |
| 5 | `$1400`–`$17FF` | Low code: column cast (`cast_column` `$16CD`). |
| 6 | `$1800`–`$1BFF` | Low code: render / portal paint. |
| 7 | `$1C00`–`$1FFF` | Low code: item collect/sort/draw. |
| 8 | `$2000`–`$23FF` | Low code: item draw / VDDA. |
| 9 | `$2400`–`$27FF` | Low code: `blit_fb` `$248B`, enemy_low, mapscreen. |
| 10 | `$2800`–`$2BFF` | Low code through `end_low` `$28B3`. **`$28B3`–`$293F`** (**141**): free scrap. **`$2940`–`$29FF`** (192): minigun B sprites (3×64). **`$2A00`–`$2BFF`** (512): fist right-hand sprites (8×64). |
| 11 | `$2C00`–`$2FFF` | **`$2C00`–`$2DBF`**: fist punch sprites. **`$2DC0`–`$2DFF`** (64): chainsaw blade hi2 (overwrites punch pad). **`$2E00`–`$2FFF`** (512): chainsaw body layers (8×64). |
| 12 | `$3000`–`$33FF` | **`$3000`–`$317F`** (384): minigun A/shared (6×64). **`$3180`–`$337F`** (512): rocket + pink flash (8×64). **`$3380`–`$33FF`**: start of shotgun body sprites. |
| 13 | `$3400`–`$37FF` | Shotgun body through `$34FF`. **`$3500`–`$367F`** (384): pistol body (6×64). **`$3680`–`$377F`** (256): shared muzzle flash A/B (4×64). **`$3780`–`$37FF`** (128): gap before charset. |
| 14 | `$3800`–`$3BFF` | **`$3800`–`$3B4F`** (848): packed charset (106 chars × 8). **`$3B50`–`$3B7F`** (48): charset pad. **`$3B80`–`$3BFF`**: shotgun cock sprites (start of 6×64 = 384). |
| 15 | `$3C00`–`$3FFF` | Rest of cock sprites through `$3CFF`. **`$3D00`–`$3FFF`**: **mid code** start (`MID_BASE`) — weapon setup, HUD init, gameloop early. |
| 16–25 | `$4000`–`$67FF` | Mid code: weapons, playsound, player, process, enemies, missiles/hitscan, HUD, pickup, cheats. |
| 26 | `$6800`–`$6BFF` | Mid code: loader (`LoadPrg` `$6943`, `LoadLevel` `$69C8`, `LoadMenu` `$69D9`), `game_start` `$69FF`, titleflow / `music_init` `$6A44`. |
| 27 | `$6C00`–`$6FFF` | Mid code: title/print helpers (`cell_addr` `$6C8D`), render_near / project_y / clip. |
| 28 | `$7000`–`$73FF` | Mid code tail + **enemy mip headers** (`enemy_mip_*` ~`$712E`). Soft-sprite atlas follows. |
| 29–34 | `$7400`–`$8BFF` | Enemy soft-sprite mip atlas. |
| 35 | `$8C00`–`$8FFF` | Enemy atlas end. **`wall_switch_tex`** through `$8F48`. **`end_mid`** `$8F49`; **`$8F49`–`$8FFF`** (**183**): free mid scrap. |
| 36–39 | `$9000`–`$9FFF` | **SID music window** (4K) — level PRG prefix (relocated SidTracker + pad); init `$9000`, play `$9003`. **`$9FFF`**: SidTracker flag (1 = shadow merge). |
| 40 | `$A000`–`$A3FF` | **Level data** (disk): `level_map` 32×32 = **1024** bytes. |
| 41 | `$A400`–`$A7FF` | Level sector tables: `SEC_FLOOR`/`CEIL`/`TYPE`/`TARGET`/`FCOL`/`CCOL` (200 each); into `SEC_BRIGHT`. |
| 42 | `$A800`–`$ABFF` | Level tail through `$AA50` (**2641** total). Then high tables: `angtab` `$AA51`, `fishtab` `$AA79`, dist/colbase/maprow, start of `sintab` `$ABF4`. |
| 43 | `$AC00`–`$AFFF` | Rest of `sintab`/`costab`, `sky_cols` `$AD34` (40×12 = **480**), start of `recip_lo` `$AF14`. |
| 44 | `$B000`–`$B3FF` | `recip_hi` `$B014` (**256**), item mip headers / soft-sprites. |
| 45–46 | `$B400`–`$BBFF` | Item soft-sprite bitmaps. **`$BB32`–`$BBF1`**: `pcsfreq_lo`/`hi`. **`end_high`** `$BBF2`; **`$BBF2`–`$BBFF`** (**14**): free high. |
| 47–49 | `$BC00`–`$C7FF` | `py_tab` (12 pages; flush against SQTAB). |
| 50–51 | `$C800`–`$CFFF` | **SQTAB1–4** (Judd; built at warm start; replaces load-time kernal blob). |
| 52–55 | `$D000`–`$DFFF` | I/O: VIC, SID, colour RAM `$D800`, CIA1/2. |
| 56 | `$E000`–`$E3FF` | **`SCREENBUFFER`** (**1024**). UI loads use first **592** (`UI_LOAD_MAX`). **`MENU_BASE`** `$E250`. |
| 57 | `$E400`–`$E7FF` | **`PATTERNBUFFER`** (**1024**). |
| 58–59 | `$E800`–`$EFFF` | **`COL_CLIP_N`** `$E800` (**40**); **`COL_CLIP_ENTRIES`** `$E828` (40 × 56 = **2240**). |
| 60 | `$F000`–`$F3FF` | Clip stacks end `$F0E7`. **`$F0E8`–`$F277`** (**400**): ray cache. **`$F278`–`$F29E`** (**39**): profiler BSS. **`$F29F`–`$F2CE`** (**48**): door processes. **`$F2CF`–`$F396`** (**200**): `SEC_SEEN`. Item sort starts `$F397`. |
| 61 | `$F400`–`$F7FF` | Item sort through `$F4E6`. **`$F4E7`–`$F6F7`** (**529**): mobj SoA + aim. **`$F6F8`–`$F7BF`** (**200**): `SEC_FLATGRP`. **`$F7C0`–`$F7FF`**: start of `SEC_VISITED`. |
| 62 | `$F800`–`$FBFF` | Rest of `SEC_VISITED` (**200** @ `$F7C0`). **`SEC_WDARK`** `$F888` (**200**). **`$F950`–`$FBFF`**: relocated **dpsounds** (`dpclaw` `$F950`). |
| 63 | `$FC00`–`$FFFF` | `sound_table` `$FC68`, **levelstats** (`init_level_stats` `$FC8E`, `summary_tick` `$FD08`). **`kernal_vec_hole`** `$FD30`–`$FD4F` (**32**, empty — RESTOR/LoadPrg clobber). Roll-in / `put_pct_val` `$FD7F`, `summary_screen` `$FEA8`, through **`end_kernal`** `$FFD9`. **`$FFD9`–`$FFF9`** (**33**): free kernal scrap. **`$FFFA`–`$FFFF`** (**6**): hardware vectors (IRQ → `input_irq`; NMI → `nmi_stub`). |

---

## Major regions (summary)

| Range | Size | Role |
|-------|------|------|
| `$0002`–`$00FF` | 254 | Zero page |
| `$0100`–`$016E` | 111 | Under-stack play BSS (`SCRAP_UNDER`) |
| `$016F`–`$019F` | 49 | Free under-stack |
| `$033C`–`$0348` | 13 | Levelstats BSS |
| `$0349`–`$0383` | 59 | Cassette scrap BSS (`SCRAP_CASS`) |
| `$0384`–`$03FB` | 120 | Free cassette |
| `$0400`–`$07FF` | 1K | VIC screen + sprite pointers |
| `$0801`–`$28B2` | ~8.3K | Low code |
| `$28B3`–`$293F` | 141 | Free low |
| `$2940`–`$3CFF` | ~3.3K | Weapon VIC sprites (+ charset `$3800`–`$3B4F`, cock `$3B80`) |
| `$3D00`–`$8F48` | ~20.6K | Mid code + enemy mip atlas |
| `$8F49`–`$8FFF` | 183 | Free mid |
| `$9000`–`$9FFF` | 4K | SID music (level PRG prefix; init `$9000` / play `$9003`) |
| `$A000`–`$AA50` | 2641 | Level blob (disk) |
| `$AA51`–`$BBF1` | ~4.4K | High tables / sky / recip / item bitmaps / pcsfreq |
| `$BBF2`–`$BBFF` | 14 | Free high |
| `$BC00`–`$C7FF` | 3K | `py_tab` |
| `$C800`–`$CFFF` | 2K | SQTAB1–4 |
| `$D000`–`$DFFF` | 4K | I/O + colour RAM |
| `$E000`–`$F94F` | ~6.3K | Play BSS (screen/pattern/clip/rays/procs/mobj/sector tables) |
| `$F950`–`$FFD8` | 1673 | dpsounds + levelstats (incl. `$FD30` hole) |
| `$FFD9`–`$FFF9` | 33 | Free kernal scrap |
| `$FFFA`–`$FFFF` | 6 | Vectors |

---

## Level layout at `$A000` (2641 bytes)

| Addr | Size | Field |
|------|------|-------|
| `$A000` | 1024 | `level_map` 32×32 |
| `$A400` | 200 | `SEC_FLOOR` |
| `$A4C8` | 200 | `SEC_CEIL` |
| `$A590` | 200 | `SEC_TYPE` |
| `$A658` | 200 | `SEC_TARGET` |
| `$A720` | 200 | `SEC_FCOL` |
| `$A7E8` | 200 | `SEC_CCOL` |
| `$A8B0` | 200 | `SEC_BRIGHT` |
| `$A978` | 3 | spawn x, y, angle |
| `$A97B` | 192 | items SoA (4×48) |
| `$AA3B` | 17 | switch faces |
| `$AA4C` | 5 | sector_max, enemies, items, secrets, par |
| `$AA51` | — | `angtab` (first high table) |

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
| `$F4E7` | 529 | `MOBJ_*` + aim |
| `$F6F8` | 200 | `SEC_FLATGRP` |
| `$F7C0` | 200 | `SEC_VISITED` |
| `$F888` | 200 | `SEC_WDARK` |
| `$F950` | 1673 | dpsounds + levelstats through `end_kernal` (`SEC_WDARK_END`) |
| `$FD30` | 32 | `kernal_vec_hole` (RESTOR clobber; keep empty) |

---

## VIC graphics (bank 0)

| Resource | Address |
|----------|---------|
| Screen RAM | `$0400` |
| Sprite pointers | `$07F8`–`$07FF` |
| Charset | `$3800`–`$3B4F` |
| Colour RAM | `$D800`–`$DBFF` |
| Minigun B | `$2940` (192) |
| Fist right | `$2A00` (512) |
| Fist punch | `$2C00` |
| Chainsaw | `$2DC0` / `$2E00` |
| Minigun A | `$3000` (384) |
| Rocket | `$3180` (512) |
| Shotgun | `$3380` (384) |
| Pistol | `$3500` (384) |
| Muzzle flash | `$3680` (256) |
| Shotgun cock | `$3B80` (384) |

---

## Free scrap (tracked at assemble)

| Region | Bytes | Notes |
|--------|------:|-------|
| Under-stack (`$016F`–`$019F`) | 49 | After play BSS |
| Cassette (`$0384`–`$03FB`) | 120 | After scrap BSS |
| Low (`$28B3`–`$293F`) | 141 | Before minigun B |
| Mid (`$8F49`–`$8FFF`) | 183 | Before SID |
| High (`$BBF2`–`$BBFF`) | 14 | Before `py_tab` |
| Kernal scrap (`$FFD9`–`$FFF9`) | 33 | After levelstats; before `$FFFA` |
| Menu budget (`$E250`–`$F0E7`) | 3736 | When MENU.PRG loaded |

Sources: `squaredoom.asm`, `zeropage.asm`, `warmstart.asm`, `loader.asm`, `levelstats.asm`, `squaredoom.lbl`.
