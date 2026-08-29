!zone warmstart

warmstart
	sei
	cld
	; Kill CIA NMI/IRQ while KERNAL still owns $FFFA (SYS is $37). Banking
	; KERNAL out first left a window where leftover IEC FLAG jumped to $0000.
	lda $01
	ora #$04			; I/O in
	sta $01
	lda #$7f
	sta $dc0d
	sta $dd0d
	lda $dc0d
	lda $dd0d
	lda #0
	sta $dc0e			; stop leftover BASIC jiffy (CIA1 TA)
	sta $dc0f
	sta $dd0e			; CIA2 timers (IEC / profiler)
	sta $dd0f
	sta $d01a			; no VIC IRQs
	sta $d015			; no leftover sprite DMA
	lda $d019
	sta $d019

	lda #$35			; KERNAL out so $FFFA/$FFFE are RAM
	sta $01
	lda #<nmi_stub
	sta $fffa
	sta $0318
	lda #>nmi_stub
	sta $fffb
	sta $0319
	lda #<irq_rti_stub
	sta $fffe
	lda #>irq_rti_stub
	sta $ffff

	lda #$ff
	sta $dc02			; CIA1 Port A out (keyboard cols)
	lda #0
	sta $dc03			; Port B in (keyboard rows)

	lda #0
	sta $d020
	sta $d021
	jsr set_vic_bank3

	jsr copy_kernal_blob		; $9000 staging → $F950
	lda #$34
	sta $01
	jsr copy_vic_gfx		; sprites + charset into bank 3 DRAM
	jsr init_sqtabs			; $BC00 (RAM at $34 and $35)

	lda #$35
	sta $01
	lda #$7f
	sta $dd0d
	lda $dd0d
	jsr init_weapon
	lda #0
	jsr fill_color_ram
	jsr prof_init
	jsr play_sound_init
	jsr input_irq_init

	lda #$34			; play default: I/O out
	sta $01
	jmp game_start
