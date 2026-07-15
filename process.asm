!zone process

; SoA thinkers: TIMER, RAISE/LOWER_CEIL, RAISE/LOWER_FLOOR.
; Door use: K + NESW neighbour within 2 world units of the shared face.
; Absolute JMPs used where relative branches would exceed ±127.

DOOR_OPEN_GAP = 5
DOOR_RECLOSE_MS_L = <5000
DOOR_RECLOSE_MS_H = >5000
MOTION_STEP_MS = 128			; 1 height unit per 128 ms

; Clear all process slots
proc_init
	ldx #0
	lda #PROC_FREE
.pi
	sta PROC_KIND,x
	inx
	cpx #PROC_NUM
	bne .pi
	rts

; Find free slot → C=0 Y=index; C=1 none
proc_find_free
	ldy #0
.pff
	lda PROC_KIND,y
	beq .pff_ok
	iny
	cpy #PROC_NUM
	bne .pff
	sec
	rts
.pff_ok
	clc
	rts

; Alloc: tmp0=kind tmp1=A tmp2=B tmp3=C tmp4=D → C=0 Y=slot; C=1 fail
proc_alloc
	jsr proc_find_free
	bcs .pa_fail
	lda tmp0
	sta PROC_KIND,y
	lda tmp1
	sta PROC_A,y
	lda tmp2
	sta PROC_B,y
	lda tmp3
	sta PROC_C,y
	lda tmp4
	sta PROC_D,y
	clc
.pa_fail
	rts

; C=1 if any live proc has PROC_A == tmp1 (sector)
proc_sector_busy
	ldx #0
.psb
	lda PROC_KIND,x
	beq .psb_next
	lda PROC_A,x
	cmp tmp1
	beq .psb_yes
.psb_next
	inx
	cpx #PROC_NUM
	bne .psb
	clc
	rts
.psb_yes
	sec
	rts

; Count free slots → A
proc_count_free
	ldx #0
	lda #0
	sta tmp0
.pcf
	lda PROC_KIND,x
	bne .pcf_next
	inc tmp0
.pcf_next
	inx
	cpx #PROC_NUM
	bne .pcf
	lda tmp0
	rts

; local axis → tmp0=tile-local hi (0..7), tmp1=frac
.tu_get_x
	lda playerx_h
	and #7
	sta tmp0
	lda playerx
	sta tmp1
	rts

.tu_get_y
	lda playery_h
	and #7
	sta tmp0
	lda playery
	sta tmp1
	rts

; C=1 if local ≤ 2.0 (near low face)
.tu_near_lo
	lda tmp0
	cmp #3
	bcs .tnl_no
	cmp #2
	bcc .tnl_yes
	lda tmp1
	bne .tnl_no
.tnl_yes
	sec
	rts
.tnl_no
	clc
	rts

; C=1 if local ≥ 6.0 (near high face at 8)
.tu_near_hi
	lda tmp0
	cmp #6
	bcc .tnh_no
	sec
	rts
.tnh_no
	clc
	rts

; ------------------------------------------------------------------
; try_use — K held: NESW neighbour door within 2u → raise + reclose timer
; ------------------------------------------------------------------
try_use
	lda key_use
	bne .tu_go
.tu_far
	rts
.tu_go
	jsr player_tile

	; Snap playera to NESW: (a+32)>>6 → 0=N 1=E 2=S 3=W
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

	cmp #0
	beq .tu_n
	cmp #1
	beq .tu_e
	cmp #2
	beq .tu_s
	jmp .tu_w

.tu_n
	jsr .tu_get_y
	jsr .tu_near_lo
	bcs .tu_n_ok
	jmp .tu_far
.tu_n_ok
	lda mapy
	bne .tu_n_map
	jmp .tu_far
.tu_n_map
	sec
	sbc #1
	sta mapy
	jmp .tu_have_cell

.tu_e
	jsr .tu_get_x
	jsr .tu_near_hi
	bcs .tu_e_ok
	jmp .tu_far
.tu_e_ok
	lda mapx
	cmp #MAP_SIZE - 1
	bcc .tu_e_map
	jmp .tu_far
.tu_e_map
	clc
	adc #1
	sta mapx
	jmp .tu_have_cell

.tu_s
	jsr .tu_get_y
	jsr .tu_near_hi
	bcs .tu_s_ok
	jmp .tu_far
.tu_s_ok
	lda mapy
	cmp #MAP_SIZE - 1
	bcc .tu_s_map
	jmp .tu_far
.tu_s_map
	clc
	adc #1
	sta mapy
	jmp .tu_have_cell

.tu_w
	jsr .tu_get_x
	jsr .tu_near_lo
	bcs .tu_w_ok
	jmp .tu_far
.tu_w_ok
	lda mapx
	bne .tu_w_map
	jmp .tu_far
.tu_w_map
	sec
	sbc #1
	sta mapx

.tu_have_cell
	jsr sector_at_map
	bne .tu_got_id
	jmp .tu_far
.tu_got_id
	sta tmp1
	tax
	lda SEC_TYPE,x
	cmp #DOOR_TYPE
	beq .tu_is_door
	jmp .tu_far
