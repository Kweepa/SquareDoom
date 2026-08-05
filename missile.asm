!zone missile

; ============================================================================
; missile.asm — player rocket + enemy fireball/plasma flight
; Dt-scaled at 2 tiles/sec; substeps ≤~3 wu; wall push before impact FX.
; ============================================================================

MAX_PROJ_STEP_MS = 188		; ~3 world units @ 2 tiles/sec
PROJ_LIFE_MS = 16000		; ~32 tiles of flight at 2 tiles/sec
PROJ_NUDGE_MS = 25		; spawn look-ahead (clears player center)

; ---------------------------------------------------------------------------
; BSS — under-stack scrap (zeropage.asm)
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; proj_scale_vel — A = sintab amp; vel_ms set → tmp0/tmp1 at 2 tiles/sec
; (walk scale_vel is 1 tile/sec; ASL doubles).
; ---------------------------------------------------------------------------
proj_scale_vel
	jsr scale_vel
	asl tmp0
	rol tmp1
	rts

; ---------------------------------------------------------------------------
; Missile_TryMove — wish_x/y delta; C=1 ok C=0 blocked (restore)
; ---------------------------------------------------------------------------
missile_try_move
	jsr obj_xy
	lda tmp0
	lsr
	lsr
	lsr
	sta mapx
	sta tmp4
	lda tmp1
	lsr
	lsr
	lsr
	sta mapy
	sta tmp5
	ldx enemy_actor
	lda MOBJ_XFRAC,x
	sta save_xl
	lda tmp0
	sta save_xh
	lda MOBJ_YFRAC,x
	sta save_yl
	lda tmp1
	sta save_yh
	; X += wish_x
	clc
	lda MOBJ_XFRAC,x
	adc wish_x_l
	sta MOBJ_XFRAC,x
	lda tmp0
	adc wish_x_h
	sta tmp0
	; Y += wish_y
	clc
	lda MOBJ_YFRAC,x
	adc wish_y_l
	sta MOBJ_YFRAC,x
	lda tmp1
	adc wish_y_h
	sta tmp1
	jsr obj_set_xy
	; tile check (dest + diagonal corner cells)
	lda tmp0
	lsr
	lsr
	lsr
	sta mapx
	lda tmp1
	lsr
	lsr
	lsr
	sta mapy
	; both axes changed tile → require ortho corners open
	lda mapx
	cmp tmp4
	beq .mtm_dest
	lda mapy
	cmp tmp5
	beq .mtm_dest
	; corner (new_x, old_y)
	lda tmp5
	sta mapy
	jsr sector_at_map
	jsr missile_tile_blocked
	bcs .mtm_block
	; corner (old_x, new_y)
	lda tmp4
	sta mapx
	lda tmp1
	lsr
	lsr
	lsr
	sta mapy
	jsr sector_at_map
	jsr missile_tile_blocked
	bcs .mtm_block
	; restore dest map tile
	lda tmp0
	lsr
	lsr
	lsr
	sta mapx
.mtm_dest
	jsr sector_at_map
	jsr missile_tile_blocked
	bcc .mtm_ok
.mtm_block
	ldx enemy_actor
	lda save_xl
	sta MOBJ_XFRAC,x
	lda save_yl
	sta MOBJ_YFRAC,x
	lda save_xh
	sta tmp0
	lda save_yh
	sta tmp1
	jsr obj_set_xy
	clc
	rts
.mtm_ok
	sec
	rts

; A = sector id → C=1 blocked (void / closed door only; no floor steps)
missile_tile_blocked
	beq .mtb_yes
	tax
	lda SEC_CEIL,x
	sec
	sbc SEC_FLOOR,x
	cmp #4
	bcc .mtb_yes
	clc
	rts
.mtb_yes
	sec
	rts

; ---------------------------------------------------------------------------
; missile_push_walls — snap local 2..5.5 from impassable neighbors (missile rules)
; Expects enemy_obj / enemy_actor; clobbers tmp0–5, mapx/y.
; ---------------------------------------------------------------------------
missile_push_walls
	jsr obj_xy
	lda tmp0
	lsr
	lsr
	lsr
	sta mapx
	sta tmp4
	lda tmp1
	lsr
	lsr
	lsr
	sta mapy
	sta tmp5

	; West: neighbor (mapx-1, mapy)
