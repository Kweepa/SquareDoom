; In-game automap: floor-coloured visited tiles + TheKeep player arrow
; Colour backbuffer in FRAMEBUFFER; chars set once; blit colours on vsync.
!zone mapscreen

MAP_OX = 4				; center 32 cols in 40
MAP_SCROLL_MAX = 7			; 32 - 25
; MAP_SOLID / MAP_ARROW0 — see squaredoom.asm charset map

map_scroll	!byte 0
map_row		!byte 0
map_pl_on	!byte 0			; 1 = pointer currently drawn
map_pl_row	!byte 0			; screen row of pointer
map_pl_col	!byte 0			; screen col of pointer

; NESW (0..3) → TheKeep arrow (L=0 U=1 R=2 D=3); 180° from prior table
map_arrow_dir
	!byte 3, 0, 1, 2			; N→D E→L S→U W→R

; ------------------------------------------------------------------
; mapscreen — overlay; F1 toggles exit (edge); W/S held scroll 1 row/frame
; ------------------------------------------------------------------
mapscreen
	jsr hide_weapon
	lda #1
	sta input_paused
	lda #0
	sta map_pl_on
	jsr ui_wait_map_up

	; Center vertically on player tile
	jsr player_tile
	lda mapy
	sec
	sbc #12
	bcs .ms_sc_ok
	lda #0
.ms_sc_ok
	cmp #MAP_SCROLL_MAX + 1
	bcc .ms_sc_store
	lda #MAP_SCROLL_MAX
.ms_sc_store
	sta map_scroll

	jsr map_fill_chars
	jsr map_build_colours
	jsr wait_frame
	jsr map_blit_colours
	jsr map_draw_player

.ms_loop
	jsr ui_read_keys

	lda ui_pressed
	and #UI_MAP
	bne .ms_exit

	; Held W/S → one row per frame (smooth)
	lda ui_keys
	and #UI_UP
	beq .ms_noup
	lda map_scroll
	beq .ms_noup
	dec map_scroll
	jmp .ms_scroll
.ms_noup
	lda ui_keys
	and #UI_DOWN
	beq .ms_idle
	lda map_scroll
	cmp #MAP_SCROLL_MAX
	bcs .ms_idle
	inc map_scroll
.ms_scroll
	jsr map_erase_player
	jsr map_build_colours
	jsr wait_frame
	jsr map_blit_colours
	jsr map_draw_player
	jmp .ms_loop

.ms_idle
	jsr wait_frame
	jmp .ms_loop

.ms_exit
	jsr ui_wait_map_up
	lda #0
	sta input_paused
	lda #1
	sta hud_dirty			; map used FRAMEBUFFER as colour backbuffer
	rts

; ------------------------------------------------------------------
; map_fill_chars — once: margins space, map area solid (colours carry fog)
; ------------------------------------------------------------------
map_fill_chars
	ldx #0
	lda #32
.mfc_sp
	sta $0400,x
	sta $0500,x
	sta $0600,x
	sta $06e8,x
	inx
	bne .mfc_sp

	lda #0
	sta map_row
.mfc_row
	lda #MAP_OX
	ldx map_row
	jsr cell_addr
	ldy #0
	lda #MAP_SOLID
.mfc_col
	sta (ptr_l),y
	iny
	cpy #MAP_SIZE
	bne .mfc_col
	inc map_row
	lda map_row
	cmp #25
	bcc .mfc_row
	rts

; ------------------------------------------------------------------
; map_get_id — mapx/mapy → A = sector id (uses tmp0/tmp1 only)
; ------------------------------------------------------------------
map_get_id
	ldy mapy
	lda maprowlo,y
	clc
	adc mapx
	sta tmp0
	lda maprowhi,y
	sta tmp1
	ldy #0
	lda (tmp0),y
	rts

; ------------------------------------------------------------------
; map_build_colours — paint viewport colours into FRAMEBUFFER (backbuffer)
; ------------------------------------------------------------------
map_build_colours
	ldx #0
	lda #0
.mbc_clr
	sta FRAMEBUFFER,x
	sta FRAMEBUFFER+$100,x
	sta FRAMEBUFFER+$200,x
	sta FRAMEBUFFER+$2e8,x
	inx
	bne .mbc_clr

	lda #0
	sta map_row
.mbc_row
	clc
	lda map_scroll
	adc map_row
	sta mapy
	lda #0
	sta mapx

	; aux → FRAMEBUFFER + row*40 + MAP_OX (colour backbuffer cell)
	lda #MAP_OX
	ldx map_row
	jsr cell_addr
	lda ptr_l
	sec
	sbc #<$0400
	sta aux_l
	lda ptr_h
	sbc #>$0400
	clc
	adc #>FRAMEBUFFER
	sta aux_h

	; row map pointer once (mapy fixed for the row)
	ldy mapy
	lda maprowlo,y
	sta tmp0
	lda maprowhi,y
	sta tmp1

	ldy #0
.mbc_col
	lda (tmp0),y
	beq .mbc_skip			; void → black
	tax
	lda SEC_VISITED,x
	beq .mbc_skip			; fog → black
	lda SEC_FCOL,x
	sta (aux_l),y
.mbc_skip
	iny
	cpy #MAP_SIZE
	bne .mbc_col
	inc map_row
	lda map_row
	cmp #25
	bcc .mbc_row
	rts

; ------------------------------------------------------------------
; map_blit_colours — FRAMEBUFFER → $d800 (call during / after vsync)
; ------------------------------------------------------------------
map_blit_colours
	ldx #0
.mbl
	lda FRAMEBUFFER,x
	sta $d800,x
	lda FRAMEBUFFER+$100,x
	sta $d900,x
	lda FRAMEBUFFER+$200,x
	sta $da00,x
	lda FRAMEBUFFER+$2e8,x
	sta $dae8,x
	inx
	bne .mbl
	rts

; ------------------------------------------------------------------
; map_erase_player — restore solid block under previous pointer
; ------------------------------------------------------------------
map_erase_player
	lda map_pl_on
	beq .mep_done
	lda #0
	sta map_pl_on
	lda map_pl_col
	ldx map_pl_row
	jsr cell_addr
	lda #MAP_SOLID
	ldy #0
	sta (ptr_l),y
.mep_done
	rts

; ------------------------------------------------------------------
; map_draw_player — white arrow; colour under comes from blit
; ------------------------------------------------------------------
map_draw_player
	jsr player_tile
	lda mapy
	sec
	sbc map_scroll
	bcc .mdp_off
	cmp #25
	bcs .mdp_off
	sta map_pl_row
	tax
	clc
	lda mapx
	adc #MAP_OX
	sta map_pl_col
	jsr cell_addr

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
	tay
	lda map_arrow_dir,y
	clc
	adc #MAP_ARROW0
	ldy #0
	sta (ptr_l),y
	lda #1				; white
	sta (aux_l),y
	lda #1
	sta map_pl_on
	rts
.mdp_off
	lda #0
	sta map_pl_on
	rts
