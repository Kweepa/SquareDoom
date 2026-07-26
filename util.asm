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

; playera → A = NESW face: 0=N 1=E 2=S 3=W  ((a+32)>>6 & 3)
player_face_nesw
	lda playera
	clc
	adc #32
	lsr
	lsr
	lsr
	lsr
	lsr
	lsr
	and #3
	rts

; Fill colour+pattern column: A = colour, ytop..ybot-1
; Clobbers X (colour kept in X across the dual-FB store).
fill_col_span
	ldy ytop
	sty fill_y0
	ldy ybot
	sty fill_y1
	; fall through
; A = colour, fill_pat = screen code; fill_y0..fill_y1-1 into both FBs
; Clobbers X. Empty span (fill_y0 == fill_y1) is a no-op.
fill_span
!if PROFILE = 1 {
	inc span_lo
	bne .fs_go
	inc span_hi
.fs_go
}
	tax				; colour in X — avoids pha/pla per row (30→25 cy)
	ldy fill_y0
	jmp .fs_loop_test
.fs_loop
	txa
	sta (col_base_l),y
	lda fill_pat
	sta (pat_base_l),y
	iny
.fs_loop_test
	cpy fill_y1
	bne .fs_loop
	rts

; A = colour; fill_y0..fill_y1-1 with fill_pat (flat remainder path).
; Clobbers X. paint_near inlines its own copies to avoid jsr tax.
fill_flat_span
!if PROFILE = 1 {
	inc span_lo
	bne .ffs_go
	inc span_hi
.ffs_go
}
	tax
	ldy fill_y0
	jmp .ffs_test
.ffs_lp
	txa
	sta (col_base_l),y
	lda fill_pat
	sta (pat_base_l),y
	iny
.ffs_test
	cpy fill_y1
	bne .ffs_lp
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

; wall_pat = min(15, min(15, wallz_h) + (15 - SEC_BRIGHT[cur_id]))
; SEC_BRIGHT 16 = full bright (pattern 0, no distance darken).
; also → fill_pat for wall strips. Clobbers X.
set_wall_pat
	ldx cur_id
	lda SEC_BRIGHT,x
	cmp #16
	bcc .swp_dim
	lda #0				; full bright: ignore wallz
	sta wall_pat
	sta fill_pat
	rts
.swp_dim
	tax
	lda bright_to_darken,x
	sta fill_pat			; scratch: darken stops (overwritten below)
	lda wallz_h
	cmp #16
	bcc .swp_zok
	lda #15
.swp_zok
	clc
	adc fill_pat
	tax
	lda pat_clamp,x
	sta wall_pat
	sta fill_pat
	rts

; A = SEC_BRIGHT → A = floor screen code FLOOR_PAT_BASE..+15 (16 → base). Clobbers X.
bright_to_floor_pat
	cmp #16
	bcc .btfp_dim
	lda #FLOOR_PAT_BASE
	rts
.btfp_dim
	tax
	lda bright_to_darken,x
	clc
	adc #FLOOR_PAT_BASE
	rts

; SEC_BRIGHT 0..15 → extra dither stops (15 = distance only, 0 = +15 stops)
bright_to_darken
	!byte 15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0

; pat_clamp[i] = min(15, i) for i = 0..30 (max depth15 + darken15)
pat_clamp
	!byte 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
	!byte 15,15,15,15,15,15,15,15,15,15,15,15,15,15,15

; Deathchase GetRandom8 — new = 9 * old + 193
GetRandom8
	lda random8
	asl
	asl
	asl
	clc
	adc random8
	clc
	adc #193
	sta random8
	rts

; From Stephen Judd's Fridge rand1.s (Deathchase); new = 5 * old + $3611
; Clobber: A, tmp0. Result in random / random+1.
GetRandom16
	lda random + 1
	sta tmp0
	lda random
	asl
	rol tmp0
	asl
	rol tmp0
	clc
	adc random
	pha
	lda tmp0
	adc random + 1
	sta random + 1
	pla
	clc				; kweepa fix vs Judd
	adc #$11
	sta random
	lda random + 1
	adc #$36
	sta random + 1
	rts

random	!word $a3b7			; 16-bit LCG state
