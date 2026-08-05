!zone level

; ---------------------------------------------------------------------------
; start_level — bind player/enemies/HUD to the loaded map
; ---------------------------------------------------------------------------
start_level
	jsr proc_init
	lda #0
	sta boss_floors_done
	jsr find_spawn
	jsr enemy_alloc_all
	jsr item_sector_cache_init
	jsr init_level_stats
	jsr init_hud_state
	lda #$ff
	sta last_playera			; force rebuild_col_rays
	jsr build_sec_flatgrp
	lda #$ff
	sta seen_gen			; first frame wraps, clears flat-group scratch, then uses 1
	jsr build_sec_wdark
	jsr flash_lights_init
	jsr clear_sector_visited		; automap fog starts cleared
	jsr player_tile
	jsr map_sector_id
	sta player_prev_sec
	jsr update_eye
	rts

; Default status values. health=0 (new game / death / menu restart) → full
; reset; else keep ammo, weapons, health, armor, backpack across maps.
init_hud_state
	lda health
	bne .ihs_carry
	lda #50
	sta ammo_bullets
	lda #0
	sta ammo_shells
	sta ammo_rockets
	lda #$02			; pistol owned (bit1)
	sta owned_weapons
	lda #100
	sta health
	lda #0
	sta armor
	sta combat_armor
	sta has_backpack
	; Force pistol defaults at level start
	lda #$ff
	sta cur_weapon
	ldx #2
	jsr switch_weapon
.ihs_carry
	lda #0
	sta keys
	sta info_ms_l
	sta info_ms_h
	sta info_len
	sta info_kind
	sta key_use_was
	sta radsuit_ms
	sta radsuit_ms + 1
	sta hurt_flash
	sta death_ms
	sta death_ms + 1
	lda #1
	sta hud_dirty
	rts

; Load player start from level_spawn (x, y, angle)
find_spawn
	lda level_spawn
	sta playerx_h
	lda level_spawn + 1
	sta playery_h
	lda level_spawn + 2
	sta playera
	lda #0
	sta playerx
	sta playery
	rts

; eyeheight = floor(sector at player) + 3
; Uses player_prev_sec from try_walk_into (same frame on alive path;
; death path does not move — cached id stays valid).
; Also patches project_y_sbc_eye immediate (project_y hot path).
update_eye
	lda player_prev_sec
	beq .ue_empty
	tax
	lda SEC_FLOOR,x
	clc
	adc #3
	sta eyeheight
	sta project_y_sbc_eye + 1
	rts
.ue_empty
	lda #11
	sta eyeheight
	sta project_y_sbc_eye + 1
	rts

; ---------------------------------------------------------------------------
; build_sec_flatgrp — SEC_FLATGRP[id] = group of identical floor/ceil/colours/bright
;
; Once at level load. Door / elevator / stairs sectors and any SEC_TARGET id get a
; unique group (their own id) so soft-portal matching never ties them to
; static rooms — floor/ceil motion does not require rebuilding this table.
; Void (id 0) is group 0. Clobbers: tmp0, X, Y, A; uses SEC_SEEN as scratch.
; ---------------------------------------------------------------------------
build_sec_flatgrp
	jsr clear_sector_seen		; SEC_SEEN = 0
	lda level_sector_max
	bne .bf_go
	rts
.bf_go
	; Mark mutables: door/floor/stairs actions and every SEC_TARGET → SEC_SEEN[$ff]
	ldx #1
.bf_mark
	lda SEC_TARGET,x
	beq .bf_mdoor
	tay
	lda #$ff
	sta SEC_SEEN,y
.bf_mdoor
	jsr sec_action
	cmp #ACT_OPEN_DOOR
	beq .bf_mut
	cmp #ACT_OPEN_DOOR_FOREVER
	beq .bf_mut
	cmp #ACT_OPEN_DOOR_10S
	beq .bf_mut
	cmp #ACT_OPEN_DOOR_30S
	beq .bf_mut
	cmp #ACT_LOWER_FLOOR
	beq .bf_mut
	cmp #ACT_LOWER_FLOOR_15S
	beq .bf_mut
	cmp #ACT_LOWER_FLOOR_FOREVER
	beq .bf_mut
	cmp #ACT_RAISE_FLOOR
	beq .bf_mut
	cmp #ACT_RAISE_STAIRS
	beq .bf_mut
	cmp #ACT_CONTINUE_STAIRS
	beq .bf_mut
	cmp #ACT_FLASH_LIGHTS
	beq .bf_mut
	cmp #ACT_OPEN_MONSTER_CLOSET
	beq .bf_mut
	jmp .bf_mnext
.bf_mut
	lda #$ff
	sta SEC_SEEN,x
.bf_mnext
	cpx level_sector_max
	bcs .bf_assign
	inx
	bne .bf_mark

.bf_assign
	lda #0
	sta SEC_FLATGRP			; void
	ldx #1
.bf_i
	lda SEC_SEEN,x
	bne .bf_new			; mutable → unique group = id
	stx tmp0
	ldy #1
	cpy tmp0
	bcs .bf_new
.bf_j
	lda SEC_SEEN,y
	bne .bf_jn			; never inherit from a mutable
	lda SEC_FLOOR,x
	cmp SEC_FLOOR,y
	bne .bf_jn
	lda SEC_CEIL,x
	cmp SEC_CEIL,y
	bne .bf_jn
	lda SEC_FCOL,x
	cmp SEC_FCOL,y
	bne .bf_jn
	lda SEC_CCOL,x
	cmp SEC_CCOL,y
	bne .bf_jn
	lda SEC_BRIGHT,x
	cmp SEC_BRIGHT,y
	bne .bf_jn
	lda SEC_FLATGRP,y
	sta SEC_FLATGRP,x
	jmp .bf_next
.bf_jn
	iny
	cpy tmp0
	bcc .bf_j
.bf_new
	txa
	sta SEC_FLATGRP,x
.bf_next
	cpx level_sector_max
	bcs .bf_wipe
	inx
	bne .bf_i
.bf_wipe
	jmp clear_sector_seen		; drop mark scratch before play