.mpw_west
	lda tmp4
	sec
	sbc #1
	sta mapx
	lda tmp5
	sta mapy
	jsr sector_at_map
	jsr missile_tile_blocked
	bcc .mpw_east
	lda tmp0
	and #7
	cmp #2
	bcs .mpw_east			; local_x >= 2 — leave frac alone
	lda tmp4
	asl
	asl
	asl
	ora #2
	sta tmp0
	ldx enemy_actor
	lda #$80
	sta MOBJ_XFRAC,x

.mpw_east
	lda tmp4
	clc
	adc #1
	sta mapx
	lda tmp5
	sta mapy
	jsr sector_at_map
	jsr missile_tile_blocked
	bcc .mpw_north
	lda tmp0
	and #7
	cmp #6
	bcs .mpw_e_push			; local_x >= 6 → snap to 5.5
	cmp #5
	bcc .mpw_north			; local_x <= 4 — ok
	ldx enemy_actor
	lda MOBJ_XFRAC,x
	cmp #$81
	bcc .mpw_north			; local 5.0..5.5 — ok
.mpw_e_push
	lda tmp4
	asl
	asl
	asl
	ora #5
	sta tmp0
	ldx enemy_actor
	lda #$80
	sta MOBJ_XFRAC,x

.mpw_north
	lda tmp4
	sta mapx
	lda tmp5
	sec
	sbc #1
	sta mapy
	jsr sector_at_map
	jsr missile_tile_blocked
	bcc .mpw_south
	lda tmp1
	and #7
	cmp #2
	bcs .mpw_south
	lda tmp5
	asl
	asl
	asl
	ora #2
	sta tmp1
	ldx enemy_actor
	lda #$80
	sta MOBJ_YFRAC,x

.mpw_south
	lda tmp4
	sta mapx
	lda tmp5
	clc
	adc #1
	sta mapy
	jsr sector_at_map
	jsr missile_tile_blocked
	bcc .mpw_done
	lda tmp1
	and #7
	cmp #6
	bcs .mpw_s_push
	cmp #5
	bcc .mpw_done
	ldx enemy_actor
	lda MOBJ_YFRAC,x
	cmp #$81
	bcc .mpw_done
.mpw_s_push
	lda tmp5
	asl
	asl
	asl
	ora #5
	sta tmp1
	ldx enemy_actor
	lda #$80
	sta MOBJ_YFRAC,x
.mpw_done
	jmp obj_set_xy

; ---------------------------------------------------------------------------
; missile_scale_mom — A = signed delta, span_a = dist ≥ 1
; → wish_x = (delta * 64) / dist as signed 8.8 (sintab-amp; lo=0)
; ---------------------------------------------------------------------------
missile_scale_mom
	sta tmp2
	lda #0
	sta aux_l
	sta aux_h
	lda tmp2
	bpl .msm_abs
	eor #$ff
	clc
	adc #1
.msm_abs
	sta aux_l
	; *64
	asl aux_l
	rol aux_h
	asl aux_l
	rol aux_h
	asl aux_l
	rol aux_h
	asl aux_l
	rol aux_h
	asl aux_l
	rol aux_h
	asl aux_l
	rol aux_h
	lda span_a
	jsr udiv16x8
	sta wish_x_h
	lda #0
	sta wish_x_l
	lda tmp2
	bpl .msm_rts
	lda #0
	sec
	sbc wish_x_l
	sta wish_x_l
	lda #0
	sbc wish_x_h
	sta wish_x_h
.msm_rts
	rts

; ---------------------------------------------------------------------------
; spawn_enemy_missile — aim from current enemy_actor toward player
; ---------------------------------------------------------------------------
spawn_enemy_missile
	; Aim like hitscan: (x0,y0,z0=floor+2) → (player, eyeheight)
	jsr obj_sector
	tay
	lda SEC_FLOOR,y
	clc
	adc #2
	sta missile_z
	lda #0
	sta missile_zfrac
	lda eyeheight
	sec
	sbc missile_z
	sta tmp4				; dz (signed)
	jsr obj_xy
	lda playerx_h
	sec
	sbc tmp0
	sta fracy				; dx
	lda playery_h
	sec
	sbc tmp1
	sta fracx				; dy
	lda fracy
	sta tmp0
	lda fracx
	sta tmp1
	jsr p_approx_distance
	bne .sem_dnz
	lda #1
