!zone render_near

; ============================================================================
; render_near.asm — PROFILE N (near-sector floor/ceiling into the clip)
; ============================================================================
; At a sector edge, paint the *leaving* sector’s ceil/floor strips into
; [ytop,ybot), then leave span_a / span_b for ledge math in render_ledge.
; Front-to-back: ceil first; floor only if clip still open (and floor not
; above HORIZON — raised floors keep span_b but do not yank ybot).
;
; PROFILE: dump pending work to N before each project_y so P is projection
; only (ceil fill must not land in the floor P sample). Final N bookend at
; on_cell .after_near covers remaining floor fill / glue.
; Flat fills are inlined with lda near_fpat (no jsr fill_span).
; ============================================================================

; A = row → clamp into [ytop, ybot]; result in A. Macro-local @ labels.
; Used by clamp_span (ledge); paint_near fuses clamp with fill decisions.
!macro clamp_span_inline {
	cmp ytop
	bcs @cs1
	lda ytop
	bcc @cs2			; C=0 after untaken bcs; lda preserves C
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
!if PROFILE = 1 {
	ldy #PROF_NEAR
	jsr prof_add_bucket		; post-W glue → N (not P)
}
	lda near_ceil
	jsr project_y
!if PROFILE = 1 {
	jsr prof_add_py
	lda py_row
}
	sta span_a			; nearCeilY for paint_portal (A = py_row)

	; Fuse clamp + fill test: no fill when row <= ytop (clamps to ytop).
	; Else ceilEnd = min(row, ybot); fill even when ceilEnd == ybot.
	cmp ytop
	beq .nc
	bcc .nc
	cmp ybot
	bcc .pn_cf_ready
	lda ybot
.pn_cf_ready
	sta tmp1			; ceilEnd in (ytop, ybot]
!if PROFILE = 1 {
	inc span_lo
	bne .pn_cf_go
	inc span_hi
.pn_cf_go
}
	ldx near_ccol
	ldy ytop
	; tmp1 > ytop → at least one row; enter body directly
.pn_cf_lp
	txa
	sta (col_base_l),y
	lda near_fpat
	sta (pat_base_l),y
	iny
	cpy tmp1
	bne .pn_cf_lp
	sty ytop			; Y == tmp1 at exit; shrink open window from the top
.nc
	lda ytop
	cmp ybot
	bcc .pn_floor
	lda #255
	sta span_b
	rts
.pn_floor
	; --- Floor strip (only when at/below HORIZON) ---
!if PROFILE = 1 {
	ldy #PROF_NEAR
	jsr prof_add_bucket		; clamp + ceil fill → N (not floor P)
}
	lda near_floor
	jsr project_y
!if PROFILE = 1 {
	jsr prof_add_py
	lda py_row
}
	sta span_b			; nearFloorY kept even if we skip fill
	cmp #HORIZON
	bcc .pnd			; raised floor: span_b only, leave ybot

	; Fuse clamp + fill test: floorStart = clamp(row); fill iff start < ybot
	; (including floorStart == ytop for false-opening close).
	cmp ytop
	bcs .pn_ff_hi
	lda ytop
	bcc .pn_ff_clamped		; C=0 after untaken bcs; always taken
.pn_ff_hi
	cmp ybot
	bcs .pnd			; start >= ybot → empty
.pn_ff_clamped
	sta tmp1			; floorStart in [ytop, ybot)
!if PROFILE = 1 {
	inc span_lo
	bne .pn_ff_go
	inc span_hi
.pn_ff_go
}
	ldx near_fcol
	ldy tmp1
	; tmp1 < ybot → at least one row; enter body directly
.pn_ff_lp
	txa
	sta (col_base_l),y
	lda near_fpat
	sta (pat_base_l),y
	iny
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
!if PROFILE = 1 {
	ldy #PROF_NEAR
	jsr prof_add_bucket
}
	lda near_ceil
	ldy near_floor
	jsr project_y_pair
	stx span_a
	sta span_b
!if PROFILE = 1 {
	jsr prof_add_py_pair
}
	rts

; ---------------------------------------------------------------------------
; clamp_span — A = row → clamp into [ytop, ybot]; result in A
; Used by render_ledge; paint_near fuses clamp via open-coded compares.
; ---------------------------------------------------------------------------
clamp_span
	+clamp_span_inline
	rts
