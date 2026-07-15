!zone project_y

; ============================================================================
; render_project_y.asm — PROFILE P (world height → screen row)
; ============================================================================
; TheKeep-style: walk texstep from HORIZON until |height − eyeheight| is
; covered, one screen row per successful step. Used only for flats/ledges
; (not solid wall strips). See learnings.txt for sum vs divide experiments.
;
; Entry: A = world height (0..31). Uses texstep_l/h from calc_wallz.
; Exit:  py_row = screen row 0..25. Must not clobber tmp4/tmp5 (portal).
;
; Paths:
;   Δh = 0     → HORIZON
;   Δh > 0     → walk up (DEX); lo: DEC signed remaining on carry
;   Δh < 0     → walk down (INX); lo: INC signed remaining on carry
;   texstep_h=0  → lo path (A = running acc_l)
;   texstep_h≠0  → hi / one-step (tmp1 = |Δh| when going down)
; ============================================================================

; ---------------------------------------------------------------------------
; project_y — A = world y → py_row
;
; tmp3 = signed remaining (lo). tmp1 = |Δh| (hi-down only). Lo loop: A=acc_l.
; ---------------------------------------------------------------------------
project_y
	sec
	sbc eyeheight			; A = signed Δh = height − eye
	beq .py_at_eye
	bmi .py_going_down
	jmp .py_going_up

.py_at_eye
	lda #HORIZON
	sta py_row
	rts

	; ----- Δh < 0: height below eye → walk screen downward (INX) -----
.py_going_down
	sta tmp3				; signed remaining (negative)
	lda texstep_h
	beq .py_lo_going_down
	lda tmp3
	eor #$ff
	clc
	adc #1
	sta tmp1				; |Δh| for one-step / hi compare
	lda texstep_h
	cmp tmp1					; same cheap test as going_up
	bcc .py_hi_going_down
	; texstep_h >= |Δh| → one row below horizon
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
	cmp tmp1				; stop when acc_h >= |Δh|
	bcc .py_hi_going_down_lp
	bcs .py_store_row

.py_lo_going_down
	; 8-bit texstep: A = acc_l; on carry, INC tmp3 toward 0
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

	; ----- Δh > 0: height above eye → walk screen upward (DEX) -----
.py_going_up
	sta tmp3				; positive remaining
	lda texstep_h
	beq .py_lo_going_up
	cmp tmp3
	bcc .py_hi_going_up
	; texstep_h >= Δh → one row above horizon
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
	cmp tmp3				; stop when acc_h >= Δh
	bcc .py_hi_going_up_lp
	bcs .py_store_row

.py_lo_going_up
	; On carry out of acc_l, DEC remaining until 0
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

.py_store_row
	stx py_row
	rts
