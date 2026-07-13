!zone gameloop

gameloop
.frame
	jsr read_input
	clc
	lda playera
	adc turn
	sta playera
	jsr update_eye
	jsr render
	jmp .frame
