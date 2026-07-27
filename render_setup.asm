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
; Also frac*_inv for +axis. Caches plr_mapx/y, plr_id, plr_tile_* so each
; column can restore after DDA mutates map*/tile*.
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
	lda fishtab,x
	jsr mul_16x8			; A=lo, X=hi
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
	lda fishtab,x
	jsr mul_16x8
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
