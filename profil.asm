!zone profil

; CIA2 Timer A: free-running ϕ2 for in-frame bucket deltas.
; CIA2 Timer B: cascaded (counts TA underflows) → with A, a 32-bit clock
; for whole-frame period (input + render + HUD), shown as F.
; Buckets: cycles accumulated per frame (24-bit each).
; HUD: F S D N L P (W collected, not printed). Scratch uses prof_* ZP only.

PROF_SETUP  = 0
PROF_DDA    = 1
PROF_WALLZ  = 2
PROF_NEAR   = 3
PROF_LEDGE  = 4
PROF_PROJECT_Y = 5
PROF_NBUCKET = 6

; 24-bit buckets in free RAM (id-indexed)
prof_lo		= $2d00
prof_mid	= $2d00 + PROF_NBUCKET
prof_hi		= $2d00 + PROF_NBUCKET * 2

; Cascade samples / frame period (cycles). HUD prints (period>>8)/4 ≈ ms.
frame_t0	= $2d12			; 4 bytes: TA_L, TA_H, TB_L, TB_H
frame_cy	= $2d16			; 4 bytes: last full-frame period
casc_now	= $2d1a			; 4 bytes: scratch sample

; CIA2
CIA2_TA_LO	= $dd04
CIA2_TA_HI	= $dd05
CIA2_TB_LO	= $dd06
CIA2_TB_HI	= $dd07
CIA2_ICR	= $dd0d
CIA2_CRA	= $dd0e
CIA2_CRB	= $dd0f

PROF_SCR	= $0403
PROF_COL	= $d803
PROF_SHOW	= 5				; S D N L P (F printed first)

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
	rts

; Read Timer A into A=hi X=lo (retry if HI changes mid-read).
prof_read_cia
	lda CIA2_TA_HI
	ldx CIA2_TA_LO
	cmp CIA2_TA_HI
	bne prof_read_cia
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

; Charge elapsed since snap to P. Does not preserve A/X/Y.
prof_add_py
	ldy #PROF_PROJECT_Y
	jmp prof_add_bucket

; Print F then S D N L P. Each value is (cycles>>8)/4 ≈ ms, 3 decimal digits.
; Digit conversion borrowed from JSW-Tape PrintDec3 (rope_test.asm).
prof_print
	ldx #0
	lda #$86			; inverse 'F'
	sta PROF_SCR,x
	lda #1
	sta PROF_COL,x
	inx
	lda frame_cy + 2
	ldy frame_cy + 1
	jsr .pp_ms3
	inx				; gap

	ldy #0
.pp_buck
	tya
	pha
	lda .pp_letter,y
	sta PROF_SCR,x
	lda #1
	sta PROF_COL,x
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
	cpy #PROF_SHOW
	bcc .pp_buck
	rts

.pp_id
	!byte PROF_SETUP
	!byte PROF_DDA
	!byte PROF_NEAR
	!byte PROF_LEDGE
	!byte PROF_PROJECT_Y

.pp_letter
	!byte $93			; S
	!byte $84			; D
	!byte $8e			; N
	!byte $8c			; L
	!byte $90			; P

SCREEN_DIGIT_BASE = $b0

; A:Y = hi:mid (cycles>>8) → (A:Y)>>2 ≈ ms → 3 decimal digits at PROF_SCR,x
; Uses prof_dt_*; advances X by 3.
.pp_ms3
	sta prof_dt_h
	sty prof_dt_l
	lsr prof_dt_h
	ror prof_dt_l
	lsr prof_dt_h
	ror prof_dt_l
	; clamp to 999
	lda prof_dt_h
	beq .pp_dec3
	cmp #4
	bcs .pp_sat
	cmp #3
	bcc .pp_dec3
	lda prof_dt_l
	cmp #$e8			; $03E8 = 1000
	bcc .pp_dec3
.pp_sat
	lda #3
	sta prof_dt_h
	lda #$e7			; 999
	sta prof_dt_l

; 0..999 in prof_dt_h:l → three inverse digits (Willy-Tape PrintDec3 style)
.pp_dec3
	txa
	pha
	ldx #SCREEN_DIGIT_BASE
.pp_hund
	lda prof_dt_h
	bne .pp_sub100
	lda prof_dt_l
	cmp #100
	bcc .pp_tens
.pp_sub100
	sec
	lda prof_dt_l
	sbc #100
	sta prof_dt_l
	lda prof_dt_h
	sbc #0
	sta prof_dt_h
	inx
	bne .pp_hund
.pp_tens
	ldy #SCREEN_DIGIT_BASE
.pp_tenlp
	lda prof_dt_l
	cmp #10
	bcc .pp_ones
	sbc #10
	sta prof_dt_l
	iny
	bne .pp_tenlp
.pp_ones
	; X = hundreds screen code, Y = tens, prof_dt_l = ones (0-9)
	; stack: dest index
	stx prof_now_l			; hundreds (reuse scratch; print-only)
	sty prof_now_h			; tens
	pla				; dest index
	tax
	lda prof_now_l
	sta PROF_SCR,x
	lda #1
	sta PROF_COL,x
	inx
	lda prof_now_h
	sta PROF_SCR,x
	lda #1
	sta PROF_COL,x
	inx
	lda prof_dt_l
	clc
	adc #SCREEN_DIGIT_BASE
	sta PROF_SCR,x
	lda #1
	sta PROF_COL,x
	inx
	rts
