!zone render_switch

; ============================================================================
; render_switch.asm — wall-face 16×16 switch texture on solid walls
; ============================================================================
; Bindings are cooked into level_data (level_switch_n/sec/dir): switch sector
; id + NESW face of the solid that faces that sector. Editor/cook picks:
;   1 solid  → that wall
;   3 solids → wall opposite the gap (alcove back wall)
;   2 or 4   → first solid in N,E,S,W order (avoid 2 in data)
;
; Solid-wall paint: neighbour sector on the hit face + face → table lookup.
; sample wall_switch_tex[u*16+v] with V=0 at near_floor, V=15 at near_ceil.
; $ff = clear → wall_col. Pattern = fill_pat (distance dither).
;
; Hit face from side+step: N=side1∧ystep>0, E=side0∧xstep<0,
; S=side1∧ystep<0, W=side0∧xstep>0.
; ---------------------------------------------------------------------------

; NESW Δ from solid → switch cell (indexed by solid face)
sw_nb_dx
	!byte 0, 1, 0, $ff			; N E S W
sw_nb_dy
	!byte $ff, 0, 1, 0

; ---------------------------------------------------------------------------
; switch_face_match — C=0 if solid at mapx/mapy + hit face is a switch face
; ---------------------------------------------------------------------------
switch_face_match
	lda side
	bne .sfm_y
	lda xstep
	bmi .sfm_face_e
	lda #3				; W
	bne .sfm_got
.sfm_face_e
	lda #1				; E
	bne .sfm_got
.sfm_y
	lda ystep
	bmi .sfm_face_s
	lda #0				; N
	beq .sfm_got
.sfm_face_s
	lda #2				; S
.sfm_got
	sta tmp4
	; Neighbour on that face = switch sector cell
	tax
	lda mapx
	clc
	adc sw_nb_dx,x
	sta tmp0
	cmp #MAP_SIZE
	bcs .sfm_no
	lda mapy
	clc
	adc sw_nb_dy,x
	sta tmp1
	cmp #MAP_SIZE
	bcs .sfm_no
	; sector id at (tmp0,tmp1) without clobbering mapx/mapy
	ldy tmp1
	lda maprowlo,y
	clc
	adc tmp0
	sta ptr_l
	lda maprowhi,y
	sta ptr_h
	ldy #0
	lda (ptr_l),y
	beq .sfm_no
	sta tmp3
	; fall through

; ---------------------------------------------------------------------------
; switch_face_listed — C=0 if (tmp3=switch sector, tmp4=dir) is cooked
; ---------------------------------------------------------------------------
switch_face_listed
	ldx SWITCH_FACE_N
	beq .sfm_no
	dex
.sfm_lp
	lda SWITCH_FACE_SEC,x
	cmp tmp3
	bne .sfm_nx
	lda SWITCH_FACE_DIR,x
	cmp tmp4
	bne .sfm_nx
	clc
	rts
.sfm_nx
	dex
	bpl .sfm_lp
.sfm_no
	sec
	rts

; ---------------------------------------------------------------------------
; paint_switch_col — textured solid wall into [ytop, ybot)
; Entry: wall_col / fill_pat / near_floor / near_ceil / texstep set;
;        col_base from set_col_base
;
; Close (texstep_h=0): vstep = 16·texstep/dh, seed from unclamped floor row
;   wallBot = HORIZON + (eye−floor)·256/texstep so clipped columns show the
;   matching slice of the 16-tall face. Far (texstep_h≠0): fall back to
;   mapping across the visible strip (wall fits on screen).
; ---------------------------------------------------------------------------
paint_switch_col
	lda ytop
	cmp ybot
	bcc .psc_go
	rts
