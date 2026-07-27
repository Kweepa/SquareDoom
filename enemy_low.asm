!zone enemy_low

; ============================================================================
; enemy_low.asm — E1M8 boss death → forever floors; exploding barrels
; (lives in low for mid headroom). Baron hook from enemy_mid .ed_kill.
; ============================================================================

BARREL_FUSE = $83			; bit7 lit + 3-frame countdown
BARREL_SPLASH = 8			; world units (1 tile)
MAX_PLACEABLE_ITEMS = 46		; slots 0..45 (46/47 reserved)

boss_floors_done	!byte 0
boss_scan_sec	!byte 0

; e1m8_baron_kill_hook — after any kill; if last baron on E1M8, lower floors
e1m8_baron_kill_hook
	lda enemy_info
	cmp #MOBJINFO_BARON
	bne .e1h_rts
	lda level_num
	cmp #8
	bne .e1h_rts
	; fall through
; e1m8_check_barons_dead — if no live barons remain, lower forever floors
e1m8_check_barons_dead
	ldx #0
.e1b_lp
	lda MOBJ_ALLOC,x
	beq .e1b_nx
	lda MOBJ_INFO,x
	cmp #MOBJINFO_BARON
	bne .e1b_nx
	lda MOBJ_HEALTH,x
	bne .e1h_rts			; still one alive
.e1b_nx
	inx
	cpx #MAX_MOBJ
	bcc .e1b_lp
	jmp boss_lower_forever_floors
.e1h_rts
	rts

; boss_lower_forever_floors — lower every forever+none sector (self). Once/level.
boss_lower_forever_floors
	lda boss_floors_done
	bne .blf_rts
	lda #1
	sta boss_floors_done
	ldx #1
.blf_lp
	stx boss_scan_sec
	jsr sec_trigger
	cmp #TRIG_NONE
	bne .blf_nx
	ldx boss_scan_sec
	jsr sec_action
	cmp #ACT_LOWER_FLOOR_FOREVER
	bne .blf_nx
	ldx boss_scan_sec
	stx tmp1
	lda #0
	sta elev_mode
	jsr elevator_find_dest
	sta elev_dest
	ldx tmp1
	jsr forever_adopt_nb
	lda elev_dest
	sta tmp2
	jsr floor_forever_activate
.blf_nx
	ldx boss_scan_sec
	cpx level_sector_max
	bcs .blf_rts
	inx
	bne .blf_lp
.blf_rts
	rts

; ---------------------------------------------------------------------------
; barrel_near_y — Y = item slot; C=0 if within BARREL_SPLASH of save_xh/yh
; ---------------------------------------------------------------------------
barrel_near_y
	lda level_item_x,y
	sec
	sbc save_xh
	bpl .bny_ax
	eor #$ff
	clc
	adc #1
.bny_ax
	cmp #BARREL_SPLASH+1
	bcs .bny_out
	lda level_item_y,y
	sec
	sbc save_yh
	bpl .bny_ay
	eor #$ff
	clc
	adc #1
.bny_ay
	cmp #BARREL_SPLASH+1
	rts
.bny_out
	sec
	rts

; ---------------------------------------------------------------------------
; barrel_explode — X = barrel item slot
; barexpl for 2 display frames; splash enemies; fuse neighbour barrels.
; ---------------------------------------------------------------------------
barrel_explode
	lda #ITEM_TYPE_BAREXPL
	sta level_item_type,x
	lda #2
	sta level_item_meta,x
	stx tmp4
	lda level_item_x,x
	sta save_xh
	lda level_item_y,x
	sta save_yh
	lda #SOUND_SHOTGN
	jsr play_sound
	ldx #0
.bex_mobj
	lda MOBJ_ALLOC,x
	beq .bex_mn
	lda MOBJ_INFO,x
	cmp #MOBJINFO_IMPSHOT
	bcs .bex_mn
	ldy MOBJ_OBJ,x
	jsr barrel_near_y
	bcs .bex_mn
	stx tmp5
	sty tmp3
	jsr GetRandom8
	and #31
	adc #16
	ldx tmp3
	jsr enemy_damage
	ldx tmp5
.bex_mn
	inx
	cpx #MOBJ_PLAYER_ROCKET
	bcc .bex_mobj
	ldx #0
.bex_item
	cpx tmp4
	beq .bex_in
	lda level_item_type,x
	cmp #ITEM_TYPE_BARREL
	bne .bex_in
	lda level_item_meta,x
	bmi .bex_in
	txa
	tay
	jsr barrel_near_y
	bcs .bex_in
	lda #BARREL_FUSE
	sta level_item_meta,x
.bex_in
	inx
	cpx #MAX_PLACEABLE_ITEMS
	bcc .bex_item
	rts

; ---------------------------------------------------------------------------
; barrel_update — barexpl countdown + fused barrel detonation (after fire)
; ---------------------------------------------------------------------------
barrel_update
	ldx #0
.bu_lp
	lda level_item_type,x
	cmp #ITEM_TYPE_BAREXPL
	beq .bu_expl
	cmp #ITEM_TYPE_BARREL
	bne .bu_nx
	lda level_item_meta,x
	bpl .bu_nx
	dec level_item_meta,x
	lda level_item_meta,x
	cmp #$80
	bne .bu_nx
	stx tmp2
	jsr barrel_explode
	ldx tmp2
	jmp .bu_nx
.bu_expl
	lda level_item_meta,x
	beq .bu_clr
	dec level_item_meta,x
	jmp .bu_nx
.bu_clr
	lda #ITEM_TYPE_EMPTY_E
	sta level_item_type,x
.bu_nx
	inx
	cpx #MAX_PLACEABLE_ITEMS
	bcc .bu_lp
	rts
