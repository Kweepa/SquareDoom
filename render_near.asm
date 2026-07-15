!zone render_near

; ============================================================================
; render_near.asm — PROFILE N (near-sector floor/ceiling into the clip)
; ============================================================================
; At a sector edge, paint the *leaving* sector’s ceil/floor strips into
; [ytop,ybot), then leave span_a / span_b for ledge math in render_ledge.
; Front-to-back: ceil first; floor only if clip still open (and floor not
; above HORIZON — raised floors keep span_b but do not yank ybot).
;
; project_y cost is bucketed to P via prof_add_py, not N.
; ============================================================================

; ---------------------------------------------------------------------------
; paint_near — fill near ceil/floor strips; update ytop/ybot and span_a/b
;
; Ceil: if clamp(ceilY) > ytop, fill [ytop, ceilEnd) even when ceilEnd == ybot
; (must close false openings for solid walls). Floor: only when floorY >=
; HORIZON; fill [floorStart, ybot) and set ybot. span_b=$FF if floor skipped.
; ---------------------------------------------------------------------------
paint_near
	lda ytop
	cmp ybot
	bcc .pn_go
	lda #255
	sta span_b			; clip closed — no floor Y for ledge
	rts
.pn_go
!if PROFILE = 1 {
	ldy #PROF_NEAR
	jsr prof_add_bucket
}
	lda #FLOOR_PAT			; flats: fully lit horizontal dither
	sta fill_pat
	; --- Ceiling strip ---
	lda near_ceil
	jsr project_y
!if PROFILE = 1 {
	jsr prof_add_py
}
	lda py_row
	sta span_a			; nearCeilY for paint_portal

	jsr clamp_span
	sta tmp1			; ceilEnd in [ytop,ybot]
	cmp ytop
	beq .nc
	bcc .nc
	; Fill [ytop, ceilEnd) even when ceilEnd==ybot (close false openings)
	ldy ytop
	sty fill_y0
	ldy tmp1
	sty fill_y1
	lda near_ccol
	jsr fill_span
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
!if PROFILE = 1 {
	ldy #PROF_NEAR
	jsr prof_add_bucket
}
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
	jsr clamp_span
	sta tmp1
	cmp ybot
	bcs .pnd
	cmp ytop
	bcc .pnd
	beq .pnd
	; Fill [floorStart, ybot) and pull ybot up
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

; ---------------------------------------------------------------------------
; load_near_sector — cur_id → near_floor/ceil/fcol/ccol (SoA tables)
; ---------------------------------------------------------------------------
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
; ---------------------------------------------------------------------------
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
