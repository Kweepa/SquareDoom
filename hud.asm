; Status bar — bottom row, 8 chars left + 8 chars right (VicDoom doomfont)
; Left:  ammo icon + 3 digits + health icon + 3 digits  (red)
; Right: armor icon + 3 digits + space + R/Y/B keyglyphs
!zone hud

HUD_ROW = 24
HUD_SCR_LEFT = $0400 + HUD_ROW * 40		; $07c0
HUD_COL_LEFT = $d800 + HUD_ROW * 40		; $dbc0
HUD_SCR_RIGHT = HUD_SCR_LEFT + 32		; $07e0
HUD_COL_RIGHT = HUD_COL_LEFT + 32		; $dbe0

HUD_AMMO_ICON = 38			; pistol glyph (VicDoom weaponSymbol)
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
; draw_hud — poke status after blit (overwrites bottom view strip)
; ---------------------------------------------------------------------------
draw_hud
	; --- left: ammo ---
	lda #HUD_AMMO_ICON
	sta HUD_SCR_LEFT
	lda #HUD_COL_CYAN
	sta HUD_COL_LEFT

	lda ammo
	ldx #<HUD_SCR_LEFT + 1
	ldy #>HUD_SCR_LEFT + 1
	jsr hud_print3
	lda #HUD_COL_RED
	sta HUD_COL_LEFT + 1
	sta HUD_COL_LEFT + 2
	sta HUD_COL_LEFT + 3

	; --- left: health ---
	lda #HUD_HEALTH_ICON
	sta HUD_SCR_LEFT + 4
	lda #HUD_COL_WHITE
	sta HUD_COL_LEFT + 4

	lda health
	ldx #<HUD_SCR_LEFT + 5
	ldy #>HUD_SCR_LEFT + 5
	jsr hud_print3
	lda #HUD_COL_RED
	sta HUD_COL_LEFT + 5
	sta HUD_COL_LEFT + 6
	sta HUD_COL_LEFT + 7

	; --- right: armor ---
	lda #HUD_ARMOR_ICON
	sta HUD_SCR_RIGHT
	lda #HUD_COL_GREEN
	sta HUD_COL_RIGHT

	lda armor
	ldx #<HUD_SCR_RIGHT + 1
	ldy #>HUD_SCR_RIGHT + 1
	jsr hud_print3
	lda #HUD_COL_GREEN
	sta HUD_COL_RIGHT + 1
	sta HUD_COL_RIGHT + 2
	sta HUD_COL_RIGHT + 3

	lda #HUD_SPACE
	sta HUD_SCR_RIGHT + 4
	lda #0
	sta HUD_COL_RIGHT + 4

	; --- right: keys (red / yellow / blue) ---
	ldx #0
.key_loop
	lda #HUD_KEY_ICON
	sta HUD_SCR_RIGHT + 5,x
	lda key_masks,x
	bit keys
	beq .key_off
	lda key_colors,x
	bne .key_col
.key_off
	lda #0				; black = invisible on black bg
.key_col
	sta HUD_COL_RIGHT + 5,x
	inx
	cpx #3
	bcc .key_loop
	rts

key_masks
	!byte $01, $02, $04		; red, yellow, blue
key_colors
	!byte HUD_COL_RED, HUD_COL_YELLOW, HUD_COL_BLUE

; ---------------------------------------------------------------------------
; hud_print3 — write 3 ASCII digits of A (0–255) to screen at X=lo Y=hi
; Uses tmp0–tmp2. Digit glyphs are doomfont $30–$39.
; ---------------------------------------------------------------------------
hud_print3
	stx ptr_l
	sty ptr_h
	sta tmp0			; remaining
	lda #0
	sta tmp1			; hundreds
	sta tmp2			; tens
.hund
	lda tmp0
	cmp #100
	bcc .tens
	sec
	sbc #100
	sta tmp0
	inc tmp1
	bne .hund
.tens
	lda tmp0
	cmp #10
	bcc .ones
	sec
	sbc #10
	sta tmp0
	inc tmp2
	bne .tens
.ones
	lda tmp1
	clc
	adc #$30
	ldy #0
	sta (ptr_l),y
	lda tmp2
	clc
	adc #$30
	iny
	sta (ptr_l),y
	lda tmp0
	clc
	adc #$30
	iny
	sta (ptr_l),y
	rts
