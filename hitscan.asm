!zone hitscan

; ============================================================================
; hitscan.asm — one claim per enemy_think frame for possessed LOS
; Request: if hs_claimed already → fail; else take slot (overwrite stale).
; Process walks map Bresenham with Z lerp; same sector → CLEAR immediately.
; ============================================================================

HS_IDLE = 0
HS_PENDING = 1
HS_CLEAR = 2
HS_BLOCKED = 3
HS_MAX_STEPS = 32

hs_status		!byte 0
hs_actor		!byte 0
hs_claimed		!byte 0		; 1 = someone already requested this think frame
hs_x0			!byte 0
hs_y0			!byte 0
hs_x1			!byte 0
hs_y1			!byte 0
hs_z0			!byte 0
hs_z1			!byte 0

; Process scratch (safe: only used in hitscan_process outside render)
hs_dx			!byte 0
hs_dy			!byte 0
hs_sx			!byte 0
hs_sy			!byte 0
hs_err_l		!byte 0
hs_err_h		!byte 0
hs_steps		!byte 0		; max(|dx|,|dy|) for Z Bresenham
hs_z			!byte 0
hs_zd			!byte 0		; |z1-z0|
hs_zs			!byte 0		; +1 / $ff
hs_zerr			!byte 0
hs_cur			!byte 0		; current sector id
hs_count		!byte 0

; ---------------------------------------------------------------------------
; hitscan_reset — idle slot (enemy_reset)
; ---------------------------------------------------------------------------
hitscan_reset
	lda #HS_IDLE
	sta hs_status
	lda #0
	sta hs_claimed
	lda #$ff
	sta hs_actor
	rts

; ---------------------------------------------------------------------------
; hitscan_frame — call once at start of enemy_think; opens a new claim window
; ---------------------------------------------------------------------------
hitscan_frame
	lda #0
	sta hs_claimed
	rts

; ---------------------------------------------------------------------------
; hitscan_request — X = enemy_actor
; If another enemy already claimed this frame → C=1 fail.
; Else take the slot (overwrite any stale PENDING/CLEAR/BLOCKED), C=0.
; Same sector → CLEAR now; else PENDING for hitscan_process.
; ---------------------------------------------------------------------------
hitscan_request
	lda hs_claimed
	bne .hr_busy
	inc hs_claimed
	stx hs_actor
	jsr obj_sector
	cmp player_sector
	bne .hr_snap
	lda #HS_CLEAR
	sta hs_status
	clc
	rts
.hr_snap
	tay
	lda SEC_FLOOR,y
	clc
	adc #2
	sta hs_z0
	ldy player_sector
	lda SEC_FLOOR,y
	clc
	adc #3
	sta hs_z1
	jsr obj_xy
	lda tmp0
	sta hs_x0
	lda tmp1
	sta hs_y0
	lda playerx_h
	sta hs_x1
	lda playery_h
	sta hs_y1
	lda #HS_PENDING
	sta hs_status
	clc
	rts
.hr_busy
	sec
	rts

; ---------------------------------------------------------------------------
; hitscan_release — free slot (after a_shoot / blocked miss)
; ---------------------------------------------------------------------------
hitscan_release
	lda #HS_IDLE
	sta hs_status
	lda #$ff
	sta hs_actor
	rts

; ---------------------------------------------------------------------------
; hitscan_process — at most one walk per frame; no-op unless PENDING
; ---------------------------------------------------------------------------
hitscan_process
	lda hs_status
	cmp #HS_PENDING
	beq .hp_go
	rts
.hp_go
	; map tiles
	lda hs_x0
	lsr
	lsr
	lsr
	sta mapx
	lda hs_y0
	lsr
	lsr
	lsr
	sta mapy
	lda hs_x1
	lsr
	lsr
	lsr
	sta tmp0			; endx
	lda hs_y1
	lsr
	lsr
	lsr
	sta tmp1			; endy

	jsr map_sector_id
	sta hs_cur
	lda hs_z0
	sta hs_z

	; dx/sx
	lda tmp0
	sec
	sbc mapx
	bcs .hp_dxpos
	eor #$ff
	clc
	adc #1
	sta hs_dx
	lda #$ff
	sta hs_sx
	bne .hp_dy
.hp_dxpos
	sta hs_dx
	lda #1
	sta hs_sx
.hp_dy
	lda tmp1
	sec
	sbc mapy
	bcs .hp_dypos
	eor #$ff
	clc
	adc #1
	sta hs_dy
	lda #$ff
	sta hs_sy
	bne .hp_err
.hp_dypos
	sta hs_dy
	lda #1
	sta hs_sy
