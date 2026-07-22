!zone gameloop

gameloop
.frame
	lda end_level
	beq .gl_play
	jmp after_level_end
.gl_play
	jsr gameloop_check_esc
	jsr player_frame
	jsr calc_frame_dt
	jsr read_input
	clc
	lda playera
	adc turn
	sta playera
	jsr apply_move
	jsr try_walk_elevator
	jsr try_pickups
	jsr try_use
	jsr try_end_switch
	jsr proc_update
	jsr update_info_msg
	jsr update_eye
	jsr render
	; After render so TryDamageEnemy sees this frame's COL_AIM_*
	jsr update_muzzle_flash
	jsr hitscan_process
	jsr enemy_think
	jmp .frame
