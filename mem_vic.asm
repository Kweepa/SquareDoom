; VIC bank 3 layout + sprite bases (shared with sprites_bank3.asm)
; CIA2 $DD00 bits 0–1 = %00 → bank $C000–$FFFF.
; $d018 = $16: screen block 1 ($C400), charset block 3 ($D800).

VIC_SCREEN = $c400
SPR_PTR = VIC_SCREEN + $3f8		; $c7f8
VIC_SPRITES = $c800
CHARSET = $d800
CHARSET_NUM = 106
CHARSET_END = CHARSET + CHARSET_NUM * 8	; $db50
CHARSET_BYTES = CHARSET_NUM * 8
SPRITE_BYTES = 4032			; 63 × 64
SPRITE_HEAD = $800			; $C800–$CFFF loads in place
SPRITE_TAIL = SPRITE_BYTES - SPRITE_HEAD	; $D000–$D7BF copied at $34
D018_VIC = $16

; Packed like bank 0 ($2940…) but contiguous: punch pad overlapped by saw hi2.
MINIGUN_B_SPRITES = VIC_SPRITES			; $c800, 3×64
FIST_RIGHT_SPRITES = MINIGUN_B_SPRITES + 3 * 64	; $c8c0
FIST_PUNCH_SPRITES = FIST_RIGHT_SPRITES + 8 * 64	; $cac0
CHAINSAW_BLADE_HI2_SPRITES = FIST_PUNCH_SPRITES + 7 * 64	; $cc80
CHAINSAW_SPRITES = FIST_PUNCH_SPRITES + 8 * 64	; $ccc0
MINIGUN_SPRITES = CHAINSAW_SPRITES + 8 * 64	; $cec0
ROCKET_SPRITES = MINIGUN_SPRITES + 6 * 64	; $d040
SHOTGUN_SPRITES = ROCKET_SPRITES + 8 * 64	; $d240
PISTOL_SPRITES = SHOTGUN_SPRITES + 6 * 64	; $d3c0
MUZZLE_FLASH_SPRITES = PISTOL_SPRITES + 6 * 64	; $d540
SHOTGUN_COCK_SPRITES = MUZZLE_FLASH_SPRITES + 4 * 64	; $d640
!if SHOTGUN_COCK_SPRITES + 6 * 64 - VIC_SPRITES != SPRITE_BYTES {
	!error "sprite span != SPRITE_BYTES"
}

MEM_LEVEL = $9000
LEVEL_BYTES = 3473
PY_TAB_PAGES = 12
PY_TAB_SIZE = PY_TAB_PAGES * 256
PY_TAB = $b000
SQTAB_BASE = $bc00

; $01: $34 = 64K RAM (play / copy_vic). $36 = I/O + KERNAL, BASIC out (boot).
; $35 = I/O in, KERNAL out — loadraw needs IEC at $DD00. Resident is $8E00
; (always RAM, below the map). BASIC maps in at $A000 as a side effect
; (write-through still hits DRAM). Must be under SEI.
BANK_RAM	= $34
BANK_IO		= $36
BANK_LOADER	= $35

; Krill v194 (krill/loadersymbols-c64.inc): resident $8E00, install $2000, ZP $60.
!source "krill/loadersymbols-c64.inc"
KRILL_INSTALL	= install
KRILL_RESIDENT	= loadraw
KRILL_STUB	= $02a0			; trampoline: loadraw MENU/GAME at $0400
KRILL_STUB_END	= $02f8			; sid_filt_shadow; stub must not reach here

; Boot / menu / game split. Boot is disposable at $0801; overlays start at $0400
; so GAME does not leave a 1K hole under the old $0900 load address.
LOADER_BASE	= $0801			; disposable boot.prg (SYS 2061)
LOCODE_BASE	= $0400			; MENU overlay, then game.prg (code only)
GFX_STAGING	= $A000			; gfx.prg; MENU copy_vic copies under I/O

; Selectors below $0400 so they survive GAME load. Packed after SID shadows.
episode		= $02fa
music_vol	= $02fb
level_num	= $02fc
effects_vol	= $02fd
game_complete	= $02fe
difficulty	= $02ff

; Menu hires (VIC bank 1). Game uses VIC_SCREEN in bank 3.
SCREEN		= $4000
BITMAP		= $6000
BITMAP_SIZE	= 8000
BITMAP_END	= BITMAP + BITMAP_SIZE
