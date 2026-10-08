; Menu music + sprite mux. When a tune loaded, CIA1 Timer A calls MUSIC_PLAY
; and all three SID voices belong to it. SidTracker init sets the rate
; (25..48 Hz). At Doom's Gate is 50 Hz and the latch is loaded after init.
; Otherwise Timer A stays ~50 Hz for menu blips (voice 2).
; Raster IRQ muxes the logo / cursor / hint sprites.
; Banks KERNAL out ($01=$35) so $fffe is live; boot restores $36 after menu.

!zone menu_sfx

SAMPLE_TA_LO	= <$4FFF
SAMPLE_TA_HI	= >$4FFF

; Needs: music_ok (mus file resident at $9000). Runs with I=1 on exit I=0.
menu_sfx_init
	sei
	lda #$35
	sta $01
	lda #$7f
	sta $dc0d
	lda $dc0d
	lda #0
	sta $d01a
	sta music_en
	sta music_due
	lda $d019
	sta $d019
	ldx #$18
	lda #0
.msi_clr
	sta $d400,x
	dex
	bpl .msi_clr
	lda music_ok
	beq .msi_sfx
	lda effects_vol
	and #15
	sta $d418
	; Player ZP is restored only while it runs. SidTracker init programs
	; $dc04/05. At Doom's Gate (track 3) is a 50 Hz player and does not.
	jsr music_zp_swap
	lda #0
	jsr MENU_MUSIC_INIT
	jsr music_zp_swap
	lda music_track
	cmp #3
	bne .msi_rate
	lda #SAMPLE_TA_LO
	sta $dc04
	lda #SAMPLE_TA_HI
	sta $dc05
.msi_rate
	lda #1
	sta music_en
	bne .msi_vec
.msi_sfx
	lda #SAMPLE_TA_LO
	sta $dc04
	lda #SAMPLE_TA_HI
	sta $dc05
	lda effects_vol
	and #15
	sta $d418
.msi_vec
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
	lda #$11				; start + force-load latch
	sta $dc0e
	lda #1
	sta $d01a				; raster IRQ
	lda music_en
	bne .msi_go
	jsr play_sound_init
.msi_go
	cli
	rts

; Exchange player ZP state with the menu's $f0-$ff.
music_zp_swap
	ldx #MENU_MUSIC_ZP_N - 1
.mzs
	lda MENU_MUSIC_ZP,x
	tay
	lda music_zp,x
	sta MENU_MUSIC_ZP,x
	tya
	sta music_zp,x
	dex
	bpl .mzs
	rts

; Caller holds I=1. Silence all three voices.
music_stop
	lda #0
	sta music_en
	sta $d404
	sta $d40b
	sta $d412
	sta $d406
	sta $d40d
	sta $d414
	rts

; Stop raster mux and hide sprites; music silenced.
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
	sta wip_spr_en
	lda $d019
	sta $d019
	jsr music_stop
	cli
	rts

; Leaves the state later KERNAL/Krill loads expect: CIA1 masked+stopped,
; raster off, music silent, $01=$36, I=0.
menu_sfx_done
	jsr menu_raster_off
	sei
	lda #$7f
	sta $dc0d
	lda $dc0d
	lda #0
	sta $dc0e
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
; CIA tick can land in the skull-to-hint gap and the play routine is
; long enough to miss that split. Ack it anywhere; play only once the
; hint sprites are in (phase 0, the stretch down to the logo raster).
.msi_cia
	lda $dc0d
	and #1
	beq .msi_due
	lda #1
	sta music_due
.msi_due
	lda menu_mux_phase
	bne .msi_rti
	lda music_due
	beq .msi_rti
	lda #0
	sta music_due
	lda music_en
	beq .msi_blip
	jsr music_zp_swap
	cli					; play ~1.7k cycles; raster mux must preempt
	jsr MENU_MUSIC_PLAY
	sei
	jsr music_zp_swap
	jmp .msi_rti
.msi_blip
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
