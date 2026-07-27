!zone render_clip

; ============================================================================
; render_clip.asm — per-column portal clip stack + SEC_SEEN helpers
; ============================================================================
; Stack layout (idx = col*CLIP_MAX + n): COL_CLIP_TOP/BOT/ZL/ZH.
; Entry 0 = nearest (player, Z=0); higher n = farther after hard portals /
; solid close. Z = full 16-bit fish wallz from calc_wallz.
; Billboards: want16 = depth16·255/512 in wz_x — both Z and item depth16
; are perpendicular distances (255/tile vs 512/tile), one constant scale.
; Closed (top>=bot): occlude if Z < want; Z == want ties fall back nearer.
;
; clip_base_l/h = &COL_CLIP_TOP[col*CLIP_MAX] — computed once per column.
; ============================================================================

CLIP_STRIDE = COL_NUM * CLIP_MAX	; bytes between TOP / BOT / ZL / ZH tables

; ---------------------------------------------------------------------------
; clear_sector_seen — clear SEC_SEEN[1..level_sector_max]
; ---------------------------------------------------------------------------
clear_sector_seen
	lda #0
	ldx level_sector_max
	beq .css_done
.css_lp
	sta SEC_SEEN,x
	dex
	bne .css_lp
.css_done
	rts

; ---------------------------------------------------------------------------
; clear_sector_visited — clear SEC_VISITED[1..level_sector_max] (automap fog)
; ---------------------------------------------------------------------------
clear_sector_visited
	lda #0
	ldx level_sector_max
	beq .csv_done
.csv_lp
	sta SEC_VISITED,x
	dex
	bne .csv_lp
.csv_done
	rts

; ---------------------------------------------------------------------------
; mark_seen — X = sector id; mark visible this frame + ever-visited (id 0 ignored)
; ---------------------------------------------------------------------------
mark_seen
	txa
	beq .ms_done
	lda #$ff
	sta SEC_SEEN,x
	sta SEC_VISITED,x
.ms_done
	rts

; ---------------------------------------------------------------------------
; clip_col_bind — clip_base = COL_CLIP_TOP + col*CLIP_MAX
; Clobbers: tmp1, ptr_l/h, X, A
; ---------------------------------------------------------------------------
clip_col_bind
	lda col
	jsr clip_mul_col
	clc
	lda ptr_l
	adc #<COL_CLIP_TOP
	sta clip_base_l
	lda ptr_h
	adc #>COL_CLIP_TOP
	sta clip_base_h
	rts

; ---------------------------------------------------------------------------
; clip_col_reset — COL_CLIP_N[col] = 0; bind clip_base for this column
; ---------------------------------------------------------------------------
clip_col_reset
	ldy col
	lda #0
	sta COL_CLIP_N,y
	jmp clip_col_bind

; ---------------------------------------------------------------------------
; clip_mul_col — A = col → ptr_l/h = col * CLIP_MAX (16-bit)
; Clobbers: tmp1, X. Does not touch tmp0/tmp2/tmp3 (n / sector / count).
; ---------------------------------------------------------------------------
clip_mul_col
!if CLIP_MAX = 16 {
	ldx #0
	stx ptr_h
	asl
	rol ptr_h
	asl
	rol ptr_h
	asl
	rol ptr_h
	asl
	rol ptr_h
	sta ptr_l
} else {
	; CLIP_MAX=24: col*24 = col*16 + col*8
	ldx #0
	stx ptr_h
	asl
	rol ptr_h
	asl
	rol ptr_h
	asl
	rol ptr_h				; A:ptr_h = col*8
	sta tmp1
	ldx ptr_h				; X = hi of *8
	asl
	rol ptr_h				; A:ptr_h = col*16
	clc
	adc tmp1
	sta ptr_l
	txa
	adc ptr_h
	sta ptr_h
}
	rts

