!zone gameloop

gameloop
.frame
	lda end_level
	beq .gl_play
	jmp after_level_end
.gl_play
	lda health
	beq .gl_dead
	jsr gameloop_check_esc
	jsr player_frame
	jsr calc_frame_dt
	jsr update_map_time
	jsr read_input
	jsr gameloop_check_map
	sei
	clc
	lda playera
	adc turn
	clc
	adc mouse_turn
	sta playera
	lda #0
	sta mouse_turn
	cli
	jsr apply_move
	jsr try_walk_into
	jsr try_pickups
	jsr try_use
	jsr try_switch
	jmp .gl_world
.gl_dead
	jsr read_input			; need key_use for death confirm
	jsr player_death_frame		; may jmp next_level
.gl_world
	jsr proc_update
	jsr sector_specials_update
	jsr update_info_msg
	jsr update_eye
	jsr player_death_eye
	jsr render
	; After render so TryDamageEnemy sees this frame's COL_AIM_*
	lda health
	beq .gl_ai
	jsr update_muzzle_flash
	jsr hitscan_process
.gl_ai
	jsr enemy_think
	jsr barrel_update
	jmp .frame