.sem_dnz
	sta span_a
	lda fracy
	jsr missile_scale_mom
	lda wish_x_l
	sta missile_momx_l
	lda wish_x_h
	sta missile_momx_h
	lda fracx
	jsr missile_scale_mom
	lda wish_x_l
	sta missile_momy_l
	lda wish_x_h
	sta missile_momy_h
	lda tmp4
	jsr missile_scale_mom
	lda wish_x_l
	sta missile_momz_l
	lda wish_x_h
	sta missile_momz_h
	jsr obj_xy
	lda enemy_info
	cmp #MOBJINFO_BARON
	bne .sem_fb
	lda #ITEM_TYPE_PLASMABALL
	bne .sem_type
.sem_fb
	lda #ITEM_TYPE_FIREBALL
.sem_type
	sta level_item_type + ITEM_MISSILE
	lda tmp0
	sta level_item_x + ITEM_MISSILE
	lda tmp1
	sta level_item_y + ITEM_MISSILE
	ldx #ITEM_MISSILE
	jsr item_refresh_sector
	ldx #MOBJ_MISSILE
	lda #1
	sta MOBJ_ALLOC,x
	lda #ITEM_MISSILE
	sta MOBJ_OBJ,x
	txa
	sta MOBJ_FOR_ITEM + ITEM_MISSILE
	lda #MOBJINFO_IMPSHOT
	sta MOBJ_INFO,x
	lda #STATE_IMPSHOTFLY
	sta MOBJ_STATE,x
	lda #0
	sta MOBJ_XFRAC,x
	sta MOBJ_YFRAC,x
	sta MOBJ_FLAGS,x
	lda #<PROJ_LIFE_MS
	sta missile_life_l
	lda #>PROJ_LIFE_MS
	sta missile_life_h
	lda enemy_info
	cmp #MOBJINFO_IMP
	bne .sem_caco
	lda #10
	bne .sem_hp
.sem_caco
	lda #30
.sem_hp
	sta MOBJ_HEALTH,x
	rts

; ---------------------------------------------------------------------------
; spawn_player_rocket — along look. C=0 spawned, C=1 busy/fail.
; ---------------------------------------------------------------------------
spawn_player_rocket
	lda MOBJ_ALLOC + MOBJ_PLAYER_ROCKET
	bne .spr_busy
	lda level_item_type + ITEM_PLAYER_ROCKET
	cmp #ITEM_TYPE_EMPTY_E
	beq .spr_ok
.spr_busy
	sec
	rts
.spr_ok
	lda playerx_h
	sta level_item_x + ITEM_PLAYER_ROCKET
	lda playery_h
	sta level_item_y + ITEM_PLAYER_ROCKET
	lda #ITEM_TYPE_ROCKET
	sta level_item_type + ITEM_PLAYER_ROCKET
	lda eyeheight
	sec
	sbc #1
	sta procket_z
	lda #0
	sta procket_zfrac
	sta procket_momz_l
	sta procket_momz_h
	sta procket_momx_l
	sta procket_momy_l
	; mom hi = sintab amp (2 tiles/sec via proj_scale_vel)
	ldy playera
	lda sintab,y
	sta procket_momx_h
	ldy playera
	lda costab,y
	jsr neg_a
	sta procket_momy_h
	ldx #MOBJ_PLAYER_ROCKET
	lda #1
	sta MOBJ_ALLOC,x
	lda #ITEM_PLAYER_ROCKET
	sta MOBJ_OBJ,x
	txa
	sta MOBJ_FOR_ITEM + ITEM_PLAYER_ROCKET
	lda #MOBJINFO_IMPSHOT
	sta MOBJ_INFO,x
	lda #STATE_IMPSHOTFLY
	sta MOBJ_STATE,x
	lda playerx
	sta MOBJ_XFRAC,x
	lda playery
	sta MOBJ_YFRAC,x
	lda #<PROJ_LIFE_MS
	sta procket_life_l
	lda #>PROJ_LIFE_MS
	sta procket_life_h
	lda #0
	sta MOBJ_FLAGS,x
	; small look-ahead along aim (dt-scaled nudge)
	lda #PROJ_NUDGE_MS
	sta vel_ms
	lda procket_momx_h
	jsr proj_scale_vel
	ldx #MOBJ_PLAYER_ROCKET
	clc
	lda MOBJ_XFRAC,x
	adc tmp0
	sta MOBJ_XFRAC,x
	lda level_item_x + ITEM_PLAYER_ROCKET
	adc tmp1
	sta level_item_x + ITEM_PLAYER_ROCKET
	lda procket_momy_h
	jsr proj_scale_vel
	ldx #MOBJ_PLAYER_ROCKET
	clc
	lda MOBJ_YFRAC,x
	adc tmp0
	sta MOBJ_YFRAC,x
	lda level_item_y + ITEM_PLAYER_ROCKET
	adc tmp1
	sta level_item_y + ITEM_PLAYER_ROCKET
	ldx #ITEM_PLAYER_ROCKET
	jsr item_refresh_sector
	clc
	rts

