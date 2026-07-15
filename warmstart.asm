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
	jsr find_spawn
	lda #$ff
	sta last_playera			; force rebuild_col_rays
	jsr update_eye
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

	; Patch light UDGs $00–$08 (8 wall tiles + floor = 72 bytes)
	ldx #0
.patch
	lda dither_wall_glyphs,x
	sta CHARSET,x
	inx
	cpx #72
	bcc .patch

	lda #CHARSET_PTR
	sta $d018
	rts

; Scan item table for type 0 (spawn); set world-byte player*_h
find_spawn
	lda #<level_items
	sta ptr_l
	lda #>level_items
	sta ptr_h
	ldx #0
.fs_loop
	ldy #0
	lda (ptr_l),y
	cmp #$ff
	beq .fs_default
	cmp #0
	beq .fs_found
	clc
	lda ptr_l
	adc #4
	sta ptr_l
	bcc .fs_nc
	inc ptr_h
.fs_nc
	inx
	cpx #MAX_ITEMS
	bcc .fs_loop
.fs_default
	lda #128
	sta playerx_h
	sta playery_h
	lda #0
	sta playerx
	sta playery
	sta playera
	rts
.fs_found
	ldy #1
	lda (ptr_l),y
	sta playerx_h
	; Editor camera sits at y≈102 in same tile; match preview pose
	lda #102
	sta playery_h
	lda #0
	sta playerx
	sta playery
	lda #250
	sta playera
	rts

; eyeheight = floor(sector at player) + 3
update_eye
	jsr player_tile
	jsr map_sector_id
	beq .ue_empty
	tax
	lda SEC_FLOOR,x
	clc
	adc #3
	sta eyeheight
	rts
.ue_empty
	lda #11
	sta eyeheight
	rts
