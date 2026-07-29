; SquareDoom — ACME root (C64)
!cpu 6502
!to "squaredoom.prg", cbm

; Column-major colour buffer (40×25); Judd tabs live under KERNAL at $E000
FRAMEBUFFER = $c800
; Matching lighting/pattern buffer (screen codes); hi = colour hi + 4
LIGHTFRAME = $cc00
CHARSET = $3800
FIST_RIGHT_SPRITES = $2a00	; 8×64 open right hand (7 used)
FIST_PUNCH_SPRITES = $2c00	; 8×64 punch pose (7 used; pad overwritten by saw hi2)
CHAINSAW_BLADE_HI2_SPRITES = FIST_PUNCH_SPRITES + 7 * 64	; $2dc0
CHAINSAW_SPRITES = $2e00	; 8×64-byte chainsaw (no flash; VIC bank 0)
MINIGUN_B_SPRITES = FIST_RIGHT_SPRITES - 3 * 64	; $2940 — frame B upper+grey L/R
MINIGUN_SPRITES = $3000	; 6×64 A/shared body (VIC bank 0)
ROCKET_SPRITES = $3180		; 8×64-byte rocket+pink flash (VIC bank 0)
SHOTGUN_SPRITES = $3380	; 6×64-byte shotgun body (VIC bank 0)
PISTOL_SPRITES = $3500		; 6×64-byte pistol body (VIC bank 0)
MUZZLE_FLASH_SPRITES = $3680	; 4×64 shared flash A/B white+red (pistol/sg/mg)
; Packed charset at $3800 (tools/gencharset.js) — mid code starts at MID_BASE
; 0–15 walls; 16–63 doomfont punct/HUD/digits + gap packs; 64–89 A–Z; 90–105 floors
MENU_CURSOR = 16		; skull (gap)
MAP_ARROW0 = 17			; arrows 17–20
MAP_SOLID = 21			; filled block (map + logo)
ITEM_PAT = MAP_SOLID		; item soft-sprite fill (solid)
MSG_LET0 = 64			; A–Z (walls own PETSCII letter codes 1–15)
MSG_LETTER0 = MSG_LET0
FLOOR_PAT_BASE = 90		; floor dither 90–105
CHARSET_NUM = 106
MID_BASE = CHARSET + CHARSET_NUM * 8	; $3b50

MAX_DDA = 32
PROFILE = 0
DBG_FPS = 0
DBG_PORTAL = 0
CENTER_COL = 19
MUZZLE_COL = 20			; pistol muzzle aim column
AIM_COL_SLACK = 2		; TryDamageEnemy also checks MUZZLE±this (18..22)
MAX_SECTORS = 199		; usable ids 1..199
SEC_TABLE_SIZE = 200		; index = sector id; [0] unused

; Memory ceilings:
;   low  → sprites before CHARSET; packed charset $3800..MID_BASE-1
;   mid  → MID_BASE → level_data at $a000; enemy mips here
;   high → FRAMEBUFFER at $c800 ($c000–$c7ff free after SQTAB move)
MEM_MID_LIMIT = $a000
MEM_HIGH_LIMIT = FRAMEBUFFER

!source "zeropage.asm"
!source "basicstub.asm"
!source "warmstart.asm"
!source "maths.asm"
!source "util.asm"
!source "input.asm"
!source "profil.asm"
!source "render.asm"
!source "blit.asm"
!source "weapon.asm"
; enemy boss-death floors — low for mid headroom
!source "enemy_low.asm"

end_low = *
free_low = MINIGUN_B_SPRITES - end_low
!if free_low < 0 {
	!error "Low code overlaps minigun B sprites at $2940; overshoot=", end_low - MINIGUN_B_SPRITES
}
!warn "mem: low  end=$", end_low, " free to minigun B $2940 =", free_low

