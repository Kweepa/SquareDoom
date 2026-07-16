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
