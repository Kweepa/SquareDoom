; SquareDoom — ACME root (C64); assembled as game.prg @ $0400
!cpu 6502
!to "game.prg", cbm

; VIC bank 3 ($C000): screen $C400, sprites $C800–$D7BF, charset $D800.
; Play default $01=$34. SQTAB $BC00. Level $9000. py_tab $B000.
; Boot loads MENU @ $0400; MENU copies GFX then GAME (code) over MENU.
; locode_entry loads HIGH ($9000–$D000) before the blob copy.
; USE_KRILL=1: Krill at $8E00. Default: KERNAL LOAD.
!source "mem_vic.asm"
SCREENBUFFER = $e000			; column-major colours (40×25)
PATTERNBUFFER = SCREENBUFFER + $400	; screen codes; hi = colour hi + 4

; 0–15 walls; 16–63 doomfont punct/HUD/digits + gap packs; 64–89 A–Z; 90–105 floors
MENU_CURSOR = 16		; skull (gap)
MAP_ARROW0 = 17			; arrows 17–20
MAP_SOLID = 21			; filled block (map + logo)
ITEM_PAT = MAP_SOLID		; item soft-sprite fill (solid)
MSG_LET0 = 64			; A–Z (walls own PETSCII letter codes 1–15)
MSG_LETTER0 = MSG_LET0
FLOOR_PAT_BASE = 90		; floor dither 90–105

MAX_DDA = 32
PROFILE = 0
DBG_FPS = 0
DBG_PORTAL = 0
CENTER_COL = 19
MUZZLE_COL = 20			; pistol muzzle aim column
AIM_COL_SLACK = 2		; TryDamageEnemy also checks MUZZLE–this (18..22)
MAX_SECTORS = 199		; usable ids 1..199
SEC_TABLE_SIZE = 200		; index = sector id; [0] unused

; MEM_CODE_LIMIT: Krill loadraw, or $9000 if KERNAL-only disk.

!source "zeropage.asm"
*= LOCODE_BASE
!source "warmstart.asm"
!source "maths.asm"
!source "util.asm"
!source "input.asm"
!source "profil.asm"
!source "render.asm"
!source "blit.asm"
; enemy boss-death floors ??? low for mid headroom
!source "enemy_low.asm"
!source "mapscreen.asm"
!source "weapon.asm"
!source "gameloop.asm"
!source "level.asm"
!source "playsound.asm"
!source "process.asm"
!source "player.asm"
!source "enemy_mid.asm"
!source "missile.asm"
!source "hitscan.asm"
!source "debug.asm"
!source "hud.asm"
!source "pickup.asm"
!source "cheats.asm"			; iddqd / idkfa / idclev (after pickup for INFO_*)
!source "loader.asm"			; LoadPrg/LoadLevel/reboot_game
!source "titleflow.asm"			; entering / summary / melt / mapscreen; menu is boot MENU.PRG
; Near flats + P + clip
!source "render_near.asm"
!source "render_project_y.asm"
!source "render_clip.asm"
; Enemy mips (always-RAM)
!source "enemy_sprites.asm"
; Switch atlas (was high; py_tab now $B000)
!source "wall_switch.asm"

end_code = *
free_code = MEM_CODE_LIMIT - end_code
!if free_code < 0 {
	!error "Code overlaps limit at $", MEM_CODE_LIMIT, "; overshoot=", end_code - MEM_CODE_LIMIT
}
!if USE_KRILL {
	!warn "mem: code end=$", end_code, " free to Krill $", loadraw, " =", free_code
} else {
	!warn "mem: code end=$", end_code, " free to map $", MEM_CODE_LIMIT, " =", free_code
}

; ------------------------------------------------------------------
; Level window $9000: kernal blob staged in first KERNAL_BLOB_SIZE bytes
; (copied to $F950), rest zero until LoadLevel. High tables follow the blob+fill.
; ------------------------------------------------------------------
*=MEM_LEVEL
kernal_blob
!pseudopc SEC_WDARK_END {
	!source "dpsounds.asm"
	!source "levelstats.asm"
end_kernal = *
}
kernal_blob_end = *
KERNAL_BLOB_SIZE = kernal_blob_end - kernal_blob
!if KERNAL_BLOB_SIZE > LEVEL_BYTES {
	!error "kernal blob exceeds level window; size=", KERNAL_BLOB_SIZE
}
	!fill LEVEL_BYTES - KERNAL_BLOB_SIZE, 0