.tu_is_door
	lda SEC_FLOOR,x
	clc
	adc #DOOR_OPEN_GAP
	sta tmp0
	lda SEC_CEIL,x
	cmp tmp0
	bcc .tu_closed
	jmp .tu_far
.tu_closed
	jsr proc_sector_busy
	bcc .tu_free
	jmp .tu_far
.tu_free
	jsr proc_count_free
	cmp #2
	bcs .tu_slots
	jmp .tu_far
.tu_slots
	ldx tmp1
	lda SEC_FLOOR,x
	clc
	adc #DOOR_OPEN_GAP
	sta tmp2
	lda #PROC_RAISE_CEIL
	sta tmp0
	lda #0
	sta tmp3
	sta tmp4
	jsr proc_alloc
	bcc .tu_got_raise
	jmp .tu_far
.tu_got_raise
	lda #PROC_TIMER
	sta tmp0
	lda #PROC_LOWER_CEIL
	sta tmp2
	lda #DOOR_RECLOSE_MS_L
	sta tmp3
	lda #DOOR_RECLOSE_MS_H
	sta tmp4
	jmp proc_alloc

; ------------------------------------------------------------------
; proc_update — tick all slots
; ------------------------------------------------------------------
proc_update
	ldx #0
.pu_loop
	lda PROC_KIND,x
	beq .pu_next
	cmp #PROC_TIMER
	beq .pu_timer
	cmp #PROC_RAISE_CEIL
	beq .pu_raise_c
	cmp #PROC_LOWER_CEIL
	beq .pu_lower_c
	cmp #PROC_RAISE_FLOOR
	beq .pu_raise_f_j
	cmp #PROC_LOWER_FLOOR
	bne .pu_next
	jmp .pu_lower_f
.pu_raise_f_j
	jmp .pu_raise_f
.pu_next
	inx
	cpx #PROC_NUM
	bne .pu_loop
	rts

.pu_to_next
	jmp .pu_next

.pu_timer
	lda PROC_C,x
	sec
	sbc dt_ms
	sta PROC_C,x
	lda PROC_D,x
	sbc #0
	sta PROC_D,x
	bcc .pu_tim_fire
	ora PROC_C,x
	bne .pu_to_next
.pu_tim_fire
	lda PROC_A,x
	sta tmp1
	lda PROC_B,x
	sta tmp0
	lda #PROC_FREE
	sta PROC_KIND,x
	lda #0
	sta tmp2
	sta tmp3
	sta tmp4
	stx tmp5
	jsr proc_alloc
	ldx tmp5
	jmp .pu_next

.pu_raise_c
	jsr .pu_accum
	bcc .pu_to_next
	ldy PROC_A,x
	lda SEC_CEIL,y
	cmp PROC_B,x
	bcs .pu_raise_c_done
	clc
	adc #1
	sta SEC_CEIL,y
	cmp PROC_B,x
	bcc .pu_to_next
.pu_raise_c_done
	lda #PROC_FREE
	sta PROC_KIND,x
	jmp .pu_next

.pu_lower_c
	stx tmp5
	jsr player_tile
	jsr map_sector_id
	ldx tmp5
	cmp PROC_A,x
	beq .pu_next_far
	jsr .pu_accum
	bcc .pu_next_far
	ldy PROC_A,x
	lda SEC_CEIL,y
	cmp SEC_FLOOR,y
	beq .pu_lower_c_done
	bcc .pu_lower_c_done
	sec
	sbc #1
	sta SEC_CEIL,y
	cmp SEC_FLOOR,y
	bne .pu_next_far
.pu_lower_c_done
	lda #PROC_FREE
	sta PROC_KIND,x
	jmp .pu_next

.pu_raise_f
	jsr .pu_accum
	bcc .pu_next_far
	ldy PROC_A,x
	lda SEC_FLOOR,y
	cmp PROC_B,x
	bcs .pu_raise_f_done
	clc
	adc #1
	sta SEC_FLOOR,y
	cmp PROC_B,x
	bcc .pu_next_far
.pu_raise_f_done
	lda #PROC_FREE
	sta PROC_KIND,x
	jmp .pu_next

.pu_lower_f
	jsr .pu_accum
	bcc .pu_next_far
	ldy PROC_A,x
	lda SEC_FLOOR,y
	cmp PROC_B,x
	beq .pu_lower_f_done
	bcc .pu_lower_f_done
	sec
	sbc #1
	sta SEC_FLOOR,y
	cmp PROC_B,x
	bne .pu_next_far
.pu_lower_f_done
	lda #PROC_FREE
	sta PROC_KIND,x
	jmp .pu_next

.pu_next_far
	jmp .pu_next

; Add dt_ms to accum; if ≥ MOTION_STEP_MS subtract and C=1 else C=0
.pu_accum
	lda PROC_C,x
	clc
	adc dt_ms
	sta PROC_C,x
	lda PROC_D,x
	adc #0
	sta PROC_D,x
	lda PROC_C,x
	cmp #MOTION_STEP_MS
	lda PROC_D,x
	sbc #0
	bcc .pua_no
	lda PROC_C,x
	sec
	sbc #MOTION_STEP_MS
	sta PROC_C,x
	lda PROC_D,x
	sbc #0
	sta PROC_D,x
	sec
	rts
.pua_no
	clc
	rts
