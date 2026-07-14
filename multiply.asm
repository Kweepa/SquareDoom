!zone multiply

; Judd/Arndt square tables in unused RAM ($C000–$C7FF), filled at runtime
SQTAB1 = $c000
SQTAB2 = $c200
SQTAB3 = $c400
SQTAB4 = $c600

; Build square tables and set ZP pointer highs.
; From https://6502.org/source/integers/fastmult.htm (Martin Arndt / Stephen Judd)
init_sqtabs
	ldx #0
	stx SQTAB3 + $fe
	stx SQTAB4 + $fe
	ldy #$ff
.loop1
	txa
	lsr
	clc
	adc SQTAB3 + $fe,x
	sta SQTAB1,x
	sta SQTAB3 + $ff,x
	sta SQTAB3,y
	lda #0
	adc SQTAB4 + $fe,x
	sta SQTAB2,x
	sta SQTAB4 + $ff,x
	sta SQTAB4,y
	dey
	inx
	bne .loop1
.loop2
	txa
	sec
	ror
	clc
	adc SQTAB1 + $ff,x
	sta SQTAB1 + $100,x
	lda #0
	adc SQTAB2 + $ff,x
	sta SQTAB2 + $100,x
	inx
	bne .loop2

	lda #>SQTAB1
	sta sq1_h
	lda #>SQTAB2
	sta sq2_h
	lda #>SQTAB3
	sta sq3_h
	lda #>SQTAB4
	sta sq4_h
	rts

; Unsigned 8×8 → 16. Y = factor1, A = factor2 → X=lo A=hi
mul_8x8
	sta sq1_l
	sta sq2_l
	eor #$ff
	sta sq3_l
	sta sq4_l
	sec
	lda (sq1_l),y
	sbc (sq3_l),y
	tax
	lda (sq2_l),y
	sbc (sq4_l),y
	rts

; Keep API: aux * A → A=lo X=hi (middle 16 of 24-bit product).
; Old Keep mul_16x8 did EOR #$FF then a shift-add that yields mid(aux * original_A).
; Old Keep mul_16x8_eor skipped that EOR (A already complemented) → mid(aux * (A^$FF)).
mul_16x8
	sta mul_fac
	jmp .mid
mul_16x8_eor
	eor #$ff
	sta mul_fac
.mid
	; mid = hi8(aux_l * fac) + (aux_h * fac)
	ldy mul_fac
	lda aux_l
	jsr mul_8x8
	sta tmp1			; hi(aux_l * fac)
	ldy mul_fac
	lda aux_h
	jsr mul_8x8
	sta tmp3			; hi(aux_h * fac)
	stx tmp2			; lo(aux_h * fac)
	clc
	lda tmp1
	adc tmp2
	tay				; result lo
	lda tmp3
	adc #0
	tax				; result hi
	tya
	rts
