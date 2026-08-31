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

; After play/menu had KERNAL out: IOINIT so CIA1 TA runs, then CLI.
; Do not RESTOR — that copies ROM $FD30 (default I/O vectors) into $0314 and
; write-throughs the same 32 bytes into RAM $FD30 (stats snap: smashed
; put_pct_val). We never poke ILOAD $0330 or IIRQ $0314; boot left them stock.
; Leaves $01=$36. CIA2 timers off (profiler / IEC). IOINIT unblanks bank 0 —
; this blanks DEN again. Caller restores VIC (LoadPrg: bank 3 + ENTERING;
; HIGH/GFX: stay blank).
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
	and #%01101111				; DEN off; drop RST8 from the read
	sta $d011
	; SETMSG must see A=0. `lda $d011` keeps RST8 when raster≥256, so A=$8x
	; enables control messages. SEARCHING/LOADING then CHROUT into $0400
	; (IOINIT bank 0 screen) which is GAME (snap: "SEARCHING FOR HIGH" over
	; mul_recip_z+$4d = $12 JAM, screen-code 'R').
	lda #0
	jsr $ff90
	lda #1
	sta $cc					; cursor off — IRQ blink also pokes $0400
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
