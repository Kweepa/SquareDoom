; SquareDoom disposable boot — splash first, then MENU @ $0400.
; KERNAL-load colour then bitmap so the cover paints in already coloured.
; USE_KRILL=1: then LOADER+INSTALL, JSR install, loadraw MENU.
; Default: trampoline KERNAL-loads MENU (no INSTALL). Trampoline at $02A7.
!cpu 6502
!to "boot.prg", cbm

!source "mem_vic.asm"

*= LOADER_BASE
!byte $0b, $08, $0a, $00, $9e, $32, $30, $36, $31, $00, $00, $00	; SYS 2061

; Bitmap clear uses these; menu will overwrite boot anyway.
clr_ptr		= $fb

*= $080d
boot_start
	lda #BANK_IO
	sta $01
	jsr $ff84				; IOINIT
	lda $d011
	and #%11101111				; DEN off until colour is in
	sta $d011
	lda #0
	sta $d020
	sta $d015
	sta $d01a
	cli

	lda #7
	ldx #<name_splashc
	ldy #>name_splashc
	jsr load_sa1
	bcs .fail
	jsr copy_splash_col
	jsr clear_bitmap
	jsr splash_vic			; matrix + colour RAM live; bitmap black

	lda #6
	ldx #<name_splash
	ldy #>name_splash
	jsr load_sa1
	bcs .fail
	jsr splash_vic			; KERNAL LOAD RMW of $dd00; keep bank 1

!if USE_KRILL {
	lda #6
	ldx #<name_loader
	ldy #>name_loader
	jsr load_sa1
	bcs .fail
	jsr splash_vic
	lda #7
	ldx #<name_install
	ldy #>name_install
	jsr load_sa1
	bcs .fail
	jsr splash_vic
	jsr KRILL_INSTALL
	bcs .fail
	jsr splash_vic			; Krill DDRA=$03 — absolute $dd00 only
}

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

; splashc: matrix already at $4000. Copy colour staging → $D800, set bg.
copy_splash_col
	ldx #0
.csc
	lda SPLASH_COL,x
	sta KOALA_COL_RAM,x
	lda SPLASH_COL + $100,x
	sta KOALA_COL_RAM + $100,x
	lda SPLASH_COL + $200,x
	sta KOALA_COL_RAM + $200,x
	inx
	bne .csc
	ldx #0
.csc_t
	lda SPLASH_COL + $300,x
	sta KOALA_COL_RAM + $300,x
	inx
	cpx #KOALA_TAIL
	bne .csc_t
	lda SPLASH_BG
	sta $d021
	sta $d020
	rts

; $6000–$7FFF ← 0 so the bitmap paints onto black, not leftover RAM.
clear_bitmap
	lda #<BITMAP
	sta clr_ptr
	lda #>BITMAP
	sta clr_ptr + 1
	ldx #32
	lda #0
	tay
.cb
	sta (clr_ptr),y
	iny
	bne .cb
	inc clr_ptr + 1
	dex
	bne .cb
	rts

; VIC bank 1 MCM bitmap. Absolute $dd00 — RMW poisons Krill IEC after install.
; $d020/$d021 already set from SPLASH_BG.
splash_vic
	lda #%00000010			; VIC bank 1; upper 6 bits 0
	sta $dd00
	lda $d011
	and #%10000111			; clear ECM/BMM/DEN/RSEL
	ora #%00111011			; bitmap + DEN + 25 rows
	sta $d011
	lda $d016
	and #%11100111
	ora #%00011000			; CSEL + MCM
	sta $d016
	lda #%00001000			; matrix $4000, bitmap $6000
	sta $d018
	lda #0
	sta $d015
	sta $d01a
	lda SPLASH_BG
	sta $d021
	sta $d020
	rts

name_splashc
	!text "SPLASHC"
	!byte 0
name_splash
	!text "SPLASH"
	!byte 0
!if USE_KRILL {
name_loader
	!text "LOADER"
	!byte 0
name_install
	!text "INSTALL"
	!byte 0
}

; Assembled as if at KRILL_STUB; bytes emitted here and copied there.
; MENU @ $0400 overwrites boot, so the caller cannot live at $0801.
stub_src
!pseudopc KRILL_STUB {
	lda #BANK_IO
	sta $01
!if USE_KRILL {
	sei
	lda #BANK_LOADER
	sta $01
	clc
	ldx #<boot_stub_name
	ldy #>boot_stub_name
	jsr loadraw
	bcs boot_stub_fail
} else {
	cli
	lda #4
	ldx #<boot_stub_name
	ldy #>boot_stub_name
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
	bcs boot_stub_fail
}
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
	!error "Boot overlay stub overlaps SID shadows; len=", stub_len
}
