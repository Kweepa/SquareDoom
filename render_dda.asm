!zone render_dda

; ============================================================================
; render_dda.asm — PROFILE D (column DDA + incremental fish wz)
; ============================================================================
; Per column: load ray cache, mid(frac*dd) → sdx/sdy, mid(s*fish) → wz,
; then TheKeep-style march comparing sdx vs sdy. Same-id cells skip on_cell
; (cheap add only). Sector changes call on_cell in render.asm.
;
; Incremental wz: each step does wz += ddw then s += dd (inlined; COL_DDWX/Y
; from setup). calc_wallz then only shifts — no fish mul at edges.
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
	; Restore player cell — previous columns left tile* mutated
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
	; Sign-extend byte for tile_h on ±X steps ($00 / $FF)
	ldx #0
	cmp #0
	bpl .xs_pos
	dex
.xs_pos
	stx xsgn
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
	; Open clip [0,25); HUD columns leave row 24 untouched.
	; Info message leaves row 0 free for cols 0..info_len-1.
	lda #0
	sta ytop
	sta last_near_ok
	lda #MAX_DDA				; countdown: dec/beq ends march
	sta dda_steps
	lda info_len
	beq .ytop_ok
	ldx col
	cpx info_len
	bcs .ytop_ok
	lda #1
	sta ytop
.ytop_ok
	lda #25
	ldx col
	cpx #8
	bcc .hud_ybot			; cols 0–7
	cpx #32
	bcc .ybot_set			; cols 8–31: full height
.hud_ybot
	lda #24				; cols 0–7 and 32–39: rows 0–23 only
.ybot_set
	sta ybot
	lda plr_id
	sta cur_id
	lda plr_tile_l
	sta tile_l
	lda plr_tile_h
	sta tile_h
	jsr clip_col_reset
	ldx plr_id
	jsr mark_seen
	lda #0
	sta wallz_h			; near clip at depth 0
	jsr clip_col_push
!if PROFILE = 1 {
	ldy #PROF_SETUP
	jsr prof_add_bucket		; preamble counts as S
}
	ldy #0				; Y=0 invariant for (tile_l) reads

; Inner: pick nearer of sdx/sdy; advance map/tile; same id → add only.
; Clip closure is only reported by on_cell (C=1) — no per-step ytop/ybot check.
.inner
	; Choose axis with smaller remaining s (tie → Y)
	lda sdx_h
	cmp sdy_h
	bcc .adv_x
	bne .to_adv_y
	lda sdx_l
	cmp sdy_l
	bcc .adv_x
.to_adv_y
	jmp .adv_y

.adv_x
	; Map is sealed with id-0 border — no mapx OOB check (tile walk is enough)
	clc
	lda tile_l
	adc xstep			; ±1 in map row
	sta tile_l
	lda tile_h
	adc xsgn				; sign-extend from preamble
	sta tile_h
	lda (tile_l),y			; Y held at 0
	cmp cur_id
	beq .ax_same			; same sector — cheap path
	sta next_id
	ldx cur_id
	lda SEC_FLATGRP,x
	ldx next_id
	cmp SEC_FLATGRP,x
	beq .ax_soft			; identical flats — no paint, keep walking
	jmp .ax_cell
.ax_soft
	; Same flats — continuous space; aperture unchanged (depth clip).
	lda next_id
	sta cur_id
	tax
	jsr mark_seen
	ldy #0				; restore Y=0 after jsr
.ax_same
	dec dda_steps
	beq .ax_done
	; wz_x += ddwx, then sdx += ddx (C = s overflow)
	clc
	lda wz_x_l
	adc ddwx_l
	sta wz_x_l
	lda wz_x_h
	adc ddwx_h
	sta wz_x_h
	clc
	lda sdx_l
	adc ddx_l
	sta sdx_l
	lda sdx_h
	adc ddx_h
	sta sdx_h
	bcs .ax_done
	jmp .inner
.ax_done
	jmp .done
.ax_cell
	lda #0
	sta side
!if PROFILE = 1 {
	ldy #PROF_DDA
	jsr prof_add_bucket
}
	jsr on_cell
	bcs .ax_done
	ldy #0
	dec dda_steps
	beq .ax_done
	clc
	lda wz_x_l
	adc ddwx_l
	sta wz_x_l
	lda wz_x_h
	adc ddwx_h
	sta wz_x_h
	clc
	lda sdx_l
	adc ddx_l
	sta sdx_l
	lda sdx_h
	adc ddx_h
	sta sdx_h
	bcs .ax_done
	jmp .inner

.adv_y
	; Map is sealed with id-0 border — no mapy OOB check
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
	lda (tile_l),y			; Y held at 0
	cmp cur_id
	beq .ay_same
	sta next_id
	ldx cur_id
	lda SEC_FLATGRP,x
	ldx next_id
	cmp SEC_FLATGRP,x
	beq .ay_soft
	jmp .ay_cell
.ay_soft
	; Same flats — continuous space; aperture unchanged (depth clip).
	lda next_id
	sta cur_id
	tax
	jsr mark_seen
	ldy #0
.ay_same
	dec dda_steps
	beq .ay_done
	clc
	lda wz_y_l
	adc ddwy_l
	sta wz_y_l
	lda wz_y_h
	adc ddwy_h
	sta wz_y_h
	clc
	lda sdy_l
	adc ddy_l
	sta sdy_l
	lda sdy_h
	adc ddy_h
	sta sdy_h
	bcs .ay_done
	jmp .inner
.ay_done
	jmp .done
.ay_cell
	lda #1
	sta side
!if PROFILE = 1 {
	ldy #PROF_DDA
	jsr prof_add_bucket
}
	jsr on_cell
	bcs .ay_done
	ldy #0
	dec dda_steps
	beq .ay_done
	clc
	lda wz_y_l
	adc ddwy_l
	sta wz_y_l
	lda wz_y_h
	adc ddwy_h
	sta wz_y_h
	clc
	lda sdy_l
	adc ddy_l
	sta sdy_l
	lda sdy_h
	adc ddy_h
	sta sdy_h
	bcs .ay_done
	jmp .inner

.done
!if PROFILE = 1 {
	ldy #PROF_DDA
	jsr prof_add_bucket
}
	jmp fill_open_remainder

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
	lda SEC_BRIGHT,x
	jsr bright_to_floor_pat
	sta fill_pat
	ldx cur_id
	lda SEC_FCOL,x
	ldy ytop
	sty fill_y0
	ldy ybot
	sty fill_y1
	jsr fill_flat_span
.for_done
	rts
