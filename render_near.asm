!zone render_near

; ============================================================================
; render_near.asm — PROFILE N (near-sector floor/ceiling into the clip)
; ============================================================================
; At a sector edge, paint the *leaving* sector’s ceil/floor strips into
; [ytop,ybot), then leave span_a / span_b for ledge math in render_ledge.
; Front-to-back: ceil first; floor only if clip still open (and floor not
; above HORIZON — raised floors keep span_b but do not yank ybot).
;
; N is sampled once at on_cell .after_near (not mid-paint). project_y
; cost is bucketed to P via prof_add_py.
; Flat fills are inlined with lda near_fpat (no jsr fill_span).
; ============================================================================

; A = row → clamp into [ytop, ybot]; result in A. Macro-local @ labels.
!macro clamp_span_inline {
	cmp ytop
	bcs @cs1
	lda ytop
	jmp @cs2
@cs1
	cmp ybot
	bcc @cs2
	lda ybot
@cs2
}

; ---------------------------------------------------------------------------
; paint_near — fill near ceil/floor strips; update ytop/ybot and span_a/b
;
; Ceil: if clamp(ceilY) > ytop, fill [ytop, ceilEnd) even when ceilEnd == ybot
; (must close false openings for solid walls). Floor: only when floorY >=
; HORIZON; fill [floorStart, ybot) even when floorStart == ytop (same false-
; opening close — else solid walls stretch over the floor). span_b=$FF if
; floor skipped.
; ---------------------------------------------------------------------------
paint_near
	lda ytop
	cmp ybot
	bcc .pn_go
	lda #255
	sta span_b			; clip closed — no floor Y for ledge
	rts
.pn_go
	; --- Ceiling strip ---
	lda near_ceil
	jsr project_y
!if PROFILE = 1 {
	jsr prof_add_py
}
	lda py_row
	sta span_a			; nearCeilY for paint_portal

	+clamp_span_inline
	sta tmp1			; ceilEnd in [ytop,ybot]
	cmp ytop
	beq .nc
	bcc .nc
	; Fill [ytop, ceilEnd) even when ceilEnd==ybot (close false openings)
!if PROFILE = 1 {
	inc span_lo
	bne .pn_cf_go
	inc span_hi
.pn_cf_go
}
	ldx near_ccol
	ldy ytop
	jmp .pn_cf_test
.pn_cf_lp
	txa
	sta (col_base_l),y
	lda near_fpat
	sta (pat_base_l),y
	iny
.pn_cf_test
	cpy tmp1
	bne .pn_cf_lp
	lda tmp1
	sta ytop			; shrink open window from the top
.nc
	lda ytop
	cmp ybot
	bcc .pn_floor
	lda #255
	sta span_b
	rts
.pn_floor
	; --- Floor strip (only when at/below HORIZON) ---
	lda near_floor
	jsr project_y
!if PROFILE = 1 {
	jsr prof_add_py
}
	lda py_row
	sta span_b			; nearFloorY kept even if we skip fill
	cmp #HORIZON
	bcc .pnd			; raised floor: span_b only, leave ybot
	+clamp_span_inline
	sta tmp1
	cmp ybot
	bcs .pnd
	; Fill [floorStart, ybot) even when floorStart==ytop (close false openings)
	; and pull ybot up. After clamp, floorStart >= ytop always.
!if PROFILE = 1 {
	inc span_lo
	bne .pn_ff_go
	inc span_hi
.pn_ff_go
}
	ldx near_fcol
	ldy tmp1
	jmp .pn_ff_test
.pn_ff_lp
	txa
	sta (col_base_l),y
	lda near_fpat
	sta (pat_base_l),y
	iny
.pn_ff_test
	cpy ybot
	bne .pn_ff_lp
	lda tmp1
	sta ybot
.pnd
	rts

; ---------------------------------------------------------------------------
; refresh_near_spans — project near ceil/floor into span_a/b only (no fills)
;
; Used when same-flat skip avoids paint_near but a portal ledge still needs
; nearFloorY / nearCeilY at the current wallz.
; ---------------------------------------------------------------------------
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

; ---------------------------------------------------------------------------
; clamp_span — A = row → clamp into [ytop, ybot]; result in A
; Used by render_ledge; paint_near inlines via +clamp_span_inline.
; ---------------------------------------------------------------------------
clamp_span
	+clamp_span_inline
	rts
