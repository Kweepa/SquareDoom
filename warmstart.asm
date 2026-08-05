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

	; dpsounds/levelstats load at $c800 (SQTAB slot); relocate before SQTAB build
	jsr copy_kernal_blob
	jsr init_sqtabs
	jsr prof_init
	jsr play_sound_init
	jsr input_irq_init
	jmp game_start

; Copy kernal_blob → SEC_WDARK_END (size KERNAL_BLOB_SIZE). Uses $fb–$fe.
copy_kernal_blob
	lda #<kernal_blob
	sta $fb
	lda #>kernal_blob
	sta $fc
	lda #<SEC_WDARK_END
	sta $fd
	lda #>SEC_WDARK_END
	sta $fe
	ldy #0
	ldx #>KERNAL_BLOB_SIZE
	beq .last
.pages
	lda ($fb),y
	sta ($fd),y
	iny
	bne .pages
	inc $fc
	inc $fe
	dex
	bne .pages
.last
	ldx #<KERNAL_BLOB_SIZE
	beq .done
.tail
	lda ($fb),y
	sta ($fd),y
	iny
	dex
	bne .tail
.done
	rts
