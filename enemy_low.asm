!zone enemy_low

; ============================================================================
; enemy_low.asm — E1M8 boss death → forever floors (lives in low for mid headroom)
; Called from enemy_mid .ed_kill via e1m8_baron_kill_hook.
; ============================================================================

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
