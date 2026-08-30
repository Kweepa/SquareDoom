; SquareDoom disposable boot — install Krill, then hand off to MENU @ $0400.
; KERNAL LOAD only for LOADER + INSTALL. After JSR install, every load is loadraw.
; MENU overwrites this image (and the $2000 installer); trampoline at $02A0 survives.
!cpu 6502
!to "boot.prg", cbm

!source "mem_vic.asm"

*= LOADER_BASE
!byte $0b, $08, $0a, $00, $9e, $32, $30, $36, $31, $00, $00, $00	; SYS 2061

*= $080d
boot_start
	lda #BANK_IO
	sta $01
	jsr $ff84				; IOINIT
	lda $d011
	and #%11101111				; DEN off — IOINIT restores bank 0
	sta $d011
	lda #0
	sta $d020
	cli

	lda #6
	ldx #<name_loader
	ldy #>name_loader
	jsr load_sa1
	bcs .fail
	lda #7
	ldx #<name_install
	ldy #>name_install
	jsr load_sa1
	bcs .fail
	jsr KRILL_INSTALL			; C=1 → no fallback, hang
	bcs .fail

	ldx #0
.copy
	lda stub_src,x
	sta KRILL_STUB,x
	inx
	cpx #stub_len
	bne .copy
	jmp KRILL_STUB

.fail
	lda #BANK_LOADER
	sta $01
.hang
	jmp .hang

; KERNAL LOAD, SA=1 (address from the PRG header). A=len, X/Y=name.
; Only used for LOADER and INSTALL, before Krill is up.
load_sa1
	jsr $ffbd
	lda #1
	ldx $ba
	ldy #1
	jsr $ffba
	lda #0
	jsr $ffd5
	php
	lda #1
	jsr $ffc3
	plp
	rts

name_loader
	!text "LOADER"
	!byte 0
name_install
	!text "INSTALL"
	!byte 0

; Assembled as if at KRILL_STUB; bytes emitted here and copied there.
; loadraw of MENU @ $0400 overwrites boot, so the caller cannot live at $0801.
stub_src
!pseudopc KRILL_STUB {
	sei
	lda #BANK_LOADER
	sta $01
	clc
	ldx #<boot_stub_name
	ldy #>boot_stub_name
	jsr loadraw
	bcs boot_stub_fail
	jmp LOCODE_BASE
boot_stub_fail
	lda #BANK_LOADER
	sta $01
boot_stub_hang
	jmp boot_stub_hang
boot_stub_name
	!text "MENU"
	!byte 0
}
stub_end = *
stub_len = stub_end - stub_src
!if stub_len > KRILL_STUB_END - KRILL_STUB {
	!error "Boot Krill stub overlaps SID shadows; len=", stub_len
}
