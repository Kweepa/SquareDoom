; Disk load — Krill loadraw (USE_KRILL=1) or KERNAL LOAD (default).
; Levels → $96E0 (cooked blob, header address). Reboot KERNAL-loads SQUAREDOOM.
!zone loader

!if USE_KRILL {
} else {
	!source "kernal_load.asm"
}

level_dos_name
	!text "E1M1"
	!byte 0

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

ENTER_MIN_JIFFIES = 120			; ~2s NTSC / 2.4s PAL (KERNAL IRQ $A2)

!if USE_KRILL {

; LoadPrg — X/Y = 0-terminated name. Dest from PRG header (carry clear).
; If load_do_pad ≠ 0, hold ~2s on success (level ENTERING). Jiffy is dead
; (SEI, KERNAL out) so that hold is wait_frames_120, not $A2.
; C=0 ok, C=1 error. Do not IOINIT: $DD02=$3F uninstalls Krill drive code.
LoadPrg
	stx load_name_l
	sty load_name_h

	sei
	cld
	lda #BANK_LOADER
	sta $01
	lda #$7f
	sta $dc0d
	lda $dc0d
	lda #0
	sta $d01a
	sta $dd0e				; profiler sits on CIA2 timers; Krill uses PRA
	sta $dd0f

	ldx load_name_l
	ldy load_name_h
	clc					; dest from PRG header
	jsr loadraw
	php

	bcs .lp_done
	lda load_do_pad
	beq .lp_done
	jsr wait_frames_120

.lp_done
	lda #BANK_LOADER
	sta $01
	lda #0
	sta $d020
	sta $d021
	jsr set_vic_bank3
	lda $d011
	ora #%00010000				; DEN on after ENTERING / play
	sta $d011
	jsr prof_init
	jsr input_irq_init
	lda #BANK_RAM
	sta $01
	plp
	rts

} else {

; LoadPrg — A=name length, X/Y=name pointer. Pre-Krill KERNAL LOAD.
; If load_do_pad ≠ 0, hold ≥ ENTER_MIN_JIFFIES on success (level ENTERING).
; IOINIT resets VIC to bank 0 / $0400; put bank 3 + DEN back so ENTERING
; at $C400 stays visible. Do not fill_color_ram — that blacks the text.
LoadPrg
	sta load_namelen
	stx load_name_l
	sty load_name_h

	jsr kernal_prepare
	jsr set_vic_bank3
	lda $d011
	ora #%00010000
	sta $d011

	lda $a2
	sta load_jiffy0

	lda load_namelen
	ldx load_name_l
	ldy load_name_h
	jsr kernal_load_sa1
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
	lda #BANK_LOADER
	sta $01
	lda #0
	sta $d020
	sta $d021
	jsr set_vic_bank3
	lda $d011
	ora #%00010000
	sta $d011
	jsr prof_init
	jsr input_irq_init
	lda #BANK_RAM
	sta $01
	plp
	rts

}

; LoadLevel — FormatDosName + LoadPrg with ENTERING frame pad. C=0 ok, C=1 error.
LoadLevel
	jsr FormatDosName
	lda #1
	sta load_do_pad
!if USE_KRILL {
	ldx #<level_dos_name
	ldy #>level_dos_name
} else {
	lda #4
	ldx #<level_dos_name
	ldy #>level_dos_name
}
	jmp LoadPrg

; reboot_game — IOINIT, KERNAL-load SQUAREDOOM, JMP $080d.
reboot_game
	sei
	lda #BANK_IO
	sta $01
	ldx #$ff
	txs
	jsr $ff84				; IOINIT — also tears down drive-side Krill
	lda $d011
	and #%11101111				; DEN off — IOINIT restores bank 0
	sta $d011
	lda #0
	sta $d015
	sta $d020
	sta $d021
	lda #10
	ldx #< .rg_name
	ldy #> .rg_name
	jsr $ffbd				; SETNAM
	lda #1
	ldx $ba
	ldy #1
	jsr $ffba				; SETLFS
	lda #0
	jsr $ffd5				; LOAD squaredoom
	bcs .rg_hang
	jmp $080d				; boot_start
.rg_hang
	jmp .rg_hang
.rg_name
	!text "SQUAREDOOM"
