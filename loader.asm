; Load PRG from disk device 8 (SA=1 → file load address).
; Levels → $9000 (cooked blob, no SID); MENU → MENU_BASE;
; UI screens via overlay LoadUiFile.
!zone loader

LEVEL_LFN = 15
LEVEL_DEVICE = 8

level_dos_name
	!text "E1M1"

menu_dos_name
	!text "MENU"

; 4-byte SETNAM scratch — must be outside under-KERNAL (LoadPrg banks $01=$36)
ui_name_buf
	!text "LOGO"

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

; load_namelen…load_do_pad — cassette scrap BSS (zeropage.asm)

ENTER_MIN_JIFFIES = 120			; ~2s NTSC / 2.4s PAL

; LoadPrg — A=name length, X/Y=name pointer.
; If load_do_pad ≠ 0, hold ≥ ENTER_MIN_JIFFIES on success (level ENTERING).
; C=0 ok, C=1 error. cur_weapon at $FB survives; no stash.
LoadPrg
	sta load_namelen
	stx load_name_l
	sty load_name_h

	sei
	cld					; IEC timeouts use ADC; D=1 → tape fall-through
	lda #$35				; I/O in before CIA (play default is $34)
	sta $01
	lda #$7f
	sta $dc0d
	sta $dd0d
	lda $dc0d
	lda $dd0d

	; Stop profiler timers — they sit on CIA2 with the IEC port
	lda #0
	sta $dd0e
	sta $dd0f

	lda #$36				; KERNAL in, BASIC out, I/O in
	sta $01

	jsr $ff8a				; RESTOR — KERNAL vectors
	jsr $ff84				; IOINIT — $DD00=$07 (bank 0), $01=$E7
	lda #$36				; IOINIT mapped BASIC+KERNAL; keep BASIC out
	sta $01
	lda $dd00
	ora #$03				; VIC bank 0 for IEC (bits 0–1 = %11)
	sta $dd00

	; IOINIT points VIC at $0400 (boot text). Black bg + colour 0 hides it.
	lda #0
	sta $d020
	sta $d021
	jsr fill_color_ram

	lda #0					; silent — no SEARCHING/LOADING text
	jsr $ff90				; SETMSG

	; ST…LDTND ($90–$98); stray $98 kills OPEN (no game symbols here)
	ldx #0
	txa
.lp_clr
	sta $90,x
	inx
	cpx #9
	bne .lp_clr

	jsr $ffe7				; CLALL

	cli
	lda $a2					; jiffy low (ticks under KERNAL IRQ)
	sta load_jiffy0

	lda load_namelen
	ldx load_name_l
	ldy load_name_h
	jsr $ffbd				; SETNAM
	lda #LEVEL_LFN
	ldx #LEVEL_DEVICE
	ldy #1					; SA=1 → load to PRG address
	jsr $ffba				; SETLFS
	ldx #LEVEL_DEVICE			; IEC; KERNAL OPEN BCS falls into tape if $BA<3
	stx $ba
	lda #0
	jsr $ffd5				; LOAD
	php

	plp
	php
	bcs .lp_done
	lda load_do_pad
	beq .lp_done
.lp_pad
	lda $a2
	sec
	sbc load_jiffy0
	cmp #ENTER_MIN_JIFFIES
	bcc .lp_pad

.lp_done
	sei
	lda #$35
	sta $01
	lda #0
	sta $d020
	sta $d021
	jsr set_vic_bank3			; IOINIT may have restored bank 0
	jsr prof_init
	jsr input_irq_init
	lda #$34
	sta $01
	plp
	rts

; LoadLevel — FormatDosName + LoadPrg with ENTERING jiffy pad. C=0 ok, C=1 error.
LoadLevel
	jsr FormatDosName
	lda #1
	sta load_do_pad
	lda #4
	ldx #<level_dos_name
	ldy #>level_dos_name
	jmp LoadPrg

; LoadMenu — MENU.PRG → MENU_BASE (play-buffer pack after UI_LOAD_MAX). C=0 ok, C=1 error.
LoadMenu
	lda #0
	sta load_do_pad
	lda #4
	ldx #<menu_dos_name
	ldy #>menu_dos_name
	jmp LoadPrg
