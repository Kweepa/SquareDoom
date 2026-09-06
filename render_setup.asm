!zone render_setup

; ============================================================================
; render_setup.asm — PROFILE S (frame + angle setup)
; ============================================================================
; Once per frame: derive map cell / frac / sector from world 8.8 player.
; When playera changes: rebuild per-column ray cache (ddx/ddy, fish-scaled
; ddwx/ddwy, xstep/ystep) at $2f00 / $3000.
;
; Note: most of the per-column S cost lives in cast_column's preamble
; (sdx/sdy/wz init) in render_dda.asm — S bucket closes there.
; ============================================================================

; ---------------------------------------------------------------------------
; setup_player_tile — once per frame
;
; World 8.8 >> 3 → tile 8.8: map = high, frac = low (TheKeep first-hit).
; Also frac*_inv for +axis. Caches plr_mapx/y, plr_id, plr_tile_* once/frame.
; Columns restore tile* after DDA mutates it; mapx/mapy are not marched.
; ---------------------------------------------------------------------------
setup_player_tile
	; tile 8.8 = world 8.8 / 8
	lda playerx
	sta fracx
	lda playerx_h
	lsr
	ror fracx
	lsr
	ror fracx
	lsr
	ror fracx
	sta plr_mapx
	sta mapx
	lda fracx
	eor #$ff
	sta fracx_inv			; distance to +X gridline for first hit
	lda playery
	sta fracy
	lda playery_h
	lsr
	ror fracy
	lsr
	ror fracy
	lsr
	ror fracy
	sta plr_mapy
	sta mapy
	lda fracy
	eor #$ff
	sta fracy_inv
	jsr map_sector_id		; also leaves tile ptr in ptr_l/h
	sta plr_id
	lda ptr_l
	sta plr_tile_l
	lda ptr_h
	sta plr_tile_h
	rts

; ---------------------------------------------------------------------------
; rebuild_col_rays — when playera changes (or forced at boot)
;
; For each of 40 columns: angtab+look → fixsec → COL_DDX/Y; mid(dd*fish) →
; COL_DDWX/Y; sign of angle axes → COL_XSTEP/YSTEP (±1).
; X = col, Y = secant index (mul_16x8 returns A=lo X=hi — reload col after).
; ---------------------------------------------------------------------------
rebuild_col_rays
	; Sky scroll depends on the same angle. Hoist the strip base and patch
	; render's col-0 pointer + wrap column (induction adds 12 per column).
	lda playera
	sta tmp0
	asl
	asl
	clc
	adc tmp0			; playera * 5
	lsr
	lsr
	lsr				; byte-wrapped /8 → 0..31, matching old per-column math
	sta sky_col_base
	; sky_ptr = sky_cols + base*12 (col 0; base is 0..31 so no wrap)
	lda #0
	sta tmp1
	lda sky_col_base
	tax
	asl
	rol tmp1
	asl
	rol tmp1
	asl
	rol tmp1			; *8 → A/tmp1
	sta tmp0
	lda tmp1
	sta tmp2			; *8 hi
	lda #0
	sta tmp1
	txa
	asl
	rol tmp1
	asl
	rol tmp1			; *4 → A/tmp1
	clc
	adc tmp0
	sta tmp0			; *12 lo
	lda tmp1
	adc tmp2
	sta tmp1			; *12 hi
	clc
	lda tmp0
	adc #<sky_cols
	sta sky_ptr_l
	sta sky_ptr_init_l + 1
	lda tmp1
	adc #>sky_cols
	sta sky_ptr_h
	sta sky_ptr_init_h + 1
	lda #40
	sec
	sbc sky_col_base		; 40 when base=0 (never matches col 1..39)
	sta sky_wrap_cmp + 1

	; base = playera − 64 (north alignment); per-col angle = angtab[col] + base
	lda playera
	sec
	sbc #64
	sta rcr_abase
	lda #0
	sta col
.rcr_lp
	; Column world angle: angtab[col] + playera − 64
	ldx col
	lda angtab,x
	clc
	adc rcr_abase
	sta angle

	; ---- X secant + fish-scaled Δwz per X-step ----
	; fold A&127 → fixsec index 0..63 (inlined)
	and #127
	cmp #63
	bcc .rcr_xok
	eor #127
.rcr_xok
	tay				; Y = secant index
	lda fixsecl,y
	sta COL_DDX_L,x
	sta aux_l
	lda fixsech,y
	sta COL_DDX_H,x
	sta aux_h
	; Fish factor once — both mid(dd×fish) muls share sq1..sq4
	lda fishtab,x
	sta sq1_l
	sta sq2_l
	eor #$ff
	sta sq3_l
	sta sq4_l
	jsr mul_16x8_ready		; A=lo, X=hi
	ldy col
	sta COL_DDWX_L,y
	txa
	sta COL_DDWX_H,y
	tya
	tax				; X = col again

	; ---- Y secant: angle+64, fold, fixsec, mid(ddy×fish) ----
	lda angle
	clc
	adc #64
	sta tmp0
	and #127
	cmp #63
	bcc .rcr_yok
	eor #127
.rcr_yok
	tay
	lda fixsecl,y
	sta COL_DDY_L,x
	sta aux_l
	lda fixsech,y
	sta COL_DDY_H,x
	sta aux_h
	jsr mul_16x8_ready		; sq* still = fish
	ldy col
	sta COL_DDWY_L,y
	txa
	sta COL_DDWY_H,y

	; xstep from angle+64 (TheKeep +X factor / “east” axis)
	lda tmp0
	bmi .rcr_xn
	lda #1
	bne .rcr_xs
.rcr_xn
	lda #$ff			; −1
.rcr_xs
	sta COL_XSTEP,y

	; ystep from folded look angle (north/south)
	lda angle
	bmi .rcr_yn
	lda #1
	bne .rcr_ys
.rcr_yn
	lda #$ff
.rcr_ys
	sta COL_YSTEP,y

	inc col
	lda col
	cmp #40
	bcs .rcr_done
	jmp .rcr_lp
.rcr_done
	rts
