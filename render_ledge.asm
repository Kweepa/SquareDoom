!zone render_ledge

; ============================================================================
; render_ledge.asm — PROFILE L (portal ledges + solid wall colour helper)
; ============================================================================
; After paint_near, draw upper/lower walls where far heights step relative
; to near. Contained far (far_ceil >= near_ceil and far_floor <= near_floor)
; → immediate rts. Open portal after a step-up is [ytop, farFloorY) — always
; set ybot from far floor even when that Y is above HORIZON.
;
; Door sectors: upper ledge uses far ceil colour.
; Elevator sectors: lower ledge (riser) uses far floor colour.
; Else N/S vs E/W grey.
; ============================================================================

; ---------------------------------------------------------------------------
; paint_portal — ledges for next_id vs near_*; may advance ytop/ybot
;
; Uses span_a/span_b from paint_near (or refresh_near_spans) as near ceil/
; floor screen Y. tmp4 = farCeilY; tmp5 = farFloorY when projected.
; ---------------------------------------------------------------------------
paint_portal
	jsr wall_colour_ns_ew
.pg
	ldx next_id
	lda SEC_FLOOR,x
	sta far_floor
	lda SEC_CEIL,x
	sta far_ceil
!if DBG_PORTAL = 1 {
	lda #255
	sta dbg_far_y
}

	; Contained far (higher/equal ceil AND lower/equal floor) → no ledge
	cmp near_ceil
	bcc .pp_upper			; far_ceil < near_ceil → upper
	lda far_floor
	cmp near_floor
	bcc .ppd
	beq .ppd
	jmp .pp_lower			; lower ledge only

.pp_upper
!if PROFILE = 1 {
	ldy #PROF_LEDGE
	jsr prof_add_bucket
}
	lda far_ceil
	jsr project_y
!if PROFILE = 1 {
	jsr prof_add_py
}
	lda py_row
	sta tmp4			; farCeilY
	lda far_floor
	cmp near_floor
	bcc .pp_do_u
	beq .pp_do_u
	; Both ledges at this edge
!if PROFILE = 1 {
	ldy #PROF_LEDGE
	jsr prof_add_bucket
}
	lda far_floor
	jsr project_y
!if PROFILE = 1 {
	jsr prof_add_py
}
	lda py_row
	sta tmp5			; farFloorY
!if DBG_PORTAL = 1 {
	sta dbg_far_y
}
	jsr .pp_draw_u
	jmp .pp_do_l

.pp_do_u
	jsr .pp_draw_u
.ppd
	rts

.pp_lower
!if PROFILE = 1 {
	ldy #PROF_LEDGE
	jsr prof_add_bucket
}
	lda far_floor
	jsr project_y
!if PROFILE = 1 {
	jsr prof_add_py
}
	lda py_row
	sta tmp5
!if DBG_PORTAL = 1 {
	sta dbg_far_y
}
.pp_do_l
	; Lower wall strip between farFloorY and nearFloorY
	lda ytop
	cmp ybot
	bcs .ppd
	lda tmp5
	jsr clamp_span
	sta tmp1			; farFloorY clamped
	lda span_b
	jsr clamp_span
	sta tmp2			; nearFloorY clamped
	lda tmp2
	cmp tmp1
	bcc .ppd
	beq .ppd
	ldy tmp1
	sty fill_y0
	ldy tmp2
	sty fill_y1
	ldx next_id
	lda SEC_TYPE,x
	cmp #ELEVATOR_LOWER_TYPE
	beq .pp_lfcol
	cmp #ELEVATOR_RAISE_TYPE
	beq .pp_lfcol
	lda wall_col
	jmp .pp_lfill
.pp_lfcol
	lda SEC_FCOL,x
.pp_lfill
	jsr fill_span
	; Open window becomes [ytop, farFloorY). Never yank ytop to nearFloorY —
	; that closed stair portals early when the step straddled HORIZON.
	lda tmp1
	cmp ybot
	bcs .ppd
	sta ybot
	rts

; ---------------------------------------------------------------------------
; .pp_draw_u — fill upper ledge [nearCeilY, farCeilY); advance ytop
; ---------------------------------------------------------------------------
.pp_draw_u
	lda span_a
	jsr clamp_span
	sta tmp1			; nearCeilY
	lda tmp4
	jsr clamp_span
	sta tmp2			; farCeilY
	lda tmp2
	cmp tmp1
	bcc .pdu_r
	beq .pdu_r
	ldy tmp1
	sty fill_y0
	ldy tmp2
	sty fill_y1
	ldx next_id
	lda SEC_TYPE,x
	cmp #DOOR_TYPE
	bne .pdu_grey
	lda SEC_CCOL,x
	jmp .pdu_fill
.pdu_grey
	lda wall_col
.pdu_fill
	jsr fill_span
	lda tmp2
	cmp ytop
	bcc .pdu_r
	sta ytop			; push open window down past upper ledge
.pdu_r
	rts

; ---------------------------------------------------------------------------
; wall_colour_ns_ew — side 0 → WALL_NS, side 1 → WALL_EW → wall_col
; ---------------------------------------------------------------------------
wall_colour_ns_ew
	lda side
	bne .ew
	lda #WALL_NS
	sta wall_col
	rts
.ew
	lda #WALL_EW
	sta wall_col
	rts
