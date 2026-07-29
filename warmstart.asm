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

	lda #CHARSET_PTR		; charset baked at $3800 in PRG
	sta $d018
	jsr init_weapon			; HUD weapon sprites + muzzle flash state

	; Clear colour RAM (chars filled by blit_fb)
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
	jsr play_sound_init
	jsr input_irq_init
	jmp game_start
