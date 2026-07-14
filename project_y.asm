!zone project_y

; Project world height → screen row (Keep-style texstep walk from HORIZON).
; On entry A = world y. Signed Δh = height − eyeheight:
;   Δh > 0 → walk up  (DEX): lo DECs remaining Δh to 0
;   Δh < 0 → walk down (INX): lo INCs remaining Δh to 0
;   Δh = 0 → HORIZON
; Hybrid: lo paths never take |Δh| (DEC/INC signed remaining). Hi / one-step
; need a positive target for CMP — going_up already has one; going_down pays
; abs once into tmp1 only when texstep_h ≠ 0.
; tmp3 = signed remaining (lo). tmp1 = |Δh| (hi-down only). Lo: A = acc_l.
project_y
	sec
	sbc eyeheight
	beq .py_at_eye
	bmi .py_going_down
	jmp .py_going_up

.py_at_eye
	lda #HORIZON
	sta py_row
	rts

	; ----- Δh < 0 -----
.py_going_down
	sta tmp3
	lda texstep_h
	beq .py_lo_going_down
	lda tmp3
	eor #$ff
	clc
	adc #1
	sta tmp1				; |Δh| once for one-step + hi
	lda texstep_h
	cmp tmp1
	bcc .py_hi_going_down
	ldx #HORIZON
	inx
	jmp .py_store_row

.py_hi_going_down
	lda #0
	sta acc_l
	sta acc_h
	ldx #HORIZON
.py_hi_going_down_lp
	cpx #25
	beq .py_store_row
	inx
	clc
	lda acc_l
	adc texstep_l
	sta acc_l
	lda acc_h
	adc texstep_h
	sta acc_h
	cmp tmp1				; same cheap test as going_up
	bcc .py_hi_going_down_lp
	bcs .py_store_row

.py_lo_going_down
	ldx #HORIZON
	lda #0
.py_lo_going_down_lp
	cpx #25
	beq .py_store_row
	inx
	clc
	adc texstep_l
	bcc .py_lo_going_down_lp
	inc tmp3
	bne .py_lo_going_down_lp
	beq .py_store_row

	; ----- Δh > 0 -----
.py_going_up
	sta tmp3
	lda texstep_h
	beq .py_lo_going_up
	cmp tmp3
	bcc .py_hi_going_up
	ldx #HORIZON
	dex
	jmp .py_store_row

.py_hi_going_up
	lda #0
	sta acc_l
	sta acc_h
	ldx #HORIZON
.py_hi_going_up_lp
	cpx #0
	beq .py_store_row
	dex
	clc
	lda acc_l
	adc texstep_l
	sta acc_l
	lda acc_h
	adc texstep_h
	sta acc_h
	cmp tmp3
	bcc .py_hi_going_up_lp
	bcs .py_store_row

.py_lo_going_up
	ldx #HORIZON
	lda #0
.py_lo_going_up_lp
	cpx #0
	beq .py_store_row
	dex
	clc
	adc texstep_l
	bcc .py_lo_going_up_lp
	dec tmp3
	bne .py_lo_going_up_lp
	; fall through

.py_store_row
	stx py_row
	rts
