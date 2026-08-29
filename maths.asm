!zone multiply

; Judd/Arndt square tables at SQTAB* ($BC00, always RAM)

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

; TheKeep API: aux * A → A=lo X=hi (middle 16 of 24-bit product).
; Used for mid(dd*fish) cache + initial wz = mid(s*fish).
mul_16x8
	sta sq1_l
	sta sq2_l
	eor #$ff
	sta sq3_l
	sta sq4_l
	ldy aux_l
	sec
	lda (sq1_l),y
	sbc (sq3_l),y
	lda (sq2_l),y
	sbc (sq4_l),y
	sta tmp1				; hi(aux_l * fac)
	ldy aux_h
	sec
	lda (sq1_l),y
	sbc (sq3_l),y
	sta tmp2				; lo(aux_h * fac)
	lda (sq2_l),y
	sbc (sq4_l),y
	sta tmp3				; hi(aux_h * fac)
	clc
	lda tmp1
	adc tmp2
	tay
	lda tmp3
	adc #0
	tax
	tya
	rts

; Column setup: mid(ddx * A) → sdx. A = fac.
calc_sdx
	sta sq1_l
	sta sq2_l
	eor #$ff
	sta sq3_l
	sta sq4_l
	ldy ddx_l
	sec
	lda (sq1_l),y
	sbc (sq3_l),y
	lda (sq2_l),y
	sbc (sq4_l),y
	sta tmp1
	ldy ddx_h
	sec
	lda (sq1_l),y
	sbc (sq3_l),y
	tax
	lda (sq2_l),y
	sbc (sq4_l),y
	sta sdx_h
	clc
	txa
	adc tmp1
	sta sdx_l
	bcc .csx
	inc sdx_h
.csx
	rts

; mid(ddy * A) → sdy
calc_sdy
	sta sq1_l
	sta sq2_l
	eor #$ff
	sta sq3_l
	sta sq4_l
	ldy ddy_l
	sec
	lda (sq1_l),y
	sbc (sq3_l),y
	lda (sq2_l),y
	sbc (sq4_l),y
	sta tmp1
	ldy ddy_h
	sec
	lda (sq1_l),y
	sbc (sq3_l),y
	tax
	lda (sq2_l),y
	sbc (sq4_l),y
	sta sdy_h
	clc
	txa
	adc tmp1
	sta sdy_l
	bcc .csy
	inc sdy_h
.csy
	rts

; ---------------------------------------------------------------------------
; mul_recip_z — A = signed v, X = depth z (1..255)
; Exit: A = clamp(v*32/z, -127..127)
; Uses recip_lo/hi (65536/z): result = (v * recip) >> 11.
; Larsson workstage / Andropolis-style reciprocal projection.
; Clobbers: tmp0..tmp4, Y
; ---------------------------------------------------------------------------
mul_recip_z
	sta tmp2				; signed v
	stx tmp3				; depth z (mul_8x8 clobbers X)
	lda #0
	sta tmp4				; sign flag
	lda tmp2
	bpl .mrz_abs
	eor #$ff
	clc
	adc #1
	sta tmp2
	inc tmp4
.mrz_abs
	; mid16 = (|v| * recip) >> 8 = hi(|v|*lo) + |v|*hi
	ldx tmp3
	ldy recip_lo,x
	lda tmp2
	jsr mul_8x8				; X=lo A=hi of |v|*recip_lo
	sta tmp0				; hi(|v|*lo)
	ldx tmp3
	ldy recip_hi,x
	lda tmp2
	jsr mul_8x8				; X=lo A=hi of |v|*recip_hi
	sta tmp1				; hi(|v|*hi)
	txa					; lo(|v|*hi)
	clc
	adc tmp0
	sta tmp0				; mid lo
	lda tmp1
	adc #0
	sta tmp1				; mid hi (= product >> 8)
	; >>3 more → product >> 11 = v*32/z
	lsr tmp1
	ror tmp0
	lsr tmp1
	ror tmp0
	lsr tmp1
	ror tmp0
	; clamp |result| to 127
	lda tmp1
	bne .mrz_sat			; ≥256 after >>11 → sat
	lda tmp0
	cmp #128
	bcc .mrz_ok
.mrz_sat
	lda #127
	sta tmp0
.mrz_ok
	lda tmp4
	beq .mrz_out
	lda tmp0
	eor #$ff
	clc
	adc #1
	rts
.mrz_out
	lda tmp0
	rts

