!zone input

; CIA1: J = turn left (PA4/PB2), L = turn right (PA5/PB2)

TURN_SPEED = 3

read_input
	lda #0
	sta turn

	lda #$ff
	sta $dc02
	lda #0
	sta $dc03

	lda #$ef
	sta $dc00
	lda $dc01
	and #$04
	bne .no_j
	lda turn
	sec
	sbc #TURN_SPEED
	sta turn
.no_j
	lda #$df
	sta $dc00
	lda $dc01
	and #$04
	bne .no_l
	lda turn
	clc
	adc #TURN_SPEED
	sta turn
.no_l
	lda #$7f
	sta $dc00
	rts
