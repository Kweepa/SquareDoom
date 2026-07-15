!zone render_near

; PROFILE N — near-sector ceil/floor strips (+ same-flat span refresh)

; Ceil first; only project floor if clip still open (saves project_y when
; near ceil eats the column — on_cell then skips paint_portal).
paint_near
	lda ytop
	cmp ybot
	bcc .pn_go
	lda #255
	sta span_b
	rts
.pn_go
!if PROFILE = 1 {
	ldy #PROF_NEAR
	jsr prof_add_bucket			; load_near + preamble → N
}
	lda near_ceil
	jsr project_y
!if PROFILE = 1 {
	jsr prof_add_py
}
	lda py_row
	sta span_a

	jsr clamp_span
	sta tmp1
	; Editor: ceilEnd = clamp(nearCeilY); if ceilEnd > yTop fill and
	; yTop = ceilEnd — including when ceilEnd == yBot (closes portal).
	; Old bcs-skip when == ybot left a false opening for solid wall.
	cmp ytop
	beq .nc
	bcc .nc
	ldy ytop
	sty fill_y0
	ldy tmp1
	sty fill_y1
	lda near_ccol
	jsr fill_span
	lda tmp1
	sta ytop
.nc
	lda ytop
	cmp ybot
	bcc .pn_floor
	lda #255				; no floor project this call
	sta span_b
	rts
.pn_floor
!if PROFILE = 1 {
	ldy #PROF_NEAR
	jsr prof_add_bucket			; ceil fill → N
}
	lda near_floor
	jsr project_y
!if PROFILE = 1 {
	jsr prof_add_py
}
	lda py_row
	sta span_b
	; Floor above eye → above HORIZON: keep span_b for ledges but do not
	; paint a floor strip / yank ybot into the upper half.
	cmp #HORIZON
	bcc .pnd
	jsr clamp_span
	sta tmp1
	cmp ybot
	bcs .pnd
	cmp ytop
	bcc .pnd
	beq .pnd
	ldy tmp1
	sty fill_y0
	ldy ybot
	sty fill_y1
	lda near_fcol
	jsr fill_span
	lda tmp1
	sta ybot
.pnd
	rts

load_near_sector
	ldx cur_id
	lda SEC_FLOOR,x
	sta near_floor
	lda SEC_CEIL,x
	sta near_ceil
	lda SEC_FCOL,x
	sta near_fcol
	lda SEC_CCOL,x
	sta near_ccol
	rts

; Project near ceil/floor into span_a/b only (same-flat skip + portal ledge).
refresh_near_spans
	lda near_ceil
	jsr project_y
!if PROFILE = 1 {
	jsr prof_add_py
}
	lda py_row
	sta span_a
	lda near_floor
	jsr project_y
!if PROFILE = 1 {
	jsr prof_add_py
}
	lda py_row
	sta span_b
	rts

clamp_span
	cmp ytop
	bcs .c1
	lda ytop
	rts
.c1
	cmp ybot
	bcc .c2
	lda ybot
.c2
	rts
