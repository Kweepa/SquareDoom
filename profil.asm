!zone profil

; CIA2 Timer A: ϕ2 free-run (buckets when PROFILE; cascade base always).
; CIA2 Timer B: cascaded off TA → 32-bit clock for frame period (F).
; PROFILE=1 HUD: F S D N L P. PROFILE=0 HUD: F only (still ≈ ms).

!if PROFILE = 1 {
PROF_SETUP  = 0
PROF_DDA    = 1
PROF_WALLZ  = 2
PROF_NEAR   = 3
PROF_LEDGE  = 4
PROF_PROJECT_Y = 5
PROF_NBUCKET = 6

prof_lo		= PROF_BSS
prof_mid	= PROF_BSS + PROF_NBUCKET
prof_hi		= PROF_BSS + PROF_NBUCKET * 2
frame_t0	= PROF_BSS + $12
frame_cy	= PROF_BSS + $16
casc_now	= PROF_BSS + $1a
} else {
frame_t0	= PROF_BSS
frame_cy	= PROF_BSS + 4
casc_now	= PROF_BSS + 8
}

; CIA2
CIA2_TA_LO	= $dd04
CIA2_TA_HI	= $dd05
CIA2_TB_LO	= $dd06
CIA2_TB_HI	= $dd07
CIA2_ICR	= $dd0d
CIA2_CRA	= $dd0e
CIA2_CRB	= $dd0f

PROF_SCR	= $0403

prof_init
	lda #$7f
	sta CIA2_ICR		; no CIA2 IRQs
	lda CIA2_ICR		; ack
	lda #$ff
	sta CIA2_TA_LO
	sta CIA2_TA_HI
	sta CIA2_TB_LO
	sta CIA2_TB_HI
	; Timer A: bit0=start, bit4=force load, continuous, count ϕ2
	lda #$11
	sta CIA2_CRA
	; Timer B: start + force load + count TA underflows (cascade)
	lda #$51
	sta CIA2_CRB
	jsr prof_read_casc
	jsr prof_store_t0
	lda #0
	sta frame_cy
	sta frame_cy + 1
	sta frame_cy + 2
	sta frame_cy + 3
	sta turn_acc_l
	sta turn_acc_h
	lda #20
	sta dt_ms
	rts

; frame_cy >> 10 → dt_ms (HUD binary-ms). 0 → 20; saturate at 255.
calc_frame_dt
	lda frame_cy + 1
	sta tmp0
	lda frame_cy + 2
	lsr
	ror tmp0
	lsr
	ror tmp0
	tay				; hi after >>2
	bne .cfd_sat
	lda tmp0
	bne .cfd_ok
	lda #20
.cfd_ok
	sta dt_ms
	rts
.cfd_sat
	lda #255
	sta dt_ms
	rts

; Consistent 32-bit cascade sample → casc_now.
prof_read_casc
.prc_retry
	lda CIA2_TB_HI
	sta casc_now + 3
	lda CIA2_TB_LO
	sta casc_now + 2
	lda CIA2_TA_HI
	sta casc_now + 1
	lda CIA2_TA_LO
	sta casc_now
	lda CIA2_TB_HI
	cmp casc_now + 3
	bne .prc_retry
	lda CIA2_TB_LO
	cmp casc_now + 2
	bne .prc_retry
	rts

prof_store_t0
	lda casc_now
	sta frame_t0
	lda casc_now + 1
	sta frame_t0 + 1
	lda casc_now + 2
	sta frame_t0 + 2
	lda casc_now + 3
	sta frame_t0 + 3
	rts

; Period since last call → frame_cy; update t0. Countdown: delta = t0 − now.
prof_frame_sample
	jsr prof_read_casc
	sec
	lda frame_t0
	sbc casc_now
	sta frame_cy
	lda frame_t0 + 1
	sbc casc_now + 1
	sta frame_cy + 1
	lda frame_t0 + 2
	sbc casc_now + 2
	sta frame_cy + 2
	lda frame_t0 + 3
	sbc casc_now + 3
	sta frame_cy + 3
	jmp prof_store_t0

!if PROFILE = 1 {
; Read Timer A into A=hi X=lo (retry if HI changes mid-read).
prof_read_cia
	lda CIA2_TA_HI
	ldx CIA2_TA_LO
	cmp CIA2_TA_HI
	bne prof_read_cia
	rts

prof_snap
	jsr prof_read_cia
	stx prof_snap_l
	sta prof_snap_h
	rts

prof_reset_frame
	ldx #PROF_NBUCKET - 1
	lda #0
.prf
	sta prof_lo,x
	sta prof_mid,x
	sta prof_hi,x
	dex
	bpl .prf
	jmp prof_snap

; Y = bucket id. Add (snap - now) into bucket; leave snap = now.
; Uses only prof_now_* / prof_dt_* — never tmp0..tmp5.
prof_add_bucket
	jsr prof_read_cia
	stx prof_now_l
	sta prof_now_h
	sec
	lda prof_snap_l
	sbc prof_now_l
	sta prof_dt_l
	lda prof_snap_h
	sbc prof_now_h
	sta prof_dt_h
	lda prof_now_l
	sta prof_snap_l
	lda prof_now_h
	sta prof_snap_h
	clc
	lda prof_lo,y
	adc prof_dt_l
	sta prof_lo,y
	lda prof_mid,y
	adc prof_dt_h
	sta prof_mid,y
	lda prof_hi,y
	adc #0
	sta prof_hi,y
	rts

prof_add_py
	ldy #PROF_PROJECT_Y
	jmp prof_add_bucket
}

