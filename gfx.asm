; Sprite blob + charset staged at $A000; MENU copy_vic copies to $C800 / $D800.
!cpu 6502
!to "gfx.prg", cbm

!source "mem_vic.asm"

*= GFX_STAGING
gfx_sprites
	!bin "tmp/sprites.bin", SPRITE_BYTES
!if * - gfx_sprites != SPRITE_BYTES {
	!error "gfx sprite size mismatch"
}
gfx_charset
	!source "charset.asm"
!if * - gfx_charset != CHARSET_BYTES {
	!error "gfx charset size mismatch: got ", * - gfx_charset, " expected ", CHARSET_BYTES
}
!if * > VIC_SCREEN {
	!error "gfx staging reached VIC screen; ended at $", *
}
