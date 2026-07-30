; Status bar — bottom row, 8 chars left + 8 chars right (VicDoom doomfont)
; Left:  ammo icon + 3 digits + health icon + 3 digits  (red)
; Right: armor icon + 3 digits + space + R/Y/B keyglyphs
; Painted into FRAMEBUFFER/LIGHTFRAME row 24 when hud_dirty (pre-blit).
!zone hud

HUD_ROW = 24
HUD_COL_AMMO = 0
HUD_COL_HEALTH = 4
HUD_COL_ARMOR = 32
HUD_COL_KEYS = 37

; Per-weapon ammo icons (cyan): fist/saw blank; pistol, shotgun, chaingun, rocket
hud_ammo_icons
	!byte 32, 32, 38, 31, 34, 60
HUD_HEALTH_ICON = 47			; '/' medkit
HUD_ARMOR_ICON = 30
HUD_KEY_ICON = 59			; ';' keycard
HUD_SPACE = 32

HUD_COL_RED = 2
HUD_COL_CYAN = 3
HUD_COL_GREEN = 5
HUD_COL_BLUE = 6
HUD_COL_YELLOW = 7
HUD_COL_WHITE = 1

; ---------------------------------------------------------------------------
; draw_hud — into FB row 24 if hud_dirty (DDA leaves those cells alone)
; ---------------------------------------------------------------------------
draw_hud
	lda hud_dirty
	bne .dh_go
	rts
.dh_go
	lda #0
	sta hud_dirty

	; --- left: ammo (icon + count for current weapon) ---
	ldx cur_weapon
	lda hud_ammo_icons,x
	sta tmp0
	ldx #HUD_COL_AMMO
	lda #HUD_COL_CYAN
	jsr hud_put

	ldx cur_weapon
	lda wpn_ammo_idx,x
	tax
	lda ammo_bullets,x
	ldx #HUD_COL_AMMO + 1
	ldy #HUD_COL_RED
	jsr hud_print3

	; --- left: health ---
	ldx #HUD_COL_HEALTH
	lda #HUD_HEALTH_ICON
	sta tmp0
	lda #HUD_COL_WHITE
	jsr hud_put

	lda health
	ldx #HUD_COL_HEALTH + 1
	ldy #HUD_COL_RED
	jsr hud_print3

	; --- right: armor (green ≤100%, blue >100%) ---
	lda #HUD_COL_GREEN
	ldx armor
	cpx #101
	bcc .dh_armor_col
	lda #HUD_COL_BLUE
.dh_armor_col
	sta tmp2			; armor colour
	ldx #HUD_COL_ARMOR
	lda #HUD_ARMOR_ICON
	sta tmp0
	lda tmp2
	jsr hud_put

	lda armor
	ldx #HUD_COL_ARMOR + 1
	ldy tmp2
	jsr hud_print3

	ldx #HUD_COL_ARMOR + 4
	lda #HUD_SPACE
	sta tmp0
	lda #0
	jsr hud_put

	; --- right: keys (red / yellow / blue) ---
	ldx #0
.key_loop
	txa
	clc
	adc #HUD_COL_KEYS
	sta tmp5			; column
	lda #HUD_KEY_ICON
	sta tmp0
	lda key_masks,x
	bit keys
	beq .key_off
	lda key_colors,x
	bne .key_col
.key_off
	lda #0				; black = invisible on black bg
.key_col
	stx tmp4			; save key index
	ldx tmp5
	jsr hud_put
	ldx tmp4
	inx
	cpx #3
	bcc .key_loop
	rts

key_masks
	!byte $01, $02, $04		; red, yellow, blue
key_colors
	!byte HUD_COL_RED, HUD_COL_YELLOW, HUD_COL_BLUE

; ---------------------------------------------------------------------------
; hud_put — A = colour, tmp0 = pattern, X = column, row HUD_ROW
; ---------------------------------------------------------------------------
hud_put
	sta tmp1			; colour
	lda colbaselo,x
	sta col_base_l
	sta pat_base_l
	lda colbasehi,x
	sta col_base_h
	clc
	adc #4				; LIGHTFRAME = FRAMEBUFFER+$400
	sta pat_base_h
	ldy #HUD_ROW
	lda tmp1
	sta (col_base_l),y
	lda tmp0
	sta (pat_base_l),y
	rts

; ---------------------------------------------------------------------------
; hud_print3 — A = value 0–255, X = start column, Y = digit colour
; Uses tmp0–tmp4. Digit glyphs are doomfont $30–$39.
; ---------------------------------------------------------------------------
hud_print3
	sty tmp3			; colour
	stx tmp4			; start column
	sta tmp0			; remaining
	lda #0
	sta tmp1			; hundreds
	sta tmp2			; tens
.hund
	lda tmp0
	cmp #100
	bcc .tens
	sbc #100
	sta tmp0
	inc tmp1
	bne .hund
.tens
	lda tmp0
	cmp #10
	bcc .ones
	sbc #10
	sta tmp0
	inc tmp2
	bne .tens
.ones
	; tmp0=ones, tmp1=hundreds, tmp2=tens → glyphs; ones saved on stack
	lda tmp0
	pha
	lda tmp1
	clc
	adc #$30
	sta tmp0
	ldx tmp4
	lda tmp3
	jsr hud_put
	lda tmp2
	clc
	adc #$30
	sta tmp0
	ldx tmp4
	inx
	lda tmp3
	jsr hud_put
	pla
	clc
	adc #$30
	sta tmp0
	ldx tmp4
	inx
	inx
	lda tmp3
	jmp hud_put