!if * != MEM_LEVEL + LEVEL_BYTES {
	!error "level window must end at $", MEM_LEVEL + LEVEL_BYTES, "; ended at $", *
}

MAP_SIZE = 32
MAP_CELLS = 1024
MAX_ITEMS = 48			; vis-list cap (AABB + mobjs)
SPAWN_BYTES = 3
STATS_BYTES = 4			; num_enemies, num_items, num_secrets, par_time
MAX_SWITCH_FACES = 8
SWITCH_FACE_BYTES = 1 + MAX_SWITCH_FACES * 2	; n + sec[8] + dir[8]

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
ACT_FLASH_LIGHTS = 14		; SEC_BRIGHT → 16, 1 Hz (max 2 sectors)
ACT_OPEN_MONSTER_CLOSET = 15	; raise floor+ceil +6, permanent
ACT_SECRET = 16			; walk-into oneshot → inc secrets found

; Item layer byte: 0 = empty, else type | skillBits<<5 (stripped at start_level)

level_data = MEM_LEVEL
level_map = level_data
level_items = level_map + MAP_CELLS		; $9400, 32-aligned
SEC_FLOOR  = level_items + MAP_CELLS
SEC_CEIL   = SEC_FLOOR + SEC_TABLE_SIZE
SEC_TYPE   = SEC_CEIL + SEC_TABLE_SIZE
SEC_TARGET = SEC_TYPE + SEC_TABLE_SIZE
SEC_FCOL   = SEC_TARGET + SEC_TABLE_SIZE
SEC_CCOL   = SEC_FCOL + SEC_TABLE_SIZE
SEC_BRIGHT = SEC_CCOL + SEC_TABLE_SIZE

level_spawn = SEC_BRIGHT + SEC_TABLE_SIZE
level_switch_n = level_spawn + SPAWN_BYTES
level_switch_sec = level_switch_n + 1
level_switch_dir = level_switch_sec + MAX_SWITCH_FACES
SWITCH_FACE_N = level_switch_n
SWITCH_FACE_SEC = level_switch_sec
SWITCH_FACE_DIR = level_switch_dir

level_sector_max = level_switch_dir + MAX_SWITCH_FACES
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
!source "pcsfreq.asm"

!zone 0

end_high = *
free_high = PY_TAB - end_high
!if free_high < 0 {
	!error "High data overlaps py_tab at $", PY_TAB, "; overshoot=", end_high - PY_TAB
}

*=PY_TAB
!source "pytab.asm"
!if * != PY_TAB + PY_TAB_SIZE {
	!error "py_tab must end at $", PY_TAB + PY_TAB_SIZE, "; ended at $", *
}

!if SEC_WDARK_END > $10000 {
	!error "Under-KERNAL BSS past $10000; SEC_WDARK_END=$", SEC_WDARK_END
}
!if MENU_LIMIT > $fffa {
	!error "COL_CLIP_END past vectors; COL_CLIP_END=$", COL_CLIP_END
}

!if end_kernal < SEC_WDARK_END {
	!error "Kernal scrap wrapped past $FFFF; end=$", end_kernal
}
!if end_kernal > $fffa {
	!error "Kernal scrap overlaps hardware vectors ($FFFA+); end=$", end_kernal
}
!if CASS_LEVELSTATS_END > CASS_BUF_END {
	!error "cassette BSS overflow"
}
!if SCRAP_UNDER_END > UNDER_STACK_END {
	!error "under-stack scrap BSS overflow; end=$", SCRAP_UNDER_END
}
!if SCRAP_CASS_END > CASS_BUF_END {
	!error "cassette scrap BSS overflow; end=$", SCRAP_CASS_END
}

; Copies run once from locode_entry (labels resolved here).
copy_kernal_blob
	ldx #0
-
!for .p, 0, (>KERNAL_BLOB_SIZE) - 1 {
	lda kernal_blob + .p * $100,x
	sta SEC_WDARK_END + .p * $100,x
}
!if (<KERNAL_BLOB_SIZE) != 0 {
	lda kernal_blob + KERNAL_BLOB_SIZE - $100,x
	sta SEC_WDARK_END + KERNAL_BLOB_SIZE - $100,x
}
	inx
	bne -
	rts

; First 2K of sprites load at $C800 (always RAM). Tail copied into $D000 by MENU copy_vic.
*=VIC_SPRITES
	!bin "tmp/sprites.bin", SPRITE_HEAD
!if * != VIC_SPRITES + SPRITE_HEAD {
	!error "sprite head must end at $", VIC_SPRITES + SPRITE_HEAD, "; ended at $", *
}