.psc_go
	jsr calc_wall_u
	lda wall_u
	lsr
	lsr
	lsr
	lsr
	sta tmp0				; texel U 0..15

	lda near_ceil
	sec
	sbc near_floor
	sta tmp4				; dh (world)
	beq .psc_to_vis
	lda texstep_h
	bne .psc_to_vis

	; vstep_88 = 16·texstep/dh = (texstep_l · recip[dh]) >> 12
	; (t·recip)>>8 ≈ t·256/dh, then >>4 → t·16/dh. texstep_h=0 here.
	; mul_8x8: Y×A → X=lo A=hi (do not use mul_16x8's A=lo X=hi here).
	ldx tmp4				; dh
	ldy texstep_l
	lda recip_lo,x
	jsr mul_8x8			; A=hi(t*rl) = (t*rl)>>8
	sta tmp1
	ldx tmp4
	ldy texstep_l
	lda recip_hi,x
	jsr mul_8x8			; A:X = t*rh
	tay					; hi(t*rh)
	txa
	clc
	adc tmp1				; (t*rl)>>8 + lo(t*rh)
	sta wish_y_l
	tya
	adc #0
	sta wish_y_h			; (t·recip)>>8
	ldx #4
.psc_vsr
	lsr wish_y_h
	ror wish_y_l
	dex
	bne .psc_vsr			; >>4 → vstep_88
	lda wish_y_l
	ora wish_y_h
	bne .psc_vs_ok
	lda #1				; at least 1/256 texel per row
	sta wish_y_l
.psc_vs_ok

	; offset = (eye − near_floor) · 256 / texstep  (floor at/below eye)
	lda eyeheight
	sec
	sbc near_floor
	bcs .psc_d_ok
.psc_to_vis
	jmp .psc_vis			; dh=0 / far / floor above eye
.psc_d_ok
	sta tmp2				; d
	beq .psc_off0
	ldx texstep_l
	ldy tmp2
	lda recip_lo,x
	jsr mul_8x8			; A=hi(d*rl)
	sta tmp1
	ldx texstep_l
	ldy tmp2
	lda recip_hi,x
	jsr mul_8x8			; A:X = d*rh
	tay
	txa
	clc
	adc tmp1
	sta tmp1				; offset_l
	tya
	adc #0
	sta tmp2				; offset_h
	jmp .psc_wallbot
.psc_off0
	lda #0
	sta tmp1
	sta tmp2
.psc_wallbot
	; wallBot16 = HORIZON + offset; seed = wallBot − ybot
	clc
	lda tmp1
	adc #HORIZON
	sta aux_l
	lda tmp2
	adc #0
	sta aux_h
	sec
	lda aux_l
	sbc ybot
	sta aux_l
	lda aux_h
	sbc #0
	sta aux_h
	bpl .psc_seed_mul
.psc_seed0
	lda #0
	sta acc_l
	sta acc_h
	jmp .psc_rows
.psc_seed_mul
	; acc_88 = seed16 * vstep (prefer vstep_h=0 when close)
	lda wish_y_h
	bne .psc_seed_w
	ldy wish_y_l
	lda aux_l
	jsr mul_8x8
	stx acc_l
	sta acc_h
	ldy wish_y_l
	lda aux_h
	jsr mul_8x8			; X=lo A=hi of seed_h*vstep_l
	tay
	txa
	clc
	adc acc_h
	sta acc_h
	tya
	adc #0
	beq .psc_rows
	lda #15				; past top of texture
	sta acc_h
	lda #$ff
	sta acc_l
	jmp .psc_rows
.psc_seed_w
	; seed usually small when vstep_h≠0; use lo seed × 16-bit vstep
	lda aux_h
	bne .psc_seed0			; huge seed + fat step → start at V=0; loop clamps
	ldy aux_l
	lda wish_y_l
	jsr mul_8x8
	stx acc_l
	sta tmp1
	ldy aux_l
	lda wish_y_h
	jsr mul_8x8
	clc
	txa
	adc tmp1
	sta acc_h
	bcc .psc_rows
	lda #15
	sta acc_h
	lda #$ff
	sta acc_l
	jmp .psc_rows

; Far / fallback: map V across visible [ytop,ybot)
.psc_vis
	lda ybot
	sec
	sbc ytop
	beq .psc_r
	tax
	lda recip_lo,x
	sta tmp2
	lda recip_hi,x
	lsr
	ror tmp2
	lsr
	ror tmp2
	lsr
	ror tmp2
	lsr
	ror tmp2
	sta wish_y_h
	lda tmp2
	sta wish_y_l
	lda #0
	sta acc_l
	sta acc_h

.psc_rows
	ldy ybot
.psc_row
	dey
	sty tmp3				; screen row
	lda acc_h
	cmp #16
	bcc .psc_vok
	lda #15
.psc_vok
	sta tmp2				; V
	lda tmp0
	asl
	asl
	asl
	asl					; U*16
	clc
	adc tmp2
	tay
	lda wall_switch_tex,y
	cmp #$ff
	bne .psc_pix
	lda wall_col
.psc_pix
	ldy tmp3
	sta (col_base_l),y
	lda fill_pat
	sta (pat_base_l),y
	clc
	lda acc_l
	adc wish_y_l
	sta acc_l
	lda acc_h
	adc wish_y_h
	sta acc_h
	cpy ytop
	bne .psc_row
.psc_r
	rts
