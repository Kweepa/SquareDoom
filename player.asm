!zone player

; ============================================================================
; player.asm — player damage / feedback (more player logic moves here later)
; ============================================================================

; hurt_flash / death_ms — under-stack scrap (zeropage.asm)
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
;
; Armor (VicDoom): blue absorbs 1/2, green ≈1/3 (damage/4 + damage/16).
; No clamp — leftover armorDamage still reduces health hit; armor underflow
; (unsigned >200) clears armor + combat_armor.
; ---------------------------------------------------------------------------
damage_player
	sta tmp0			; damage remaining for health
	lda health
	beq .dp_rts			; already dead
	lda god_mode
	bne .dp_rts			; iddqd
	lda #SOUND_OOF
	jsr play_sound
	lda #1
	sta hurt_flash
	lda #2
	sta $d020

	lda armor
	beq .dp_health
	; saved = combat_armor ? damage/2 : damage/4 + damage/16
	lda combat_armor
	bne .dp_half
	lda tmp0
	lsr
	lsr				; /4
	sta tmp1
	lda tmp0
	lsr
	lsr
	lsr
	lsr				; /16
	clc
	adc tmp1
	jmp .dp_saved
.dp_half
	lda tmp0
	lsr				; /2
.dp_saved
	beq .dp_health			; tiny hit, nothing absorbed
	sta tmp1
	lda tmp0
	sec
	sbc tmp1
	sta tmp0
	lda armor
	sec
	sbc tmp1
	sta armor
	cmp #201			; underflow → used up
	bcc .dp_health
	lda #0
	sta armor
	sta combat_armor

.dp_health
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
