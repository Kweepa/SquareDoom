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
; Quadrant: xstep/ystep are fixed per column — preamble SMC-patches the
; tile advances (INC/DEC zp for ±X; CLC+ADC / SEC+SBC for ±Y). dda_steps
; lives in X on the same-id hot path (dex/beq); spilled around soft/cell.
;
; Branch form vs PROFILE (see march comments below):
;   PROFILE=0 — short relatives where in range: bne/bcs .adv_y from .inner,
;               bcc .inner from .ax_cell. Release build gets these cycles.
;   PROFILE=1 — prof_add_bucket in .ax_cell/.ay_cell adds 5 bytes and pushes
;               .adv_y and .ax_cell→.inner past ±127; use .to_adv_y trampoline
;               and jmp .inner there. Same control flow; a few extra cycles
;               per affected step only in the instrumented build.
;   Always jmp .inner from .adv_y (whole .adv_x sits between — out of range
;   even with PROFILE=0). Always bcc .inner from .ax_same (in range either way).
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
	; Fold first-hit fac; SMC will patch tile advances from xstep/ystep
	lda COL_YSTEP,y
	sta ystep
	lda COL_XSTEP,y
	sta xstep
	bpl .xs_pos
	lda fracx				; −X uses fracx
	jsr calc_sdx
	jmp .ym_fac
.xs_pos
	lda fracx_inv			; +X uses fracx_inv
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
	lda sdx_l
	sta aux_l
	lda sdx_h
	sta aux_h
	lda fishtab,y
	sta tmp0				; A already = fish for mul
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

	; Patch tile advances for this column's (xstep, ystep) quadrant
	ldx #$e6				; INC zp
	lda xstep
	bpl .patch_x
	ldx #$c6				; DEC zp
.patch_x
	stx .smc_x_lo
	stx .smc_x_hi
	ldx #$18				; CLC
	ldy #$69				; ADC #
	lda ystep
	bpl .patch_y
	ldx #$38				; SEC
	ldy #$e9				; SBC #
.patch_y
	stx .smc_y_clc
	sty .smc_y_op1
	sty .smc_y_op2

.cc_init
	; Open clip [0,25); HUD columns leave row 24 untouched.
	; Info message leaves row 0 free for cols 0..info_len-1.
	lda #0
	sta ytop
	sta last_near_ok
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
	sta wallz_l
	sta wallz_h			; near clip at depth 0
	jsr clip_col_push
!if PROFILE = 1 {
	ldy #PROF_SETUP
	jsr prof_add_bucket		; preamble counts as S
}
	ldy #0				; Y=0 invariant for (tile_l) reads
	ldx #MAX_DDA			; step countdown in X on hot path

; Inner: pick nearer of sdx/sdy; advance map/tile; same id → add only.
; Clip closure is only reported by on_cell (C=1) — no per-step ytop/ybot check.
;
; Axis pick → .adv_y: with PROFILE=0, .adv_y is within ±127 of .inner so we
; branch directly. PROFILE=1 inserts 5 bytes in .ax_cell, pushing .adv_y
; out of range — trampoline required (same 3 cy as a taken branch when the
; jmp is used, but the extra jmp vs a short bne costs when PROFILE=0).
.inner
	lda sdx_h
	cmp sdy_h
	bcc .adv_x
!if PROFILE = 1 {
	bne .to_adv_y
	lda sdx_l
	cmp sdy_l
	bcc .adv_x
.to_adv_y
	jmp .adv_y
} else {
	bne .adv_y
	lda sdx_l
	cmp sdy_l
	bcs .adv_y
}

.adv_x
	; ±X: SMC INC/DEC tile (page fix on wrap). Map sealed — no OOB check.
.smc_x_lo
	inc tile_l
	bne .smc_x_ok
.smc_x_hi
	inc tile_h
.smc_x_ok
	lda (tile_l),y			; Y held at 0
	cmp cur_id
	beq .ax_same			; same sector — cheap path
	sta next_id
	stx dda_steps			; spill steps — flatgrp/soft/cell use X
	ldx cur_id
	lda SEC_FLATGRP,x
	ldx next_id
	cmp SEC_FLATGRP,x
	beq .ax_soft			; identical flats — no paint, keep walking
	bne .ax_cell			; Z=0 after untaken beq; always taken
.ax_soft
	; Same flats — continuous space; aperture unchanged (depth clip).
	; X already = next_id; mark_seen preserves Y=0
	stx cur_id
	jsr mark_seen
	ldx dda_steps
.ax_same
	dex
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
	; Same-id → .inner is always in bcc range (PROFILE bytes live in .ax_cell,
	; after this path). Untaken bcs ⇒ C=0 ⇒ bcc always taken on continue.
	bcc .inner
.ax_done
	jmp .done
.ax_cell
	sty side				; Y=0 invariant through the march
!if PROFILE = 1 {
	ldy #PROF_DDA
	jsr prof_add_bucket
}
	jsr on_cell
	bcs .ax_done
	ldy #0
	ldx dda_steps
	dex
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
	; Cell → .inner: PROFILE=1 inserts 5 bytes here and lands ~4 past ±127;
	; PROFILE=0 fits bcc .inner. Overflow falls through to .ax_done via bcs.
!if PROFILE = 1 {
	bcs .ax_done
	jmp .inner
} else {
	bcc .inner
	bcs .ax_done
}

.adv_y
	; ±Y: SMC CLC+ADC #32 / SEC+SBC #32. Map sealed — no OOB check.
.smc_y_clc
	clc
	lda tile_l
.smc_y_op1
	adc #MAP_SIZE
	sta tile_l
	lda tile_h
.smc_y_op2
	adc #0
	sta tile_h
	lda (tile_l),y			; Y held at 0
	cmp cur_id
	beq .ay_same
	sta next_id
	stx dda_steps
	ldx cur_id
	lda SEC_FLATGRP,x
	ldx next_id
	cmp SEC_FLATGRP,x
	beq .ay_soft
	bne .ay_cell
.ay_soft
	stx cur_id
	jsr mark_seen
	ldx dda_steps
.ay_same
	dex
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
	; Y→.inner is always past ±127 (whole .adv_x sits in between), so
	; both PROFILE builds use jmp. Not gated — short branch impossible.
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
	ldx dda_steps
	dex
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
	jsr clip_col_commit		; COL_CLIP_N ← clip_n/4 for item draw
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
	tay					; Y survives bright_to_floor_pat
	lda SEC_BRIGHT,y
	jsr bright_to_floor_pat
	sta fill_pat
	lda SEC_FCOL,y
	ldy ytop
	sty fill_y0
	ldy ybot
	sty fill_y1
	jmp fill_flat_span
.for_done
	rts
