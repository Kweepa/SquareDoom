; SquareDoom disposable boot — fits LOADER_BASE..REBOOT_STUB-1.
; MENU @ $0900 → JSR menu → GFX stage + JSR copy_vic (+3) → GAME → JMP $0900.
; Per file: SETNAM / SETLFS / LOAD / CLOSE only.
!cpu 6502
!to "boot.prg", cbm

!source "mem_vic.asm"

*= LOADER_BASE
!byte $0b, $08, $0a, $00, $9e, $32, $30, $36, $31, $00, $00, $00	; SYS 2061

*= $080d
boot_start
	lda #$36
	sta $01
	jsr $ff84				; IOINIT
	lda $d011
	and #%11101111				; DEN off — IOINIT restores bank 0
	sta $d011
	cli

	lda #4
	ldx #<name_menu
	ldy #>name_menu
	jsr $ffbd
	ldy #0
	jsr setlfs
	ldx #<LOCODE_BASE
	ldy #>LOCODE_BASE
	jsr load_close
	bcs .fail
	jsr LOCODE_BASE

	lda #3
	ldx #<name_gfx
	ldy #>name_gfx
	jsr $ffbd
	ldy #0
	jsr setlfs
	ldx #<GFX_STAGING
	ldy #>GFX_STAGING
	jsr load_close
	bcs .fail
	jsr MENU_COPY_VIC

	lda #4
	ldx #<name_game
	ldy #>name_game
	jsr $ffbd
	ldy #1
	jsr setlfs
	jsr load_close
	bcs .fail
	ldx #$ff
	txs
	jmp LOCODE_BASE

.fail
	lda #$35
	sta $01
.hang
	jmp .hang

setlfs
	lda #1
	ldx $ba
	jmp $ffba

load_close
	lda #0
	jsr $ffd5
	php
	lda #1
	jsr $ffc3
	plp
	rts

name_menu	!text "MENU"
name_gfx	!text "GFX"
name_game	!text "GAME"

end_boot = *
!if end_boot > REBOOT_STUB {
	!error "Boot overlaps REBOOT_STUB; end=$", end_boot
}
