!zone profil

; CIA2 Timer A free-running ϕ2 countdown for light profiling.
; Buckets: cycles accumulated per frame (24-bit each).

PROF_SETUP  = 0
PROF_DDA    = 1
PROF_WALLZ  = 2
PROF_NEAR   = 3
PROF_LEDGE  = 4
PROF_NBUCKET = 5

; 24-bit buckets in free RAM (id-indexed)
prof_lo		= $2d00
prof_mid	= $2d00 + PROF_NBUCKET
prof_hi		= $2d00 + PROF_NBUCKET * 2

; CIA2
CIA2_TA_LO	= $dd04
CIA2_TA_HI	= $dd05
CIA2_ICR	= $dd0d
CIA2_CRA	= $dd0e

prof_init
	lda #$7f
	sta CIA2_ICR		; no CIA2 IRQs
	lda CIA2_ICR		; ack
	lda #$ff
	sta CIA2_TA_LO
	sta CIA2_TA_HI
	; bit0=start, bit4=force load, continuous, count ϕ2
	lda #$11
	sta CIA2_CRA
	rts

; Read CIA2 Timer A into A=hi X=lo (retry if HI changes mid-read).
prof_read_cia
	lda CIA2_TA_HI
	sta tmp5
	ldx CIA2_TA_LO
	cmp CIA2_TA_HI
	bne prof_read_cia
	; A = hi, X = lo
	rts

; Read timer → ZP snap (atomic)
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
; Countdown timer: unsigned 16-bit delta (segments must stay < 64k cycles).
prof_add_bucket
	jsr prof_read_cia
	stx tmp4			; now lo
	sta tmp5			; now hi
	sec
	lda prof_snap_l
	sbc tmp4
	sta tmp0
	lda prof_snap_h
	sbc tmp5
	sta tmp1
	lda tmp4
	sta prof_snap_l
	lda tmp5
	sta prof_snap_h
	clc
	lda prof_lo,y
	adc tmp0
	sta prof_lo,y
	lda prof_mid,y
	adc tmp1
	sta prof_mid,y
	lda prof_hi,y
	adc #0
	sta prof_hi,y
	rts

; Print cycles>>8 for S D W N L at $0403..; peak at $0400/$0401; blank at $0402
prof_print
	ldy #0
	ldx #0			; screen offset from $0403
.pp_buck
	lda .pp_letter,y
	sta $0403,x
	lda #1
	sta $d803,x
	inx
	lda prof_hi,y
	jsr .pp_byte
	lda prof_mid,y
	jsr .pp_byte
	inx			; gap between groups
	iny
	cpy #PROF_NBUCKET
	bcc .pp_buck
	rts

.pp_letter
	!byte $93			; inverse 'S'
	!byte $84			; inverse 'D'
	!byte $97			; inverse 'W'
	!byte $8e			; inverse 'N'
	!byte $8c			; inverse 'L'

; A = byte → 2 inverse hex digits at $0403,x ; advances X
.pp_byte
	pha
	lsr
	lsr
	lsr
	lsr
	jsr .pp_nib
	pla
	and #$0f
	; fall through
.pp_nib
	cmp #10
	bcc .pp_dec
	; A-F → screen codes $01..$06 (PETSCII A-F) + $80 inverse
	sec
	sbc #9			; 10→1 .. 15→6
	ora #$80
	bne .pp_store
.pp_dec
	ora #$b0			; inverse '0'..'9'
.pp_store
	sta $0403,x
	lda #1
	sta $d803,x
	inx
	rts
