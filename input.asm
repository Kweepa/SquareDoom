!zone input

; CIA1 keys:
;   J = turn left (PA4/PB2), L = turn right (PA5/PB2)
;   W/A/S = PA1 column; D = PA2 column
;   W forward, S back, A strafe left, D strafe right
; Facing matches editor: forward = (sin θ, −cos θ)
; Wish deltas add into world-byte player*_h (~sintab amp 1).

TURN_SPEED = 3

read_input
	lda #0
	sta turn
	sta wish_x
	sta wish_y

	lda #$ff
	sta $dc02
	lda #0
	sta $dc03

	; --- turn J / L ---
	lda #$ef
	sta $dc00
	lda $dc01
	and #$04
	bne .no_j
	lda turn
	sec
	sbc #TURN_SPEED
	sta turn
.no_j
	lda #$df
	sta $dc00
	lda $dc01
	and #$04
	bne .no_l
	lda turn
	clc
	adc #TURN_SPEED
	sta turn
.no_l

	; --- WAS column (PA1 = $FD): W bit1, A bit2, S bit5 ---
	lda #$fd
	sta $dc00
	lda $dc01
	sta tmp0

	; W = forward (sin, −cos)
	lda tmp0
	and #$02
	bne .no_w
	ldy playera
	lda sintab,y
	jsr wish_add_x
	lda playera
	clc
	adc #64
	tay
	lda sintab,y
	jsr neg_a
	jsr wish_add_y
.no_w
	; S = back (−sin, +cos)
	lda tmp0
	and #$20
	bne .no_s
	ldy playera
	lda sintab,y
	jsr neg_a
	jsr wish_add_x
	lda playera
	clc
	adc #64
	tay
	lda sintab,y
	jsr wish_add_y
.no_s
	; A = strafe left (−cos, −sin)
	lda tmp0
	and #$04
	bne .no_a
	lda playera
	clc
	adc #64
	tay
	lda sintab,y
	jsr neg_a
	jsr wish_add_x
	ldy playera
	lda sintab,y
	jsr neg_a
	jsr wish_add_y
.no_a

	; --- D column (PA2 = $FB): D bit2 ---
	lda #$fb
	sta $dc00
	lda $dc01
	and #$04
	bne .no_d
	; D = strafe right (cos, sin)
	lda playera
	clc
	adc #64
	tay
	lda sintab,y
	jsr wish_add_x
	ldy playera
	lda sintab,y
	jsr wish_add_y
.no_d

	lda #$7f
	sta $dc00
	rts

; A = signed delta → wish_x
wish_add_x
	clc
	adc wish_x
	sta wish_x
	rts

; A = signed delta → wish_y
wish_add_y
	clc
	adc wish_y
	sta wish_y
	rts

neg_a
	eor #$ff
	clc
	adc #1
	rts

; Apply wish into world-byte player*_h; revert if new tile is void
apply_move
	lda wish_x
	ora wish_y
	bne .am_go
	rts
.am_go
	lda playerx_h
	sta save_xh
	lda playery_h
	sta save_yh

	clc
	lda playerx_h
	adc wish_x
	sta playerx_h
	clc
	lda playery_h
	adc wish_y
	sta playery_h

	jsr player_tile
	jsr map_sector_id
	bne .am_ok
	lda save_xh
	sta playerx_h
	lda save_yh
	sta playery_h
.am_ok
	rts
