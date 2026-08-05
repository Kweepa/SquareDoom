!zone hitscan

; ============================================================================
; hitscan.asm — one claim per enemy_think frame for possessed LOS
; Request: if hs_claimed already → fail; else take slot (overwrite stale).
; Process: TheKeep sdx/sdy DDA (same as render_dda, no fish/clip/paint).
; ============================================================================

HS_IDLE = 0
HS_PENDING = 1
HS_CLEAR = 2
HS_BLOCKED = 3
HS_MAX_STEPS = 32

; hs_* BSS — under-stack scrap (zeropage.asm)

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
; hitscan_process — TheKeep DDA march (one axis per step); portal/Z only
; ---------------------------------------------------------------------------
hitscan_process
	lda hs_status
	cmp #HS_PENDING
	beq .hp_go
	rts
.hp_go
	; Start / end tiles
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
	sta hs_endx
	lda hs_y1
	lsr
	lsr
	lsr
	sta hs_endy

	lda mapx
	cmp hs_endx
	bne .hp_setup
	lda mapy
	cmp hs_endy
	bne .hp_setup
	jmp .hp_clear			; same tile (should be rare; same-sec early out)

.hp_setup
	; Tile 8.8 frac from integer world: (world & 7) << 5
	lda hs_x0
	and #7
	asl
	asl
	asl
	asl
	asl
	sta fracx
	eor #$ff
	sta fracx_inv
	lda hs_y0
	and #7
	asl
	asl
	asl
	asl
	asl
	sta fracy
	eor #$ff
	sta fracy_inv

	jsr map_sector_id
	sta cur_id

	; Signed world delta → xstep/ystep + abs
	lda hs_x1
	sec
	sbc hs_x0
	sta tmp0			; dx
	bcs .hp_xpos
	lda #$ff
	sta xstep
	lda tmp0
	eor #$ff
	adc #1
	sta hs_absx
	jmp .hp_dy
.hp_xpos
	beq .hp_x0
	lda #1
	sta xstep
	lda tmp0
	sta hs_absx
	jmp .hp_dy
.hp_x0
	lda #0
	sta xstep
	sta hs_absx
.hp_dy
	lda hs_y1
	sec
	sbc hs_y0
	sta tmp0			; dy
	bcs .hp_ypos
	lda #$ff
	sta ystep
	lda tmp0
	eor #$ff
	adc #1
	sta hs_absy
	jmp .hp_tdelta
.hp_ypos
	beq .hp_y0
	lda #1
	sta ystep
	lda tmp0
	sta hs_absy
	jmp .hp_tdelta
.hp_y0
	lda #0
	sta ystep
	sta hs_absy
.hp_tdelta
	; Z edge count = |tile_dx| + |tile_dy|
	lda hs_endx
	sec
	sbc mapx
	bcs .hp_txp
	eor #$ff
	adc #1
.hp_txp
	sta hs_steps
	lda hs_endy
	sec
	sbc mapy
	bcs .hp_typ
	eor #$ff
	adc #1
.hp_typ
	clc
	adc hs_steps
	sta hs_steps
	bne .hp_zinit
	lda #1
	sta hs_steps
.hp_zinit
	lda hs_z0
	sta hs_z
	lda hs_z1
	sec
	sbc hs_z0
	bcs .hp_zdpos
	eor #$ff
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
	lda #HS_MAX_STEPS
	sta hs_count			; countdown — dec/bmi at each step

	; Axis-aligned: unused axis s = $ffff so the other always wins
	lda xstep
	bne .hp_hasx
	lda #$ff
	sta sdx_l
	sta sdx_h
	jmp .hp_cky
.hp_hasx
	lda ystep
	bne .hp_both
	; X only — ddx = fixsec[0], first-hit from frac
	lda fixsecl
	sta ddx_l
	lda fixsech
	sta ddx_h
	lda xstep
	bmi .hp_xraw
	lda fracx_inv
	jsr calc_sdx
	jmp .hp_yinf
.hp_xraw
	lda fracx
	jsr calc_sdx
.hp_yinf
	lda #$ff
	sta sdy_l
	sta sdy_h
	jmp .hp_loop
.hp_cky
	lda ystep
	bne .hp_yonly
	jmp .hp_clear			; both zero — same point
.hp_yonly
	lda fixsecl
	sta ddy_l
	lda fixsech
	sta ddy_h
	lda ystep
	bmi .hp_yraw
	lda fracy_inv
	jsr calc_sdy
	jmp .hp_loop