.hp_err
	; err = dx - dy (signed 16-bit)
	lda hs_dx
	sec
	sbc hs_dy
	sta hs_err_l
	lda #0
	sbc #0
	sta hs_err_h
	; steps = max(dx,dy); if 0 → CLEAR (same tile; should not reach here)
	lda hs_dx
	cmp hs_dy
	bcs .hp_st
	lda hs_dy
.hp_st
	sta hs_steps
	bne .hp_zi_setup
	jmp .hp_clear
.hp_zi_setup
	; Z Bresenham setup
	lda hs_z1
	sec
	sbc hs_z0
	bcs .hp_zdpos
	eor #$ff
	clc
	adc #1
	sta hs_zd
	lda #$ff
	sta hs_zs
	bne .hp_zi
.hp_zdpos
	sta hs_zd
	lda #1
	sta hs_zs
.hp_zi
	lda #0
	sta hs_zerr
	sta hs_count

.hp_loop
	; reached end?
	lda mapx
	cmp tmp0
	bne .hp_step
	lda mapy
	cmp tmp1
	bne .hp_step
	jmp .hp_clear
.hp_step
	lda hs_count
	cmp #HS_MAX_STEPS
	bcc .hp_okcnt
	jmp .hp_block			; path too long — fail closed
.hp_okcnt
	; Bresenham step (may move X and/or Y)
	; e2 = 2*err
	lda hs_err_l
	asl
	sta tmp2
	lda hs_err_h
	rol
	sta tmp3

	; if e2 > -dy → step X  (signed: e2 + dy > 0)
	lda tmp2
	clc
	adc hs_dy
	sta tmp4
	lda tmp3
	adc #0
	bmi .hp_noy
	ora tmp4
	beq .hp_noy
	lda hs_err_l
	sec
	sbc hs_dy
	sta hs_err_l
	lda hs_err_h
	sbc #0
	sta hs_err_h
	clc
	lda mapx
	adc hs_sx
	sta mapx
.hp_noy
	; if e2 < dx → step Y
	lda tmp2
	cmp hs_dx
	lda tmp3
	sbc #0
	bpl .hp_nox
	lda hs_err_l
	clc
	adc hs_dx
	sta hs_err_l
	lda hs_err_h
	adc #0
	sta hs_err_h
	clc
	lda mapy
	adc hs_sy
	sta mapy
.hp_nox
	inc hs_count

	; bounds 0..31
	lda mapx
	cmp #32
	bcc .hp_xb
	jmp .hp_block
.hp_xb
	lda mapy
	cmp #32
	bcc .hp_yb
	jmp .hp_block
.hp_yb
	; advance Z toward z1 (one Bresenham tick per cell step)
	lda hs_zerr
	clc
	adc hs_zd
	sta hs_zerr
.hp_zlp
	lda hs_zerr
	cmp hs_steps
	bcc .hp_zdone
	sbc hs_steps
	sta hs_zerr
	clc
	lda hs_z
	adc hs_zs
	sta hs_z
	jmp .hp_zlp
.hp_zdone
	jsr map_sector_id
	bne .hp_got
	jmp .hp_block			; void / solid
.hp_got
	sta next_id
	cmp hs_cur
	beq .hp_same

	; Portal opening at z
	ldx hs_cur
	lda SEC_FLOOR,x
	sta near_floor
	lda SEC_CEIL,x
	sta near_ceil
	ldx next_id
	lda SEC_FLOOR,x
	sta far_floor
	lda SEC_CEIL,x
	sta far_ceil
	; max floor
	lda near_floor
	cmp far_floor
	bcs .hp_mf
	lda far_floor
.hp_mf
	cmp hs_z
	bcc .hp_floork
	jmp .hp_block			; z <= max_floor
.hp_floork
	; min ceil — need z < min_ceil
	lda near_ceil
	cmp far_ceil
	bcc .hp_mc
	lda far_ceil
.hp_mc
	cmp hs_z
	beq .hp_ceilb
	bcc .hp_ceilb
	lda next_id
	sta hs_cur
	jmp .hp_loop
.hp_ceilb
	jmp .hp_block

.hp_same
	; z must be strictly inside current sector
	ldx hs_cur
	lda SEC_FLOOR,x
	cmp hs_z
	bcc .hp_sf
	jmp .hp_block
.hp_sf
	lda SEC_CEIL,x
	cmp hs_z
	beq .hp_scb
	bcc .hp_scb
	jmp .hp_loop
.hp_scb
	jmp .hp_block

.hp_clear
	lda #HS_CLEAR
	sta hs_status
	rts
.hp_block
	lda #HS_BLOCKED
	sta hs_status
	rts
