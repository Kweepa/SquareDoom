; Sound effects — Wolf PC-speaker envelopes on SID voice 2 pulse (50% duty).
; Data: pcsounds.asm + pcsfreq.asm (tools/gensounds.py from AUDIOT.WL1).
; Decimated 3x; stepped once per CIA1 Timer A IRQ (~50 Hz).
; SID Fn lo fixed at $80 (hi LUT only — saves 256 bytes).

!zone playsound

SFX_VOL		= $0f				; default if menu skipped

; ------------------------------------------------------------------
; play_sound_init — clear SID; voice 2 ready; master volume from menu
; ------------------------------------------------------------------
play_sound_init
	lda #$ff
	sta sound_index
	lda #0
	sta sound_priority
	sta sound_count
	sta sound_max
	ldx #$18
	lda #0
.psi_clr
	sta $d400,x
	dex
	bpl .psi_clr
	jsr sfx_voice2_adsr
	lda effects_vol
	and #SFX_VOL
	sta $d418
	rts

sfx_voice2_adsr
	lda #$00
	sta $d409				; PW lo — 50% duty
	lda #$08
	sta $d40a				; PW hi
	lda #$00
	sta $d40c				; AD: instant
	lda #$f0
	sta $d40d				; SR: full sustain, fast release
	rts

; ------------------------------------------------------------------
; play_sound — A = sound index; higher-or-equal priority preempts
; Queue-only: no SID access (safe at $01=$34); the Timer A IRQ
; (update_sfx) does all SID writes, starting on the next tick.
; Preserves X,Y and caller's I flag; A clobbered
; ------------------------------------------------------------------
play_sound
	php
	sei
	stx ps_save_x
	sty ps_save_y
	tax
	lda sound_priorities,x
	cmp sound_priority
	bcc .ps_skip

	sta sound_priority

	txa
	asl
	tay
	lda sound_table,y
	sta sound_ptr_l
	lda sound_table+1,y
	sta sound_ptr_h
	ldy #0
	lda (sound_ptr_l),y
	tay
	iny
	sty sound_max
	lda #0
	sta sound_count

	stx sound_index
.ps_skip
	ldx ps_save_x
	ldy ps_save_y
	plp
	rts

; ------------------------------------------------------------------
; update_sfx — one PC speaker sample per call (~50 Hz Timer A)
; Must not touch tmp0–tmp5 / other main-thread ZP. Voice 2 only.
; ------------------------------------------------------------------
update_sfx
	lda sound_index
	bmi .sfx_idle

	inc sound_count
	ldy sound_count
	cpy sound_max
	beq .sfx_stop
	lda (sound_ptr_l),y
	beq .sfx_silent
	tax
	jsr sfx_voice2_adsr
	lda #$80
	sta $d407
	lda pcsfreq_hi,x
	sta $d408
	lda #$41				; pulse + gate
	sta $d40b
	rts

.sfx_silent
	lda #0
	sta $d40b
	rts

.sfx_stop
	lda #0
	sta $d40b
	lda #$ff
	sta sound_index
	lda #0
	sta sound_priority
	lda effects_vol
	and #SFX_VOL
	sta $d418
.sfx_idle
	rts

; sound_* / ps_save_* live in ZP (zp.asm) — shared with MENU overlay
