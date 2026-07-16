!zone warmstart

CHARSET_PTR = $1e			; $D018: screen $0400, charset $3800

warmstart
	sei
	lda #$35		; BASIC+KERNAL out, I/O in (RAM under $A000/$E000)
	sta $01

	lda #$ff
	sta $dc02		; CIA1 Port A out (keyboard cols)
	lda #0
	sta $dc03		; Port B in (keyboard rows)

	lda #$00
	sta $d020		; border black
	sta $d021		; background black

	jsr init_charset		; ROM font @ $3800 + dither UDGs
	jsr init_weapon			; HUD weapon sprites + muzzle flash state

	; Clear colour RAM (chars filled by blit_fb_to_chars)
	lda #0
	ldx #0
.fill_col
	sta $d800,x
	sta $d900,x
	sta $da00,x
	sta $dae8,x
	inx
	bne .fill_col

	jsr init_sqtabs
	jsr prof_init
	jsr input_irq_init
	jsr start_level
	cli
	jmp gameloop

; Copy CHARROM → $3800, patch light glyphs $00–$08, point VIC at it
init_charset
	lda $01
	pha
	lda #$33			; CHARROM visible at $D000
	sta $01
	ldx #0
.copy0
	lda $d000,x
	sta CHARSET,x
	lda $d100,x
	sta CHARSET+$100,x
	lda $d200,x
	sta CHARSET+$200,x
	lda $d300,x
	sta CHARSET+$300,x
	lda $d400,x
	sta CHARSET+$400,x
	lda $d500,x
	sta CHARSET+$500,x
	lda $d600,x
	sta CHARSET+$600,x
	lda $d700,x
	sta CHARSET+$700,x
	inx
	bne .copy0
	pla
	sta $01				; restore $35 (KERNAL out, I/O in)

	; Overlay VicDoom doomfont glyphs 0–63 (digits, HUD icons)
	ldx #0
.copy_df
	lda doomfont_udgs,x
	sta CHARSET,x
	lda doomfont_udgs+$100,x
	sta CHARSET+$100,x
	inx
	bne .copy_df

	; Patch light UDGs $00–$09 (8 wall + floor + item = 80 bytes)
	; overwrites doomfont chars 0–9 (view patterns)
	ldx #0
.patch
	lda dither_wall_glyphs,x
	sta CHARSET,x
	inx
	cpx #80
	bcc .patch

	; A–Z for top-line messages at screen codes 192–217 (dither owns 0–9)
	ldx #0
.msgfont
	lda doomfont_udgs + 8,x		; char 1 = 'A'
	sta CHARSET + 192 * 8,x
	inx
	cpx #26 * 8
	bne .msgfont

	lda #CHARSET_PTR
	sta $d018
	rts
