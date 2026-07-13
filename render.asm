!zone render

; TheKeep secant-DDA + texstep summing for portal heights.
; Bugfixes vs earlier Keep port:
;  - lookang−64 maps editor north onto Keep axes
;  - target = |Δh|, texstep = wallz>>2 (×4/×8 targets made full-screen flats)
;  - overflow ends ray on both axes
;  - fill_col_span must not clobber span edge temps (util fill_row)

WALL_NS = 8
WALL_EW = 9
HORIZON = 12
; target = |Δh|; texstep = wallz>>2 (Keep). mid-product wallz ≈ tiles·fish
; screen rows ≈ Δh·4/tiles ≈ editor Δh·PROJ/(tiles·8)
TEXSTEP_SHIFT = 2

render
	lda #0
	sta col
.col_loop
	jsr cast_column
	inc col
	lda col
	cmp #40
	bcc .col_loop
	rts

; ------------------------------------------------------------------
cast_column
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
	jsr map_sector_id
	sta cur_id

; ----- Keep innerloop -----
.inner
	lda ytop
	cmp ybot
	bcc .igo
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
	clc
	lda mapx
	adc xstep
	sta mapx
	lda #0
	sta side
	jsr map_sector_id
	sta next_id
	jsr on_cell
	bcs .done
	clc
	lda sdx_l
	adc ddx_l
	sta sdx_l
	lda sdx_h
	adc ddx_h
	sta sdx_h
	bcc .inner
.done
	rts

.adv_y
	clc
	lda mapy
	adc ystep
	sta mapy
	lda #1
	sta side
	jsr map_sector_id
	sta next_id
	jsr on_cell
	bcs .done
	clc
	lda sdy_l
	adc ddy_l
	sta sdy_l
	lda sdy_h
	adc ddy_h
	sta sdy_h
	bcc .inner
	rts

; C=1 stop column
on_cell
	lda next_id
	cmp cur_id
	bne .chg
	clc
	rts
.chg
	jsr calc_wallz
	lda cur_id
	beq .void_enter
	jsr load_near_sector
	jsr paint_near
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
	sec
	rts
.portal
	jsr paint_portal
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

; Count screen rows by summing texstep until covers |Δh| world units
; (Keep yloop: rows = how far tex advances over pixels; no divide).
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
	beq .py_zero			; height == eye → horizon
	sta tmp3			; target = |Δh| (matches mid-product wallz scale)
	lda #0
	sta acc_l
	sta acc_h
	tax
.py_loop
	cpx #40
	bcs .py_have
	clc
	lda acc_l
	adc texstep_l
	sta acc_l
	lda acc_h
	adc texstep_h
	sta acc_h
	inx
	cmp tmp3
	bcc .py_loop
.py_have
	stx tmp5
	lda tmp2
	bne .pyn
	sec
	lda #HORIZON
	sbc tmp5
	bcs .pyh
	lda #0
.pyh
	jmp .pyc
.pyn
	clc
	lda #HORIZON
	adc tmp5
	bcc .pyc
	lda #25
.pyc
	cmp #26
	bcc .pys
	lda #25
.pys
	sta py_row
	rts
.py_zero
	lda #HORIZON
	sta py_row
	rts

; ------------------------------------------------------------------
paint_near
	lda near_ceil
	jsr project_y
	sta span_a
	lda near_floor
	jsr project_y
	sta span_b

	lda span_a
	jsr clamp_span
	sta tmp1
	cmp ytop
	beq .nc
	bcc .nc
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
	bcs .pnd
	lda span_b
	jsr clamp_span
	sta tmp1
	cmp ybot
	bcs .pnd
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
	lda next_id
	jsr sector_type
	cmp #DOOR_TYPE
	bne .pn
	lda next_id
	jsr sector_ccol
	sta wall_col
	jmp .pg
.pn
	jsr wall_colour_ns_ew
.pg
	lda next_id
	jsr sector_floor
	sta far_floor
	lda next_id
	jsr sector_ceil
	sta far_ceil

	lda near_ceil
	jsr project_y
	sta span_a
	lda near_floor
	jsr project_y
	sta span_b
	lda far_ceil
	jsr project_y
	sta tmp4
	lda far_floor
	jsr project_y
	sta tmp5

	lda far_ceil
	cmp near_ceil
	bcs .pu
	lda span_a
	jsr clamp_span
	sta tmp1
	lda tmp4
	jsr clamp_span
	sta tmp2
	lda tmp2
	cmp tmp1
	bcc .pu
	beq .pu
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
	bcc .pu
	sta ytop
.pu
	lda ytop
	cmp ybot
	bcs .ppd
	lda far_floor
	cmp near_floor
	bcc .ppd
	beq .ppd
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
.ppd
	rts

load_near_sector
	lda cur_id
	jsr sector_floor
	sta near_floor
	lda cur_id
	jsr sector_ceil
	sta near_ceil
	lda cur_id
	jsr sector_fcol
	sta near_fcol
	lda cur_id
	jsr sector_ccol
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
