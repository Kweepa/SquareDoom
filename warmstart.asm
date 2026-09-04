!zone locode

; MENU trampoline JMP $0400 lands here after GAME overwrites MENU.
; GAME image already holds the kernal blob at MEM_LEVEL.
locode_entry
	sei
	cld
	lda $01
	ora #$04			; I/O in
	sta $01
	lda #$7f
	sta $dc0d
	sta $dd0d
	lda $dc0d
	lda $dd0d
	lda #0
	sta $dc0f
	sta $dd0e			; CIA2 timers (IEC / profiler)
	sta $dd0f
	sta $d01a
	sta $d015
	lda $d019
	sta $d019
!if USE_KRILL {
	sta $dc0e			; stop leftover BASIC jiffy (CIA1 TA)
}
	jsr locode_play_takeover
	jsr set_vic_bank3

	jsr copy_kernal_blob		; MEM_LEVEL staging → SEC_WDARK_END
	lda #$34
	sta $01
	jsr init_sqtabs			; $B800 (RAM at $34 and $35)

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

; $01=$35, RAM NMI/IRQ, keyboard DDR. Caller has already SEI'd.
locode_play_takeover
	lda #$35
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
	sta $dc02
	lda #0
	sta $dc03
	lda #0
	sta $d020
	sta $d021
	rts
