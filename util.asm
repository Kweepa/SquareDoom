!zone util

; mapx/mapy → A = sector id (0 if OOB)
map_sector_id
	lda mapx
	cmp #MAP_SIZE
	bcs .msi_oob
	lda mapy
	cmp #MAP_SIZE
	bcs .msi_oob
	lda #0
	sta ptr_h
	lda mapy
	asl
	rol ptr_h
	asl
	rol ptr_h
	asl
	rol ptr_h
	asl
	rol ptr_h
	asl
	rol ptr_h
	clc
	adc mapx
	sta ptr_l
	bcc .msi_nc
	inc ptr_h
.msi_nc
	clc
	lda ptr_l
	adc #<level_map
	sta ptr_l
	lda ptr_h
	adc #>level_map
	sta ptr_h
	ldy #0
	lda (ptr_l),y
	rts
.msi_oob
	lda #0
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

; A = sector id (1..255) → ptr → sector record; offset (id-1)*7
set_sector_ptr
	sec
	sbc #1
	sta tmp2
	lda tmp2
	sta ptr_l
	lda #0
	sta ptr_h
	asl ptr_l
	rol ptr_h
	asl ptr_l
	rol ptr_h
	asl ptr_l
	rol ptr_h
	sec
	lda ptr_l
	sbc tmp2
	sta ptr_l
	lda ptr_h
	sbc #0
	sta ptr_h
	clc
	lda ptr_l
	adc #<level_sectors
	sta ptr_l
	lda ptr_h
	adc #>level_sectors
	sta ptr_h
	rts

sector_floor
	jsr set_sector_ptr
	ldy #0
	lda (ptr_l),y
	rts
sector_ceil
	jsr set_sector_ptr
	ldy #1
	lda (ptr_l),y
	rts
sector_type
	jsr set_sector_ptr
	ldy #2
	lda (ptr_l),y
	rts
sector_fcol
	jsr set_sector_ptr
	ldy #4
	lda (ptr_l),y
	rts
sector_ccol
	jsr set_sector_ptr
	ldy #5
	lda (ptr_l),y
	rts

; Fill colour column: X = colour, ytop..ybot-1 rows at current col
; Uses tmp0=colour, fill_row=row (must not touch tmp1–tmp5 / span_*)
fill_col_span
	stx tmp0
	lda ytop
	sta fill_row
.fcs_loop
	lda fill_row
	cmp ybot
	bcs .fcs_done
	tay
	lda row40lo,y
	clc
	adc col
	sta ptr_l
	lda row40hi,y
	adc #$d8
	sta ptr_h
	ldy #0
	lda tmp0
	sta (ptr_l),y
	inc fill_row
	bne .fcs_loop
.fcs_done
	rts
