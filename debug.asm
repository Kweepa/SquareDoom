!zone debug

; Two inverse digits of dda_peak at $0400/$0401; leave $0402 blank before stats
; (chars only — colour from blit)
print_dda_peak
	lda dda_peak
	ldx #0
.pdp_tens
	cmp #10
	bcc .pdp_ones
	sbc #10
	inx
	bne .pdp_tens
.pdp_ones
	ora #$b0			; inverse screen codes for '0'..'9'
	sta $0401
	txa
	ora #$b0
	sta $0400
	; leave $0402 untouched (gap before F — colour shows through)
	rts

!if DBG_PORTAL = 1 {
; Center-column portal dump (chars after blit; colour shows through).
; Per line: id ytop ybot span_a span_b near_floor above_eye farFloorY texstep_h
; farFloorY=$FF if this edge did not project far floor (solid / no lower)
DBG_BUF		= $2e00			; 24 × 9 bytes
DBG_MAX		= 24
DBG_STRIDE	= 9

; If col == CENTER_COL, append post-paint debug fields.
dbg_portal_log
	lda col
	cmp #CENTER_COL
	bne .dpl_out
	lda dbg_n
	cmp #DBG_MAX
	bcs .dpl_out
	sta tmp0
	asl				; *2
	sta tmp1
	asl				; *4
	asl				; *8
	clc
	adc tmp0			; *9
	tax
	lda next_id
	sta DBG_BUF,x
	lda ytop
	sta DBG_BUF + 1,x
	lda ybot
	sta DBG_BUF + 2,x
	lda span_a
	sta DBG_BUF + 3,x
	lda span_b
	sta DBG_BUF + 4,x
	lda near_floor
	sta DBG_BUF + 5,x
	lda #0
	sta DBG_BUF + 6,x
	lda near_floor
	cmp eyeheight
	bcc .dpl_far
	beq .dpl_far
	lda #1
	sta DBG_BUF + 6,x
.dpl_far
	lda dbg_far_y
	sta DBG_BUF + 7,x
	lda texstep_h
	sta DBG_BUF + 8,x
	lda #255
	sta dbg_far_y			; consume — solid edges leave $FF
	inc dbg_n
.dpl_out
	rts

; Print 9×3-digit groups with skipped-column gaps (no colour / no $20).
dbg_portal_flush
	lda #0
	sta tmp2			; entry index
	lda #1
	sta tmp3			; screen row
.dpf_lp
	lda tmp2
	cmp dbg_n
	bcs .dpf_done
	sta tmp0
	asl
	sta tmp1
	asl
	asl				; *8
	clc
	adc tmp0			; *9
	pha
	lda tmp3
	jsr .dpf_row_ptr
	pla
	sta tmp1
	ldx #0				; field 0..8
.dpf_fields
	txa
	pha
	clc
	adc tmp1
	tay
	lda DBG_BUF,y
	jsr .dpf_u8_3
	pla
	tax
	inx
	cpx #DBG_STRIDE
	bcs .dpf_next
	inc fill_row			; gap
	jmp .dpf_fields
.dpf_next
	inc tmp2
	inc tmp3
	lda tmp3
	cmp #25
	bcc .dpf_lp
.dpf_done
	rts

; A = screen row 0..24 → ptr = $0400+40*A
.dpf_row_ptr
	sta tmp0
	lda #0
	sta ptr_h
	lda tmp0
	asl
	asl
	asl				; *8
	sta tmp1
	asl				; *16
	rol ptr_h
	asl				; *32
	rol ptr_h
	clc
	adc tmp1			; *40
	sta ptr_l
	bcc .dpf_r1
	inc ptr_h
.dpf_r1
	clc
	lda ptr_l
	adc #<$0400
	sta ptr_l
	lda ptr_h
	adc #>$0400
	sta ptr_h
	lda #0
	sta fill_row			; column within row
	rts

; A = char at (ptr)+fill_row; leave colour RAM alone; inc fill_row
.dpf_ch
	ldy fill_row
	sta (ptr_l),y
	inc fill_row
	rts

; A = 0..255 → three inverse digits at current fill_row (Willy PrintDec3)
.dpf_u8_3
	ldx #SCREEN_DIGIT_BASE
.dpf_h
	cmp #100
	bcc .dpf_t
	sbc #100
	inx
	bcs .dpf_h
.dpf_t
	ldy #SCREEN_DIGIT_BASE
.dpf_tl
	cmp #10
	bcc .dpf_o
	sbc #10
	iny
	bne .dpf_tl
.dpf_o
	pha				; ones
	tya
	pha				; tens screen code
	txa
	jsr .dpf_ch
	pla
	jsr .dpf_ch
	pla
	clc
	adc #SCREEN_DIGIT_BASE
	jmp .dpf_ch
}
