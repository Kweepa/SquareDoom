; Auto-generated — compact interleaved colour RAM + screen blit
; Column loop; 25 rows unrolled. Source: col-major $e000 / $e400
; Dest: pattern $C400 (RAM, $34), colour $D800 (I/O, $35); yield $34+cli/col
; Row 24: always blit cols 8–31 (view); HUD cols 0–7/32–39 if hud_dirty
!zone blit_fb

blit_fb
	ldx #0
.col
	lda colbaselo,x
	sta col_base_l
	sta pat_base_l
	lda colbasehi,x
	sta col_base_h
	clc
	adc #4
	sta pat_base_h
	ldy #0
	lda (pat_base_l),y
	sta $c400,x
	iny
	lda (pat_base_l),y
	sta $c428,x
	iny
	lda (pat_base_l),y
	sta $c450,x
	iny
	lda (pat_base_l),y
	sta $c478,x
	iny
	lda (pat_base_l),y
	sta $c4a0,x
	iny
	lda (pat_base_l),y
	sta $c4c8,x
	iny
	lda (pat_base_l),y
	sta $c4f0,x
	iny
	lda (pat_base_l),y
	sta $c518,x
	iny
	lda (pat_base_l),y
	sta $c540,x
	iny
	lda (pat_base_l),y
	sta $c568,x
	iny
	lda (pat_base_l),y
	sta $c590,x
	iny
	lda (pat_base_l),y
	sta $c5b8,x
	iny
	lda (pat_base_l),y
	sta $c5e0,x
	iny
	lda (pat_base_l),y
	sta $c608,x
	iny
	lda (pat_base_l),y
	sta $c630,x
	iny
	lda (pat_base_l),y
	sta $c658,x
	iny
	lda (pat_base_l),y
	sta $c680,x
	iny
	lda (pat_base_l),y
	sta $c6a8,x
	iny
	lda (pat_base_l),y
	sta $c6d0,x
	iny
	lda (pat_base_l),y
	sta $c6f8,x
	iny
	lda (pat_base_l),y
	sta $c720,x
	iny
	lda (pat_base_l),y
	sta $c748,x
	iny
	lda (pat_base_l),y
	sta $c770,x
	iny
	lda (pat_base_l),y
	sta $c798,x
	iny
	cpx #8
	bcc .hud_side_p
	cpx #32
	bcc .blit_r24_p
.hud_side_p
	lda hud_dirty
	beq .hud_clean_p
.blit_r24_p
	lda (pat_base_l),y
	sta $c7c0,x
.hud_clean_p
	lda #$35
	sta $01
	ldy #0
	lda (col_base_l),y
	sta $d800,x
	iny
	lda (col_base_l),y
	sta $d828,x
	iny
	lda (col_base_l),y
	sta $d850,x
	iny
	lda (col_base_l),y
	sta $d878,x
	iny
	lda (col_base_l),y
	sta $d8a0,x
	iny
	lda (col_base_l),y
	sta $d8c8,x
	iny
	lda (col_base_l),y
	sta $d8f0,x
	iny
	lda (col_base_l),y
	sta $d918,x
	iny
	lda (col_base_l),y
	sta $d940,x
	iny
	lda (col_base_l),y
	sta $d968,x
	iny
	lda (col_base_l),y
	sta $d990,x
	iny
	lda (col_base_l),y
	sta $d9b8,x
	iny
	lda (col_base_l),y
	sta $d9e0,x
	iny
	lda (col_base_l),y
	sta $da08,x
	iny
	lda (col_base_l),y
	sta $da30,x
	iny
	lda (col_base_l),y
	sta $da58,x
	iny
	lda (col_base_l),y
	sta $da80,x
	iny
	lda (col_base_l),y
	sta $daa8,x
	iny
	lda (col_base_l),y
	sta $dad0,x
	iny
	lda (col_base_l),y
	sta $daf8,x
	iny
	lda (col_base_l),y
	sta $db20,x
	iny
	lda (col_base_l),y
	sta $db48,x
	iny
	lda (col_base_l),y
	sta $db70,x
	iny
	lda (col_base_l),y
	sta $db98,x
	iny
	cpx #8
	bcc .hud_side_c
	cpx #32
	bcc .blit_r24_c
.hud_side_c
	lda hud_dirty
	beq .hud_clean_c
.blit_r24_c
	lda (col_base_l),y
	sta $dbc0,x
.hud_clean_c
	lda #$34
	sta $01
	cli
	inx
	cpx #40
	beq .done
	jmp .col
.done
	lda #0
	sta hud_dirty
	rts
