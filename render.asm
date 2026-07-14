!zone render

; TheKeep secant-DDA + texstep summing for portal heights.
; Bugfixes vs earlier Keep port:
;  - lookang−64 maps editor north onto Keep axes
;  - target = |Δh|, texstep = wallz>>2 (×4/×8 targets made full-screen flats)
;  - overflow ends ray on both axes
;  - paints into transposed FRAMEBUFFER; blit_fb_to_color copies to $D800

WALL_NS = 8
WALL_EW = 9
HORIZON = 12
; target = |Δh|; texstep = wallz>>2 (Keep). mid-product wallz ≈ tiles·fish
; screen rows ≈ Δh·4/tiles ≈ editor Δh·PROJ/(tiles·8)
TEXSTEP_SHIFT = 2

render
	lda #0
	sta dda_peak
!if PROFILE = 1 {
	jsr prof_reset_frame
}
	lda #0
	sta col
.col_loop
	jsr set_col_base
	jsr cast_column
	inc col
	lda col
	cmp #40
	bcc .col_loop
	jsr blit_fb_to_color
	jsr prof_frame_sample
	jsr prof_print
	jmp print_dda_peak

; ------------------------------------------------------------------
cast_column
!if PROFILE = 1 {
	jsr prof_snap
}
	; Keep angle = column + look − 64 (editor sin/−cos north ↔ Keep)
	ldy col
	lda angtab,y
	clc
	adc playera
	sec
	sbc #64
	sta angle

	and #127
	cmp #63
	bcc .dx_ok
	eor #127
.dx_ok
	sta dxindex

	lda angle
	clc
	adc #64
	sta tmp0			; angle+64 for X step sign
	and #127
	cmp #63
	bcc .dy_ok
	eor #127
