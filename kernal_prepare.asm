; kernal_prepare — always assembled: reboot_game KERNAL-loads on both disks.
; LoadPrg (KERNAL disk) also JSRs this. Do not RESTOR — ROM $FD30 write-through
; smashes levelstats. SETMSG 0 / $CC=1 so SEARCHING/LOADING/cursor do not
; CHROUT into $0400 (MENU dest after JMP $080d).
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
	jsr $ff84				; IOINIT — also tears down drive-side Krill
	lda #BANK_IO
	sta $01
	lda $dd00
	ora #$03				; VIC bank 0 for IEC
	sta $dd00
	lda #0
	sta $d020
	sta $d021
	sta $d015
	lda $d011
	and #%01101111				; DEN off; drop RST8 from the read
	sta $d011
	; SETMSG must see A=0. `lda $d011` keeps RST8 when raster≥256, so A=$8x
	; enables control messages. SEARCHING/LOADING then CHROUT into $0400
	; (IOINIT bank 0 screen) which is GAME (snap: "SEARCHING FOR GAME" over
	; mul_recip_z+$4d = $12 JAM, screen-code 'R'). After E1M8, $9D=ui_str_l
	; = <str_press_key ($A0) so messages would be on into boot's MENU load.
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
