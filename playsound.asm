; Sound effects — Doom PC speaker envelopes on SID noise (pitch from pcsfreq_*).
; Data/freq table: dpsounds.asm (from pcsounds/DP*.lmp via tools/gensounds.js).
;
; PC speaker Doom: each byte is a musical pitch 0..95 (0 = silence) held 1/140 s.
; Full resolution via pcsfreq_* into SID voice 3 noise (music keeps voices 1–2).
; CIA1 Timer B steps @ ~140 Hz.
;
; Music prepare redirects STA $D417/$D418 → sid_filt_shadow / sid_vol_shadow
; for SidTracker tunes only (flag at MUSIC_SIDTRACKER_FLAG = $9FFF).
; After MUSIC_PLAY, music_apply_sid_shadows merges filter modes + game volume
; onto the real SID (never voice3-off; drop voice3-from-filter while SFX).
; MUSIC_SIDTRACKER_FLAG is a stub (no SID on the level PRG).

!zone playsound

; Readable scrap mirrors (tools/prepare_music.py SID_*_SHADOW).
; Not $0314–$0333 — that page is KERNAL soft vectors (NMI = $0318/$0319).
sid_filt_shadow	= $02f8			; music wanted $D417
sid_vol_shadow	= $02f9			; music wanted $D418
music_sidtracker_flag
	!byte 0				; no SidTracker on level PRG
MUSIC_SIDTRACKER_FLAG = music_sidtracker_flag

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
SOUND_BAREXP = 18

sound_priorities
; claw, dmpain, doropn, dorcls, itemup, oof
	!byte 2,2,1,1,1,2
; gurgle, pistol, plpain, popain, sgcock, sgtdth
	!byte 0,2,2,2,2,2
; shotgn, stnmov, sawidl, sawful, sawhit, punch, barexp
	!byte 2,0,0,1,2,2,2

; sound_index / sound_priority…sid_merge_tmp — under-stack scrap (zeropage.asm)

; ------------------------------------------------------------------
; play_sound_init — clear SID; voice 3 noise ready; idle vol = music_vol
; ------------------------------------------------------------------
play_sound_init
	jsr io_push
	lda #$ff
	sta sound_index
	lda #0
	sta sound_priority
	sta sound_count
	sta sound_max
	sta sid_filt_shadow
	sta sid_vol_shadow
	; turn off all channels
	ldx #$18
	lda #0
.psi_clr
	sta $d400,x
	dex
	bpl .psi_clr
	jsr sfx_voice3_adsr
	jsr music_apply_sid_shadows
	jmp io_pop

; Voice 3 ADSR for gated noise. io_push: play_sound runs at $01=$34,
; and pistol_mid lives at $D400 (SID window).
sfx_voice3_adsr
	jsr io_push
	lda #$00
	sta $d413				; AD: instant
	lda #$f0
	sta $d414				; SR: full sustain, fast release
	jmp io_pop

; ------------------------------------------------------------------
; music_apply_sid_shadows — after MUSIC_PLAY (or any vol change).
; SidTracker: merge shadowed D417/D418. Else: volume only (music owns filter).
; ------------------------------------------------------------------
music_apply_sid_shadows
	jsr io_push
	lda MUSIC_SIDTRACKER_FLAG
	beq .mas_plain

	lda sid_filt_shadow
	ldx sound_index
	bmi .mas_filt
	and #$fb				; voice 3 not into filter during SFX
.mas_filt
	sta $d417

	; volume → sid_merge_tmp
	ldx sound_index
	bmi .mas_mvol
	lda effects_vol
	cpx #14				; sawidl
	bne .mas_havev
	lsr
	lsr
	jmp .mas_havev
.mas_mvol
	lda music_vol
.mas_havev
	sta sid_merge_tmp
	lda sid_vol_shadow
	and #$70				; keep LP/BP/HP only
	ora sid_merge_tmp
	sta $d418
	jmp io_pop

; Non-SidTracker: do not touch $D417; set master volume only
.mas_plain
	ldx sound_index
	bmi .mas_p_mvol
	lda effects_vol
	cpx #14
	bne .mas_p_store
	lsr
	lsr
	jmp .mas_p_store
.mas_p_mvol
	lda music_vol
.mas_p_store
	sta $d418
	jmp io_pop

; ------------------------------------------------------------------
; play_sound — A = sound index; higher-or-equal priority preempts
; Preserves X,Y and caller's I flag; A clobbered
; ------------------------------------------------------------------
play_sound
	php				; keep caller's I (summary holds SEI)
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
	jsr sfx_voice3_adsr
	jsr music_apply_sid_shadows
.ps_skip
	ldx ps_save_x
	ldy ps_save_y
	plp
	rts

; ------------------------------------------------------------------
; update_sfx — one PC speaker sample per call (CIA1 Timer B @ ~140 Hz)
; Must not touch tmp0–tmp5 / other main-thread ZP. Voice 3 only.
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
	jsr sfx_voice3_adsr
	jsr io_push
	lda pcsfreq_lo,x
	sta $d40e
	lda pcsfreq_hi,x
	sta $d40f
	lda #$81			; noise + gate
	sta $d412
	jmp io_pop

.sfx_silent
	jsr io_push
	lda #0
	sta $d412
	jmp io_pop

.sfx_stop
	jsr io_push
	lda #0
	sta $d412
	jsr io_pop

	lda #$ff
	sta sound_index
	lda #0
	sta sound_priority
	jmp music_apply_sid_shadows

.sfx_idle
	rts
