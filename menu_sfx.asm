; Menu CIA1 Timer A (~50 Hz) → update_sfx. Raster IRQ: MCM logo band, then hires + cursor/hint.
; Banks KERNAL out ($01=$35) so $fffe is live; boot restores $36 after menu.

!zone menu_sfx

SAMPLE_TA_LO	= <$4FFF
SAMPLE_TA_HI	= >$4FFF

menu_sfx_init
	sei
	lda #$35
	sta $01
	lda #$7f
	sta $dc0d
	lda $dc0d
	lda #0
	sta $d01a
	lda $d019
	sta $d019
	lda #SAMPLE_TA_LO
	sta $dc04
	lda #SAMPLE_TA_HI
	sta $dc05
	lda #<menu_sfx_irq
	sta $fffe
	lda #>menu_sfx_irq
	sta $ffff
	lda #<menu_nmi_stub
	sta $fffa
	sta $0318
	lda #>menu_nmi_stub
	sta $fffb
	sta $0319
	lda $d011
	and #%01111111
	sta $d011
	lda #MUX_LOGO_RASTER
	sta $d012
	lda #0
	sta menu_mux_phase
	lda #1
	sta menu_raster_en
	lda #$81
	sta $dc0d
	lda #$11
	sta $dc0e
	lda #1
	sta $d01a				; raster IRQ
	jsr play_sound_init
	cli
	rts

; Stop raster mux and hide sprites; CIA Timer A stays for SFX.
; $d019 raster still latches when $d012 matches even if $d01a=0 — CIA
; ticks would remux unless menu_raster_en is clear first.
menu_raster_off
	sei
	lda #0
	sta menu_raster_en
	sta $d01a
	sta $d015
	sta hint_spr_en
	sta cursor_spr_en
	lda $d019
	sta $d019
	cli
	rts

menu_sfx_done
	jsr menu_raster_off
	sei
	lda #$7f
	sta $dc0d
	lda $dc0d
	lda #0
	sta $dc0e
	sta $d40b
	lda #$36
	sta $01
	cli
	rts

menu_nmi_stub
	pha
	lda $01
	pha
	lda #$35
	sta $01
	lda $dd0d
	pla
	sta $01
	pla
	rti

menu_sfx_irq
	pha
	; Mode bit only; $d021 already grey in both MCM and hires.
	lda $d019
	lsr
	bcc .msi_rest
	lda menu_mux_phase
	bne .msi_ph
	lda #$18				; CSEL + MCM
	sta $d016
	jmp .msi_rest
.msi_ph
	cmp #1
	bne .msi_rest
	lda #$08				; CSEL, hires
	sta $d016
.msi_rest
	txa
	pha
	tya
	pha
	lda $01
	pha
	lda #$35
	sta $01
	lda $d019
	sta $d019
	and #1
	bne .msi_vic
	jmp .msi_cia
.msi_vic
	lda menu_raster_en
	bne .msi_mux
	jmp .msi_cia
.msi_mux
	lda menu_mux_phase
	beq .msi_logo
	cmp #1
	beq .msi_cur
	; phase 2 — hint keys, then wrap
	jsr mux_hint_spr
	lda #0
	sta menu_mux_phase
	lda $d011
	and #%01111111
	sta $d011
	lda #MUX_LOGO_RASTER
	sta $d012
	jmp .msi_cia
.msi_logo
	jsr mux_logo_spr
	lda #1
	sta menu_mux_phase
	lda $d011
	and #%01111111
	sta $d011
	lda #MUX_HIRES_RASTER
	sta $d012
	jmp .msi_cia
.msi_cur
	jsr mux_hires_mcm
	lda cursor_spr_en
	beq .msi_skip_cur
	jsr mux_cursor_spr
	lda #2
	sta menu_mux_phase
	lda $d011
	and #%01111111
	sta $d011
	lda cursor_spr_y
	clc
	adc #21
	sta $d012
	jmp .msi_cia
.msi_skip_cur
	jsr mux_hint_spr
	lda #0
	sta menu_mux_phase
	lda $d011
	and #%01111111
	sta $d011
	lda #MUX_LOGO_RASTER
	sta $d012
.msi_cia
	lda $dc0d
	and #1
	beq .msi_rti
	jsr update_sfx
.msi_rti
	pla
	sta $01
	pla
	tay
	pla
	tax
	pla
	rti

sfx_movegun1
	lda #SOUND_MOVEGUN1
	jmp play_sound

sfx_movegun2
	lda #SOUND_MOVEGUN2
	jmp play_sound

sfx_shoot
	lda #SOUND_SHOOT
	jmp play_sound

sfx_esc
	lda #SOUND_ESCPRESSED
	jmp play_sound
