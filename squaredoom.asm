; SquareDoom — ACME root (C64)
!cpu 6502
!to "squaredoom.prg", cbm

; Column-major colour buffer (40×25), after Judd tabs at $C000–$C7FF
FRAMEBUFFER = $c800

!source "zeropage.asm"
!source "basicstub.asm"
!source "warmstart.asm"
!source "multiply.asm"
!source "util.asm"
!source "input.asm"
!source "render.asm"
!source "blit.asm"
!source "gameloop.asm"

; ------------------------------------------------------------------
; Level + tables under BASIC ROM ($A000), visible after $01=$36
; ------------------------------------------------------------------
*=$a000
level_data
	!binary "levels/e1m1.bin"

; Offsets into level_data
SECTOR_BYTES = 7
MAP_SIZE = 32
MAP_CELLS = 1024
MAX_SECTORS = 255
MAX_ITEMS = 48
ITEM_BYTES = 4
DOOR_TYPE = 18

level_sectors = level_data
level_map = level_data + MAX_SECTORS * SECTOR_BYTES
level_items = level_map + MAP_CELLS

!source "tables.asm"
