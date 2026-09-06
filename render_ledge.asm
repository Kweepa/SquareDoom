!zone render_ledge

; ============================================================================
; render_ledge.asm — PROFILE L (portal ledges + solid wall colour helper)
; ============================================================================
; After paint_near, draw upper/lower walls where far heights step relative
; to near. Contained far (far_ceil >= near_ceil and far_floor <= near_floor)
; → immediate rts. Open portal after a step-up is [ytop, farFloorY) — always
; set ybot from far floor even when that Y is above HORIZON.
;
; Door sectors: upper ledge left/right 1/8ths = far ceil colour, middle =
; far floor colour (secret doors can match surrounding flats).
; Elevator sectors: lower ledge (riser) uses far floor colour.
; Else N/S vs E/W grey.
; ledge_col_flags[action]: bit0 = door upper (CCOL/FCOL by U), bit1 = lower→FCOL
; ---------------------------------------------------------------------------

ledge_col_flags
	!byte 0			; 0 none
	!byte 0			; 1 window
	!byte 1			; 2 open_door 5s
	!byte 1			; 3 open_door forever
	!byte 1			; 4 open_door 30s
	!byte 2			; 5 lower_floor 5s
	!byte 2			; 6 raise_floor
	!byte 0			; 7 raise_stairs
	!byte 0			; 8 continue_stairs
	!byte 0			; 9 end_level
	!byte 2			; 10 lower_floor forever
	!byte 1			; 11 open_door 10s
	!byte 2			; 12 lower_floor 15s
	!byte 0			; 13 damage_floor
	!byte 0			; 14 flash_lights
	!byte 2			; 15 open_monster_closet
	!fill 16, 0

; ---------------------------------------------------------------------------
; paint_portal — ledges for next_id vs near_*; may advance ytop/ybot
;
; Uses span_a/span_b from paint_near (or refresh_near_spans) as near ceil/
; floor screen Y. tmp4 = farCeilY; tmp5 = farFloorY when projected.
; ---------------------------------------------------------------------------
paint_portal
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
	bne .pp_lower			; Z=0 after untaken beq; always taken

.pp_upper
	; Only pay NS/EW colour when a ledge will paint
	jsr wall_colour_ns_ew
!if PROFILE = 1 {
	ldy #PROF_LEDGE
	jsr prof_add_bucket
}
	lda far_floor
	cmp near_floor
	bcc .pp_upper_only
	beq .pp_upper_only
	; Both ledges at this edge — pair-project far ceil + floor
	lda far_ceil
	ldy far_floor
	jsr project_y_pair
	stx tmp4			; farCeilY
	sta tmp5			; farFloorY
!if DBG_PORTAL = 1 {
	sta dbg_far_y
}
!if PROFILE = 1 {
	jsr prof_add_py_pair
}
	jsr .pp_draw_u
	jmp .pp_do_l

.pp_upper_only
	lda far_ceil
	jsr project_y
!if PROFILE = 1 {
	jsr prof_add_py
	lda py_row
}
	sta tmp4			; farCeilY
	jmp .pp_draw_u
.ppd
	rts

.pp_lower
	jsr wall_colour_ns_ew
!if PROFILE = 1 {
	ldy #PROF_LEDGE
	jsr prof_add_bucket
}
	lda far_floor
	jsr project_y
!if PROFILE = 1 {
	jsr prof_add_py
	lda py_row
}
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
	cmp ytop
	bcs .pp_l_f0
	lda ytop
	bcc .pp_l_f0c			; C=0 after untaken bcs
.pp_l_f0
	cmp ybot
	bcc .pp_l_f0c
	lda ybot
.pp_l_f0c
	sta fill_y0			; farFloorY clamped
	lda span_b
	cmp ytop
	bcs .pp_l_f1
	lda ytop
	bcc .pp_l_f1c
.pp_l_f1
	cmp ybot
	bcc .pp_l_f1c
	lda ybot
.pp_l_f1c
	sta fill_y1			; nearFloorY clamped
	cmp fill_y0
	bcc .ppd
	beq .ppd
	ldx next_id
	lda SEC_TYPE,x
	and #ACT_MASK
	tay
	lda ledge_col_flags,y
	and #2
	beq .pp_lwall
	lda SEC_FCOL,x
	jmp .pp_lfill
.pp_lwall
	lda wall_col
.pp_lfill
	jsr fill_span
	; Open window becomes [ytop, farFloorY). Never yank ytop to nearFloorY —
	; that closed stair portals early when the step straddled HORIZON.
	lda fill_y0
	cmp ybot
	bcs .ppd
	sta ybot
	rts

; ---------------------------------------------------------------------------
; .pp_draw_u — fill upper ledge [nearCeilY, farCeilY); advance ytop
; ---------------------------------------------------------------------------
.pp_draw_u
	lda span_a
	cmp ytop
	bcs .pdu_n0
	lda ytop
	bcc .pdu_n0c
.pdu_n0
	cmp ybot
	bcc .pdu_n0c
	lda ybot
.pdu_n0c
	sta fill_y0			; nearCeilY clamped
	lda tmp4
	cmp ytop
	bcs .pdu_f0
	lda ytop
	bcc .pdu_f0c
.pdu_f0
	cmp ybot
	bcc .pdu_f0c
	lda ybot
.pdu_f0c
	sta fill_y1			; farCeilY clamped
	cmp fill_y0
	bcc .pdu_r
	beq .pdu_r
	ldx next_id
	lda SEC_TYPE,x
	and #ACT_MASK
	tay
	lda ledge_col_flags,y
	lsr				; C = door upper (CCOL sides / FCOL mid)
	lda wall_col
	bcc .pdu_fill
	; Door: CCOL on outer 1/8ths, FCOL on middle 6/8ths.
	; calc_wall_u clobbers tmp0..tmp3 / X — keep next_id on stack
	; (tmp5 may hold farFloorY for a following lower ledge).
	txa
	pha
	jsr calc_wall_u
	pla
	tax
	lda wall_u
	cmp #$20
	bcc .pdu_ccol
	cmp #$e0
	bcc .pdu_fcol
.pdu_ccol
	lda SEC_CCOL,x
	jmp .pdu_fill
.pdu_fcol
	lda SEC_FCOL,x
.pdu_fill
	jsr fill_span
	lda fill_y1
	cmp ytop
	bcc .pdu_r
	sta ytop			; push open window down past upper ledge
.pdu_r
	rts

; ---------------------------------------------------------------------------
; wall_colour_ns_ew — side 0 → WALL_NS, side 1 → WALL_EW → wall_col
; Requires WALL_EW = WALL_NS + 1 (side is always 0/1). Clears C itself
; (paint_portal .pp_lower arrives with C=1 from the floor compare).
; ---------------------------------------------------------------------------
wall_colour_ns_ew
	lda side
	clc
	adc #WALL_NS
	sta wall_col
	rts
