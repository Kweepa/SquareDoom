!zone project_y

; Count screen rows until tex covers |Δh| (Keep-style yloop).
; Walk from HORIZON: ceil DEX / floor INX each add; stop at coverage or screen edge (0 / 25).
; Simplified lo path: A contains acc_l throughout loop, Y=|Δh| countdown on carry.
; On entry A = world y to project
project_y
	sec
	sbc eyeheight
	sta tmp1
	lda #0
	sta tmp2
	lda tmp1
	bpl .pyp
	eor #$ff
	clc
	adc #1
	sta tmp1
	lda #1
	sta tmp2
.pyp
	lda tmp1
	bne .py_nz
	jmp .py_zero			; height == eye → horizon
.py_nz
	sta tmp3			; target = |Δh|

	lda texstep_h
	cmp tmp3
	bcc .py_sum
	; n=1: one screen step from horizon
	ldx #HORIZON
	lda tmp2
	bne .py_n1_dn
	dex
	jmp .py_have_row
.py_n1_dn
	inx
	jmp .py_have_row

.py_sum
	lda tmp2
	bne .py_dn				; below eye → floor
	; ----- ceiling: walk X down from HORIZON -----
	lda texstep_h
	beq .py_lo_up
	lda #0
	sta acc_l
	sta acc_h
	ldx #HORIZON
.py_hi_up
	cpx #0
	beq .py_have_row
	dex
	clc
	lda acc_l
	adc texstep_l
	sta acc_l
	lda acc_h
	adc texstep_h
	sta acc_h
	cmp tmp3
	bcc .py_hi_up
	bcs .py_have_row

.py_lo_up
	ldx #HORIZON
	ldy tmp3
	lda #0					; acc_l
.py_lo_up_lp
	cpx #0
	beq .py_have_row
	dex
	clc
	adc texstep_l
	bcc .py_lo_up_lp
	dey
	bne .py_lo_up_lp
	beq .py_have_row

	; ----- floor: walk X up from HORIZON -----
.py_dn
	lda texstep_h
	beq .py_lo_dn
	lda #0
	sta acc_l
	sta acc_h
	ldx #HORIZON
.py_hi_dn
	cpx #25
	beq .py_have_row
	inx
	clc
	lda acc_l
	adc texstep_l
	sta acc_l
	lda acc_h
	adc texstep_h
	sta acc_h
	cmp tmp3
	bcc .py_hi_dn
	bcs .py_have_row

.py_lo_dn
	ldx #HORIZON
	ldy tmp3
	lda #0
.py_lo_dn_lp
	cpx #25
	beq .py_have_row
	inx
	clc
	adc texstep_l
	bcc .py_lo_dn_lp
	dey
	bne .py_lo_dn_lp
	; fall through

.py_have_row
	stx py_row
	rts

.py_zero
	lda #HORIZON
	sta py_row
	rts

