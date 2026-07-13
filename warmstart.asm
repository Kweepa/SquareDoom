!zone warmstart

warmstart
	sei
	lda #$36		; BASIC out, KERNAL+I/O in
	sta $01

	lda #$ff
	sta $dc02		; CIA1 Port A out (keyboard cols)
	lda #0
	sta $dc03		; Port B in (keyboard rows)

	lda #$00
	sta $d020		; border black
	sta $d021		; background black

	; Fill screen with inverse space ($a0)
	lda #$a0
	ldx #0
.fill_scr
	sta $0400,x
	sta $0500,x
	sta $0600,x
	sta $06e8,x
	inx
	bne .fill_scr

	; Clear colour RAM
	lda #0
	ldx #0
.fill_col
	sta $d800,x
	sta $d900,x
	sta $da00,x
	sta $dae8,x
	inx
	bne .fill_col

	jsr find_spawn
	jsr update_eye
	jmp gameloop

; Scan item table for type 0 (spawn); set playerx/y as 8.8 world
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
	lda #$80
	sta playerx
	sta playery
	lda #0
	sta playera
	rts
.fs_found
	ldy #1
	lda (ptr_l),y
	sta playerx_h
	; Editor camera sits at y≈102 in same tile; match preview pose
	lda #102
	sta playery_h
	lda #$80
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
	jsr sector_floor
	clc
	adc #3
	sta eyeheight
	rts
.ue_empty
	lda #11
	sta eyeheight
	rts
