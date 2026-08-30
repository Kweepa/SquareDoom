; KERNAL LOAD, SA=1 (dest from PRG header). A=len, X/Y=name.
; $01 = BANK_IO ($36), CLI, CIA1 Timer A running (VICE traps hit $ED24/$EE14).
kernal_load_sa1
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

; After play/menu had KERNAL out: RESTOR + IOINIT so CIA1 TA runs, then CLI.
; Leaves $01=$36. Does not stop CIA1 TA (IOINIT starts it). CIA2 timers off
; (profiler / IEC). IOINIT unblanks bank 0 — this blanks DEN again. Caller
; restores VIC (LoadPrg: bank 3 + ENTERING; HIGH/GFX: stay blank).
kernal_prepare
	sei
	cld
	lda #BANK_LOADER
	sta $01
	lda #$7f
	sta $dc0d
	sta $dd0d
	lda $dc0d
	lda $dd0d
	lda #0
	sta $dd0e
	sta $dd0f
	lda #BANK_IO
	sta $01
	jsr $ff8a				; RESTOR
	jsr $ff84				; IOINIT
	lda #BANK_IO
	sta $01
	lda $dd00
	ora #$03				; VIC bank 0 for IEC
	sta $dd00
	lda #0
	sta $d020
	sta $d021
	lda $d011
	and #%11101111				; DEN off — IOINIT unblanks bank 0
	sta $d011
	jsr $ff90				; SETMSG (A=0)
	ldx #0
	txa
.kp_clr
	sta $90,x
	inx
	cpx #9
	bne .kp_clr
	jsr $ffe7				; CLALL
	cli
	rts