; Weapon sprite banks in VIC bank 0, before charset
; minigun_weapon.asm: B×3 then *= MINIGUN_SPRITES for A/shared×6
*=MINIGUN_B_SPRITES
!source "minigun_weapon.asm"
*=FIST_RIGHT_SPRITES
!source "fist_righthand.asm"
*=FIST_PUNCH_SPRITES
!source "fist_punch.asm"
; chainsaw_weapon.asm: hi2 (64) then 8 layers — starts in punch pad
*=CHAINSAW_BLADE_HI2_SPRITES
!source "chainsaw_weapon.asm"
*=ROCKET_SPRITES
!source "rocket_weapon.asm"
*=SHOTGUN_SPRITES
!source "shotgun_weapon.asm"
*=PISTOL_SPRITES
!source "pistol_sprites.asm"
*=MUZZLE_FLASH_SPRITES
!source "muzzle_flash.asm"
!if * > CHARSET {
	!error "Muzzle sprites overlap charset at $3800; end=$", *
}

; Packed charset image (VIC reads in place); mid follows immediately
*=CHARSET
!source "charset.asm"
!if * != MID_BASE {
	!error "charset.asm size mismatch: ended at $", *, " expected MID_BASE $", MID_BASE
}
*=MID_BASE
!source "gameloop.asm"
!source "level.asm"
!source "playsound.asm"
!source "process.asm"
!source "player.asm"
!source "enemy_mid.asm"
!source "hitscan.asm"
!source "debug.asm"
!source "hud.asm"
!source "pickup.asm"
!source "logo_defs.asm"			; LOGO_* constants (payload on disk → FRAMEBUFFER)
!source "loader.asm"			; mid — LoadPrg/LoadUiFile; mid has room after UI dumps left
!source "titlemenus.asm"
; Near flats + P + clip in mid (low headroom for PROFILE hooks elsewhere)
!source "render_near.asm"
!source "render_project_y.asm"
!source "render_clip.asm"
; Enemy mips in mid (always-RAM); dpsounds moved to high for headroom
!source "enemy_sprites.asm"

; py_tab: 12 page-aligned pages, packed against $a000 so mid free is the
; gap before it (old mid-file !align pad + tail, now one allocatable region).
PY_TAB_PAGES = 12
PY_TAB_SIZE = PY_TAB_PAGES * 256
PY_TAB = MEM_MID_LIMIT - PY_TAB_SIZE	; $9400

end_mid = *
free_mid = PY_TAB - end_mid
!if free_mid < 0 {
	!error "Mid code overlaps py_tab at $", PY_TAB, "; overshoot=", end_mid - PY_TAB
}
!warn "mem: mid  end=$", end_mid, " free to py_tab $", PY_TAB, " =", free_mid

*=PY_TAB
!source "pytab.asm"
!if * != MEM_MID_LIMIT {
	!error "py_tab must end at $a000; ended at $", *
}

; ------------------------------------------------------------------
; Level window under BASIC ROM ($A000), RAM with $01=$35 — loaded from disk
; Layout: map first ($a000, 32-byte aligned for maprow+mapx), then 7×200
; sector attr tables, spawn, items, sector_max, enemies, items, secrets, par
; ------------------------------------------------------------------
LEVEL_BYTES = 2624
*=$a000
level_data
	!fill LEVEL_BYTES, 0

MAP_SIZE = 32
MAP_CELLS = 1024
MAX_ITEMS = 48
ITEM_BYTES = 4			; SoA: 4 arrays × MAX_ITEMS
SPAWN_BYTES = 3
STATS_BYTES = 4			; num_enemies, num_items, num_secrets, par_time
; SEC_TYPE packed: action[4:0] | trigger[6:5] | single_shot[7]
ACT_MASK = $1f
TRIG_MASK = $60
TRIG_SHIFT = 5
TRIG_NONE = 0
TRIG_WALK = 1
TRIG_USE = 2
TRIG_SWITCH = 3
SHOT_BIT = $80			; bmi after lda SEC_TYPE,x