; Print F (always). PROFILE=1: S D W N L P (ms). PROFILE=0: C = span count.
; Bucket ms ≈ (cycles>>8)/4, 3 decimal digits. Chars only — colour from blit.
prof_print
	ldx #0
	lda #$86			; inverse 'F'
	sta PROF_SCR,x
	inx
	lda frame_cy + 2
	ldy frame_cy + 1
	jsr .pp_ms3
!if PROFILE = 1 {
	inx				; gap
	ldy #0
.pp_buck
	tya
	pha
	lda .pp_letter,y
	sta PROF_SCR,x
	inx
	lda .pp_id,y
	tay
	lda prof_hi,y
	pha
	lda prof_mid,y
	tay
	pla
	jsr .pp_ms3
	inx				; gap
	pla
	tay
	iny
	cpy #6				; S D W N L P
	bcc .pp_buck
} else {
	inx				; gap
	lda #$83			; inverse 'C'
	sta PROF_SCR,x
	inx
	lda span_hi
	ldy span_lo
	jsr .pp_u16_3
}
	rts

!if PROFILE = 1 {
.pp_id
	!byte PROF_SETUP
	!byte PROF_DDA
	!byte PROF_WALLZ
	!byte PROF_NEAR
	!byte PROF_LEDGE
	!byte PROF_PROJECT_Y

.pp_letter
	!byte $93			; S
	!byte $84			; D
	!byte $97			; W
	!byte $8e			; N
	!byte $8c			; L
	!byte $90			; P
}

SCREEN_DIGIT_BASE = $b0

; Frame print scratch when PROFILE=0 (no prof_now_*/prof_dt_* from buckets).
!if PROFILE = 0 {
pp_tmp_l	= PROF_BSS + $0c
pp_tmp_h	= PROF_BSS + $0d
pp_dig_h	= PROF_BSS + $0e
pp_dig_t	= PROF_BSS + $0f
} else {
pp_tmp_l	= prof_dt_l
pp_tmp_h	= prof_dt_h
pp_dig_h	= prof_now_l
pp_dig_t	= prof_now_h
}

; A:Y = hi:lo count → 3 decimal digits at PROF_SCR,x (clamp 999)
.pp_u16_3
	sta pp_tmp_h
	sty pp_tmp_l
	lda pp_tmp_h
	beq .pp_dec3
	cmp #4
	bcs .pp_sat
	cmp #3
	bcc .pp_dec3
	lda pp_tmp_l
	cmp #$e8
	bcc .pp_dec3
	bcs .pp_sat

; A:Y = hi:mid (cycles>>8) → (A:Y)>>2 ≈ ms → 3 decimal digits at PROF_SCR,x
.pp_ms3
	sta pp_tmp_h
	sty pp_tmp_l
	lsr pp_tmp_h
	ror pp_tmp_l
	lsr pp_tmp_h
	ror pp_tmp_l
	lda pp_tmp_h
	beq .pp_dec3
	cmp #4
	bcs .pp_sat
	cmp #3
	bcc .pp_dec3
	lda pp_tmp_l
	cmp #$e8
	bcc .pp_dec3
.pp_sat
	lda #3
	sta pp_tmp_h
	lda #$e7
	sta pp_tmp_l

.pp_dec3
	txa
	pha
	ldx #SCREEN_DIGIT_BASE
.pp_hund
	lda pp_tmp_h
	bne .pp_sub100
	lda pp_tmp_l
	cmp #100
	bcc .pp_tens
.pp_sub100
	sec
	lda pp_tmp_l
	sbc #100
	sta pp_tmp_l
	lda pp_tmp_h
	sbc #0
	sta pp_tmp_h
	inx
	bne .pp_hund
.pp_tens
	ldy #SCREEN_DIGIT_BASE
.pp_tenlp
	lda pp_tmp_l
	cmp #10
	bcc .pp_ones
	sbc #10
	sta pp_tmp_l
	iny
	bne .pp_tenlp
.pp_ones
	stx pp_dig_h
	sty pp_dig_t
	pla
	tax
	lda pp_dig_h
	sta PROF_SCR,x
	inx
	lda pp_dig_t
	sta PROF_SCR,x
	inx
	lda pp_tmp_l
	clc
	adc #SCREEN_DIGIT_BASE
	sta PROF_SCR,x
	inx
	rts
