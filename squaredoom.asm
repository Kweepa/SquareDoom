; SquareDoom — ACME root (C64)
!cpu 6502
!to "squaredoom.prg", cbm

; Column-major colour buffer (40×25); Judd tabs live under KERNAL at $E000
FRAMEBUFFER = $c800
; Matching lighting/pattern buffer (screen codes); hi = colour hi + 4
LIGHTFRAME = $cc00
CHARSET = $3800
PISTOL_SPRITES = $3680		; 6×64-byte hi-res pistol+flash overlays (VIC bank 0)
FLOOR_PAT = $08			; dither tile #2 rotated 90° (flats)
ITEM_PAT = $09			; itemudg.png shading glyph

MAX_DDA = 32
PROFILE = 0
DBG_FPS = 0
DBG_PORTAL = 0
CENTER_COL = 19

; Memory ceilings:
;   low  → CHARSET at $3800 (COL/SQTAB/profil are under KERNAL $E000+)
;   mid  → level_data at $a000 (BASIC ROM area, RAM with $01=$35)
;   high → FRAMEBUFFER at $c800 ($c000–$c7ff free after SQTAB move)
MEM_MID_LIMIT = $a000
MEM_HIGH_LIMIT = FRAMEBUFFER

!source "zeropage.asm"
!source "basicstub.asm"
!source "warmstart.asm"
!source "weapon.asm"
!source "multiply.asm"
!source "util.asm"
!source "input.asm"
!source "profil.asm"
!source "render.asm"
!source "blit.asm"

end_low = *
free_low = PISTOL_SPRITES - end_low
!if free_low < 0 {
	!error "Low code overlaps pistol sprites at $3680; overshoot=", end_low - PISTOL_SPRITES
}
!warn "mem: low  end=$", end_low, " free to pistol $3680 =", free_low

; Pistol flash+weapon sprites (6×64 bytes) in VIC bank 0, before charset
*=PISTOL_SPRITES
!source "pistol_sprites.asm"

; Char blit + rest after charset window $3800–$3FFF
*=$4000
!source "blit_chars.asm"
!source "gameloop.asm"
!source "process.asm"
!source "debug.asm"
!source "ditherchars.asm"
!source "doomfont.asm"
!source "hud.asm"
!source "pickup.asm"

end_mid = *
free_mid = MEM_MID_LIMIT - end_mid
!if free_mid < 0 {
	!error "Mid code overlaps level at $a000; overshoot=", end_mid - MEM_MID_LIMIT
}
!warn "mem: mid  end=$", end_mid, " free to $a000 =", free_mid

; ------------------------------------------------------------------
; Level + tables under BASIC ROM ($A000), RAM with $01=$35
; SoA layout: 7×256 sector attr tables (id-indexed), map, items
; ------------------------------------------------------------------
*=$a000
level_data
	!binary "levels/e1m1.bin"

MAP_SIZE = 32
MAP_CELLS = 1024
MAX_SECTORS = 255
MAX_ITEMS = 48
ITEM_BYTES = 4
DOOR_TYPE = 18
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
level_items = level_map + MAP_CELLS
level_sector_max = level_items + MAX_ITEMS * ITEM_BYTES

!source "tables.asm"
!source "item_bitmaps.asm"

end_high = *
free_high = MEM_HIGH_LIMIT - end_high
!if free_high < 0 {
	!error "High data overlaps FRAMEBUFFER at $c800; overshoot=", end_high - MEM_HIGH_LIMIT
}
!warn "mem: high end=$", end_high, " free to FB $c800 =", free_high

; Under-KERNAL BSS: SQTAB $e000–$e7ff, COL, PROF, PROC; tail free to $10000
free_kernal = $10000 - ITEM_SORT_END
free_total = free_low + free_mid + free_high + free_kernal
!warn "mem: kernal BSS $e000..$", ITEM_SORT_END - 1, " free tail =", free_kernal
!warn "mem: TOTAL free =", free_total, " (low+mid+high+kernal-tail)"