; ---------------------------------------------------------------------------
; a_fly — dispatch player rocket vs enemy missile
; ---------------------------------------------------------------------------
a_fly
	ldx enemy_actor
	cpx #MOBJ_PLAYER_ROCKET
	bne .afy_enemy
	lda #1
	sta proj_mode
	jmp proj_fly
.afy_enemy
	lda #0
	sta proj_mode
	; fall through
; ---------------------------------------------------------------------------
; proj_fly — dt-scaled substeps; mode in proj_mode
; ---------------------------------------------------------------------------
proj_fly
	; lifetime
	lda proj_mode
	bne .pf_life_rok
	lda missile_life_l
	sec
	sbc dt_ms
	sta tmp0
	lda missile_life_h
	sbc #0
	bcs .pf_life_ok_m
	jmp .pf_impact
.pf_life_ok_m
	sta missile_life_h
	lda tmp0
	sta missile_life_l
	jmp .pf_start
.pf_life_rok
	lda procket_life_l
	sec
	sbc dt_ms
	sta tmp0
	lda procket_life_h
	sbc #0
	bcs .pf_life_ok_r
	jmp .pf_impact
.pf_life_ok_r
	sta procket_life_h
	lda tmp0
	sta procket_life_l
.pf_start
	lda dt_ms
	bne .pf_got_dt
	lda #1
.pf_got_dt
	sta proj_rem_dt
.pf_loop
	lda proj_rem_dt
	bne .pf_have_rem
	rts
.pf_have_rem
	; step = min(rem, MAX_PROJ_STEP_MS) — keep ≤~3 wu at 2 tiles/sec
	cmp #MAX_PROJ_STEP_MS + 1
	bcc .pf_step_ok
	lda #MAX_PROJ_STEP_MS
.pf_step_ok
	sta vel_ms
	sta proj_step_ms
	; hit-test at current pose
	lda proj_mode
	bne .pf_hit_rok
	jsr missile_try_hit_player
	bcc .pf_scale
	jmp .pf_impact_hit
.pf_hit_rok
	jsr procket_try_hit
	bcc .pf_scale
	jmp .pf_impact
.pf_scale
	; wish XY = proj_scale_vel(dir, step); Z after successful move
	lda #0
	sta wish_x_l
	sta wish_x_h
	sta wish_y_l
	sta wish_y_h
	lda proj_mode
	bne .pf_sc_rok
	lda missile_momx_h
	jsr proj_scale_vel
	lda tmp0
	sta wish_x_l
	lda tmp1
	sta wish_x_h
	lda missile_momy_h
	jsr proj_scale_vel
	lda tmp0
	sta wish_y_l
	lda tmp1
	sta wish_y_h
	jmp .pf_move
.pf_sc_rok
	lda procket_momx_h
	jsr proj_scale_vel
	lda tmp0
	sta wish_x_l
	lda tmp1
	sta wish_x_h
	lda procket_momy_h
	jsr proj_scale_vel
	lda tmp0
	sta wish_y_l
	lda tmp1
	sta wish_y_h
.pf_move
	jsr missile_try_move
	bcs .pf_moved
	jmp .pf_impact
.pf_moved
	; Z step then floor / ceil
	lda proj_step_ms
	sta vel_ms
	lda proj_mode
	bne .pf_z_rok
	lda missile_momz_h
	jsr proj_scale_vel
	clc
	lda missile_zfrac
	adc tmp0
	sta missile_zfrac
	lda missile_z
	adc tmp1
	sta missile_z
	jsr obj_sector
	bne .pf_sec_m
	jmp .pf_impact
.pf_sec_m
	tax
	lda SEC_FLOOR,x
	cmp missile_z
	bcc .pf_fl_m
	jmp .pf_impact
.pf_fl_m
	lda SEC_CEIL,x
	cmp missile_z
	beq .pf_imp_j
	bcc .pf_imp_j
	jmp .pf_adv
.pf_imp_j
	jmp .pf_impact
