!zone level

; ---------------------------------------------------------------------------
; start_level — bind player/enemies/HUD to the loaded map
; ---------------------------------------------------------------------------
start_level
	jsr proc_init
	jsr find_spawn
	jsr enemy_alloc_all
	jsr init_hud_state
	lda #$ff
	sta last_playera			; force rebuild_col_rays
	jsr build_sec_flatgrp
	jsr player_tile
	jsr map_sector_id
	sta player_prev_sec
	jsr update_eye
	rts

; Default status values
init_hud_state
	lda #50
	sta ammo
	lda #100
	sta health
	lda #0
	sta armor
	sta keys
	sta info_ms_l
	sta info_ms_h
	sta info_len
	sta has_backpack
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
update_eye
	jsr player_tile
	jsr map_sector_id
	beq .ue_empty
	tax
	lda SEC_FLOOR,x
	clc
	adc #3
	sta eyeheight
	rts
.ue_empty
	lda #11
	sta eyeheight
	rts

; ---------------------------------------------------------------------------
; build_sec_flatgrp — SEC_FLATGRP[id] = group of identical floor/ceil/colours/bright
;
; Once at level load. Door / elevator sectors and any SEC_TARGET id get a
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
	; Mark mutables: DOOR/ELEVATOR types and every SEC_TARGET → SEC_SEEN[$ff]
	ldx #1
.bf_mark
	lda SEC_TARGET,x
	beq .bf_mdoor
	tay
	lda #$ff
	sta SEC_SEEN,y
.bf_mdoor
	lda SEC_TYPE,x
	cmp #DOOR_TYPE
	beq .bf_mut
	cmp #ELEVATOR_LOWER_TYPE
	beq .bf_mut
	cmp #ELEVATOR_RAISE_TYPE
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
