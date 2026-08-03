; Auto-generated — compact interleaved colour RAM + screen blit
; Column loop; 25 rows unrolled. Source: col-major $e000 / $e400
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
	lda (col_base_l),y
	sta $d800,x
	lda (pat_base_l),y
	sta $400,x
	iny
	lda (col_base_l),y
	sta $d828,x
	lda (pat_base_l),y
	sta $428,x
	iny
	lda (col_base_l),y
	sta $d850,x
	lda (pat_base_l),y
	sta $450,x
	iny
	lda (col_base_l),y
	sta $d878,x
	lda (pat_base_l),y
	sta $478,x
	iny
	lda (col_base_l),y
	sta $d8a0,x
	lda (pat_base_l),y
	sta $4a0,x
	iny
	lda (col_base_l),y
	sta $d8c8,x
	lda (pat_base_l),y
	sta $4c8,x
	iny
	lda (col_base_l),y
	sta $d8f0,x
	lda (pat_base_l),y
	sta $4f0,x
	iny
	lda (col_base_l),y
	sta $d918,x
	lda (pat_base_l),y
	sta $518,x
	iny
	lda (col_base_l),y
	sta $d940,x
	lda (pat_base_l),y
	sta $540,x
	iny
	lda (col_base_l),y
	sta $d968,x
	lda (pat_base_l),y
	sta $568,x
	iny
	lda (col_base_l),y
	sta $d990,x
	lda (pat_base_l),y
	sta $590,x
	iny
	lda (col_base_l),y
	sta $d9b8,x
	lda (pat_base_l),y
	sta $5b8,x
	iny
	lda (col_base_l),y
	sta $d9e0,x
	lda (pat_base_l),y
	sta $5e0,x
	iny
	lda (col_base_l),y
	sta $da08,x
	lda (pat_base_l),y
	sta $608,x
	iny
	lda (col_base_l),y
	sta $da30,x
	lda (pat_base_l),y
	sta $630,x
	iny
	lda (col_base_l),y
	sta $da58,x
	lda (pat_base_l),y
	sta $658,x
	iny
	lda (col_base_l),y
	sta $da80,x
	lda (pat_base_l),y
	sta $680,x
	iny
	lda (col_base_l),y
	sta $daa8,x
	lda (pat_base_l),y
	sta $6a8,x
	iny
	lda (col_base_l),y
	sta $dad0,x
	lda (pat_base_l),y
	sta $6d0,x
	iny
	lda (col_base_l),y
	sta $daf8,x
	lda (pat_base_l),y
	sta $6f8,x
	iny
	lda (col_base_l),y
	sta $db20,x
	lda (pat_base_l),y
	sta $720,x
	iny
	lda (col_base_l),y
	sta $db48,x
	lda (pat_base_l),y
	sta $748,x
	iny
	lda (col_base_l),y
	sta $db70,x
	lda (pat_base_l),y
	sta $770,x
	iny
	lda (col_base_l),y
	sta $db98,x
	lda (pat_base_l),y
	sta $798,x
	iny
	lda hud_dirty
	beq .hud_clean
	lda (col_base_l),y
	sta $dbc0,x
	lda (pat_base_l),y
	sta $7c0,x
.hud_clean
	inx
	cpx #40
	beq .done
	jmp .col
.done
	lda #0
	sta hud_dirty
	rts
