; Auto-generated — compact interleaved colour RAM + screen blit
; Column loop; 25 rows unrolled. Source: col-major $e000 / $e400
; Dest: pattern $C000 (RAM, $34), colour $D800 (I/O, $35); yield $34+cli/col
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
	sta $c000,x
	iny
	lda (pat_base_l),y
	sta $c028,x
	iny
	lda (pat_base_l),y
	sta $c050,x
	iny
	lda (pat_base_l),y
	sta $c078,x
	iny
	lda (pat_base_l),y
	sta $c0a0,x
	iny
	lda (pat_base_l),y
	sta $c0c8,x
	iny
	lda (pat_base_l),y
	sta $c0f0,x
	iny
	lda (pat_base_l),y
	sta $c118,x
	iny
	lda (pat_base_l),y
	sta $c140,x
	iny
	lda (pat_base_l),y
	sta $c168,x
	iny
	lda (pat_base_l),y
	sta $c190,x
	iny
	lda (pat_base_l),y
	sta $c1b8,x
	iny
	lda (pat_base_l),y
	sta $c1e0,x
	iny
	lda (pat_base_l),y
	sta $c208,x
	iny
	lda (pat_base_l),y
	sta $c230,x
	iny
	lda (pat_base_l),y
	sta $c258,x
	iny
	lda (pat_base_l),y
	sta $c280,x
	iny
	lda (pat_base_l),y
	sta $c2a8,x
	iny
	lda (pat_base_l),y
	sta $c2d0,x
	iny
	lda (pat_base_l),y
	sta $c2f8,x
	iny
	lda (pat_base_l),y
	sta $c320,x
	iny
	lda (pat_base_l),y
	sta $c348,x
	iny
	lda (pat_base_l),y
	sta $c370,x
	iny
	lda (pat_base_l),y
	sta $c398,x
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
	sta $c3c0,x
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