.hp_yraw
	lda fracy
	jsr calc_sdy
	jmp .hp_loop

.hp_both
	; TheKeep angle from octant + fine = absy*64/(absx+absy)
	ldy hs_absy
	lda #64
	jsr mul_8x8			; X=lo A=hi
	stx aux_l
	sta aux_h
	lda hs_absx
	clc
	adc hs_absy
	bne .hp_div
	lda #32
	bne .hp_fine
.hp_div
	jsr udiv16x8
	cmp #64
	bcc .hp_fine
	lda #63
.hp_fine
	sta tmp0			; fine 0..63
	; Pack into TheKeep `angle` (same ranges as rebuild_col_rays steps)
	lda xstep
	bmi .hp_xw
	lda ystep
	bmi .hp_se
	; NE: angle = fine
	lda tmp0
	jmp .hp_ang
.hp_se
	; SE: angle = fine - 64
	lda tmp0
	clc
	adc #$c0
	jmp .hp_ang
.hp_xw
	lda ystep
	bmi .hp_sw
	; NW: angle = 64 + fine
	lda tmp0
	clc
	adc #64
	jmp .hp_ang
.hp_sw
	; SW: angle = $80 + fine
	lda tmp0
	clc
	adc #$80
.hp_ang
	sta angle
	; ddx = fixsec[fold(angle)]
	jsr .hs_fold_sec
	tay
	lda fixsecl,y
	sta ddx_l
	lda fixsech,y
	sta ddx_h
	; ddy = fixsec[fold(angle+64)]
	lda angle
	clc
	adc #64
	jsr .hs_fold_sec
	tay
	lda fixsecl,y
	sta ddy_l
	lda fixsech,y
	sta ddy_h
	; First-hit s (same preamble as cast_column)
	lda xstep
	bmi .hp_xm
	lda fracx_inv
	jsr calc_sdx
	jmp .hp_ym
.hp_xm
	lda fracx
	jsr calc_sdx
.hp_ym
	lda ystep
	bmi .hp_ymr
	lda fracy_inv
	jsr calc_sdy
	jmp .hp_loop
.hp_ymr
	lda fracy
	jsr calc_sdy

; ---- march (render_dda .inner shape) ----
.hp_loop
	lda mapx
	cmp hs_endx
	bne .hp_step
	lda mapy
	cmp hs_endy
	bne .hp_step
	jmp .hp_clear
.hp_step
	dec hs_count
	bpl .hp_ok
	jmp .hp_block
.hp_ok
	; nearer of sdx/sdy (tie → Y)
	lda sdx_h
	cmp sdy_h
	bcc .hp_advx
	bne .hp_advy
	lda sdx_l
	cmp sdy_l
	bcs .hp_advy

.hp_advx
	clc
	lda mapx
	adc xstep
	sta mapx
	cmp #32
	bcc .hp_axok
	jmp .hp_block
.hp_axok
	clc
	lda sdx_l
	adc ddx_l
	sta sdx_l
	lda sdx_h
	adc ddx_h
	sta sdx_h
	jmp .hp_cell

.hp_advy
	clc
	lda mapy
	adc ystep
	sta mapy
	cmp #32
	bcc .hp_ayok
	jmp .hp_block
.hp_ayok
	clc
	lda sdy_l
	adc ddy_l
	sta sdy_l
	lda sdy_h
	adc ddy_h
	sta sdy_h

.hp_cell
	; Z toward target
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
	jmp .hp_block
.hp_got
	sta next_id
	cmp cur_id
	beq .hp_same

	; Portal opening at z
	ldx cur_id
	lda SEC_FLOOR,x
	sta near_floor
	lda SEC_CEIL,x
	sta near_ceil
	ldx next_id
	lda SEC_FLOOR,x
	sta far_floor
	lda SEC_CEIL,x
	sta far_ceil
	lda near_floor
	cmp far_floor
	bcs .hp_mf
	lda far_floor
.hp_mf
	cmp hs_z
	bcc .hp_floork
	jmp .hp_block
.hp_floork
	lda near_ceil
	cmp far_ceil
	bcc .hp_mc
	lda far_ceil
.hp_mc
	cmp hs_z
	beq .hp_ceilb
	bcc .hp_ceilb
	lda next_id
	sta cur_id
	jmp .hp_loop
.hp_ceilb
	jmp .hp_block

.hp_same
	ldx cur_id
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

; A&127 → fixsec index 0..63
.hs_fold_sec
	and #127
	cmp #63
	bcc .hs_fsok
	eor #127
.hs_fsok
	rts
