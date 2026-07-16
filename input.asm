!zone input

; CIA1 keys:
;   J = turn left (PA4/PB2), L = turn right (PA5/PB2)
;   K = use (PA4/PB5) — open door
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
	sta key_use
	sta key_fire

	lda #$ff
	sta $dc02
	lda #0
	sta $dc03

	; --- turn J / L (one deliver per frame); K = use, I = fire (same col as J) ---
	lda #0
	sta tmp3				; turn_dir: 0 none, $ff left, 1 right
	lda #$ef
	sta $dc00
	lda $dc01
	tax
	and #$04
	bne .no_j
	lda #$ff
	sta tmp3
.no_j
	txa
	and #$20				; K = PB5
	bne .no_k
	lda #1
	sta key_use
.no_k
	txa
	and #$02				; I = PB1 (PA4/$EF column)
	bne .no_i
	lda #1
	sta key_fire
.no_i
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

; Apply wish 8.8; push 1 unit from blocking faces (slide); axis fallback
; Blocking = void/OOB, headroom < 4, or step-up > 2 height vs old_floor.
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

	jsr player_tile
	jsr map_sector_id
	beq .am_void_fl
	tax
	lda SEC_FLOOR,x
	sta old_floor
	jmp .am_have_fl
.am_void_fl
	lda #0
	sta old_floor
.am_have_fl
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

	; Wish consumed — reuse wish_* as post-wish XY for axis fallback
	lda playerx
	sta wish_x_l
	lda playerx_h
	sta wish_x_h
	lda playery
	sta wish_y_l
	lda playery_h
	sta wish_y_h

	jsr push_walls
	jsr standing_blocked
	bcc .am_ok

	; X-new + Y-old
	lda wish_x_l
	sta playerx
	lda wish_x_h
	sta playerx_h
	lda save_yl
	sta playery
	lda save_yh
	sta playery_h
	jsr push_walls
	jsr standing_blocked
	bcc .am_ok

	; X-old + Y-new
	lda save_xl
	sta playerx
	lda save_xh
	sta playerx_h
	lda wish_y_l
	sta playery
	lda wish_y_h
	sta playery_h
	jsr push_walls
	jsr standing_blocked
	bcc .am_ok

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

; A = sector id → C=1 blocked, C=0 walkable (vs old_floor)
tile_blocked
	cmp #0
	beq .tb_yes
	tax
	lda SEC_CEIL,x
	sec
	sbc SEC_FLOOR,x
	cmp #4
	bcc .tb_yes
	lda SEC_FLOOR,x
	cmp old_floor
	bcc .tb_no
	beq .tb_no
	sec
	sbc old_floor
	cmp #3
	bcs .tb_yes
.tb_no
	clc
	rts
.tb_yes
	sec
	rts

; mapx/mapy → A = sector id; OOB → 0
sector_at_map
	lda mapx
	cmp #MAP_SIZE
	bcs .sam_oob
	lda mapy
	cmp #MAP_SIZE
	bcs .sam_oob
	jmp map_sector_id
.sam_oob
	lda #0
	rts

; C=1 if player tile blocking
standing_blocked
	jsr player_tile
	jsr sector_at_map
	jmp tile_blocked

; Push player 1 world unit away from each adjacent blocking face
push_walls
	jsr player_tile
	lda mapx
	sta tmp4
	lda mapy
	sta tmp5

	; West: neighbor (mapx-1, mapy)
	lda tmp4
	sec
	sbc #1
	sta mapx
	lda tmp5
	sta mapy
	jsr sector_at_map
	jsr tile_blocked
	bcc .pw_east
	lda playerx_h
	and #7
	bne .pw_east			; local_x >= 1.0
	lda tmp4
	asl
	asl
	asl
	ora #1
	sta playerx_h
	lda #0
	sta playerx

.pw_east
	lda tmp4
	clc
	adc #1
	sta mapx
	lda tmp5
	sta mapy
	jsr sector_at_map
	jsr tile_blocked
	bcc .pw_north
	lda playerx_h
	and #7
	cmp #7
	bne .pw_north
	lda playerx
	beq .pw_north			; local_x == 7.0 exactly
	lda tmp4
	asl
	asl
	asl
	ora #7
	sta playerx_h
	lda #0
	sta playerx

.pw_north
	; map Y−1 (smaller playery)
	lda tmp4
	sta mapx
	lda tmp5
	sec
	sbc #1
	sta mapy
	jsr sector_at_map
	jsr tile_blocked
	bcc .pw_south
	lda playery_h
	and #7
	bne .pw_south
	lda tmp5
	asl
	asl
	asl
	ora #1
	sta playery_h
	lda #0
	sta playery

.pw_south
	lda tmp4
	sta mapx
	lda tmp5
	clc
	adc #1
	sta mapy
	jsr sector_at_map
	jsr tile_blocked
	bcc .pw_done
	lda playery_h
	and #7
	cmp #7
	bne .pw_done
	lda playery
	beq .pw_done
	lda tmp5
	asl
	asl
	asl
	ora #7
	sta playery_h
	lda #0
	sta playery
.pw_done
	rts
