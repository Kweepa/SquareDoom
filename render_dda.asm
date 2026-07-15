!zone render_dda

; ============================================================================
; render_dda.asm — PROFILE D (column DDA + incremental fish wz)
; ============================================================================
; Per column: load ray cache, mid(frac*dd) → sdx/sdy, mid(s*fish) → wz,
; then TheKeep-style march comparing sdx vs sdy. Same-id cells skip on_cell
; (cheap add only). Sector changes call on_cell in render.asm.
;
; Incremental wz: each .add_sdx/y also does wz += ddw (COL_DDWX/Y from setup).
; calc_wallz then only shifts — no fish mul at edges.
;
; PROFILE: S closes after preamble (.cc_init); D covers the inner march.
; ============================================================================

; ---------------------------------------------------------------------------
; cast_column — one screen column (col already set; col_base from set_col_base)
;
; Restores plr map/tile; builds sdx/sdy/wz; walks until clip closed, MAX_DDA,
; or s overflow. Ends with fill_open_remainder if [ytop,ybot) still open.
; ---------------------------------------------------------------------------
cast_column
!if PROFILE = 1 {
	jsr prof_snap
}
	; Restore player cell — previous columns left map*/tile* mutated
	lda plr_mapx
	sta mapx
	lda plr_mapy
	sta mapy

	; Load this column's ray constants from rebuild_col_rays cache
	ldy col
	lda COL_DDX_L,y
	sta ddx_l
	lda COL_DDX_H,y
	sta ddx_h
	lda COL_DDY_L,y
	sta ddy_l
	lda COL_DDY_H,y
	sta ddy_h
	lda COL_DDWX_L,y
	sta ddwx_l
	lda COL_DDWX_H,y
	sta ddwx_h
	lda COL_DDWY_L,y
	sta ddwy_l
	lda COL_DDWY_H,y
	sta ddwy_h
	lda COL_XSTEP,y
	sta xstep
	lda COL_YSTEP,y
	sta ystep

	; First-hit distance: +X uses fracx_inv, −X uses fracx → sdx
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
	jmp .cc_wz
.ym_raw
	lda fracy
	jsr calc_sdy
.cc_wz
	; Initial fish-scaled depth: wz = mid(s × fish) at first gridlines
	ldy col
	lda fishtab,y
	sta tmp0
	lda sdx_l
	sta aux_l
	lda sdx_h
	sta aux_h
	lda tmp0
	jsr mul_16x8
	sta wz_x_l
	stx wz_x_h
	lda sdy_l
	sta aux_l
	lda sdy_h
	sta aux_h
	lda tmp0
	jsr mul_16x8
	sta wz_y_l
	stx wz_y_h
.cc_init
	; Open clip [0,25); start in player sector; clear same-flat cache
	lda #0
	sta ytop
	sta dda_steps
	sta last_near_ok
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
	jsr prof_add_bucket		; preamble counts as S
}

; Inner: pick nearer of sdx/sdy; advance map/tile; same id → add only
.inner
	lda ytop
	cmp ybot
	bcc .igo
!if PROFILE = 1 {
	ldy #PROF_DDA
	jsr prof_add_bucket
}
	rts				; clip already closed — nothing left to paint
.igo
	; Choose axis with smaller remaining s (tie → Y)
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
	dex				; X = $ff for tile_h sign-extend on −X
.axp
	clc
	adc mapx
	sta mapx
	cmp #MAP_SIZE
	bcs .ax_oob
	clc
	lda tile_l
	adc xstep			; ±1 in map row (sign-extend via X)
	sta tile_l
	txa
	adc tile_h
	sta tile_h
	ldy #0
	lda (tile_l),y
	sta next_id
	cmp cur_id
	bne .ax_cell			; still same sector — cheap path
	jsr dda_bump
	bcs .ax_done
	jsr .add_sdx
	bcs .ax_done
	jmp .inner
.ax_done
	jmp .done
.ax_oob
	lda #0
	sta next_id			; off-map = solid void
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
	; +Y: tile pointer += MAP_SIZE (next row in map array)
	clc
	lda tile_l
	adc #MAP_SIZE
	sta tile_l
	lda tile_h
	adc #0
	sta tile_h
	jmp .ay_rd
.ay_n
	; −Y: tile pointer −= MAP_SIZE
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

; s += dd and wz += ddw; C = s overflow (ray end). wz overflow ignored.
.add_sdx
	clc
	lda sdx_l
	adc ddx_l
	sta sdx_l
	lda sdx_h
	adc ddx_h
	sta sdx_h
	php				; preserve s overflow for caller
	clc
	lda wz_x_l
	adc ddwx_l
	sta wz_x_l
	lda wz_x_h
	adc ddwx_h
	sta wz_x_h
	plp
	rts

.add_sdy
	clc
	lda sdy_l
	adc ddy_l
	sta sdy_l
	lda sdy_h
	adc ddy_h
	sta sdy_h
	php
	clc
	lda wz_y_l
	adc ddwy_l
	sta wz_y_l
	lda wz_y_h
	adc ddwy_h
	sta wz_y_h
	plp
	rts

.done
!if PROFILE = 1 {
	ldy #PROF_DDA
	jsr prof_add_bucket
}
	jmp fill_open_remainder

; ---------------------------------------------------------------------------
; dda_bump — inc dda_steps / dda_peak; C=1 if >= MAX_DDA
; ---------------------------------------------------------------------------
dda_bump
	inc dda_steps
	lda dda_steps
	cmp dda_peak
	bcc .dc_chk
	sta dda_peak
.dc_chk
	cmp #MAX_DDA
	rts

; ---------------------------------------------------------------------------
; fill_open_remainder — if clip still open after ray stop, flood with cur
; sector floor colour (no project_y; wallz may be stale on overflow/cap).
; ---------------------------------------------------------------------------
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
