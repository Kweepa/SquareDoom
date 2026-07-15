!zone render_wallz

; ============================================================================
; render_wallz.asm — PROFILE W (depth → texstep)
; ============================================================================
; At each painted sector edge, turn the side’s incremental fish-scaled
; distance (wz_x or wz_y from render_dda) into texstep for project_y.
; No mul here — fish was applied in column setup / DDA adds.
; ============================================================================

; ---------------------------------------------------------------------------
; calc_wallz — side 0 → wz_x, side 1 → wz_y; texstep = wallz >> TEXSTEP_SHIFT
;
; Guarantees texstep ≠ 0 (min 1). Stores wallz_l/h for debug/inspection.
; ---------------------------------------------------------------------------
calc_wallz
	; Pick the axis that just hit (side set by cast_column)
	lda side
	bne .czy
	lda wz_x_l
	ldx wz_x_h
	jmp .czn
.czy
	lda wz_y_l
	ldx wz_y_h
.czn
	sta wallz_l
	stx wallz_h
	ora wallz_h
	bne .czok0
	lda #1				; never leave wallz = 0
	sta wallz_l
.czok0
	; texstep = wallz >> TEXSTEP_SHIFT (TheKeep uses >>2)
	lda wallz_l
	ldx wallz_h
	stx texstep_h
	ldy #TEXSTEP_SHIFT
.czs
	lsr texstep_h
	ror
	dey
	bne .czs
	sta texstep_l
	lda texstep_h
	ora texstep_l
	bne .czok
	lda #1				; project_y must advance each row
	sta texstep_l
.czok
	rts
