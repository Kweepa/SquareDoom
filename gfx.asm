; Sprite tail + charset staged at $A000; MENU copy_vic copies to $D000 / $D800.
!cpu 6502
!to "gfx.prg", cbm

!source "mem_vic.asm"

*= GFX_STAGING
gfx_sprite_tail
	!bin "tmp/sprites.bin", SPRITE_TAIL, SPRITE_HEAD
!if * - gfx_sprite_tail != SPRITE_TAIL {
	!error "gfx sprite tail size mismatch"
}
gfx_charset
	!source "charset.asm"
!if * - gfx_charset != CHARSET_BYTES {
	!error "gfx charset size mismatch: got ", * - gfx_charset, " expected ", CHARSET_BYTES
}
