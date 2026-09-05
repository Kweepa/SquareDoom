!zone project_y

; ============================================================================
; render_project_y.asm — PROFILE P (world height → screen row)
; ============================================================================
; Row offset from HORIZON is n = ceil(|Δh|·256 / texstep), clamped to the
; screen rails (12 rows up / 13 down). For texstep_h=0 that whole function
; is a lookup: py_tab[(|Δh|−1)·256 + texstep_l] = min(n,13) for |Δh| 1..11,
; and |Δh| ≥ 12 is always offscreen (ceil(12·256/255) = 13 → row 0 / 25).
; Table built by tools/genpytab.js; matches the old walk loops bit-for-bit
; except upward offset-13 now clamps to row 0 (was A=$FF before the edge
; path). texstep_h≠0 keeps the hi / one-step walk (rare, short).
;
; Entry: A = world height (0..31). Uses texstep_l/h from calc_wallz.
; Exit:  A = screen row 0..25. PROFILE=1 also stores py_row (callers reload
; after prof_add_py). Must not clobber tmp4/tmp5 (portal).
; Eyeheight is an SMC immediate (project_y_sbc_eye+1), patched by update_eye
; / player_death_eye; zp eyeheight stays in sync for non-project readers.
; ============================================================================

; ---------------------------------------------------------------------------
; project_y — A = world y → screen row in A (and py_row when PROFILE)
;
; Fast path uses A/Y + SMC operand only. Hi paths: tmp3 = Δh (up),
; tmp1 = |Δh| (down); acc_l/h walk as before.
; ---------------------------------------------------------------------------
project_y
	sec
project_y_sbc_eye
	sbc #11				; patched to eyeheight (default = empty sector)
	beq .py_at_eye
	bmi .py_going_down

	; ----- Δh > 0: height above eye → row above horizon -----
	ldy texstep_h
	bne .py_up_hi
	cmp #12
	bcs .py_up_edge			; |Δh| ≥ 12: always offset 13 → row 0
	adc #>py_tab - 1		; carry clear; page for this Δh
	sta .py_up_ld+2
	ldy texstep_l
.py_up_ld
	lda py_tab,y			; offset 2..13 (SMC hi byte)
	eor #$ff
	adc #HORIZON+1			; C=0 after page add → 12 − offset
	bcs .py_store_a			; offset ≤ 12 → on-screen row
.py_up_edge
	lda #0				; offset 13 (or |Δh|≥12): clamp to top
.py_store_a
!if PROFILE = 1 {
	sta py_row
}
	rts

.py_at_eye
	lda #HORIZON
!if PROFILE = 1 {
	sta py_row
}
	rts

	; ----- Δh < 0: height below eye → row below horizon -----
.py_going_down
	ldy texstep_h
	bne .py_dn_hi
	cmp #$100-11
	bcc .py_dn_edge			; |Δh| ≥ 12: always offset 13 → row 25
	eor #$ff			; |Δh|−1 = page index
	adc #>py_tab - 1		; carry set from cmp → + page base
	sta .py_dn_ld+2
	ldy texstep_l
.py_dn_ld
	lda py_tab,y			; offset 2..13 (SMC hi byte)
	adc #HORIZON			; carry clear (page add ≤ $AA) → 12 + offset ≤ 25
!if PROFILE = 1 {
	sta py_row
}
	rts
.py_dn_edge
	lda #25
!if PROFILE = 1 {
	sta py_row
}
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
!if PROFILE = 1 {
	sta py_row				; also leave row in A (callers may use it)
}
	rts

; ---------------------------------------------------------------------------
; project_y_lo — A = height → A = row; requires texstep_h = 0. Clobbers Y.
; Kept as scalar helper; project_y_pair inlines this for the dual lo path.
; ---------------------------------------------------------------------------
project_y_lo
	sec
	sbc eyeheight
	beq .plo_eye
	bmi .plo_dn
	cmp #12
	bcs .plo_up_edge
	adc #>py_tab - 1
	sta .plo_uld + 2
	ldy texstep_l
.plo_uld
	lda py_tab,y
	eor #$ff
	adc #HORIZON+1
	bcs .plo_out
.plo_up_edge
	lda #0
.plo_out
	rts
.plo_eye
	lda #HORIZON
	rts
.plo_dn
	cmp #$100-11
	bcc .plo_dn_edge
	eor #$ff
	adc #>py_tab - 1
	sta .plo_dld + 2
	ldy texstep_l
.plo_dld
	lda py_tab,y
	adc #HORIZON
	rts
.plo_dn_edge
	lda #25
	rts

; ---------------------------------------------------------------------------
; project_y_pair — A = height0, Y = height1 → X = row0, A = row1
;
; Shares one texstep_h test. Lo path: dual-inline of project_y_lo (shared
; texstep_l index in tmp1). Hi path: two scalar project_y. Uses tmp0/tmp1/tmp2;
; must not touch tmp4/tmp5.
; ---------------------------------------------------------------------------
project_y_pair
	sta tmp0				; height0
	sty tmp2				; height1
	lda texstep_h
	beq .pyp_lo
	jmp .pyp_hi
.pyp_lo
	lda texstep_l
	sta tmp1				; shared table index
	; ----- height0 -----
	lda tmp0
	sec
	sbc eyeheight
	beq .pyp0_eye
	bmi .pyp0_dn
	cmp #12
	bcs .pyp0_up_edge
	adc #>py_tab - 1
	sta .pyp0_uld + 2
	ldy tmp1
.pyp0_uld
	lda py_tab,y
	eor #$ff
	adc #HORIZON+1
	bcs .pyp0_done
.pyp0_up_edge
	lda #0
	beq .pyp0_done			; always
.pyp0_eye
	lda #HORIZON
	bne .pyp0_done			; always (HORIZON≠0)
.pyp0_dn
	cmp #$100-11
	bcc .pyp0_dn_edge
	eor #$ff
	adc #>py_tab - 1
	sta .pyp0_dld + 2
	ldy tmp1
.pyp0_dld
	lda py_tab,y
	adc #HORIZON
	jmp .pyp0_done
.pyp0_dn_edge
	lda #25
.pyp0_done
	sta tmp0				; row0
	; ----- height1 -----
	lda tmp2
	sec
	sbc eyeheight
	beq .pyp1_eye
	bmi .pyp1_dn
	cmp #12
	bcs .pyp1_up_edge
	adc #>py_tab - 1
	sta .pyp1_uld + 2
	ldy tmp1
.pyp1_uld
	lda py_tab,y
	eor #$ff
	adc #HORIZON+1
	bcs .pyp1_done
.pyp1_up_edge
	lda #0
	beq .pyp1_done
.pyp1_eye
	lda #HORIZON
	bne .pyp1_done
.pyp1_dn
	cmp #$100-11
	bcc .pyp1_dn_edge
	eor #$ff
	adc #>py_tab - 1
	sta .pyp1_dld + 2
	ldy tmp1
.pyp1_dld
	lda py_tab,y
	adc #HORIZON
	jmp .pyp1_done
.pyp1_dn_edge
	lda #25
.pyp1_done
	ldx tmp0				; X = row0, A = row1
!if PROFILE = 1 {
	sta py_row
}
	rts

.pyp_hi
	lda tmp0
	jsr project_y
	sta tmp0
	lda tmp2
	jsr project_y
	ldx tmp0
	rts