; ---------------------------------------------------------------------------
; clip_col_push — push {ytop, ybot, wallz_l, wallz_h} if n < CLIP_MAX
; Requires clip_base bound. Clobbers: tmp0, ptr_l/h, X, Y
; ---------------------------------------------------------------------------
clip_col_push
	ldy col
	lda COL_CLIP_N,y
	cmp #CLIP_MAX
	bcs .ccp_full
	adc clip_base_l
	sta ptr_l
	lda clip_base_h
	adc #0
	sta ptr_h
	ldy #0
	lda ytop
	sta (ptr_l),y
	clc
	lda ptr_l
	adc #<CLIP_STRIDE
	sta ptr_l
	lda ptr_h
	adc #>CLIP_STRIDE
	sta ptr_h
	lda ybot
	sta (ptr_l),y
	clc
	lda ptr_l
	adc #<CLIP_STRIDE
	sta ptr_l
	lda ptr_h
	adc #>CLIP_STRIDE
	sta ptr_h
	lda wallz_l
	sta (ptr_l),y
	clc
	lda ptr_l
	adc #<CLIP_STRIDE
	sta ptr_l
	lda ptr_h
	adc #>CLIP_STRIDE
	sta ptr_h
	lda wallz_h
	sta (ptr_l),y
	ldx col
	inc COL_CLIP_N,x
.ccp_full
	rts

; ---------------------------------------------------------------------------
; clip_col_find — want16 in wz_x_l/h (same scale as stack Z: ≈255·perp tiles)
; Entries are pushed near→far with increasing Z; an empty (top>=bot) entry is
; always last (DDA stops after closing). Pick the last entry with Z <= want:
;   open  → that aperture
;   empty → Z < want: occluded (miss); Z == want: quantization tie — the
;           sprite sits on that surface, use the previous (open) entry
; Exit: C=0 found, tmp0=top, tmp1=bot; C=1 miss/occluded
; Clobbers: tmp3,tmp4,tmp5, ptr_l/h, aux_l/h, X, Y
; ---------------------------------------------------------------------------
clip_col_find
	ldy col
	lda COL_CLIP_N,y
	bne .ccf_go
.ccf_miss
	sec
	rts
.ccf_go
	sta tmp3				; n
	jsr clip_col_bind
	; aux = &ZL[0], ptr = &ZH[0] (plane bases; index with Y)
	clc
	lda clip_base_l
	adc #<(CLIP_STRIDE*2)
	sta aux_l
	lda clip_base_h
	adc #>(CLIP_STRIDE*2)
	sta aux_h
	clc
	lda clip_base_l
	adc #<(CLIP_STRIDE*3)
	sta ptr_l
	lda clip_base_h
	adc #>(CLIP_STRIDE*3)
	sta ptr_h
	lda #$ff
	sta tmp4				; best index ($FF = none)
	ldy #0
.ccf_lp
	lda (ptr_l),y			; zh
	cmp wz_x_h
	bcc .ccf_lt				; zh < want_h → Z < want
	bne .ccf_done			; zh > want_h → Z > want; stop (monotonic)
	lda (aux_l),y			; zl
	cmp wz_x_l
	beq .ccf_eq
	bcs .ccf_done			; Z > want; stop
.ccf_lt
	sty tmp4
	lda #0
	sta tmp5				; Z < want
	beq .ccf_nx
.ccf_eq
	sty tmp4
	lda #1
	sta tmp5				; Z == want (tie)
.ccf_nx
	iny
	cpy tmp3
	bcc .ccf_lp
.ccf_done
	lda tmp4
	bmi .ccf_miss
.ccf_load
	; TOP/BOT for entry tmp4
	clc
	lda clip_base_l
	adc tmp4
	sta ptr_l
	lda clip_base_h
	adc #0
	sta ptr_h
	ldy #0
	lda (ptr_l),y
	sta tmp0				; top
	clc
	lda ptr_l
	adc #<CLIP_STRIDE
	sta aux_l
	lda ptr_h
	adc #>CLIP_STRIDE
	sta aux_h
	lda (aux_l),y
	sta tmp1				; bot
	lda tmp0
	cmp tmp1
	bcc .ccf_ok				; open aperture
	; empty (closed): terminal occluder
	lda tmp5
	beq .ccf_miss2			; Z < want → hidden behind it
	; Z == want tie → fall back to previous (open) entry
	lda tmp4
	beq .ccf_miss2			; entry 0 empty — nothing nearer
	dec tmp4
	lda #0
	sta tmp5				; previous entries have Z < want
	beq .ccf_load
.ccf_miss2
	sec
	rts
.ccf_ok
	clc
	rts
