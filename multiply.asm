!zone multiply

mul_u8
	sta tmp3
	stx tmp4
	lda #0
	sta prodl
	sta prodh
	ldx #8
.mulo
	asl prodl
	rol prodh
	asl tmp4
	bcc .mu_skip
	clc
	lda prodl
	adc tmp3
	sta prodl
	lda prodh
	adc #0
	sta prodh
.mu_skip
	dex
	bne .mulo
	rts

; TheKeep: aux * A → A=lo X=hi (mid product)
mul_16x8
	eor #$ff
mul_16x8_eor
	lsr
	sta tmp0
	bcc .m16_0
	lda #0
	sta mac_h
	beq .m16_ent
.m16_0
	lda aux_h
	lsr
	sta mac_h
	lda aux_l
	ror
.m16_ent
	ldx #7
.m16_loop
	lsr tmp0
	bcc .m16_nop
	lsr mac_h
	bpl .m16_ror
.m16_nop
	adc aux_l
	tay
	lda mac_h
	adc aux_h
	ror
	sta mac_h
	tya
.m16_ror
	ror
	dex
	bne .m16_loop
	ldx mac_h
	rts
