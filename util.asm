!zone util

; mapx/mapy → A = sector id
; Uses maprowlo/hi = level_map + y*32
; this requires that level_map is on a 32 byte boundary
map_sector_id
	ldy mapy
	lda maprowlo,y
	clc
	adc mapx
	sta ptr_l
	lda maprowhi,y
	sta ptr_h
	ldy #0
	lda (ptr_l),y
	rts

player_tile
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
	rts

; Fill colour+pattern column: A = colour, ytop..ybot-1
fill_col_span
	ldy ytop
	sty fill_y0
	ldy ybot
	sty fill_y1
	; fall through
; A = colour, fill_pat = screen code; fill_y0..fill_y1-1 into both FBs
fill_span
	inc span_lo
	bne .fs_go
	inc span_hi
.fs_go
	ldy fill_y0
	jmp .fs_loop_test
.fs_loop
	sta (col_base_l),y
	pha
	lda fill_pat
	sta (pat_base_l),y
	pla
	iny
.fs_loop_test
	cpy fill_y1
	bne .fs_loop
	rts

; col_base = FRAMEBUFFER + col * 25; pat_base = LIGHTFRAME + col * 25
; (LIGHTFRAME hi = FRAMEBUFFER hi + 4)
set_col_base
	ldy col
	lda colbaselo,y
	sta col_base_l
	sta pat_base_l
	lda colbasehi,y
	sta col_base_h
	clc
	adc #4
	sta pat_base_h
	rts

; wall_pat = min(7, wallz_h); also → fill_pat for wall strips
set_wall_pat
	lda wallz_h
	cmp #8
	bcc .swp_ok
	lda #7
.swp_ok
	sta wall_pat
	sta fill_pat
	rts
