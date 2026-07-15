; SquareDoom — ACME root (C64)
!cpu 6502
!to "squaredoom.prg", cbm

; Column-major colour buffer (40×25), after Judd tabs at $C000–$C7FF
FRAMEBUFFER = $c800

MAX_DDA = 24
PROFILE = 0
DBG_PORTAL = 0
CENTER_COL = 19

!source "zeropage.asm"
!source "basicstub.asm"
!source "warmstart.asm"
!source "multiply.asm"
!source "util.asm"
!source "input.asm"
!source "profil.asm"
!source "render.asm"
!source "blit.asm"
!source "gameloop.asm"
!source "debug.asm"
!source "project_y.asm"

; ------------------------------------------------------------------
; Level + tables under BASIC ROM ($A000), visible after $01=$36
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

!source "tables.asm"
