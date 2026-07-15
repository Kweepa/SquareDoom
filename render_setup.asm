!zone render_setup

; PROFILE S — frame player tile + per-angle ray cache (dd/ddw/steps)

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

; Fold A&127 → TheKeep secant index 0..63
.fold_sec
	and #127
	cmp #63
	bcc .fs_ok
	eor #127
.fs_ok
	rts

; Rebuild per-column ddx/ddy + steps + mid(dd*fish) when playera changes.
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
	sta aux_l
	ldy dxindex
	lda fixsech,y
	ldy col
	sta COL_DDX_H,y
	sta aux_h
	lda fishtab,y
	jsr mul_16x8
	ldy col
	sta COL_DDWX_L,y
	txa
	sta COL_DDWX_H,y

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
	sta aux_l
	ldy dyindex
	lda fixsech,y
	ldy col
	sta COL_DDY_H,y
	sta aux_h
	lda fishtab,y
	jsr mul_16x8
	ldy col
	sta COL_DDWY_L,y
	txa
	sta COL_DDWY_H,y

	; xstep / TheKeep +X factor polarity from angle+64
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
	bcs .rcr_done
	jmp .rcr_lp
.rcr_done
	rts
