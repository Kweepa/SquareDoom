!zone gameloop

gameloop
.frame
	jsr calc_frame_dt
	jsr read_input
	clc
	lda playera
	adc turn
	sta playera
	jsr apply_move
	jsr update_eye
	jsr render
	jmp .frame
