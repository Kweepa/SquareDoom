!zone render_clip

; ============================================================================
; render_clip.asm — per-column portal clip stack + SEC_SEEN helpers
; ============================================================================
; Stack layout (idx = col*CLIP_MAX + n): COL_CLIP_TOP/BOT/Z. Entry 0 =
; nearest (player, Z=0); higher n = farther after hard portals.
; Z = fish wallz_h at push (≈ tiles·fish). Billboards pass
; (tiles·fishtab[centre])>>8 from item_draw_one into clip_col_find.
;
; clip_base_l/h = &COL_CLIP_TOP[col*CLIP_MAX] — computed once per column.
; ============================================================================

CLIP_STRIDE = COL_NUM * CLIP_MAX	; bytes between TOP / BOT / Z tables

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
; clip_col_push — push {ytop, ybot, wallz_h} for current col if n < CLIP_MAX
; Always uses the live aperture. Hard portals push after paint_portal.
; Requires clip_base already bound for col. Clobbers: tmp0, ptr_l/h, X, Y
; ---------------------------------------------------------------------------
clip_col_push
	ldy col
	lda COL_CLIP_N,y
	cmp #CLIP_MAX
	bcs .ccp_full
	sta tmp0				; n
	; ptr = clip_base + n → TOP
	clc
	lda clip_base_l
	adc tmp0
	sta ptr_l
	lda clip_base_h
	adc #0
	sta ptr_h
	ldy #0
	lda ytop
	sta (ptr_l),y
	; BOT
	clc
	lda ptr_l
	adc #<CLIP_STRIDE
	sta ptr_l
	lda ptr_h
	adc #>CLIP_STRIDE
	sta ptr_h
	lda ybot
	sta (ptr_l),y
	; Z
	clc
	lda ptr_l
	adc #<CLIP_STRIDE
	sta ptr_l
	lda ptr_h
	adc #>CLIP_STRIDE
	sta ptr_h
	lda wallz_h
	sta (ptr_l),y
	; n++
	ldy col
	ldx COL_CLIP_N,y
	inx
	txa
	sta COL_CLIP_N,y
.ccp_full
	rts

; ---------------------------------------------------------------------------
; clip_col_find — A = billboard depth in fish wallz_h units
; Near→far: farthest entry with COL_CLIP_Z[i] <= A and non-empty TOP/BOT.
; Exit: C=0 found, tmp0=clip_top, tmp1=clip_bot; C=1 not found
; Re-binds clip_base. Clobbers: tmp2,tmp3,tmp4, ptr_l/h, aux_l/h, X, Y
; ---------------------------------------------------------------------------
clip_col_find
	sta tmp2				; wanted depth
	ldy col
	lda COL_CLIP_N,y
	bne .ccf_go
.ccf_miss
	sec
	rts
.ccf_go
	sta tmp3				; n
	jsr clip_col_bind
	lda #$ff
	sta tmp4				; best index ($FF = none)
	ldx #0					; i
.ccf_lp
	; Z at clip_base + i + 2*CLIP_STRIDE
	clc
	lda clip_base_l
	adc #<CLIP_STRIDE
	sta aux_l
	lda clip_base_h
	adc #>CLIP_STRIDE
	sta aux_h				; BOT plane base
	clc
	lda aux_l
	adc #<CLIP_STRIDE
	sta aux_l
	lda aux_h
	adc #>CLIP_STRIDE
	sta aux_h				; Z plane base
	txa
	clc
	adc aux_l
	sta aux_l
	lda aux_h
	adc #0
	sta aux_h
	ldy #0
	lda (aux_l),y
	cmp tmp2
	beq .ccf_cand
	bcc .ccf_cand			; Z <= depth
	bcs .ccf_nx				; Z > depth
.ccf_cand
	; TOP at clip_base+i
	clc
	lda clip_base_l
	stx tmp0				; save i
	adc tmp0
	sta ptr_l
	lda clip_base_h
	adc #0
	sta ptr_h
	lda (ptr_l),y
	sta tmp0				; top
	; BOT at TOP + CLIP_STRIDE
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
	bcs .ccf_nx				; empty aperture
	stx tmp4				; best = i
.ccf_nx
	inx
	cpx tmp3
	bcc .ccf_lp
	lda tmp4
	cmp #$ff
	beq .ccf_miss
	; Reload TOP/BOT for best index into tmp0/tmp1
	tax
	clc
	lda clip_base_l
	adc tmp4
	sta ptr_l
	lda clip_base_h
	adc #0
	sta ptr_h
	ldy #0
	lda (ptr_l),y
	sta tmp0
	clc
	lda ptr_l
	adc #<CLIP_STRIDE
	sta aux_l
	lda ptr_h
	adc #>CLIP_STRIDE
	sta aux_h
	lda (aux_l),y
	sta tmp1
	clc
	rts
