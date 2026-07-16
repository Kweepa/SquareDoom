!zone input

; CIA1 keys (sampled by Timer A IRQ ~every 25 binary-ms):
;   J = turn left (PA4/PB2), L = turn right (PA5/PB2)
;   K = use (PA4/PB5) — open door; I = fire (PA4/PB1)
;   W/A/S = PA1 column; D = PA2 column
;   W forward, S back, A strafe left, D strafe right
; Facing matches editor: forward = (sin θ, −cos θ)
;
; IRQ accumulates hold times into in_*; read_input snapshots under SEI and
; scales turn/wish by those times (not full-frame dt_ms):
;   turn 90°/sec = 64 angle/sec → turn_acc += vel_ms<<6, deliver >>10
;   move 1 tile/sec = 8 world/sec → delta_8_8 = (sintab * vel_ms) >> 5
; sintab AMP=64; identity: sin=64, dt=1024 → 2048 = 8.0 world.
;
; Use/fire: OR-latch if held on any sample this frame.

SAMPLE_MS = 25
; Timer load = SAMPLE_MS * 1024 - 1 (binary-ms, φ2 ticks)
SAMPLE_TA_LO = <$63FF
SAMPLE_TA_HI = >$63FF

; ------------------------------------------------------------------
; input_irq_init — CIA1 TA IRQ @ SAMPLE_MS; vector at $FFFE (KERNAL out)
; ------------------------------------------------------------------
input_irq_init
	lda #0
	sta in_turn_l
	sta in_turn_r
	sta in_fwd
	sta in_back
	sta in_strafel
	sta in_strafer
	sta in_use
	sta in_fire
	sta $d01a				; no VIC IRQs

	lda #$7f
	sta $dc0d				; clear CIA1 IRQ enables
	lda $dc0d				; ack
	lda #SAMPLE_TA_LO
	sta $dc04
	lda #SAMPLE_TA_HI
	sta $dc05
	lda #<input_irq
	sta $fffe
	lda #>input_irq
	sta $ffff
	lda #$81				; set + enable Timer A IRQ
	sta $dc0d
	lda #$11				; start + force load, continuous φ2
	sta $dc0e
	rts

; ------------------------------------------------------------------
; input_irq — sample matrix; bump hold ms / OR use+fire. No tmp*.
; ------------------------------------------------------------------
input_irq
	pha
	txa
	pha
	tya
	pha

	; J / K / I (PA4 = $EF)
	lda #$ef
	sta $dc00
	lda $dc01
	tax
	and #$04
	bne .irq_noj
	lda in_turn_l
	jsr .irq_add_ms
	sta in_turn_l
.irq_noj
	txa
	and #$20
	bne .irq_nok
	lda #1
	sta in_use
.irq_nok
	txa
	and #$02
	bne .irq_noi
	lda #1
	sta in_fire
.irq_noi

	; L (PA5 = $DF)
	lda #$df
	sta $dc00
	lda $dc01
	and #$04
	bne .irq_nol
	lda in_turn_r
	jsr .irq_add_ms
	sta in_turn_r
.irq_nol

	; W / A / S (PA1 = $FD)
	lda #$fd
	sta $dc00
	lda $dc01
	tax
	and #$02
	bne .irq_now
	lda in_fwd
	jsr .irq_add_ms
	sta in_fwd
.irq_now
	txa
	and #$04
	bne .irq_noa
	lda in_strafel
	jsr .irq_add_ms
	sta in_strafel
.irq_noa
	txa
	and #$20
	bne .irq_nos
	lda in_back
	jsr .irq_add_ms
	sta in_back
.irq_nos

	; D (PA2 = $FB)
	lda #$fb
	sta $dc00
	lda $dc01
	and #$04
	bne .irq_nod
	lda in_strafer
	jsr .irq_add_ms
	sta in_strafer
.irq_nod

	lda #$7f
	sta $dc00
	lda $dc0d				; ack Timer A
	pla
	tay
	pla
	tax
	pla
	rti

; A = counter → A = min(A + SAMPLE_MS, 255)
.irq_add_ms
	clc
	adc #SAMPLE_MS
	bcc .irq_add_ok
	lda #255
.irq_add_ok
	rts

; ------------------------------------------------------------------
; read_input — snapshot IRQ accumulators; build turn + wish from hold ms
; ------------------------------------------------------------------
read_input
	lda #0
	sta turn
	sta wish_x_l
	sta wish_x_h
	sta wish_y_l
	sta wish_y_h

	sei
	lda in_use
	sta key_use
	lda in_fire
	sta key_fire
	lda in_turn_l
	sta tmp3
	lda in_turn_r
	sta tmp4
	lda in_fwd
	pha
	lda in_back
	pha
	lda in_strafel
	pha
	lda in_strafer
	pha
	lda #0
	sta in_turn_l
	sta in_turn_r
	sta in_fwd
	sta in_back
	sta in_strafel
	sta in_strafer
	sta in_use
	sta in_fire
	cli

	; --- turn: net hold ms (right − left) ---
	lda tmp4
	cmp tmp3
	beq .turn_done
	bcs .turn_right
	; left wins: vel = left − right
	lda tmp3
	sec
	sbc tmp4
	sta vel_ms
	jsr turn_deliver
	eor #$ff
	clc
	adc #1
	sta turn
	jmp .turn_done
.turn_right
	lda tmp4
	sec
	sbc tmp3
	sta vel_ms
	jsr turn_deliver
	sta turn
.turn_done

	; stack: strafer, strafel, back, fwd (top = strafer)
	pla					; strafer
	beq .no_d
	sta vel_ms
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
	pla					; strafel
	beq .no_a
	sta vel_ms
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
	pla					; back
	beq .no_s
	sta vel_ms
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
	pla					; fwd
	beq .no_w
	sta vel_ms
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
	rts

; turn_acc += vel_ms<<6; A = turn_acc>>10; turn_acc &= $03FF
turn_deliver
	lda #0
	sta tmp1
	lda vel_ms
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
	rol tmp1				; tmp = vel_ms * 64
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

; A = signed sintab → scale (A * vel_ms) >> 5 → add into wish_x
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

; A = signed unit → tmp0/tmp1 = (A * vel_ms) >>> 5 (arithmetic)
scale_vel
	sta tmp2
	bpl .sv_abs
	eor #$ff
	clc
	adc #1
.sv_abs
	tay
	lda vel_ms
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
