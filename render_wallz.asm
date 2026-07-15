!zone render_wallz

; PROFILE W — texstep from incremental fish-scaled wz (no mul)

; texstep = wz_{side} >> TEXSTEP_SHIFT (wz maintained in render_dda)
calc_wallz
	lda side
	bne .czy
	lda wz_x_l
	ldx wz_x_h
	jmp .czn
.czy
	lda wz_y_l
	ldx wz_y_h
.czn
	sta wallz_l
	stx wallz_h
	ora wallz_h
	bne .czok0
	lda #1
	sta wallz_l
.czok0
	lda wallz_l
	ldx wallz_h
	stx texstep_h
	ldy #TEXSTEP_SHIFT
.czs
	lsr texstep_h
	ror
	dey
	bne .czs
	sta texstep_l
	lda texstep_h
	ora texstep_l
	bne .czok
	lda #1
	sta texstep_l
.czok
	rts