.pf_z_rok
	lda procket_momz_h
	jsr proj_scale_vel
	clc
	lda procket_zfrac
	adc tmp0
	sta procket_zfrac
	lda procket_z
	adc tmp1
	sta procket_z
	jsr obj_sector
	bne .pf_sec_r
	jmp .pf_impact
.pf_sec_r
	tax
	lda SEC_FLOOR,x
	cmp procket_z
	bcc .pf_fl_r
	jmp .pf_impact
.pf_fl_r
	lda SEC_CEIL,x
	cmp procket_z
	beq .pf_imp_j
	bcc .pf_imp_j
.pf_adv
	lda proj_rem_dt
	sec
	sbc proj_step_ms
	sta proj_rem_dt
	jmp .pf_loop

.pf_impact_hit
	; enemy missile scored a direct hit — damage then despawn
	ldx enemy_actor
	lda MOBJ_HEALTH,x
	sta tmp0
	jsr GetRandom8
	and #15
	clc
	adc tmp0
	jsr damage_player
	jmp missile_despawn

.pf_impact
	jsr missile_push_walls
	lda proj_mode
	bne .pf_rok_boom
	; enemy missile: splash if still near player
	jsr calc_enemy_dist
	lda enemy_dist
	cmp #4
	bcs missile_despawn
	ldx enemy_actor
	lda MOBJ_HEALTH,x
	sta tmp0
	jsr GetRandom8
	and #15
	clc
	adc tmp0
	jsr damage_player
	; fall through
missile_despawn
	lda #ITEM_TYPE_EMPTY_E
	sta level_item_type + ITEM_MISSILE
	lda #$ff
	sta MOBJ_FOR_ITEM + ITEM_MISSILE
	ldx #MOBJ_MISSILE
	lda #0
	sta MOBJ_ALLOC,x
	rts

.pf_rok_boom
	lda #$ff
	sta MOBJ_FOR_ITEM + ITEM_PLAYER_ROCKET
	ldx #MOBJ_PLAYER_ROCKET
	lda #0
	sta MOBJ_ALLOC,x
	ldx #ITEM_PLAYER_ROCKET
	jmp explode

; ---------------------------------------------------------------------------
; missile_try_hit_player — C=1 if enemy missile near player (XY+Z)
; ---------------------------------------------------------------------------
missile_try_hit_player
	jsr calc_enemy_dist
	lda enemy_dist
	cmp #3
	bcs .mth_no
	lda missile_z
	sec
	sbc eyeheight
	bcs .mth_zok
	eor #$ff
	adc #1
.mth_zok
	cmp #3
	bcs .mth_no
	sec
	rts
.mth_no
	clc
	rts

; ---------------------------------------------------------------------------
; procket_try_hit — C=1 if rocket near an enemy (XY + Z vs floor+2)
; ---------------------------------------------------------------------------
procket_try_hit
	lda level_item_x + ITEM_PLAYER_ROCKET
	sta save_xh
	lda level_item_y + ITEM_PLAYER_ROCKET
	sta save_yh
	ldx #0
.pth_lp
	lda MOBJ_ALLOC,x
	beq .pth_nx
	lda MOBJ_INFO,x
	cmp #MOBJINFO_IMPSHOT
	bcs .pth_nx
	ldy MOBJ_OBJ,x
	lda level_item_x,y
	sec
	sbc save_xh
	sta tmp0
	lda level_item_y,y
	sec
	sbc save_yh
	sta tmp1
	stx tmp5			; mobj idx
	jsr p_approx_distance
	cmp #3
	bcs .pth_rest
	; Z: |procket_z - (SEC_FLOOR+2)| < 3 (reload item; p_approx clobbers tmp*)
	ldx tmp5
	ldy MOBJ_OBJ,x
	lda level_item_x,y
	lsr
	lsr
	lsr
	sta mapx
	lda level_item_y,y
	lsr
	lsr
	lsr
	sta mapy
	jsr map_sector_id
	beq .pth_rest			; void — no height match
	tay
	lda SEC_FLOOR,y
	clc
	adc #2
	sec
	sbc procket_z
	bcs .pth_zpos
	eor #$ff
	adc #1
.pth_zpos
	cmp #3
	bcs .pth_rest
	sec
	rts
.pth_rest
	ldx tmp5
.pth_nx
	inx
	cpx #MOBJ_PLAYER_ROCKET
	bcc .pth_lp
	clc
	rts
