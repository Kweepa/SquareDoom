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
MINIGUN_SPRITES = $3000	; 6×64-byte minigun body (VIC bank 0)
ROCKET_SPRITES = $3180		; 8×64-byte rocket+pink flash (VIC bank 0)
SHOTGUN_SPRITES = $3380	; 6×64-byte shotgun body (VIC bank 0)
PISTOL_SPRITES = $3500		; 6×64-byte pistol body (VIC bank 0)
MUZZLE_FLASH_SPRITES = $3680	; 4×64 shared flash A/B white+red (pistol/sg/mg)
FLOOR_PAT_BASE = 219		; floor dither glyphs 219–234 (after skull @ 218)
ITEM_PAT = 235			; itemudg.png shading glyph

MAX_DDA = 32
PROFILE = 0
DBG_FPS = 0
DBG_PORTAL = 0
CENTER_COL = 19
MUZZLE_COL = 20			; pistol muzzle aim column
AIM_COL_SLACK = 2		; TryDamageEnemy also checks MUZZLE±this (18..22)

; Memory ceilings:
;   low  → CHARSET at $3800 (COL/SQTAB/profil are under KERNAL $E000+)
;   mid  → level_data at $a000 (BASIC ROM area, RAM with $01=$35); enemy mips here
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
; loader was mid; moved here for headroom (mid was ~48 bytes free)
!source "loader.asm"

end_low = *
free_low = FIST_RIGHT_SPRITES - end_low
!if free_low < 0 {
	!error "Low code overlaps fist sprites at $2a00; overshoot=", end_low - FIST_RIGHT_SPRITES
}
!warn "mem: low  end=$", end_low, " free to fist $2a00 =", free_low

; Weapon sprite banks in VIC bank 0, before charset
*=FIST_RIGHT_SPRITES
!source "fist_righthand.asm"
*=FIST_PUNCH_SPRITES
!source "fist_punch.asm"
; chainsaw_weapon.asm: hi2 (64) then 8 layers — starts in punch pad
*=CHAINSAW_BLADE_HI2_SPRITES
!source "chainsaw_weapon.asm"
*=MINIGUN_SPRITES
!source "minigun_weapon.asm"
*=ROCKET_SPRITES
!source "rocket_weapon.asm"
*=SHOTGUN_SPRITES
!source "shotgun_weapon.asm"
*=PISTOL_SPRITES
!source "pistol_sprites.asm"
*=MUZZLE_FLASH_SPRITES
!source "muzzle_flash.asm"

; Rest after charset window $3800–$3FFF
*=$4000
!source "gameloop.asm"
!source "level.asm"
!source "playsound.asm"
!source "process.asm"
!source "player.asm"
!source "enemy.asm"
!source "hitscan.asm"
!source "debug.asm"
!source "ditherchars.asm"
!source "doomfont.asm"
!source "hud.asm"
!source "pickup.asm"
!source "titlemenus.asm"
; P + clip moved out of low (which is nearly full); py_tab needs page alignment
!source "render_project_y.asm"
!source "render_clip.asm"
!source "pytab.asm"
; Enemy mips in mid (always-RAM); dpsounds moved to high for headroom
!source "enemy_sprites.asm"

end_mid = *
free_mid = MEM_MID_LIMIT - end_mid
!if free_mid < 0 {
	!error "Mid code overlaps level at $a000; overshoot=", end_mid - MEM_MID_LIMIT
}
!warn "mem: mid  end=$", end_mid, " free to $a000 =", free_mid

; ------------------------------------------------------------------
; Level window under BASIC ROM ($A000), RAM with $01=$35 — loaded from disk
; SoA layout: 7×256 sector attr tables (id-indexed), map, spawn, items, sector_max
; ------------------------------------------------------------------
LEVEL_BYTES = 3012
*=$a000
level_data
	!fill LEVEL_BYTES, 0

MAP_SIZE = 32
MAP_CELLS = 1024
MAX_SECTORS = 255
MAX_ITEMS = 48
ITEM_BYTES = 4			; SoA: 4 arrays × MAX_ITEMS
SPAWN_BYTES = 3
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

SEC_TABLE_SIZE = 256

; level_item_meta: skill bits (switches use meta=0)

; Attribute tables (index = sector id; [0] unused)
SEC_FLOOR  = level_data
SEC_CEIL   = SEC_FLOOR + SEC_TABLE_SIZE
SEC_TYPE   = SEC_CEIL + SEC_TABLE_SIZE
SEC_TARGET = SEC_TYPE + SEC_TABLE_SIZE
SEC_FCOL   = SEC_TARGET + SEC_TABLE_SIZE
SEC_CCOL   = SEC_FCOL + SEC_TABLE_SIZE
SEC_BRIGHT = SEC_CCOL + SEC_TABLE_SIZE

level_map = SEC_BRIGHT + SEC_TABLE_SIZE
level_spawn = level_map + MAP_CELLS	; x, y, angle (playera)
; Items SoA (contiguous; bak copies this whole block)
level_item_type = level_spawn + SPAWN_BYTES	; 48: typeId or $FF empty
level_item_x = level_item_type + MAX_ITEMS
level_item_y = level_item_x + MAX_ITEMS
level_item_meta = level_item_y + MAX_ITEMS	; skill bits / switch target
level_items = level_item_type			; bak base (= SoA start)
level_sector_max = level_item_meta + MAX_ITEMS
!if level_sector_max + 1 - level_data != LEVEL_BYTES {
	!error "LEVEL_BYTES mismatch vs layout"
}

!source "tables.asm"
!source "recip.asm"
!source "item_bitmaps.asm"
!source "mapscreen.asm"
!source "dpsounds.asm"

!zone 0

end_high = *
free_high = MEM_HIGH_LIMIT - end_high
!if free_high < 0 {
	!error "High data overlaps FRAMEBUFFER at $c800; overshoot=", end_high - MEM_HIGH_LIMIT
}
!warn "mem: high end=$", end_high, " free to FB $c800 =", free_high

; Under-KERNAL BSS: SQTAB $e000–$e7ff, COL, PROF, PROC, mobj, flatgrp, visited; tail free to $10000
free_kernal = $10000 - SEC_VISITED_END
free_total = free_low + free_mid + free_high + free_kernal
!warn "mem: kernal BSS $e000..$", SEC_VISITED_END - 1, " free tail =", free_kernal
!warn "mem: TOTAL free =", free_total, " (low+mid+high+kernal-tail)"
