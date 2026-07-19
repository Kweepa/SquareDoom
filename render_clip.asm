!zone render_clip

; ============================================================================
; render_clip.asm — per-column portal clip stack + SEC_SEEN helpers
; ============================================================================
; Stack layout (idx = col*CLIP_MAX + n): COL_CLIP_SEC/TOP/BOT. Entry 0 =
; nearest (player sector); higher n = farther after portals.
;
; clip_base_l/h = &COL_CLIP_SEC[col*CLIP_MAX] — computed once per column so
; push / push_if_new skip clip_mul_col on the hot soft-portal path.
; ============================================================================

CLIP_STRIDE = COL_NUM * CLIP_MAX	; bytes between SEC / TOP / BOT tables

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
; mark_seen — X = sector id; mark visible this frame (id 0 ignored)
; ---------------------------------------------------------------------------
mark_seen
	txa
	beq .ms_done
	lda #$ff
	sta SEC_SEEN,x
.ms_done
	rts

; ---------------------------------------------------------------------------
; clip_col_bind — clip_base = COL_CLIP_SEC + col*CLIP_MAX
; Clobbers: tmp1, ptr_l/h, X, A
; ---------------------------------------------------------------------------
clip_col_bind
	lda col
	jsr clip_mul_col
	clc
	lda ptr_l
	adc #<COL_CLIP_SEC
	sta clip_base_l
	lda ptr_h
	adc #>COL_CLIP_SEC
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
; clip_col_push — push {A=sector, ytop, ybot} for current col if n < CLIP_MAX
; Requires clip_base already bound for col. Clobbers: tmp0,tmp2, ptr_l/h, X, Y
; ---------------------------------------------------------------------------
clip_col_push
	sta tmp2				; sector id
	ldy col
	lda COL_CLIP_N,y
	cmp #CLIP_MAX
	bcs .ccp_full
	sta tmp0				; n
	; ptr = clip_base + n
	clc
	lda clip_base_l
	adc tmp0
	sta ptr_l
	lda clip_base_h
	adc #0
	sta ptr_h
	ldy #0
	lda tmp2
	sta (ptr_l),y
	; TOP
	clc
	lda ptr_l
	adc #<CLIP_STRIDE
	sta ptr_l
	lda ptr_h
	adc #>CLIP_STRIDE
	sta ptr_h
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
	; n++
	ldy col
	ldx COL_CLIP_N,y
	inx
	txa
	sta COL_CLIP_N,y
.ccp_full
	rts

; ---------------------------------------------------------------------------
; clip_col_push_if_new — A = sector; push with current ytop/ybot only if that
; id is not already on this column's stack. Soft same-flat uses this so every
; visited rect keeps its aperture (rewrite would lose earlier ids).
; Requires clip_base bound. Clobbers: tmp0,tmp2,tmp3, ptr_l/h, X, Y
; ---------------------------------------------------------------------------
clip_col_push_if_new
	sta tmp2
	ldy col
	lda COL_CLIP_N,y
	beq .ccpn_do
	sta tmp3
	lda clip_base_l
	sta ptr_l
	lda clip_base_h
	sta ptr_h
.ccpn_lp
	ldy #0
	lda (ptr_l),y
	cmp tmp2
	beq .ccpn_rts			; already on stack
	dec tmp3
	beq .ccpn_do
	inc ptr_l
	bne .ccpn_lp
	inc ptr_h
	jmp .ccpn_lp
.ccpn_do
	lda tmp2
	jmp clip_col_push
.ccpn_rts
	rts

; ---------------------------------------------------------------------------
; clip_col_find — find sector A in column's clip stack (search far→near)
; Exit: C=0 found, tmp0=clip_top, tmp1=clip_bot; C=1 not found
; Exact id only. Soft steps use clip_col_push_if_new. Skips empty windows.
; Re-binds clip_base (item draw walks many cols). Clobbers: tmp2,tmp3,
; ptr_l/h, aux_l/h, X, Y
; ---------------------------------------------------------------------------
clip_col_find
	sta tmp2				; wanted sector
	ldy col
	lda COL_CLIP_N,y
	beq .ccf_miss
	sta tmp3				; n count
	jsr clip_col_bind
	lda tmp3
	sec
	sbc #1				; n-1 (n ≥ 1 here)
	clc
	adc clip_base_l
	sta ptr_l
	lda clip_base_h
	adc #0
	sta ptr_h
.ccf_lp
	ldy #0
	lda (ptr_l),y
	cmp tmp2
	bne .ccf_next
	; load TOP/BOT
	clc
	lda ptr_l
	adc #<CLIP_STRIDE
	sta aux_l
	lda ptr_h
	adc #>CLIP_STRIDE
	sta aux_h
	lda (aux_l),y
	sta tmp0				; top
	clc
	lda aux_l
	adc #<CLIP_STRIDE
	sta aux_l
	lda aux_h
	adc #>CLIP_STRIDE
	sta aux_h
	lda (aux_l),y
	sta tmp1				; bot
	lda tmp0
	cmp tmp1
	bcs .ccf_next			; empty — keep looking
	clc
	rts
.ccf_next
	dec tmp3
	beq .ccf_miss
	lda ptr_l
	bne .ccf_dec
	dec ptr_h
.ccf_dec
	dec ptr_l
	jmp .ccf_lp
.ccf_miss
	sec
	rts
