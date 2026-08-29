!zone enemy_low

; ============================================================================
; enemy_low.asm — E1M8 boss death → forever floors; explosions (barrels + rockets)
; (lives in low for mid headroom). Baron hook from enemy_mid .ed_kill.
; ============================================================================

BARREL_FUSE_TIME = 3			; overlay frames until detonation
EXPLOSION_TIME = 2
EXPLOSION_SPLASH = 8			; world units (1 tile)

; boss_* / barrel_events — cassette scrap BSS (zeropage.asm)

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
; FX overlay (cassette): fuse / explosion sprites, not the item layer
; ---------------------------------------------------------------------------
fx_clear
	ldx #0
	lda #0
.fxc
	sta FX_KIND,x
	inx
	cpx #FX_MAX
	bcc .fxc
	rts

; mapx/mapy → C=0 X=index if an overlay occupies that tile
fx_find
	ldx #0
.fxf
	lda FX_KIND,x
	beq .fxf_nx
	lda FX_TX,x
	cmp mapx
	bne .fxf_nx
	lda FX_TY,x
	cmp mapy
	bne .fxf_nx
	clc
	rts
.fxf_nx
	inx
	cpx #FX_MAX
	bcc .fxf
	sec
	rts

fx_alloc
	ldx #0
.fxa
	lda FX_KIND,x
	beq .fxa_got
	inx
	cpx #FX_MAX
	bcc .fxa
	sec
	rts
.fxa_got
	clc
	rts

; Light a barrel fuse at mapx/mapy (no-op if already fused / overlay full)
fx_fuse_at
	jsr fx_find
	bcc .fxu_rts
	jsr fx_alloc
	bcs .fxu_rts
	lda #FX_FUSE
	sta FX_KIND,x
	lda mapx
	sta FX_TX,x
	lda mapy
	sta FX_TY,x
	lda #BARREL_FUSE_TIME
	sta FX_TIME,x
	inc barrel_events
.fxu_rts
	rts

; ---------------------------------------------------------------------------
; explosion_near_mobj — X = mobj; C=0 if within EXPLOSION_SPLASH of save_xh/yh
; ---------------------------------------------------------------------------
explosion_near_mobj
	lda MOBJ_X,x
	sec
	sbc save_xh
	bcs .eny_ax
	eor #$ff
	adc #1
.eny_ax
	cmp #EXPLOSION_SPLASH+1
	bcs .eny_out
	lda MOBJ_Y,x
	sec
	sbc save_yh
	bcs .eny_ay
	eor #$ff
	adc #1
.eny_ay
	cmp #EXPLOSION_SPLASH+1
	rts
.eny_out
	sec
	rts

; ---------------------------------------------------------------------------
; explode_tile — mapx/mapy = blast tile (barrel or rocket).
; Overlay explosion sprite; splash enemies; fuse neighbour barrels (3×3).
; ---------------------------------------------------------------------------
explode_tile
	jsr item_tile_xy
	lda tmp0
	sta save_xh
	lda tmp1
	sta save_yh
	; drop barrel from the layer if present
	jsr item_layer_id
	cmp #ITEM_TYPE_BARREL
	bne .bex_fx
	lda #0
	sta (ptr_l),y
.bex_fx
	; reuse overlay on this tile, else alloc
	jsr fx_find
	bcc .bex_set
	jsr fx_alloc
	bcs .bex_sfx			; full — still splash
.bex_set
	lda #FX_EXPL
	sta FX_KIND,x
	lda mapx
	sta FX_TX,x
	lda mapy
	sta FX_TY,x
	lda #EXPLOSION_TIME
	sta FX_TIME,x
	inc barrel_events
.bex_sfx
	lda #SOUND_BAREXP
	jsr play_sound
	ldx #0
.bex_mobj
	lda MOBJ_ALLOC,x
	beq .bex_mn
	lda MOBJ_INFO,x
	cmp #MOBJINFO_IMPSHOT
	bcs .bex_mn
	jsr explosion_near_mobj
	bcs .bex_mn
	stx tmp5
	jsr GetRandom8
	and #31
	clc
	adc #16
	ldx tmp5
	jsr enemy_damage
	ldx tmp5
.bex_mn
	inx
	cpx #MOBJ_PLAYER_ROCKET
	bcc .bex_mobj
	; 3×3 layer neighbourhood (skip center)
	lda mapx
	sta tmp4
	lda mapy
	sta tmp5
	lda tmp5
	sec
	sbc #1
	sta mapy
	ldy #3
.bex_yy
	lda tmp4
	sec
	sbc #1
	sta mapx
	ldx #3
.bex_xx
	lda mapx
	cmp #MAP_SIZE
	bcs .bex_xn
	lda mapy
	cmp #MAP_SIZE
	bcs .bex_xn
	lda mapx
	cmp tmp4
	bne .bex_chk
	lda mapy
	cmp tmp5
	beq .bex_xn
.bex_chk
	stx tmp2
	sty tmp3
	jsr item_layer_id
	cmp #ITEM_TYPE_BARREL
	bne .bex_rst
	jsr fx_fuse_at
.bex_rst
	ldx tmp2
	ldy tmp3
.bex_xn
	inc mapx
	dex
	bne .bex_xx
	inc mapy
	dey
	bne .bex_yy
	lda tmp4
	sta mapx
	lda tmp5
	sta mapy
	rts

; ---------------------------------------------------------------------------
; barrel_update — overlay fuse countdown + explosion lifetime
; ---------------------------------------------------------------------------
barrel_update
	lda barrel_events
	bne .bu_go
	rts
.bu_go
	ldx #0
.bu_lp
	lda FX_KIND,x
	beq .bu_nx
	cmp #FX_FUSE
	beq .bu_fuse
	cmp #FX_EXPL
	bne .bu_nx
	dec FX_TIME,x
	bne .bu_nx
	lda #0
	sta FX_KIND,x
	dec barrel_events
	jmp .bu_nx
.bu_fuse
	dec FX_TIME,x
	bne .bu_nx
	stx tmp2
	lda FX_TX,x
	sta mapx
	lda FX_TY,x
	sta mapy
	lda #0
	sta FX_KIND,x
	dec barrel_events			; fuse consumed
	jsr explode_tile
	ldx tmp2
.bu_nx
	inx
	cpx #FX_MAX
	bcc .bu_lp
	rts
