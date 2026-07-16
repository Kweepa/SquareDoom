!zone gameloop

gameloop
.frame
	jsr calc_frame_dt
	jsr read_input
	jsr update_muzzle_flash
	clc
	lda playera
	adc turn
	sta playera
	jsr apply_move
	jsr try_pickups
	jsr try_use
	jsr proc_update
	jsr update_info_msg
	jsr update_eye
	jsr render
	jsr enemy_think
	jmp .frame