.dy_ok
	sta dyindex

	ldy dxindex
	lda fixsecl,y
	sta ddx_l
	lda fixsech,y
	sta ddx_h
	ldy dyindex
	lda fixsecl,y
	sta ddy_l
	lda fixsech,y
	sta ddy_h

	; world → tile frac 0..255 and mapx/mapy
	lda playerx
	sta tmp1
	lda playerx_h
	lsr
	ror tmp1
	lsr
	ror tmp1
	lsr
	ror tmp1
	lda tmp1
	sta fracx
	lda playery
	sta tmp1
	lda playery_h
	lsr
	ror tmp1
	lsr
	ror tmp1
	lsr
	ror tmp1
	lda tmp1
	sta fracy
	lda playerx_h
	lsr
	lsr
	lsr
	sta mapx
	lda playery_h
	lsr
	lsr
	lsr
	sta mapy

	; sdx = frac_to_line * ddx (Keep: eor #$ff for +X)
	lda tmp0
	bmi .xn
	lda #1
	sta xstep
	lda fracx
	eor #$ff
	jmp .xm
.xn
	lda #$ff
	sta xstep
	lda fracx
.xm
	pha
	lda ddx_l
	sta aux_l
	lda ddx_h
	sta aux_h
	pla
	jsr mul_16x8
	sta sdx_l
	stx sdx_h

	lda angle
	bmi .yn
	lda #1
	sta ystep
	lda fracy
	eor #$ff
	jmp .ym
.yn
	lda #$ff
	sta ystep
	lda fracy
.ym
	pha
	lda ddy_l
	sta aux_l
	lda ddy_h
	sta aux_h
	pla
	jsr mul_16x8
	sta sdy_l
	stx sdy_h

	lda #0
	sta ytop
	lda #25
	sta ybot
	lda #0
	sta dda_steps
	jsr map_sector_id
	sta cur_id
	; Keep tile pointer at current cell (map_sector_id left ptr_*)
	lda ptr_l
	sta tile_l
	lda ptr_h
	sta tile_h
!if PROFILE = 1 {
	ldy #PROF_SETUP
	jsr prof_add_bucket
}

; ----- Keep-style innerloop: tile ptr + skip on_cell when same id -----
.inner
	lda ytop
	cmp ybot
	bcc .igo
!if PROFILE = 1 {
	ldy #PROF_DDA
	jsr prof_add_bucket
}
	rts
.igo
	lda sdx_h
	cmp sdy_h
	bcc .adv_x
	bne .adv_y
	lda sdx_l
	cmp sdy_l
	bcs .adv_y

.adv_x
	lda #0
	sta side
	ldx #0
	lda xstep
	bpl .axp
	dex				; X = $ff sign-extend
.axp
	clc
	adc mapx
	sta mapx
	cmp #MAP_SIZE
	bcs .ax_oob
	; tile += xstep (sign-extended)
	clc
	lda tile_l
	adc xstep
	sta tile_l
	txa
	adc tile_h
	sta tile_h
	ldy #0
	lda (tile_l),y
	sta next_id
	cmp cur_id
	bne .ax_cell
	; empty same-sector step — Keep-cheap
	jsr dda_bump
	bcs .ax_done
	jsr .add_sdx
	bcs .ax_done
	jmp .inner
.ax_done
	jmp .done
.ax_oob
	lda #0
	sta next_id
.ax_cell
!if PROFILE = 1 {
	ldy #PROF_DDA
	jsr prof_add_bucket
}
	jsr on_cell
	bcs .ax_done
	jsr dda_bump
	bcs .ax_done
	jsr .add_sdx
	bcs .ax_done
	jmp .inner

.adv_y
	lda #1
	sta side
	clc
	lda mapy
	adc ystep
	sta mapy
	cmp #MAP_SIZE
	bcs .ay_oob
	lda ystep
	bmi .ay_n
	clc
	lda tile_l
	adc #MAP_SIZE
	sta tile_l
	lda tile_h
	adc #0
	sta tile_h
	jmp .ay_rd
.ay_n
	sec
	lda tile_l
	sbc #MAP_SIZE
	sta tile_l
	lda tile_h
	sbc #0
	sta tile_h
.ay_rd
	ldy #0
	lda (tile_l),y
	sta next_id
	cmp cur_id
	bne .ay_cell
	jsr dda_bump
	bcs .ay_done
	jsr .add_sdy
	bcs .ay_done
	jmp .inner
.ay_done
	jmp .done
.ay_oob
	lda #0
	sta next_id
.ay_cell
!if PROFILE = 1 {
	ldy #PROF_DDA
	jsr prof_add_bucket
}
	jsr on_cell
	bcs .ay_done
	jsr dda_bump
	bcs .ay_done
	jsr .add_sdy
	bcs .ay_done
	jmp .inner

.add_sdx
	clc
	lda sdx_l
	adc ddx_l
	sta sdx_l
	lda sdx_h
	adc ddx_h
	sta sdx_h
	rts

.add_sdy
	clc
	lda sdy_l
	adc ddy_l
	sta sdy_l
	lda sdy_h
	adc ddy_h
	sta sdy_h
	rts

.done
!if PROFILE = 1 {
	ldy #PROF_DDA
	jsr prof_add_bucket
}
	jmp fill_open_remainder

; Inc step count; update peak; C=1 if >= MAX_DDA
dda_bump
	inc dda_steps
	lda dda_steps
	cmp dda_peak
	bcc .dc_chk
	sta dda_peak
.dc_chk
	cmp #MAX_DDA
	rts

; If clip still open after ray stop: fill with near floor colour (no project —
; wallz/texstep may be stale when stopping on overflow/cap).
fill_open_remainder
	lda ytop
	cmp ybot
	bcc .for_go
	rts
.for_go
	lda cur_id
	beq .for_done
	tax
	lda SEC_FCOL,x
	tax
	jsr fill_col_span
.for_done
	rts

; Two inverse digits of dda_peak at $0400/$0401; leave $0402 blank before stats
print_dda_peak
	lda dda_peak
	ldx #0
.pdp_tens
	cmp #10
	bcc .pdp_ones
	sbc #10
	inx
	bne .pdp_tens
.pdp_ones
	ora #$b0			; inverse screen codes for '0'..'9'
	sta $0401
	txa
	ora #$b0
	sta $0400
	lda #1				; white
	sta $d800
	sta $d801
	lda #$20			; gap before F/S/D/N/L/P stats
	sta $0402
	lda #1
	sta $d802
	rts

; C=1 stop column
; PROFILE: F=frame, W=wallz, N=near fills, L=portal/solid, P=project_y
on_cell
	lda next_id
	cmp cur_id
	bne .chg
	clc
	rts
.chg
	jsr calc_wallz
!if PROFILE = 1 {
	ldy #PROF_WALLZ
	jsr prof_add_bucket
}
	lda cur_id
	beq .void_enter
	jsr load_near_sector
	jsr paint_near
!if PROFILE = 1 {
	ldy #PROF_NEAR
	jsr prof_add_bucket
}
	lda ytop
	cmp ybot
	bcc .edge
	sec
	rts
.void_enter
	lda next_id
	beq .stop
	sta cur_id
	clc
	rts
.edge
	lda next_id
	bne .portal
	jsr wall_colour_ns_ew
	ldx wall_col
	jsr fill_col_span
	lda ybot			; close clip — prevent fill_open_remainder wiping the wall
	sta ytop
!if PROFILE = 1 {
	ldy #PROF_LEDGE
	jsr prof_add_bucket
}
	sec
	rts
.portal
	jsr paint_portal
!if PROFILE = 1 {
	ldy #PROF_LEDGE
	jsr prof_add_bucket
}
	lda ytop
	cmp ybot
	bcc .cont
	sec
	rts
.cont
	lda next_id
	sta cur_id
	clc
	rts
.stop
	; void→void: nothing to draw; close clip if somehow open
	lda ybot
	sta ytop
	sec
	rts

; wallz = depth*fish; texstep = wallz >> TEXSTEP_SHIFT
calc_wallz
	lda side
	bne .czy
	lda sdx_l
	ldx sdx_h
	jmp .czm
.czy
	lda sdy_l
	ldx sdy_h
.czm
	sta aux_l
	stx aux_h
	ldy col
	lda fishtab,y
	jsr mul_16x8
	sta wallz_l
	stx wallz_h
	lda wallz_h
	ora wallz_l
	bne .czn
	lda #1
	sta wallz_l
.czn
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
	lda #1
	sta texstep_l
.czok
	rts

; Count screen rows until tex covers |Δh| (Keep yloop).
; Walk from HORIZON: ceil DEX / floor INX each add; stop at coverage or
; screen edge (0 / 25). Lo path: A=acc_l, Y=|Δh| countdown on carry.
project_y
	sec
	sbc eyeheight
	sta tmp1
	lda #0
	sta tmp2
	lda tmp1
	bpl .pyp
	eor #$ff
	clc
	adc #1
	sta tmp1
	lda #1
	sta tmp2
.pyp
	lda tmp1
	bne .py_nz
	jmp .py_zero			; height == eye → horizon
.py_nz
	sta tmp3			; target = |Δh|

	lda texstep_h
	cmp tmp3
	bcc .py_sum
	; n=1: one screen step from horizon
	ldx #HORIZON
	lda tmp2
	bne .py_n1_dn
	dex
	jmp .py_have_row
.py_n1_dn
	inx
	jmp .py_have_row

.py_sum
	lda tmp2
	bne .py_dn				; below eye → floor
	; ----- ceiling: walk X down from HORIZON -----
	lda texstep_h
	beq .py_lo_up
	lda #0
	sta acc_l
	sta acc_h
	ldx #HORIZON
.py_hi_up
	cpx #0
	beq .py_have_row
	dex
	clc
	lda acc_l
	adc texstep_l
	sta acc_l
	lda acc_h
	adc texstep_h
	sta acc_h
	cmp tmp3
	bcc .py_hi_up
	bcs .py_have_row

.py_lo_up
	ldx #HORIZON
	ldy tmp3
	lda #0					; acc_l
.py_lo_up_lp
	cpx #0
	beq .py_have_row
	dex
	clc
	adc texstep_l
	bcc .py_lo_up_lp
	dey
	bne .py_lo_up_lp
	beq .py_have_row

	; ----- floor: walk X up from HORIZON -----
.py_dn
	lda texstep_h
	beq .py_lo_dn
	lda #0
	sta acc_l
	sta acc_h
	ldx #HORIZON
.py_hi_dn
	cpx #25
	beq .py_have_row
	inx
	clc
	lda acc_l
	adc texstep_l
	sta acc_l
	lda acc_h
	adc texstep_h
	sta acc_h
	cmp tmp3
	bcc .py_hi_dn
	bcs .py_have_row

.py_lo_dn
	ldx #HORIZON
	ldy tmp3
	lda #0
.py_lo_dn_lp
	cpx #25
	beq .py_have_row
	inx
	clc
	adc texstep_l
	bcc .py_lo_dn_lp
	dey
	bne .py_lo_dn_lp
	; fall through

.py_have_row
	stx py_row
	rts

.py_zero
	lda #HORIZON
	sta py_row
	rts

; ------------------------------------------------------------------
; Ceil first; only project floor if clip still open (saves project_y when
; near ceil eats the column — on_cell then skips paint_portal).
paint_near
	lda ytop
	cmp ybot
	bcs .pnd
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
	cmp ytop
	beq .nc
	bcc .nc
	cmp ybot
	bcs .nc
	lda ybot
	pha
	lda tmp1
	sta ybot
	ldx near_ccol
	jsr fill_col_span
	pla
	sta ybot
	lda tmp1
	sta ytop
.nc
	lda ytop
	cmp ybot
	bcs .pnd				; clip closed — skip floor project
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
	jsr clamp_span
	sta tmp1
	cmp ybot
	bcs .pnd
	cmp ytop
	bcc .pnd
	beq .pnd
	lda ytop
	pha
	lda tmp1
	sta ytop
	ldx near_fcol
	jsr fill_col_span
	pla
	sta ytop
	lda tmp1
	sta ybot
.pnd
	rts

paint_portal
	ldx next_id
	lda SEC_TYPE,x
	cmp #DOOR_TYPE
	bne .pn
	lda SEC_CCOL,x
	sta wall_col
	jmp .pg
.pn
	jsr wall_colour_ns_ew
.pg
	ldx next_id
	lda SEC_FLOOR,x
	sta far_floor
	lda SEC_CEIL,x
	sta far_ceil

	; No ledge if far contained in near heights — span_a/b from paint_near
	cmp near_ceil
	bcc .pp_upper			; far_ceil < near_ceil
	lda far_floor
	cmp near_floor
	bcc .ppd
	beq .ppd
	jmp .pp_lower			; only lower ledge

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
	sta tmp4
	lda far_floor
	cmp near_floor
	bcc .pp_do_u
	beq .pp_do_u
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
.pp_do_l
	lda ytop
	cmp ybot
	bcs .ppd
	lda tmp5
	jsr clamp_span
	sta tmp1
	lda span_b
	jsr clamp_span
	sta tmp2
	lda tmp2
	cmp tmp1
	bcc .ppd
	beq .ppd
	lda ytop
	pha
	lda ybot
	pha
	lda tmp1
	sta ytop
	lda tmp2
	sta ybot
	ldx wall_col
	jsr fill_col_span
	pla
	sta ybot
	pla
	sta ytop
	lda tmp1
	cmp ybot
	bcs .ppd
	sta ybot
	rts

; Draw upper ledge using span_a / tmp4; advances ytop. Clobbers tmp1/tmp2.
.pp_draw_u
	lda span_a
	jsr clamp_span
	sta tmp1
	lda tmp4
	jsr clamp_span
	sta tmp2
	lda tmp2
	cmp tmp1
	bcc .pdu_r
	beq .pdu_r
	lda ytop
	pha
	lda ybot
	pha
	lda tmp1
	sta ytop
	lda tmp2
	sta ybot
	ldx wall_col
	jsr fill_col_span
	pla
	sta ybot
	pla
	sta ytop
	lda tmp2
	cmp ytop
	bcc .pdu_r
	sta ytop
.pdu_r
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
