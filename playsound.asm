; Sound effects — Doom PC speaker envelopes on SID noise (pitch from pcsfreq_*).
; Data/freq table: dpsounds.asm (from pcsounds/DP*.lmp via tools/gensounds.js).
;
; PC speaker Doom: each byte is a musical pitch 0..95 (0 = silence) held 1/140 s.
; Full resolution via pcsfreq_* into SID voice 1 noise. CIA1 Timer B steps @ ~140 Hz.

!zone playsound

; Sound indices (VicDoom ESound / playSound.h)
SOUND_CLAW = 0
SOUND_DMPAIN = 1
SOUND_DOROPN = 2
SOUND_DORCLS = 3
SOUND_ITEMUP = 4
SOUND_OOF = 5
SOUND_GURGLE = 6
SOUND_PISTOL = 7
SOUND_PLPAIN = 8
SOUND_POPAIN = 9
SOUND_SGCOCK = 10
SOUND_SGTDTH = 11
SOUND_SHOTGN = 12
SOUND_STNMOV = 13
SOUND_SAWIDL = 14
SOUND_SAWFUL = 15
SOUND_SAWHIT = 16
SOUND_PUNCH = 17

sound_priorities
; claw, dmpain, doropn, dorcls, itemup, oof
	!byte 2,2,1,1,1,2
; gurgle, pistol, plpain, popain, sgcock, sgtdth
	!byte 0,2,2,2,2,2
; shotgn, stnmov, sawidl, sawful, sawhit, punch
	!byte 2,0,0,1,2,2

sound_index		!byte $ff
sound_priority		!byte 0
sound_count		!byte 0
sound_max		!byte 0
sfx_temp_vol		!byte 0
ps_save_x		!byte 0
ps_save_y		!byte 0

; ------------------------------------------------------------------
; play_sound_init — clear SID; noise voice ready; idle vol = music_vol
; ------------------------------------------------------------------
play_sound_init
	lda #$ff
	sta sound_index
	lda #0
	sta sound_priority
	sta sound_count
	sta sound_max
	; turn off all channels
	ldx #$18
	lda #0
.psi_clr
	sta $d400,x
	dex
	bpl .psi_clr
	; Voice 1 ADSR: instant attack/decay, full sustain (gated noise)
	lda #$00
	sta $d405
	lda #$f0
	sta $d406
	; set to music volume
	lda music_vol
	sta $d418
	rts

; ------------------------------------------------------------------
; play_sound — A = sound index; higher-or-equal priority preempts
; Preserves X,Y; A clobbered
; ------------------------------------------------------------------
play_sound
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
	; first stop the old sound
	lda #$ff
	sta sound_index
	; then set up the pointer to the data
	lda sound_table,y
	sta sound_ptr_l
	lda sound_table+1,y
	sta sound_ptr_h
	; then the counters
	ldy #0
	lda (sound_ptr_l),y
	tay
	iny
	sty sound_max
	lda #0
	sta sound_count

	; start the new sound playing
	stx sound_index
.ps_skip
	ldx ps_save_x
	ldy ps_save_y
	cli
	rts

; ------------------------------------------------------------------
; update_sfx — one PC speaker sample per call (CIA1 Timer B @ ~140 Hz)
; Must not touch tmp0–tmp5 / other main-thread ZP.
; ------------------------------------------------------------------
update_sfx
	; check we're playing a sound
	lda sound_index
	cmp #$ff
	beq .sfx_idle

	ldx effects_vol
	stx sfx_temp_vol
	cmp #14				; sawidl
	bne .sfx_vol
	lsr sfx_temp_vol
	lsr sfx_temp_vol
.sfx_vol
	; turn up volume a bit
	lda sfx_temp_vol
	sta $d418

	; play next sample (held until next ~7 ms tick — PC speaker timing)
	inc sound_count
	ldy sound_count
	cpy sound_max
	beq .sfx_stop
	lda (sound_ptr_l),y
	; pitch 0 = silence; else SID freq from pcsfreq_* (full 0..95 scale)
	beq .sfx_silent
	tax
	lda pcsfreq_lo,x
	sta $d400
	lda pcsfreq_hi,x
	sta $d401
	lda #$81			; noise + gate
	sta $d404
	rts

.sfx_silent
	lda #0
	sta $d404			; gate off
	rts

.sfx_stop
	lda #0
	sta $d404

	lda #$ff
	sta sound_index
	lda #0
	sta sound_priority

	; set to music volume
	lda music_vol
	sta $d418
.sfx_idle
	rts
