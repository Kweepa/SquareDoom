!zone render_clip

; ============================================================================
; render_clip.asm — per-column portal clip stack + SEC_SEEN helpers
; ============================================================================
; Interleaved layout: COL_CLIP_ENTRIES[col] = CLIP_MAX × {top,bot,zl,zh}.
; clip_base → column start; entry n at offset n×4 (CLIP_COL_BYTES ≤ 255).
; Entry 0 = nearest (player, Z=0); higher n = farther after hard portals /
; solid close. Z = full 16-bit fish wallz from calc_wallz.
; Billboards: want16 = depth16·255/512 in wz_x — both Z and item depth16
; are perpendicular distances (255/tile vs 512/tile), one constant scale.
; Closed (top>=bot): occlude if Z < want; Z == want ties fall back nearer.
;
; During cast_column, clip_n (zp) holds the next byte offset; COL_CLIP_N is
; written once at column end. Item draw reads COL_CLIP_N + clip_col_find.
; ============================================================================

; ---------------------------------------------------------------------------
; next_sector_seen — advance the per-frame visibility generation.
; On wrap, clear stale generation 0 entries and restart at generation 1.
; ---------------------------------------------------------------------------
next_sector_seen
	inc seen_gen
	bne .nss_done
	jsr clear_sector_seen
	inc seen_gen
.nss_done
	lda seen_gen
	sta mark_seen_gen + 1
	rts

; ---------------------------------------------------------------------------
; clear_sector_seen — clear SEC_SEEN[1..level_sector_max]
; Also used by level setup while SEC_SEEN is flat-group scratch.
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
; mark_seen — X = sector id; stamp visible this frame + ever-visited (id 0 ignored)
; ---------------------------------------------------------------------------
mark_seen
	txa
	beq .ms_done
mark_seen_gen
	lda #0				; self-modified once/frame by next_sector_seen
	sta SEC_SEEN,x
	lda #$ff
	sta SEC_VISITED,x
.ms_done
	rts

; ---------------------------------------------------------------------------
; clip_col_bind — clip_base = COL_CLIP_ENTRIES + col*CLIP_COL_BYTES
; Clobbers: X, A
; ---------------------------------------------------------------------------
clip_col_bind
	ldx col
	lda clip_base_lo,x
	sta clip_base_l
	lda clip_base_hi,x
	sta clip_base_h
	rts

; ---------------------------------------------------------------------------
; clip_col_reset — clip_n = 0; COL_CLIP_N[col] = 0; bind clip_base
; ---------------------------------------------------------------------------
clip_col_reset
	ldy col
	lda #0
	sta COL_CLIP_N,y
	sta clip_n
	jmp clip_col_bind

; COL_CLIP_ENTRIES + col*CLIP_COL_BYTES
clip_base_lo
!for .col, 40 {
	!byte <(COL_CLIP_ENTRIES + (.col - 1) * CLIP_COL_BYTES)
}
clip_base_hi
!for .col, 40 {
	!byte >(COL_CLIP_ENTRIES + (.col - 1) * CLIP_COL_BYTES)
}

; ---------------------------------------------------------------------------
; clip_col_push — push {ytop, ybot, wallz_l, wallz_h} if room
; Requires clip_base bound; uses zp clip_n (byte offset). Clobbers: Y, A
; ---------------------------------------------------------------------------
clip_col_push
	ldy clip_n
	cpy #CLIP_COL_BYTES
	bcs .ccp_full
	lda ytop
	sta (clip_base_l),y
	iny
	lda ybot
	sta (clip_base_l),y
	iny
	lda wallz_l
	sta (clip_base_l),y
	iny
	lda wallz_h
	sta (clip_base_l),y
	iny
	sty clip_n
.ccp_full
	rts

; ---------------------------------------------------------------------------
; clip_col_commit — COL_CLIP_N[col] = clip_n / 4 (end of cast_column)
; Clobbers: A, Y
; ---------------------------------------------------------------------------
clip_col_commit
	lda clip_n
	lsr
	lsr
	ldy col
	sta COL_CLIP_N,y
	rts

; ---------------------------------------------------------------------------
; clip_col_find — want16 in wz_x_l/h (same scale as stack Z: ≈255·perp tiles)
; Requires clip_base already bound (item draw binds once, advances per col).
; Entries are pushed near→far with increasing Z; an empty (top>=bot) entry is
; always last (DDA stops after closing). Pick the last entry with Z <= want:
;   open  → that aperture
;   empty → Z < want: occluded (miss); Z == want: quantization tie — the
;           sprite sits on that surface, use the previous (open) entry
; Exit: C=0 found, tmp0=top, tmp1=bot; C=1 miss/occluded
; Clobbers: tmp3,tmp4,tmp5, X, Y, A
; ---------------------------------------------------------------------------
clip_col_find
	ldy col
	lda COL_CLIP_N,y
	bne .ccf_go
.ccf_miss
	sec
	rts
.ccf_go
	sta tmp3				; n (entry count)
	; clip_base already set by caller
	lda #$ff
	sta tmp4				; best entry index ($FF = none)
	ldx #0
.ccf_lp
	txa
	asl
	asl
	tay					; Y = entry×4
	iny
	iny
	iny					; ZH
	lda (clip_base_l),y
	cmp wz_x_h
	bcc .ccf_lt				; zh < want_h → Z < want
	bne .ccf_done			; zh > want_h → Z > want; stop
	dey					; ZL
	lda (clip_base_l),y
	cmp wz_x_l
	beq .ccf_eq
	bcs .ccf_done			; Z > want; stop
.ccf_lt
	stx tmp4
	lda #0
	sta tmp5				; Z < want
	beq .ccf_nx
.ccf_eq
	stx tmp4
	lda #1
	sta tmp5				; Z == want (tie)
.ccf_nx
	inx
	cpx tmp3
	bcc .ccf_lp
.ccf_done
	lda tmp4
	bmi .ccf_miss
.ccf_load
	asl
	asl
	tay
	lda (clip_base_l),y
	sta tmp0				; top
	iny
	lda (clip_base_l),y
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
	lda tmp4
	bpl .ccf_load			; always (tmp4 ≥ 0)
.ccf_miss2
	sec
	rts
.ccf_ok
	clc
	rts
