!zone render_wallu

; ============================================================================
; render_wallu.asm — wall face U = frac at the tile-grid crossing
; ============================================================================
; DDA keeps integer mapx/mapy (+ tile ptr), not fractional XY. At a painted
; edge, recover the crossing frac on the non-hit axis (TheKeep hitcommon):
;
;   X-hit:  u8 = lo(sdx × fixcos[dyindex]) ± fracy
;   Y-hit:  u8 = lo(sdy × fixcos[dxindex]) ± fracx
;   step≥0 on the *other* axis → add; else sbc + eor #$ff
;
; dxindex/dyindex = folded fixsec indices for this column’s ray (same as DDA).
; wall_u = that u8 (0..255 along the face). Clobbers A,X,Y,aux_*,tmp0..tmp3.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; calc_wall_u
; ---------------------------------------------------------------------------
calc_wall_u
	; Column DDA angle (north-aligned) → dxindex / dyindex
	ldx col
	lda angtab,x
	clc
	adc playera
	sec
	sbc #64
	sta tmp0				; angle
	and #127
	cmp #63
	bcc .cwu_dxok
	eor #127
.cwu_dxok
	sta tmp1				; dxindex
	lda tmp0
	clc
	adc #64
	and #127
	cmp #63
	bcc .cwu_dyok
	eor #127
.cwu_dyok
	sta tmp2				; dyindex

	lda side
	bne .cwu_y
	; ---- X-hit: crossing is vertical → U from Y ----
	lda sdx_l
	sta aux_l
	lda sdx_h
	sta aux_h
	ldy tmp2				; dyindex
	lda fixcos,y
	jsr mul_16x8			; A = lo((sdx×fixcos)>>8)
	ldx ystep				; other-axis step
	ldy fracy
	jmp .cwu_combine

.cwu_y
	; ---- Y-hit: crossing is horizontal → U from X ----
	lda sdy_l
	sta aux_l
	lda sdy_h
	sta aux_h
	ldy tmp1				; dxindex
	lda fixcos,y
	jsr mul_16x8
	ldx xstep
	ldy fracx
	; fall through

; A = mul lo; X = step (±1); Y = player frac on the U axis
.cwu_combine
	cpx #0
	bmi .cwu_neg			; step = $ff → subtract path
	clc
	sty tmp0
	adc tmp0
	sta wall_u
	rts
.cwu_neg
	sec
	sty tmp0
	sbc tmp0
	eor #$ff
	sta wall_u
	rts
