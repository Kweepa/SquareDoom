!zone player

; ============================================================================
; player.asm — player damage / feedback (more player logic moves here later)
; ============================================================================

hurt_flash		!byte 0		; frames of red border left (incl. next render)

; ---------------------------------------------------------------------------
; player_frame — once per gameloop; keep hurt border through one full frame
;
; Damage is applied after render (enemy_think). Setting hurt_flash=1 means:
;   this frame ends red → next frame start keeps red through render → then off.
; ---------------------------------------------------------------------------
player_frame
	lda hurt_flash
	beq .pf_black
	dec hurt_flash
	lda #2				; red
	sta $d020
	rts
.pf_black
	lda #0
	sta $d020
	rts

; ---------------------------------------------------------------------------
; damage_player — A = damage; queue red border for the next full frame
; ---------------------------------------------------------------------------
damage_player
	sta tmp0
	lda #1
	sta hurt_flash
	lda #2
	sta $d020
	lda health
	sec
	sbc tmp0
	bcs .dp_ok
	lda #0
.dp_ok
	sta health
	rts
