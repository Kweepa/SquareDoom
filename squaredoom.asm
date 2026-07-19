; SquareDoom — ACME root (C64)
!cpu 6502
!to "squaredoom.prg", cbm

; Column-major colour buffer (40×25); Judd tabs live under KERNAL at $E000
FRAMEBUFFER = $c800
; Matching lighting/pattern buffer (screen codes); hi = colour hi + 4
LIGHTFRAME = $cc00
CHARSET = $3800
SHOTGUN_SPRITES = $3480	; 8×64-byte shotgun+flash (VIC bank 0)
PISTOL_SPRITES = $3680		; 6×64-byte pistol+flash overlays (VIC bank 0)
FLOOR_PAT = $10			; floorudg.png (flats)
ITEM_PAT = $11			; itemudg.png shading glyph

MAX_DDA = 32
PROFILE = 0
DBG_FPS = 0
DBG_PORTAL = 0
CENTER_COL = 19
MUZZLE_COL = 20			; pistol muzzle aim column

; Memory ceilings:
;   low  → CHARSET at $3800 (COL/SQTAB/profil are under KERNAL $E000+)
;   mid  → level_data at $a000 (BASIC ROM area, RAM with $01=$35)
;   high → FRAMEBUFFER at $c800 ($c000–$c7ff free after SQTAB move)
MEM_MID_LIMIT = $a000
MEM_HIGH_LIMIT = FRAMEBUFFER

!source "zeropage.asm"
!source "basicstub.asm"
!source "warmstart.asm"
!source "multiply.asm"
!source "util.asm"
!source "input.asm"
!source "profil.asm"
!source "render.asm"
!source "blit.asm"

end_low = *
free_low = SHOTGUN_SPRITES - end_low
!if free_low < 0 {
	!error "Low code overlaps shotgun sprites at $3480; overshoot=", end_low - SHOTGUN_SPRITES
}
!warn "mem: low  end=$", end_low, " free to shotgun $3480 =", free_low

; Shotgun then pistol sprite banks in VIC bank 0, before charset
*=SHOTGUN_SPRITES
!source "shotgun_weapon.asm"
*=PISTOL_SPRITES
!source "pistol_sprites.asm"

; Char blit + rest after charset window $3800–$3FFF
*=$4000
!source "blit_chars.asm"
!source "gameloop.asm"
!source "level.asm"
!source "process.asm"
!source "player.asm"
!source "enemy.asm"
!source "hitscan.asm"
!source "debug.asm"
!source "ditherchars.asm"
!source "doomfont.asm"
!source "hud.asm"
!source "pickup.asm"
!source "weapon.asm"
!source "titlemenus.asm"
; P + clip moved out of low (which is nearly full); py_tab needs page alignment
!source "render_project_y.asm"
!source "render_clip.asm"
!source "pytab.asm"

end_mid = *
free_mid = MEM_MID_LIMIT - end_mid
!if free_mid < 0 {
	!error "Mid code overlaps level at $a000; overshoot=", end_mid - MEM_MID_LIMIT
}
!warn "mem: mid  end=$", end_mid, " free to $a000 =", free_mid

; ------------------------------------------------------------------
; Level + tables under BASIC ROM ($A000), RAM with $01=$35
; SoA layout: 7×256 sector attr tables (id-indexed), map, spawn, items
; ------------------------------------------------------------------
*=$a000
level_data
	!binary "levels/e1m1.bin"

MAP_SIZE = 32
MAP_CELLS = 1024
MAX_SECTORS = 255
MAX_ITEMS = 48
ITEM_BYTES = 4
SPAWN_BYTES = 3
DOOR_TYPE = 18
WINDOW_TYPE = 19			; walk-blocked; hitscan/missiles pass
ELEVATOR_LOWER_TYPE = 20
ELEVATOR_RAISE_TYPE = 21
SEC_TABLE_SIZE = 256

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
level_items = level_spawn + SPAWN_BYTES
level_sector_max = level_items + MAX_ITEMS * ITEM_BYTES
LEVEL_NAME_LEN = 20
level_name = level_sector_max + 1	; ASCII, null-padded

!source "tables.asm"
!source "item_bitmaps.asm"
!source "enemy_sprites.asm"

!zone 0

end_high = *
free_high = MEM_HIGH_LIMIT - end_high
!if free_high < 0 {
	!error "High data overlaps FRAMEBUFFER at $c800; overshoot=", end_high - MEM_HIGH_LIMIT
}
!warn "mem: high end=$", end_high, " free to FB $c800 =", free_high

; Under-KERNAL BSS: SQTAB $e000–$e7ff, COL, PROF, PROC, mobj, flatgrp; tail free to $10000
free_kernal = $10000 - LEVEL_ITEMS_BAK_END
free_total = free_low + free_mid + free_high + free_kernal
!warn "mem: kernal BSS $e000..$", LEVEL_ITEMS_BAK_END - 1, " free tail =", free_kernal
!warn "mem: TOTAL free =", free_total, " (low+mid+high+kernal-tail)"
