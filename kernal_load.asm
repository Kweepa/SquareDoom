; KERNAL LOAD, SA=1 (dest from PRG header). A=len, X/Y=name.
; $01 = BANK_IO ($36), CLI, CIA1 Timer A running (VICE traps hit $ED24/$EE14).
kernal_load_sa1
	jsr $ffbd
	lda #1
	ldx $ba
	ldy #1
	jsr $ffba
	lda #0
	jsr $ff90				; $9D=0. Do not inherit A from SETLFS.
	lda #0					; LOAD not VERIFY (SETMSG may clobber A)
	jsr $ffd5
	php
	lda #1
	jsr $ffc3
	plp
	rts

!source "kernal_prepare.asm"
