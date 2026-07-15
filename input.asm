!zone input

; CIA1 keys:
;   J = turn left (PA4/PB2), L = turn right (PA5/PB2)
;   W/A/S = PA1 column; D = PA2 column
;   W forward, S back, A strafe left, D strafe right
; Facing matches editor: forward = (sin θ, −cos θ)
;
; Speeds use last-frame dt_ms (frame_cy>>10, binary ms):
;   turn 90°/sec = 64 angle/sec → turn_acc += dt<<6, deliver >>10
;   move 1 tile/sec = 8 world/sec → delta_8_8 = (sintab * dt_ms) >> 5
; sintab AMP=64; identity: sin=64, dt=1024 → 2048 = 8.0 world.
;
; WAS row is kept in tmp4 — scale_vel clobbers tmp0..tmp2.

read_input
	lda #0
	sta turn
	sta wish_x_l
	sta wish_x_h
	sta wish_y_l
	sta wish_y_h

	lda #$ff
	sta $dc02
	lda #0
	sta $dc03

	; --- turn J / L (one deliver per frame) ---
	lda #0
	sta tmp3				; turn_dir: 0 none, $ff left, 1 right
	lda #$ef
	sta $dc00
	lda $dc01
	and #$04
	bne .no_j
	lda #$ff
	sta tmp3
.no_j
	lda #$df
	sta $dc00
	lda $dc01
	and #$04
	bne .no_l
	lda #1
	sta tmp3
.no_l
	lda tmp3
	beq .turn_done
	jsr turn_deliver			; A = unsigned step
	ldx tmp3
	bpl .turn_right
	eor #$ff
	clc
	adc #1
.turn_right
	sta turn
.turn_done

	; --- WAS column (PA1 = $FD): W bit1, A bit2, S bit5 ---
	lda #$fd
	sta $dc00
	lda $dc01
	sta tmp4				; must survive scale_vel

	; W = forward (sin, −cos)
	lda tmp4
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
	lda tmp4
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
	lda tmp4
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

; turn_acc += dt_ms<<6; A = turn_acc>>10; turn_acc &= $03FF
turn_deliver
	lda #0
	sta tmp1
	lda dt_ms
	sta tmp0
	asl tmp0
	rol tmp1
	asl tmp0
	rol tmp1
	asl tmp0
	rol tmp1
	asl tmp0
	rol tmp1
	asl tmp0
	rol tmp1
	asl tmp0
	rol tmp1				; tmp = dt_ms * 64
	clc
	lda turn_acc_l
	adc tmp0
	sta turn_acc_l
	lda turn_acc_h
	adc tmp1
	sta turn_acc_h
	; delivered = hi >> 2  (acc >> 10 for this magnitude)
	lsr
	lsr
	pha
	lda turn_acc_h
	and #3
	sta turn_acc_h
	pla
	rts

; A = signed sintab → scale (A * dt_ms) >> 5 → add into wish_x
wish_add_x
	jsr scale_vel
	clc
	lda wish_x_l
	adc tmp0
	sta wish_x_l
	lda wish_x_h
	adc tmp1
	sta wish_x_h
	rts

; A = signed sintab → add scaled into wish_y
wish_add_y
	jsr scale_vel
	clc
	lda wish_y_l
	adc tmp0
	sta wish_y_l
	lda wish_y_h
	adc tmp1
	sta wish_y_h
	rts

; A = signed unit → tmp0/tmp1 = (A * dt_ms) >>> 5 (arithmetic)
scale_vel
	sta tmp2
	bpl .sv_abs
	eor #$ff
	clc
	adc #1
.sv_abs
	tay
	lda dt_ms
	jsr mul_8x8				; X=lo A=hi
	sta tmp1
	stx tmp0
	ldx #5
.sv_asr
	lda tmp1
	cmp #$80
	ror tmp1
	ror tmp0
	dex
	bne .sv_asr
	lda tmp2
	bpl .sv_done
	sec
	lda #0
	sbc tmp0
	sta tmp0
	lda #0
	sbc tmp1
	sta tmp1
.sv_done
	rts

neg_a
	eor #$ff
	clc
	adc #1
	rts

; Apply wish 8.8 into player; revert both axes if new tile is void
apply_move
	lda wish_x_l
	ora wish_x_h
	ora wish_y_l
	ora wish_y_h
	bne .am_go
	rts
.am_go
	lda playerx
	sta save_xl
	lda playerx_h
	sta save_xh
	lda playery
	sta save_yl
	lda playery_h
	sta save_yh

	clc
	lda playerx
	adc wish_x_l
	sta playerx
	lda playerx_h
	adc wish_x_h
	sta playerx_h
	clc
	lda playery
	adc wish_y_l
	sta playery
	lda playery_h
	adc wish_y_h
	sta playery_h

	jsr player_tile
	jsr map_sector_id
	bne .am_ok
	lda save_xl
	sta playerx
	lda save_xh
	sta playerx_h
	lda save_yl
	sta playery
	lda save_yh
	sta playery_h
.am_ok
	rts
