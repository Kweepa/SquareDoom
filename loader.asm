; Load level PRG from disk device 8 into $A000 (SA=1 uses file load address).
; DOS name E1M1..E1M9 — uppercase like JSW's R00.
!zone loader

LEVEL_LFN = 15
LEVEL_DEVICE = 8

level_dos_name
	!text "E1M1"

; FormatDosName — write "ENMM" into level_dos_name from episode + level_num
FormatDosName
	lda #'E'
	sta level_dos_name
	lda episode
	clc
	adc #'1'
	sta level_dos_name + 1
	lda #'M'
	sta level_dos_name + 2
	lda level_num
	clc
	adc #'0'
	sta level_dos_name + 3
	rts

; LoadLevel — C64 needs IOINIT so CIA2 is IEC-ready (profil_init owns CIA2 timers).
; After LOAD, hold until ~2s of jiffies have elapsed (pads fast FSDrive loads).
; C=0 ok, C=1 error.
ENTER_MIN_JIFFIES = 120			; ~2s NTSC / 2.4s PAL

load_jiffy0	!byte 0

LoadLevel
	sei
	lda #$7f
	sta $dc0d
	lda $dc0d
	sta $dd0d
	lda $dd0d

	; Stop profiler timers — they sit on CIA2 with the IEC port
	lda #0
	sta $dd0e
	sta $dd0f

	lda #$36				; KERNAL in, BASIC out, I/O in
	sta $01

	jsr $ff8a				; RESTOR — KERNAL vectors
	jsr $ff84				; IOINIT — CIA1 jiffy + CIA2 serial pins

	lda #0					; silent — no SEARCHING/LOADING text
	jsr $ff90				; SETMSG

	; ST…LDTND ($90–$98); stray $98 kills OPEN
	ldx #0
	txa
.ll_clr
	sta $90,x
	inx
	cpx #9
	bne .ll_clr

	jsr $ffe7				; CLALL

	cli
	lda $a2					; jiffy low (ticks under KERNAL IRQ)
	sta load_jiffy0

	lda #4
	ldx #<level_dos_name
	ldy #>level_dos_name
	jsr $ffbd				; SETNAM
	lda #LEVEL_LFN
	ldx #LEVEL_DEVICE
	ldy #1					; SA=1 → load to PRG address
	jsr $ffba				; SETLFS
	lda #0
	jsr $ffd5				; LOAD
	php

	; Keep ENTERING up for at least ENTER_MIN_JIFFIES (skip pad on error)
	plp
	php
	bcs .ll_done
.ll_pad
	lda $a2
	sec
	sbc load_jiffy0
	cmp #ENTER_MIN_JIFFIES
	bcc .ll_pad

.ll_done
	sei
	lda #$35
	sta $01
	lda #0
	sta $d020
	sta $d021
	jsr prof_init
	jsr input_irq_init
	; LoadLevel wiped $90-$98 (KERNAL); restore weapon fire interval
	lda #$ff
	sta cur_weapon
	ldx #0
	jsr switch_weapon
	plp
	rts
