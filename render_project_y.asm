!zone project_y

; ============================================================================
; render_project_y.asm — PROFILE P (world height → screen row)
; ============================================================================
; Row offset from HORIZON is n = ceil(|Δh|·256 / texstep), clamped to the
; screen rails (12 rows up / 13 down). For texstep_h=0 that whole function
; is a lookup: py_tab[(|Δh|−1)·256 + texstep_l] = min(n,13) for |Δh| 1..12,
; and |Δh| ≥ 13 is always offscreen (ceil(13·256/255) = 14 > 13) → constant
; row 0 / 25. Table built by tools/genpytab.js; matches the old walk loops
; bit-for-bit. texstep_h≠0 keeps the hi / one-step walk (rare, short).
;
; Entry: A = world height (0..31). Uses texstep_l/h from calc_wallz.
; Exit:  A = py_row = screen row 0..25. Must not clobber tmp4/tmp5 (portal).
; ============================================================================

; ---------------------------------------------------------------------------
; project_y — A = world y → py_row (also returned in A)
;
; Fast path uses A/Y + SMC operand only. Hi paths: tmp3 = Δh (up),
; tmp1 = |Δh| (down); acc_l/h walk as before.
; ---------------------------------------------------------------------------
project_y
	sec
	sbc eyeheight			; A = signed Δh = height − eye
	beq .py_at_eye
	bmi .py_going_down

	; ----- Δh > 0: height above eye → row above horizon -----
	ldy texstep_h
	bne .py_up_hi
	cmp #13
	bcs .py_up_edge			; |Δh| ≥ 13: offscreen above
	adc #>py_tab - 1		; carry clear; page for this Δh
	sta .py_up_ld+2
	ldy texstep_l
.py_up_ld
	lda py_tab,y			; offset 2..13 (SMC hi byte)
	eor #$ff
	adc #HORIZON+1			; carry clear (page add ≤ $AA) → 12 − offset
	bcs .py_store_a			; offset ≤ 12 → on-screen row
.py_up_edge
	lda #0
.py_store_a
	sta py_row
	rts

.py_at_eye
	lda #HORIZON
	sta py_row
	rts

	; ----- Δh < 0: height below eye → row below horizon -----
.py_going_down
	ldy texstep_h
	bne .py_dn_hi
	cmp #$100-12
	bcc .py_dn_edge			; |Δh| ≥ 13: offscreen below
	eor #$ff			; |Δh|−1 = page index
	adc #>py_tab - 1		; carry set from cmp → + page base
	sta .py_dn_ld+2
	ldy texstep_l
.py_dn_ld
	lda py_tab,y			; offset 2..13 (SMC hi byte)
	adc #HORIZON			; carry clear (page add ≤ $AA) → 12 + offset ≤ 25
	sta py_row
	rts
.py_dn_edge
	lda #25
	sta py_row
	rts

	; ----- texstep_h ≠ 0, Δh < 0: |Δh| into tmp1, one-step or walk -----
.py_dn_hi
	eor #$ff
	adc #1				; C=0 from borrow on sec/sbc eyeheight
	sta tmp1			; |Δh| for one-step / hi compare
	tya				; texstep_h
	cmp tmp1
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

	; ----- texstep_h ≠ 0, Δh > 0: one-step or walk vs tmp3 -----
.py_up_hi
	sta tmp3				; positive remaining
	tya				; texstep_h
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

.py_store_row
	txa
	sta py_row				; also leave row in A (callers may use it)
	rts
