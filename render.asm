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
!if DBG_PORTAL = 1 {
	sta dbg_n
	lda #255
	sta dbg_far_y
}
!if PROFILE = 1 {
	jsr prof_reset_frame
}
	jsr setup_player_tile
	lda playera
	cmp last_playera
	beq .rays_ok
	sta last_playera
	jsr rebuild_col_rays
.rays_ok
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
!if DBG_PORTAL = 1 {
	jsr dbg_portal_flush
}
	jmp print_dda_peak

; fracx/fracy/map start + first cell id/tile — once per frame (DDA mutates map*).
; World byte: map = world>>3, frac = (world&7)<<5.
setup_player_tile
	lda playerx_h
	tax
	lsr
	lsr
	lsr
	sta plr_mapx
	sta mapx
	txa
	and #7
	asl
	asl
	asl
	asl
	asl
	sta fracx
	eor #$ff
	sta fracx_inv
	lda playery_h
	tax
	lsr
	lsr
	lsr
	sta plr_mapy
	sta mapy
	txa
	and #7
	asl
	asl
	asl
	asl
	asl
	sta fracy
	eor #$ff
	sta fracy_inv
	jsr map_sector_id
	sta plr_id
	lda ptr_l
	sta plr_tile_l
	lda ptr_h
	sta plr_tile_h
	rts

; Fold A&127 → Keep secant index 0..63
.fold_sec
	and #127
	cmp #63
	bcc .fs_ok
	eor #127
.fs_ok
	rts

; Rebuild per-column ddx/ddy + steps when playera changes.
rebuild_col_rays
	lda #0
	sta col
.rcr_lp
	ldy col
	lda angtab,y
	clc
	adc playera
	sec
	sbc #64
	sta angle

	jsr .fold_sec
	sta dxindex
	tay
	lda fixsecl,y
	ldy col
	sta COL_DDX_L,y
	ldy dxindex
	lda fixsech,y
	ldy col
	sta COL_DDX_H,y

	lda angle
	clc
	adc #64
	sta tmp0
	jsr .fold_sec
	sta dyindex
	tay
	lda fixsecl,y
	ldy col
	sta COL_DDY_L,y
	ldy dyindex
	lda fixsech,y
	ldy col
	sta COL_DDY_H,y

	; xstep / Keep +X factor polarity from angle+64
	lda tmp0
	bmi .rcr_xn
	lda #1
	bne .rcr_xs
.rcr_xn
	lda #$ff
.rcr_xs
	ldy col
	sta COL_XSTEP,y

	lda angle
	bmi .rcr_yn
	lda #1
	bne .rcr_ys
.rcr_yn
	lda #$ff
.rcr_ys
	ldy col
	sta COL_YSTEP,y

	inc col
	lda col
	cmp #40
	bcc .rcr_lp
	rts

; ------------------------------------------------------------------
cast_column
!if PROFILE = 1 {
	jsr prof_snap
}
	; Restore player cell (previous column's DDA advanced map/tile)
	lda plr_mapx
	sta mapx
	lda plr_mapy
	sta mapy

	ldy col
	lda COL_DDX_L,y
	sta ddx_l
	lda COL_DDX_H,y
	sta ddx_h
	lda COL_DDY_L,y
	sta ddy_l
	lda COL_DDY_H,y
	sta ddy_h
	lda COL_XSTEP,y
	sta xstep
	lda COL_YSTEP,y
	sta ystep

	; sdx: +X (xstep=1) → fracx_inv; −X → fracx
	lda xstep
	bmi .xm_raw
	lda fracx_inv
	jsr calc_sdx
	jmp .ym_fac
.xm_raw
	lda fracx
	jsr calc_sdx
.ym_fac
	lda ystep
	bmi .ym_raw
	lda fracy_inv
	jsr calc_sdy
	jmp .cc_init
.ym_raw
	lda fracy
	jsr calc_sdy
.cc_init
	lda #0
	sta ytop
	sta dda_steps
	lda #25
	sta ybot
	lda plr_id
	sta cur_id
	lda plr_tile_l
	sta tile_l
	lda plr_tile_h
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
	jsr fill_col_span
.for_done
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
!if DBG_PORTAL = 1 {
	jsr dbg_portal_log
}
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
	lda wall_col
	jsr fill_col_span
	lda ybot			; close clip — prevent fill_open_remainder wiping the wall
	sta ytop
!if PROFILE = 1 {
	ldy #PROF_LEDGE
	jsr prof_add_bucket
}
!if DBG_PORTAL = 1 {
	jsr dbg_portal_log
}
	sec
	rts
.portal
	jsr paint_portal
!if PROFILE = 1 {
	ldy #PROF_LEDGE
	jsr prof_add_bucket
}
!if DBG_PORTAL = 1 {
	jsr dbg_portal_log
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

; ------------------------------------------------------------------
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
	lda ybot
	pha
	lda tmp1
	sta ybot
	lda near_ccol
	jsr fill_col_span
	pla
	sta ybot
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
	lda ytop
	pha
	lda tmp1
	sta ytop
	lda near_fcol
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
!if DBG_PORTAL = 1 {
	lda #255
	sta dbg_far_y
}

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
	lda wall_col
	jsr fill_col_span
	pla
	sta ybot
	pla
	sta ytop
	; Open continues as [ytop, farFloorY). Always advance ybot — even when
	; farFloorY sits above HORIZON (raised floor above eye). Raising ytop
	; to nearFloorY closes the stair portal early on straddling steps.
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
	lda wall_col
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