ACT_NONE = 0
ACT_WINDOW = 1			; walk-blocked; hitscan/missiles pass
ACT_OPEN_DOOR = 2		; raise ceil +5, reclose 5s
ACT_OPEN_DOOR_FOREVER = 3
ACT_OPEN_DOOR_30S = 4
ACT_LOWER_FLOOR = 5		; min adjacent + return 5s
ACT_RAISE_FLOOR = 6		; max adjacent, permanent
ACT_RAISE_STAIRS = 7
ACT_CONTINUE_STAIRS = 8
ACT_END_LEVEL = 9
ACT_LOWER_FLOOR_FOREVER = 10	; min adjacent, permanent
ACT_OPEN_DOOR_10S = 11		; raise ceil +5, reclose 10s
ACT_LOWER_FLOOR_15S = 12	; min adjacent + return 15s
ACT_DAMAGE_FLOOR = 13		; 5 HP / second while standing
ACT_FLASH_LIGHTS = 14		; SEC_BRIGHT ↔ 16, 1 Hz (max 2 sectors)
ACT_OPEN_MONSTER_CLOSET = 15	; raise floor+ceil +6, permanent
ACT_SECRET = 16			; walk-into oneshot → inc secrets found

; level_item_meta: skill bits (switches use meta=0)

; Map first so level_map is 32-byte aligned ($a000) for maprowlo+mapx
level_map = level_data
; Attribute tables (index = sector id; [0] unused)
SEC_FLOOR  = level_map + MAP_CELLS
SEC_CEIL   = SEC_FLOOR + SEC_TABLE_SIZE
SEC_TYPE   = SEC_CEIL + SEC_TABLE_SIZE
SEC_TARGET = SEC_TYPE + SEC_TABLE_SIZE
SEC_FCOL   = SEC_TARGET + SEC_TABLE_SIZE
SEC_CCOL   = SEC_FCOL + SEC_TABLE_SIZE
SEC_BRIGHT = SEC_CCOL + SEC_TABLE_SIZE

level_spawn = SEC_BRIGHT + SEC_TABLE_SIZE	; x, y, angle (playera)
; Items SoA (contiguous)
level_item_type = level_spawn + SPAWN_BYTES	; 48: typeId or $FF empty
level_item_x = level_item_type + MAX_ITEMS
level_item_y = level_item_x + MAX_ITEMS
level_item_meta = level_item_y + MAX_ITEMS	; skill bits / switch target
level_items = level_item_type

level_sector_max = level_item_meta + MAX_ITEMS
level_num_enemies = level_sector_max + 1
level_num_items = level_num_enemies + 1
level_num_secrets = level_num_items + 1
level_par_time = level_num_secrets + 1
!if level_par_time + 1 - level_data != LEVEL_BYTES {
	!error "LEVEL_BYTES mismatch vs layout"
}

!source "tables.asm"
!source "sky.asm"
!source "recip.asm"
!source "item_bitmaps.asm"
!source "mapscreen.asm"
!source "dpsounds.asm"
!source "levelstats.asm"

!zone 0

end_high = *
free_high = MEM_HIGH_LIMIT - end_high
!if free_high < 0 {
	!error "High data overlaps FRAMEBUFFER at $c800; overshoot=", end_high - MEM_HIGH_LIMIT
}
!warn "mem: high end=$", end_high, " free to FB $c800 =", free_high

; Under-KERNAL BSS: SQTAB $e000–$e7ff, COL, PROF, PROC, mobj, flatgrp, visited, wdark; tail free to $10000
free_kernal = $10000 - SEC_WDARK_END
free_total = free_low + free_mid + free_high + free_kernal
!warn "mem: kernal BSS $e000..$", SEC_WDARK_END - 1, " free tail =", free_kernal
!warn "mem: TOTAL free =", free_total, " (low+mid+high+kernal-tail)"
