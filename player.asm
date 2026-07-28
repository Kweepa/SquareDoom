!zone player

; ============================================================================
; player.asm — player damage / feedback (more player logic moves here later)
; ============================================================================

hurt_flash		!byte 0		; frames of red border left (incl. next render)
death_ms		!byte 0, 0		; death-cam timer (ms); armed on killing blow
DEATH_PAUSE_MS = 2000

; ---------------------------------------------------------------------------
; player_frame — once per gameloop; keep hurt border through one full frame
;
; Damage is applied after render (enemy_think). Setting hurt_flash=1 means:
;   this frame ends red → next frame start keeps red through render → then off.
; ---------------------------------------------------------------------------
player_frame
	jsr radsuit_tick
	lda hurt_flash
	beq .pf_suit
	dec hurt_flash
	lda #2				; red overrides green
	sta $d020
	rts
.pf_suit
	jmp radsuit_set_border

; ---------------------------------------------------------------------------
; damage_player — A = damage; queue red border for the next full frame
; ---------------------------------------------------------------------------
damage_player
	sta tmp0
	lda health
	beq .dp_rts			; already dead
	lda #SOUND_OOF
	jsr play_sound
	lda #1
	sta hurt_flash
	lda #2
	sta $d020
	lda health
	sec
	sbc tmp0
	bcs .dp_ok
	lda #0
	sta death_ms			; start death-cam pause
	sta death_ms + 1
	jsr hide_weapon
.dp_ok
	sta health
	lda #1
	sta hud_dirty
.dp_rts
	rts

; ---------------------------------------------------------------------------
; player_death_frame — dead-player preamble (replaces input/move in gameloop)
;
; Red border, frame dt, death timer → next_level after DEATH_PAUSE_MS.
; ---------------------------------------------------------------------------
player_death_frame
	lda #2				; keep hurt border
	sta $d020
	jsr calc_frame_dt
	clc
	lda death_ms
	adc dt_ms
	sta death_ms
	lda death_ms + 1
	adc #0
	sta death_ms + 1
	cmp #>DEATH_PAUSE_MS
	bcc .pdf_go
	bne .pdf_restart
	lda death_ms
	cmp #<DEATH_PAUSE_MS
	bcc .pdf_go
.pdf_restart
	jmp next_level
.pdf_go
	jmp update_map_time

; ---------------------------------------------------------------------------
; player_death_eye — after update_eye: floor+1 while dead, else leave standing
; ---------------------------------------------------------------------------
player_death_eye
	lda health
	bne .pde_rts
	lda eyeheight
	sec
	sbc #2				; floor + 3 → floor + 1
	sta eyeheight
	sta project_y_sbc_eye + 1
.pde_rts
	rts
