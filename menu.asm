; SquareDoom MENU overlay — load @ LOCODE_BASE ($0400), JMP from boot trampoline.
; Entry: +0 run_menu, +3 copy_vic. After start: load GFX, copy_vic, trampoline GAME.
; Selectors at $02FA–$02FF survive GAME overwrite. SFX: CIA1 Timer A + menu playsound.
!cpu 6502
!to "menu.prg", cbm

!source "mem_vic.asm"

MENU_SLOTS	= 8
BOX_PAD		= 2
BOX_VGAP	= 1			; empty rows inside box top/bottom
CURSOR_GAP	= 1			; blank cols between skull and text
CURSOR_CELLS	= 3			; 24px skull cursor
CURSOR_FRAMES	= 2			; overlay eyes off/on
MENU_LOGO_ROWS	= 8			; MCM Doom logo (16×8 chars)
LOGO_COLS	= 16
LOGO_LEFT	= (40 - LOGO_COLS) / 2	; 12
LOGO_TOP	= 0			; flush with top (border is black)
BRAND_KEEP_ROWS	= LOGO_TOP + MENU_LOGO_ROWS	; rows 0–7 (logo band)
CONTENT_TOP	= BRAND_KEEP_ROWS + 1	; row 8 blank (MCM→hires mux)
TITLE_ROW	= BRAND_KEEP_ROWS + 1	; 2× titles stay on rows 9–10
TITLE_ABOVE	= 3			; 2-row title + 1 gap (min box_top)
TITLE_CONTENT_TOP = CONTENT_TOP + TITLE_ABOVE	; 12
HINT_ROW	= 23
HINT_COL	= 11			; dark grey move / adjust / select labels
HINT_GAP	= 8			; px between key sprite and label
HINT_SPR_Y	= 228			; 21px sprite centered on row 23
MUX_LOGO_RASTER	= 30			; MCM on in the top border
MUX_HIRES_RASTER = 116			; first non-badline of row 8 (blank under logo)
ITEM_ROWS	= 2			; option items are 2× glyphs (16px)
dbl_hi		= $8000			; above bitmap $7F3F / matrix $4000
dbl_lo		= $8100			; byte → doubled bits 7–0
!if dbl_lo + 256 > MEM_LEVEL {
	!error "dbl tabs overlap HIGH"
}
CURSOR_TICK_MAX	= 20			; skull overlay; was 5 (~1/4 speed)
COL_MAIN	= 0			; black (menus + surround)
MCM_BG		= COL_MAIN		; $d021 during logo = black (bitmap 00)
MCM_COL		= 2			; colour RAM default for bitmap 11
HINT_SPR_RAM	= $4800			; 6×64 in VIC bank 1 (menu-only)
HINT_SPR_PTR0	= (HINT_SPR_RAM - SCREEN) / 64
CURSOR_SPR_RAM	= HINT_SPR_RAM + HINT_SPR_COUNT * 64
CURSOR_SPR_PTR0	= (CURSOR_SPR_RAM - SCREEN) / 64
WIP_SPR_RAM	= CURSOR_SPR_RAM + CURSOR_SPR_COUNT * 64	; $4B40
WIP_SPR_PTR0	= (WIP_SPR_RAM - SCREEN) / 64		; sprite 0
WIP_COL		= 1			; white
WIP_X_MIN	= 24
WIP_X_MAX	= 320
WIP_Y_MIN	= 50
WIP_Y_MAX	= 229
WIP_SPR_EN_BIT	= %00000001
glyph_lj	= $4400			; 96×8 lead-justified glyphs; below sprite RAM

TEXT_COL	= 2			; red options
HILITE_COL	= 7			; yellow selected
TITLE_COL	= 7			; yellow titles
HINT_KEY_COL	= 11			; dark grey key caps
HINT_OVER_COL	= 1			; white letter overlay on the keys
MENU_BORDER	= COL_MAIN
COL_BOX		= 0			; black
STORY_BG	= COL_MAIN		; black around the white paper
STORY_BOX	= 1			; white story panel
STORY_TEXT	= 0			; black story text
STORY_GREY_TOP	= BRAND_KEEP_ROWS	; story/text panels start just below the logo
MARK_CARET	= $1e			; !scr "^" — toggle colour span, not drawn
FONT_GAP	= 1			; pixels after each glyph
HYPHEN_I	= '-' - ' '		; `--` : second hyphen 1px left (em-dash)
SPACE_W		= 4			; empty-glyph / space width

NM_BACK		= 256 - 66
NM_START	= 256 - 10
NM_ORDER	= 256 - 3
NM_CTRL		= 256 - 4
NM_HELP		= 256 - 5
NM_CREDITS	= 256 - 7
NM_QUIT		= 256 - 6

UI_UP		= 1
UI_DOWN		= 2
UI_LEFT		= 4
UI_RIGHT	= 8
UI_SELECT	= 16
UI_ESC		= 32

ptr_l		= $fb
ptr_h		= $fc
ui_str_l	= $f9
ui_str_h	= $fa
ptr_r_l		= $f5			; bitmap cell to the right of ptr
ptr_r_h		= $f6
ptr_r2_l	= $f3			; third cell (2× blit)
ptr_r2_h	= $f4
gptr_l		= $f7			; current glyph (8 bytes)
gptr_h		= $f8
tmp0		= $02
tmp1		= $03
tmp2		= $04
tmp3		= $05
tmp4		= $06
tmp5		= $07
aux_l		= $fd
aux_h		= $fe
; Match zp.asm — playsound / menu_sfx (boot BSS still holds boot.prg)
sound_index	= $b2
sound_ptr_l	= $b3
sound_ptr_h	= $b4
sound_priority	= $c1
sound_count	= $c2
sound_max	= $c3
ps_save_x	= $c4
ps_save_y	= $c5
mouse_en	= $38			; match zp.asm — 1351 on/off (survives locode LOAD)
; copy_block_up (boot-only; aliases menu draw ZP)
src_ptr		= ptr_l
dst_ptr		= ptr_r_l

*= LOCODE_BASE
	jmp run_menu
	jmp copy_vic

; GFX staging $A000 → sprite tail $D000 + charset $D800 (Krill LOAD_UNDER_D000=0).
copy_vic
	sei
	lda #$34
	sta $01
	lda #<GFX_STAGING
	sta src_ptr
	lda #>GFX_STAGING
	sta src_ptr+1
	lda #<(VIC_SPRITES + SPRITE_HEAD)
	sta dst_ptr
	lda #>(VIC_SPRITES + SPRITE_HEAD)
	sta dst_ptr+1
	ldx #>SPRITE_TAIL
	ldy #<SPRITE_TAIL
	jsr copy_block_up
	lda #<(GFX_STAGING + SPRITE_TAIL)
	sta src_ptr
	lda #>(GFX_STAGING + SPRITE_TAIL)
	sta src_ptr+1
	lda #<CHARSET
	sta dst_ptr
	lda #>CHARSET
	sta dst_ptr+1
	ldx #>CHARSET_BYTES
	ldy #<CHARSET_BYTES
	jsr copy_block_up
	lda #$36
	sta $01
	cli
	rts

; src_ptr → dst_ptr, size X=pages Y=frac. dst > src; overlap-safe (high→low).
; Ported from Quake64 loader.asm.
copy_block_up
	txa
	clc
	adc src_ptr+1
	sta src_ptr+1
	txa
	clc
	adc dst_ptr+1
	sta dst_ptr+1
	cpy #0
	beq .cbu_pages
.cbu_frac
	dey
	lda (src_ptr),y
	sta (dst_ptr),y
	tya
	bne .cbu_frac
.cbu_pages
	cpx #0
	beq .cbu_rts
	dec src_ptr+1
	dec dst_ptr+1
.cbu_page
	dey				; 0 → 255
	lda (src_ptr),y
	sta (dst_ptr),y
	tya
	bne .cbu_page
	dex
	jmp .cbu_pages
.cbu_rts
	rts

run_menu
	sei
	jsr init_font_tabs
	jsr init_menu_vic
	lda #0
	sta menu_id
	sta menu_item
	sta menu_stack_d
	sta menu_can_ret
	sta hint_spr_en
	sta cursor_spr_en
	sta cursor_frame
	sta cursor_tick
	sta menu_mux_phase
	sta menu_raster_en
	lda #15
	sta effects_vol
	lda #10
	sta music_vol
	jsr copy_menu_sprites
	jsr setup_wip_spr
	jsr setup_logo_sprites
	jsr menu_sfx_init
	jsr detect_mouse
	jsr clear_screen_all
	jsr sync_vol_strings
	jsr sync_mouse_string
	lda game_complete
	cmp #1
	bne .rm_menu
	lda #0
	sta game_complete
	lda #<ending_lo
	ldy #>ending_lo
	ldx #ENDING_PAGES
	jsr show_story_pages
.rm_menu
	jsr draw_menu
.rm_loop
	jsr ui_read_keys
	jsr wait_frame

	lda #UI_UP
	and ui_pressed
	beq .rm_nou
	jsr menu_move_up
.rm_nou
	lda #UI_DOWN
	and ui_pressed
	beq .rm_nod
	jsr menu_move_down
.rm_nod
	lda menu_id
	cmp #3
	bne .rm_nov
	jsr menu_vol_input
.rm_nov
	lda #UI_ESC
	and ui_pressed
	beq .rm_noe
	jsr menu_esc
.rm_noe
	lda #UI_SELECT
	and ui_pressed
	beq .rm_acted
	jsr menu_select
	bcs .rm_done
.rm_acted
	lda ui_pressed
	beq .rm_loop
.rm_rel
	jsr wait_frame
	jsr ui_read_keys
	lda ui_keys
	bne .rm_rel
	jmp .rm_loop
.rm_done
	jsr menu_sfx_done
	lda $d011
	and #%11101111				; DEN off through GFX copy / GAME load
	sta $d011
	lda #0
	sta $d015
	sta $d020
	sta $d021

!if USE_KRILL {
	ldx #<name_gfx
	ldy #>name_gfx
	jsr krill_load
} else {
	jsr kernal_prepare
	lda #3
	ldx #<name_gfx
	ldy #>name_gfx
	jsr kernal_load_sa1
}
	bcs .rm_fail
	jsr copy_vic

	ldx #0
.rm_copy
	lda game_stub_src,x
	sta KRILL_STUB,x
	inx
	cpx #game_stub_len
	bne .rm_copy
	jmp KRILL_STUB

.rm_fail
	lda #BANK_LOADER
	sta $01
.rm_hang
	jmp .rm_hang

; X/Y = 0-terminated name. Carry clear → dest from PRG header. Returns sei.
!if USE_KRILL {
krill_load
	sei
	lda #BANK_LOADER
	sta $01
	clc
	jsr loadraw
	rts
} else {
	!source "kernal_load.asm"
}

name_gfx
	!text "GFX"
	!byte 0

; GAME @ $0400 overwrites MENU; caller must live below $0400.
game_stub_src
!pseudopc KRILL_STUB {
	lda #BANK_IO
	sta $01
!if USE_KRILL {
	sei
	lda #BANK_LOADER
	sta $01
	clc
	ldx #<game_stub_name
	ldy #>game_stub_name
	jsr loadraw
	bcs game_stub_fail
} else {
	cli
	jsr $ff84				; IOINIT — CIA1 TA (menu_sfx_done stopped it)
	lda #BANK_IO
	sta $01
	lda $d011
	and #%01101111				; DEN off — IOINIT unblanks bank 0
	sta $d011
	lda #0
	jsr $ff90				; no SEARCHING on $0400 (GAME dest)
	lda #1
	sta $cc
	lda #4
	ldx #<game_stub_name
	ldy #>game_stub_name
	jsr $ffbd
	lda #1
	ldx $ba
	ldy #1
	jsr $ffba
	lda #0
	jsr $ffd5
	php
	lda #1
	jsr $ffc3
	plp
	bcs game_stub_fail
}
	ldx #$ff
	txs
	jmp LOCODE_BASE
game_stub_fail
	lda #BANK_LOADER
	sta $01
game_stub_hang
	jmp game_stub_hang
game_stub_name
	!text "GAME"
	!byte 0
}
game_stub_end = *
game_stub_len = game_stub_end - game_stub_src
!if game_stub_len > KRILL_STUB_END - KRILL_STUB {
	!error "MENU overlay stub overlaps SID shadows; len=", game_stub_len
}

menu_move_up
	lda menu_item
	sta menu_prev
	tax
	dex
	bpl .mmu
	ldx menu_size
	dex
.mmu
	stx menu_item
	jsr update_selection
	jmp sfx_movegun2

menu_move_down
	lda menu_item
	sta menu_prev
	tax
	inx
	cpx menu_size
	bcc .mmd
	ldx #0
.mmd
	stx menu_item
	jsr update_selection
	jmp sfx_movegun2

; Repaint only old + new rows (no clear / full redraw)
update_selection
	ldx menu_prev
	stx tmp4
	jsr draw_menu_item
	ldx menu_item
	stx tmp4
	jmp draw_menu_item

menu_esc
	jsr sfx_esc
	lda menu_stack_d
	beq .me_rts
	tax
	dex
	stx menu_stack_d
	lda menu_stk_m,x
	sta menu_id
	lda menu_stk_i,x
	sta menu_item
	jsr draw_menu
.me_rts
	rts

menu_vol_input
	lda menu_item
	cmp #2
	beq .mvi_mouse
	cmp #2
	bcs .mvi_o
	lda #UI_RIGHT
	and ui_pressed
	bne .mvi_i
	lda #UI_LEFT
	and ui_pressed
	beq .mvi_o
	lda menu_item
	bne .mvi_md
	jmp vol_fx_dec
.mvi_md
	jmp vol_mus_dec
.mvi_i
	lda menu_item
	bne .mvi_mi
	jmp vol_fx_inc
.mvi_mi
	jmp vol_mus_inc
.mvi_mouse
	lda #UI_RIGHT
	ora #UI_LEFT
	and ui_pressed
	beq .mvi_o
	jmp mouse_toggle
.mvi_o
	rts

vol_fx_inc
	inc effects_vol
	lda effects_vol
	and #15
	sta effects_vol
	sta $d418
	jsr sfx_movegun1
	jmp sync_redraw
vol_fx_dec
	dec effects_vol
	lda effects_vol
	and #15
	sta effects_vol
	sta $d418
	jsr sfx_movegun1
	jmp sync_redraw
vol_mus_inc
	inc music_vol
	lda music_vol
	and #15
	sta music_vol
	jsr sfx_movegun1
	jmp sync_redraw
vol_mus_dec
	dec music_vol
	lda music_vol
	and #15
	sta music_vol
	jsr sfx_movegun1
sync_redraw
	jsr sync_vol_strings
	jsr sync_mouse_string
	ldx menu_item
	stx tmp4
	jmp draw_menu_item

; 1351 Port 1: pots not stuck at $00/$FF
detect_mouse
	lda #0
	sta mouse_en
	ldx #8
.dm_samp
	ldy #0
.dm_wait
	dey
	bne .dm_wait
	lda $d419
	beq .dm_y
	cmp #$ff
	beq .dm_y
.dm_yes
	lda #1
	sta mouse_en
	rts
.dm_y
	lda $d41a
	beq .dm_next
	cmp #$ff
	bne .dm_yes
.dm_next
	dex
	bne .dm_samp
	rts

mouse_toggle
	lda mouse_en
	eor #1
	sta mouse_en
	jsr sfx_movegun1
	jmp sync_redraw

sync_mouse_string
	ldx #2
	lda mouse_en
	bne .sms_on
.sms_off
	lda str_moff,x
	sta str_mouse + 15,x
	dex
	bpl .sms_off
	rts
.sms_on
	lda str_mon,x
	sta str_mouse + 15,x
	dex
	bpl .sms_on
	rts

str_mon		!scr "on "
str_moff	!scr "off"

sync_vol_strings
	lda #<str_fx_vol
	sta ptr_l
	lda #>str_fx_vol
	sta ptr_h
	ldx #15
	lda effects_vol
	jsr write_vol2
	lda #<str_mus_vol
	sta ptr_l
	lda #>str_mus_vol
	sta ptr_h
	ldx #13
	lda music_vol
	jmp write_vol2

write_vol2
	sta tmp0
	txa
	tay
	lda tmp0
	cmp #10
	bcc .wv1
	lda #'1'
	sta (ptr_l),y
	iny
	lda tmp0
	sec
	sbc #10
	clc
	adc #'0'
	sta (ptr_l),y
	rts
.wv1
	lda #' '
	sta (ptr_l),y
	iny
	lda tmp0
	clc
	adc #'0'
	sta (ptr_l),y
	rts

menu_select
	lda menu_id
	cmp #1
	bne .ms_ep
	lda menu_item
	sta episode
.ms_ep
	lda menu_id
	asl
	asl
	asl
	clc
	adc menu_item
	tax
	lda next_menu,x
	sta tmp0

	cmp #NM_BACK
	bne .ms_nb
	jsr menu_esc
	jmp .ms_st
.ms_nb
	lda tmp0
	cmp #NM_START
	bne .ms_nv
	lda menu_id
	cmp #2				; skill menu
	beq .ms_go
	jmp .ms_st
.ms_go
	jsr sfx_shoot
	lda menu_item
	sta difficulty
	jsr menu_raster_off
	lda $d011
	and #%11101111				; DEN off — no leftover logo sprites
	sta $d011
	jsr clear_screen_all
	ldx #20
	jsr wait_frames_x
	sec
	rts
.ms_nv
	lda tmp0
	bmi .ms_tx
; same-menu nop (volume) or mouse toggle
	cmp menu_id
	bne .ms_ne
	cmp #3
	bne .ms_stay
	lda menu_item
	cmp #2
	bne .ms_stay
	jsr mouse_toggle
.ms_stay
	jmp .ms_st
.ms_ne
	bcc .ms_po
	jsr sfx_shoot
	ldx menu_stack_d
	lda menu_id
	sta menu_stk_m,x
	lda menu_item
	sta menu_stk_i,x
	inx
	stx menu_stack_d
	lda #0
	sta menu_item
	lda tmp0
	sta menu_id
	jsr draw_menu
	jmp .ms_st
.ms_po
	jsr sfx_shoot
	ldx menu_stack_d
	dex
	stx menu_stack_d
	lda menu_stk_i,x
	sta menu_item
	lda tmp0
	sta menu_id
	jsr draw_menu
	jmp .ms_st
.ms_tx
	lda tmp0
	cmp #NM_ORDER
	beq .ms_ord
	cmp #NM_CTRL
	beq .ms_ctl
	cmp #NM_HELP
	beq .ms_hlp
	cmp #NM_CREDITS
	beq .ms_crd
	cmp #NM_QUIT
	beq quit_to_basic
	jmp .ms_st
.ms_ord
	jsr sfx_shoot
	lda #<order_lo
	ldy #>order_lo
	ldx #ORDER_PAGES
	jsr show_text_pages
	jmp .ms_ret
.ms_ctl
	jsr sfx_shoot
	lda #<control_text
	ldy #>control_text
	jsr show_text_screen
	jmp .ms_ret
.ms_hlp
	jsr sfx_shoot
	lda #<readthis_lo
	ldy #>readthis_lo
	ldx #READTHIS_PAGES
	jsr show_story_pages
	jmp .ms_ret
.ms_crd
	jsr sfx_shoot
	lda #<credits_lo
	ldy #>credits_lo
	ldx #CREDITS_PAGES
	jsr show_text_pages
.ms_ret
	jsr draw_menu
.ms_st
	clc
	rts

; Warm-start BASIC → READY.
quit_to_basic
	jsr sfx_shoot
	jsr menu_sfx_done
	sei
	lda #$37
	sta $01
	ldx #$ff
	txs
	jsr $ff8a				; RESTOR
	jsr $ff84				; IOINIT
	jsr $ff81				; CINT (default VIC/charset)
	lda #0
	sta $c6					; clear keyboard buffer (NDX)
	cli
	jmp ($a002)				; BASIC warm start

; Root→eps/options/ctrl/help/credits/quit; E1→skill; E2-3→order; skill→start; options stay/back
next_menu
	!byte 1, 3, NM_CTRL, NM_HELP, NM_CREDITS, NM_QUIT, 0, 0
	!byte 2, NM_ORDER, NM_ORDER, NM_BACK, 0, 0, 0, 0
	!byte NM_START, NM_START, NM_START, NM_BACK, 0, 0, 0, 0
	!byte 3, 3, 3, NM_BACK, 0, 0, 0, 0

menu_sizes
	!byte 6, 4, 4, 4

; --- drawing ---------------------------------------------------------------
draw_menu
	lda #COL_MAIN
	sta clear_bg
	jsr menu_blank
	jsr clear_screen

	ldx menu_id
	lda menu_sizes,x
	sta menu_size

	jsr calc_box
	lda menu_id
	beq .dm_notitle			; main: Doom logo only, no "SquareDoom"
	jsr draw_section_title
.dm_notitle
	lda #COL_BOX
	sta cell_bg
	jsr fill_option_box

	ldx #0
.dm_l
	stx tmp4
	jsr draw_menu_item
	ldx tmp4
	inx
	cpx menu_size
	bcc .dm_l

	jsr draw_hint
	lda #1
	sta cursor_spr_en
	jmp menu_unblank

; Title on TITLE_ROW (does not follow the option box)
draw_section_title
	lda #1
	sta pr_scale
	ldx #TITLE_ROW
	lda #COL_MAIN
	sta cell_bg
	lda #TITLE_COL
	sta ui_text_col
	ldy menu_id
	lda section_lo,y
	pha
	lda section_hi,y
	tay
	pla
	jmp print_centered

; Key sprites + "move / adjust / select" on HINT_ROW.
draw_hint
	lda #0
	sta pr_scale
	lda #COL_MAIN
	sta cell_bg
	lda #HINT_COL
	sta ui_text_col

	lda #<str_hint_move
	ldy #>str_hint_move
	sta ui_str_l
	sty ui_str_h
	jsr str_pix_len
	lda pr_len
	sta hint_w0

	lda #<str_hint_adjust
	ldy #>str_hint_adjust
	sta ui_str_l
	sty ui_str_h
	jsr str_pix_len
	lda pr_len
	sta hint_w1

	lda #<str_hint_select
	ldy #>str_hint_select
	sta ui_str_l
	sty ui_str_h
	jsr str_pix_len
	lda pr_len
	sta hint_w2

	; total = 3*24 + 5*HINT_GAP + w0+w1+w2
	lda #HINT_SPR_W * 3 + HINT_GAP * 5
	clc
	adc hint_w0
	adc hint_w1
	adc hint_w2
	sta tmp0
	lda #<320
	sec
	sbc tmp0
	lsr
	sta tmp1				; bitmap start x

	clc
	adc #24				; VIC sprite X origin
	sta hint_spr_x

	lda tmp1
	clc
	adc #HINT_SPR_W
	adc #HINT_GAP
	sta hint_tx				; "move" pixel x

	clc
	adc hint_w0
	adc #HINT_GAP
	sta tmp3				; AD bitmap x
	clc
	adc #24
	sta hint_spr_x + 1

	lda tmp3
	clc
	adc #HINT_SPR_W
	adc #HINT_GAP
	sta hint_tx + 1				; "adjust" pixel x

	clc
	adc hint_w1
	adc #HINT_GAP
	sta tmp3				; RETURN bitmap x
	clc
	adc #24
	sta hint_spr_x + 2

	lda tmp3
	clc
	adc #HINT_SPR_W
	adc #HINT_GAP
	sta hint_tx + 2				; "select" pixel x

	lda hint_tx
	sta hint_px
	lda #<str_hint_move
	ldy #>str_hint_move
	jsr hint_print_px
	lda hint_tx + 1
	sta hint_px
	lda #<str_hint_adjust
	ldy #>str_hint_adjust
	jsr hint_print_px
	lda hint_tx + 2
	sta hint_px
	lda #<str_hint_select
	ldy #>str_hint_select
	jsr hint_print_px

	lda #1
	sta hint_spr_en
	rts

; A/Y = string, hint_px = pixel x, HINT_ROW.
hint_print_px
	sta ui_str_l
	sty ui_str_h
	lda hint_px
	tax
	and #7
	sta pr_shift
	txa
	lsr
	lsr
	lsr
	sta pr_col
	ldx #HINT_ROW
	stx pr_row
	lda #0
	sta pr_mono
	sta pr_drop
	sta pr_scale
	jmp print_go

; box_top, box_left, box_width, box_height from menu strings (2× items)
calc_box
	lda #1
	sta pr_scale
	lda #0
	sta pix_max_l
	sta pix_max_h
	ldx #0
.cb_i
	stx tmp4
	lda menu_id
	asl
	asl
	asl
	clc
	adc tmp4
	tay
	lda menu_str_lo,y
	sta ui_str_l
	lda menu_str_hi,y
	sta ui_str_h
	jsr str_pix_len
	lda pr_len_h
	cmp pix_max_h
	bcc .cb_n
	bne .cb_u
	lda pr_len
	cmp pix_max_l
	bcc .cb_n
.cb_u
	lda pr_len
	sta pix_max_l
	lda pr_len_h
	sta pix_max_h
.cb_n
	ldx tmp4
	inx
	cpx menu_size
	bcc .cb_i
	; text_cells = ceil(max_pix / 8)
	lda pix_max_l
	clc
	adc #7
	sta pix_max_l
	lda pix_max_h
	adc #0
	lsr
	ror pix_max_l
	lsr
	ror pix_max_l
	lsr
	ror pix_max_l
	; Center the option box (cursor hangs left of the text inside it).
	lda pix_max_l
	clc
	adc #CURSOR_CELLS + CURSOR_GAP		; cursor + gap
	adc #BOX_PAD
	adc #BOX_PAD
	sta box_width
	jsr clamp_box_width
	; Vertically center box (2 rows per item + top/bottom gaps) above hint
	lda menu_size
	asl					; ITEM_ROWS
	clc
	adc #BOX_VGAP
	adc #BOX_VGAP
	sta box_height
	lda menu_id
	beq .cb_main
	lda #TITLE_CONTENT_TOP
	bne .cb_top
.cb_main
	lda #CONTENT_TOP
.cb_top
	sta box_top
	lda #HINT_ROW
	sec
	sbc box_height
	sec
	sbc box_top
	bcc .cb_ok
	lsr
	clc
	adc box_top
	sta box_top
.cb_ok
	dec box_top			; options one row up; titles stay on TITLE_ROW
	rts

; Width>40 → full screen; else center.
clamp_box_width
	lda box_width
	cmp #41
	bcc .cbw_c
	lda #40
	sta box_width
	lda #0
	sta box_left
	rts
.cbw_c
	lda #40
	sec
	sbc box_width
	lsr
	sta box_left
	rts

draw_menu_item
	lda #1
	sta pr_scale
	lda tmp4
	asl					; ITEM_ROWS
	clc
	adc box_top
	adc #BOX_VGAP
	sta pr_row

	lda #COL_BOX
	sta cell_bg

	; Blank two box rows (bitmap OR would smear proportional glyphs on redraw)
	lda box_left
	ldx pr_row
	jsr bmp_cell_addr
	ldy #0
.di_clr
	jsr bmp_blank_cell_y
	iny
	cpy box_width
	bcc .di_clr
	lda ptr_l
	clc
	adc #<320
	sta ptr_l
	lda ptr_h
	adc #>320
	sta ptr_h
	ldy #0
.di_clr2
	jsr bmp_blank_cell_y
	iny
	cpy box_width
	bcc .di_clr2

	lda tmp4
	cmp menu_item
	beq .di_h
	lda #TEXT_COL
	sta ui_text_col
	jmp .di_g
.di_h
	lda #HILITE_COL
	sta ui_text_col
	; Skull cursor: X = 24 + (box_left+BOX_PAD)*8, Y = 49+row*8 (centre 16px)
	lda box_left
	clc
	adc #BOX_PAD
	asl
	asl
	asl
	clc
	adc #24
	sta cursor_spr_x
	lda pr_row
	asl
	asl
	asl
	clc
	adc #49
	sta cursor_spr_y
.di_g
	lda menu_id
	asl
	asl
	asl
	clc
	adc tmp4
	tax
	lda menu_str_lo,x
	sta ui_str_l
	lda menu_str_hi,x
	sta ui_str_h
	lda box_left
	clc
	adc #BOX_PAD
	adc #CURSOR_CELLS + CURSOR_GAP
	ldx pr_row
	jmp print_at

; A/Y = lo-table (hi table follows), X = page count. Any key between pages.
show_text_pages
	sta page_l
	sty page_h
	stx page_n
	lda #<show_text_screen
	sta show_page_j + 1
	lda #>show_text_screen
	sta show_page_j + 2
	jmp show_pages

show_story_pages
	sta page_l
	sty page_h
	stx page_n
	lda #<show_story_screen
	sta show_page_j + 1
	lda #>show_story_screen
	sta show_page_j + 2

show_pages
	ldx #0
.sp_i
	stx page_i
	ldy page_i
	lda page_l
	sta ptr_l
	lda page_h
	sta ptr_h
	lda (ptr_l),y
	pha
	tya
	clc
	adc page_n
	tay
	lda (ptr_l),y
	tay
	pla
show_page_j
	jsr show_text_screen
	ldx page_i
	inx
	cpx page_n
	bne .sp_i
	rts

; A/Y = text blob: body lines\0..., empty\0 ends.
; Brand bar + black box; ^text^ = monospaced. Any key returns.
show_text_screen
	sta txt_ptr_l
	sty txt_ptr_h
	lda #COL_MAIN
	sta clear_bg
	lda #COL_BOX
	sta cell_bg
	lda #HILITE_COL
	sta ui_text_col
	lda #1
	sta pr_setcol
	lda #0
	sta pr_scale
	jmp .sts_body

; Read This! / endings: black surround, white panel, black text. Restores COL_MAIN.
show_story_screen
	sta txt_ptr_l
	sty txt_ptr_h
	lda #STORY_BG
	sta clear_bg
	sta $d021
	lda #STORY_BOX
	sta cell_bg
	lda #STORY_TEXT
	sta ui_text_col
	lda #0
	sta pr_setcol				; panel already black-on-white
	sta pr_scale
	jsr .sts_body
	lda #1
	sta pr_setcol
	lda #COL_MAIN
	sta clear_bg
	rts

.sts_body
	jsr menu_blank
	jsr clear_screen
	jsr calc_text_box
	jsr apply_story_layout
	jsr fill_option_box
	ldx #0
.st_l
	stx tmp4
	ldy #0
	lda (ui_str_l),y
	beq .st_wait
	lda box_top
	clc
	adc #BOX_VGAP
	adc tmp4
	tax
	lda box_left
	clc
	adc #BOX_PAD
	jsr print_marked
	jsr str_skip
	ldx tmp4
	inx
	cpx menu_size
	bcc .st_l
.st_wait
	jsr menu_unblank
	jsr wait_any_key
	rts

; Size box from body lines. Leaves ui_str at first line.
calc_text_box
	lda txt_ptr_l
	sta ui_str_l
	lda txt_ptr_h
	sta ui_str_h
	lda #0
	sta pix_max_l
	sta pix_max_h
	sta tmp4				; line count
.ct_l
	ldy #0
	lda (ui_str_l),y
	beq .ct_done
	jsr marked_str_pix_len
	lda pr_len_h
	cmp pix_max_h
	bcc .ct_n
	bne .ct_u
	lda pr_len
	cmp pix_max_l
	bcc .ct_n
.ct_u
	lda pr_len
	sta pix_max_l
	lda pr_len_h
	sta pix_max_h
.ct_n
	jsr str_skip
	inc tmp4
	bne .ct_l
.ct_done
	lda tmp4
	sta menu_size
	; text_cells = ceil(max_pix / 8)
	lda pix_max_l
	clc
	adc #7
	sta pix_max_l
	lda pix_max_h
	adc #0
	lsr
	ror pix_max_l
	lsr
	ror pix_max_l
	lsr
	ror pix_max_l
	lda pix_max_l
	clc
	adc #BOX_PAD
	adc #BOX_PAD
	adc #1					; extra cell; last glyph can spill
	sta box_width
	jsr clamp_box_width
	lda menu_size
	cmp #25 - BRAND_KEEP_ROWS - BOX_VGAP - BOX_VGAP + 1
	bcc .ct_sz
	lda #25 - BRAND_KEEP_ROWS - BOX_VGAP - BOX_VGAP
	sta menu_size
.ct_sz
	lda menu_size
	clc
	adc #BOX_VGAP
	adc #BOX_VGAP
	sta tmp5
	sta box_height
	lda #BRAND_KEEP_ROWS			; below logo; hints off on text pages
	sta box_top
	lda #25
	sec
	sbc tmp5
	sec
	sbc box_top
	bcc .ct_ok
	lsr
	clc
	adc box_top
	sta box_top
.ct_ok
	lda txt_ptr_l
	sta ui_str_l
	lda txt_ptr_h
	sta ui_str_h
	rts

; Story pages: center the white panel on the field below the logo.
apply_story_layout
	lda cell_bg
	cmp #STORY_BOX
	bne .asl_rts
	lda menu_size
	clc
	adc #BOX_VGAP
	adc #BOX_VGAP
	sta tmp5				; box height
	lda #25
	sec
	sbc #STORY_GREY_TOP
	sec
	sbc tmp5				; spare rows in grey
	bcc .asl_min
	lsr
	clc
	adc #STORY_GREY_TOP
	sta box_top
	rts
.asl_min
	lda #STORY_GREY_TOP
	sta box_top
.asl_rts
	rts

; --- hires bitmap (full menufont) ------------------------------------------
init_menu_vic
	lda #$35				; I/O in, KERNAL out (menu_sfx IRQ uses $fffe)
	sta $01
	lda #%00000010			; VIC bank 1 ($4000-$7FFF), upper 6 bits 0
	sta $dd00			; absolute — RMW of $dd00 poisons Krill IEC
	lda $d011
	and #%10000111			; clear ECM/BMM/DEN/RSEL
	ora #%00101011			; hires bitmap + 25 rows, DEN off until first draw
	sta $d011
	lda $d016
	and #%11100111
	ora #%00011000			; CSEL + MCM; IRQ keeps MCM for logo rows 0–7
	sta $d016
	lda #%00001000			; matrix $4000, bitmap $6000
	sta $d018
	lda #0
	sta $d015
	sta $d01a				; no leftover VIC IRQs
	lda #COL_MAIN
	sta $d021
	lda #MENU_BORDER
	sta $d020
	rts

; Clear rows BRAND_KEEP_ROWS..24 — leave the logo band alone.
clear_screen
	lda #<BITMAP + BRAND_KEEP_ROWS * 320
	sta ptr_l
	lda #>BITMAP + BRAND_KEEP_ROWS * 320
	sta ptr_h
	ldy #0
	lda #>(BITMAP + $2000)
	sta tmp5
	lda #0
.cs_p
	sta (ptr_l),y
	iny
	sta (ptr_l),y
	iny
	sta (ptr_l),y
	iny
	sta (ptr_l),y
	iny
	sta (ptr_l),y
	iny
	sta (ptr_l),y
	iny
	sta (ptr_l),y
	iny
	sta (ptr_l),y
	iny
	bne .cs_p
	inc ptr_h
	lda ptr_h
	cmp tmp5
	bcs .cs_col
	lda #0
	beq .cs_p
.cs_col
	; colour matrix below logo: 1000 - 9*40 = 640 (256+256+128); stop before $43F8
	ldx #0
	lda clear_bg
.cs_c
	sta SCREEN + BRAND_KEEP_ROWS * 40,x
	sta SCREEN + BRAND_KEEP_ROWS * 40 + $100,x
	inx
	bne .cs_c
	ldx #0
.cs_c2
	sta SCREEN + BRAND_KEEP_ROWS * 40 + $200,x
	inx
	cpx #<(1000 - BRAND_KEEP_ROWS * 40 - 512)
	bne .cs_c2
	rts

; Full bitmap + matrix clear (menu entry / exit).
clear_screen_all
	lda #<BITMAP
	sta ptr_l
	lda #>BITMAP
	sta ptr_h
	lda #0
	tax
	tay
.csa_p
	sta (ptr_l),y
	iny
	bne .csa_p
	inc ptr_h
	inx
	cpx #32
	bcc .csa_p
	ldx #0
	lda #COL_MAIN
.csa_c
	sta SCREEN,x
	sta SCREEN+$100,x
	sta SCREEN+$200,x
	sta SCREEN+$2e8,x
	inx
	bne .csa_c
	jmp blit_logo_mcm

blit_logo_mcm
	lda #<logo_mcm_bmp
	sta gptr_l
	lda #>logo_mcm_bmp
	sta gptr_h
	ldx #0
.blb_r
	stx tmp4
	txa
	clc
	adc #LOGO_TOP
	tax
	lda #LOGO_LEFT
	jsr bmp_cell_addr
	ldy #0
.blb_c
	lda (gptr_l),y
	sta (ptr_l),y
	iny
	cpy #LOGO_COLS * 8
	bne .blb_c
	lda gptr_l
	clc
	adc #LOGO_COLS * 8
	sta gptr_l
	bcc .blb_n
	inc gptr_h
.blb_n
	ldx tmp4
	inx
	cpx #MENU_LOGO_ROWS
	bne .blb_r
	lda #<logo_mcm_scr
	sta gptr_l
	lda #>logo_mcm_scr
	sta gptr_h
	lda #<logo_mcm_col
	sta ui_str_l
	lda #>logo_mcm_col
	sta ui_str_h
	ldx #0
.bls_r
	stx tmp4
	txa
	clc
	adc #LOGO_TOP
	tax
	lda #LOGO_LEFT
	jsr bmp_cell_addr
	lda aux_l
	sta ptr_r_l
	lda aux_h
	clc
	adc #>($d800 - SCREEN)
	sta ptr_r_h
	ldy #0
.bls_c
	lda (gptr_l),y
	sta (aux_l),y
	lda (ui_str_l),y
	sta (ptr_r_l),y
	iny
	cpy #LOGO_COLS
	bne .bls_c
	lda gptr_l
	clc
	adc #LOGO_COLS
	sta gptr_l
	bcc .bls_s
	inc gptr_h
.bls_s
	lda ui_str_l
	clc
	adc #LOGO_COLS
	sta ui_str_l
	bcc .bls_u
	inc ui_str_h
.bls_u
	ldx tmp4
	inx
	cpx #MENU_LOGO_ROWS
	bne .bls_r
	rts

copy_menu_sprites
	ldx #0
.cms_h
	lda menu_hint_spr,x
	sta HINT_SPR_RAM,x
	inx
	bne .cms_h
	ldx #0
.cms_h2
	lda menu_hint_spr + $100,x
	sta HINT_SPR_RAM + $100,x
	inx
	cpx #$80
	bne .cms_h2
	ldx #0
.cms_c
	lda menu_cursor_spr,x
	sta CURSOR_SPR_RAM,x
	inx
	bne .cms_c
	ldx #0
.cms_c2
	lda menu_cursor_spr + $100,x
	sta CURSOR_SPR_RAM + $100,x
	inx
	cpx #<(CURSOR_SPR_COUNT * 64)
	bne .cms_c2
	ldx #0
.cms_w
	lda menu_wip_spr,x
	sta WIP_SPR_RAM,x
	inx
	cpx #(WIP_SPR_COUNT * 64)
	bne .cms_w
	rts

; Sprite 0: WIP watermark. Mux never touches ptr/X/Y/colour.
setup_wip_spr
	lda #WIP_SPR_PTR0
	sta SCREEN + $3f8
	lda #WIP_COL
	sta $d027
	lda #40
	sta wip_x
	lda #70
	sta wip_y
	lda #0
	sta wip_spr_xmsb
	lda #1
	sta wip_dx
	sta wip_dy
	lda #WIP_SPR_EN_BIT
	sta wip_spr_en
	lda wip_x
	sta $d000
	lda wip_y
	sta $d001
	lda wip_spr_xmsb
	sta $d010
	rts

setup_logo_sprites
	lda #0
	sta $d01b				; sprites in front of bitmap
	sta $d017
	sta $d01d
	sta $d01c				; hires cursor/hints; logo can use MCM later
	rts

; Raster IRQ A — MCM on for the logo band, then cursor sprites (if enabled).
mux_logo_spr
	lda #$18				; CSEL + MCM
	sta $d016
	lda cursor_spr_en
	bne mux_cursor_spr
	lda wip_spr_en				; text pages: WIP only
	sta $d015
	lda wip_spr_xmsb
	sta $d010
	rts

; Blank line under the logo — only $d016; 00 pixels are $d021 in both modes.
mux_hires_mcm
	lda #$08				; CSEL, MCM off
	sta $d016
	rts

; Raster IRQ mid — skull cursor on sprites 1–7 (WIP stays sprite 0).
mux_cursor_spr
	lda cursor_spr_en
	bne .mc_go
	rts
.mc_go
	ldx #0
	lda #CURSOR_SPR_PTR0
.mcp
	sta SCREEN + $3f9,x
	clc
	adc #1
	inx
	cpx #CURSOR_SPR_COUNT
	bne .mcp
	ldx #0
.mccol
	lda cursor_spr_cols,x
	sta $d028,x
	inx
	cpx #CURSOR_SPR_COUNT
	bne .mccol
	ldx #0
	ldy #2
.mcxy
	lda cursor_spr_x
	sta $d000,y
	lda cursor_spr_y
	sta $d001,y
	iny
	iny
	inx
	cpx #CURSOR_SPR_COUNT
	bne .mcxy
	lda #CURSOR_BASE_MASK
	ldx cursor_frame
	beq .mc_shift
	ora #CURSOR_OVERLAY_MASK
.mc_shift
	asl					; sprites 1–7
	ora wip_spr_en
	sta $d015
	lda wip_spr_xmsb
	sta $d010
	rts

; Raster IRQ late — WS / AD / RETURN on sprites 1–6 (WIP stays sprite 0).
mux_hint_spr
	lda hint_spr_en
	bne .mh_go
	rts
.mh_go
	ldx #0
	lda #HINT_SPR_PTR0
.mhp
	sta SCREEN + $3f9,x
	clc
	adc #1
	inx
	cpx #HINT_SPR_COUNT
	bne .mhp
	lda #HINT_OVER_COL
	sta $d028
	sta $d02a
	sta $d02c
	lda #HINT_KEY_COL
	sta $d029
	sta $d02b
	sta $d02d
	ldx #0
	ldy #2
.mhx
	lda hint_spr_x,x
	sta $d000,y
	sta $d002,y
	iny
	iny
	iny
	iny
	inx
	cpx #3
	bne .mhx
	lda #HINT_SPR_Y
	sta $d003
	sta $d005
	sta $d007
	sta $d009
	sta $d00b
	sta $d00d
	lda #%00111111
	asl					; sprites 1–6
	ora wip_spr_en
	sta $d015
	lda wip_spr_xmsb
	sta $d010
	rts

fill_option_box
	lda pr_setcol
	bne .fob_bg
	lda ui_text_col
	asl
	asl
	asl
	asl
	ora cell_bg
	jmp .fob_sv
.fob_bg
	lda cell_bg
.fob_sv
	sta tmp0
	lda box_height
	sta tmp5
	ldx #0
.fob_r
	stx tmp4
	txa
	clc
	adc box_top
	tax
	lda box_left
	jsr bmp_cell_addr
	ldy #0
.fob_c
	lda tmp0
	sta (aux_l),y
	iny
	cpy box_width
	bcc .fob_c
	ldx tmp4
	inx
	cpx tmp5
	bcc .fob_r
	rts

; Blank 8 bitmap bytes for cell Y relative to ptr (col base). Saves Y.
bmp_blank_cell_y
	sty tmp1
	tya
	asl
	asl
	asl					; cell offset *8 within row strip
	tay
	lda #0
	sta (ptr_l),y
	iny
	sta (ptr_l),y
	iny
	sta (ptr_l),y
	iny
	sta (ptr_l),y
	iny
	sta (ptr_l),y
	iny
	sta (ptr_l),y
	iny
	sta (ptr_l),y
	iny
	sta (ptr_l),y
	ldy tmp1
	rts

; A=col X=row → ptr=bitmap cell, aux=screen matrix cell.
; Must not touch tmp0/tmp1/tmp2 — fill loops keep row in tmp2.
bmp_cell_addr
	sta pr_col
	stx pr_row
	lda #0
	sta tmp3				; mat_off hi
	txa
	asl
	asl
	adc pr_row				; *5
	asl
	rol tmp3				; *10
	asl
	rol tmp3				; *20
	asl
	rol tmp3				; *40
	adc pr_col
	bcc .bca1
	inc tmp3
.bca1
	sta ptr_l				; mat_off lo (not tmp2 — fill loops keep row there)
	clc
	adc #<SCREEN
	sta aux_l
	lda tmp3
	adc #>SCREEN
	sta aux_h
	lda tmp3
	sta ptr_h
	asl ptr_l
	rol ptr_h
	asl ptr_l
	rol ptr_h
	asl ptr_l
	rol ptr_h				; *8
	lda ptr_l
	clc
	adc #<BITMAP
	sta ptr_l
	lda ptr_h
	adc #>BITMAP
	sta ptr_h
	rts

print_centered
	sta ui_str_l
	sty ui_str_h
	stx pr_row
	jsr str_pix_len
	lda #<320
	sec
	sbc pr_len
	sta pix_max_l
	lda #>320
	sbc pr_len_h
	bcs .pc
	lda #0
	sta pr_shift
	sta pr_mono
	sta pr_col
	sta pr_drop
	ldx pr_row
	jmp print_go
.pc
	lsr
	ror pix_max_l
	lda pix_max_l
	tax
	and #7
	sta pr_shift
	txa
	lsr
	lsr
	lsr
	ldx pr_row
	sta pr_col
	stx pr_row
	lda #0
	sta pr_mono
	sta pr_drop
	jmp print_go

print_at
	sta pr_col
	stx pr_row
	lda #0
	sta pr_shift
	sta pr_mono
	sta pr_drop
print_go
	lda #$ff
	sta pr_prev
	ldy #0
.pa
	lda (ui_str_l),y
	beq .pa_d
	sty pr_si
	jsr bmp_put_scr
	ldy pr_si
	iny
	bne .pa
.pa_d
	rts

; ^ toggles monospaced; A=col X=row.
print_marked
	sta pr_col
	stx pr_row
	lda #0
	sta pr_shift
	sta pr_mono
	sta pr_drop
	sta pr_scale
	lda #$ff
	sta pr_prev
	ldy #0
.pm
	lda (ui_str_l),y
	beq .pm_d
	cmp #MARK_CARET
	bne .pm_ch
	lda pr_mono
	eor #1
	sta pr_mono
	beq .pm_sk				; left mono
	lda pr_shift
	beq .pm_sk
	inc pr_col				; snap to next cell
	lda #0
	sta pr_shift
.pm_sk
	iny
	bne .pm
.pm_ch
	sty pr_si
	jsr bmp_put_scr
	ldy pr_si
	iny
	bne .pm
.pm_d
	rts

; A = !scr byte → 16-bit shifted OR blit at pr_col/pr_shift.
bmp_put_scr
	cmp #MARK_CARET
	bne .bps_go
	rts
.bps_go
	jsr scr_to_font
	sta ft_idx
	ldx pr_mono
	bne .bps_mono
	cmp pr_prev
	bne .bps_nk
	cmp #HYPHEN_I
	bne .bps_nk
	jsr pix_back1
	lda pr_scale
	beq .bps_hy1
	jsr pix_back1
.bps_hy1
	lda ft_idx
.bps_nk
	sta pr_prev
	tax
	lda glyph_w_tab,x
	bne .bps_ink
	lda #SPACE_W
	sta glyph_w
	jmp bmp_advance
.bps_ink
	sta glyph_w
	jsr font_set_gptr
	jmp .bps_draw
.bps_mono
	lda #$ff
	sta pr_prev
	lda #8
	sta glyph_w
	jsr font_set_gptr
.bps_draw
	lda pr_col
	cmp #40
	bcc .bps_on
	jmp bmp_advance
.bps_on
	jsr bmp_sync_ptr
	lda #0
	sta ft_spill
	tay
	lda pr_setcol
	beq .bps_pick
	lda ui_text_col
	asl
	asl
	asl
	asl
	ora cell_bg
	sta ft_color
	sta (aux_l),y
.bps_pick
	lda pr_scale
	beq .bps_1x
	jmp blit_2x
.bps_1x
	lda pr_shift
	bne .bps_sh
	lda ft_lc
	bne blit_zdrop
	jmp blit_z
.bps_sh
	tax
	lda shift_lo,x
	sta do_shift_j + 1
	lda shift_hi,x
	sta do_shift_j + 2
	lda ft_lc
	bne .to_drop
	jmp blit_nd
.to_drop
	jmp blit_drop

; pr_shift = 0: OR 8 rows, no right cell.
blit_z
	ldy #0
	lda (gptr_l),y
	ora (ptr_l),y
	sta (ptr_l),y
	iny
	lda (gptr_l),y
	ora (ptr_l),y
	sta (ptr_l),y
	iny
	lda (gptr_l),y
	ora (ptr_l),y
	sta (ptr_l),y
	iny
	lda (gptr_l),y
	ora (ptr_l),y
	sta (ptr_l),y
	iny
	lda (gptr_l),y
	ora (ptr_l),y
	sta (ptr_l),y
	iny
	lda (gptr_l),y
	ora (ptr_l),y
	sta (ptr_l),y
	iny
	lda (gptr_l),y
	ora (ptr_l),y
	sta (ptr_l),y
	iny
	lda (gptr_l),y
	ora (ptr_l),y
	sta (ptr_l),y
	jmp bmp_advance

blit_zdrop
	ldy #0
	lda (gptr_l),y
	iny
	ora (ptr_l),y
	sta (ptr_l),y
	lda (gptr_l),y
	iny
	ora (ptr_l),y
	sta (ptr_l),y
	lda (gptr_l),y
	iny
	ora (ptr_l),y
	sta (ptr_l),y
	lda (gptr_l),y
	iny
	ora (ptr_l),y
	sta (ptr_l),y
	lda (gptr_l),y
	iny
	ora (ptr_l),y
	sta (ptr_l),y
	lda (gptr_l),y
	iny
	ora (ptr_l),y
	sta (ptr_l),y
	lda (gptr_l),y
	iny
	ora (ptr_l),y
	sta (ptr_l),y
	lda (gptr_l),y
	ldy #0
	jsr ora_below_l
	lda pr_setcol
	beq .zd_a
	lda #0
	sta ft_spill
	jsr color_below
.zd_a
	jmp bmp_advance

; Shifted, no lowercase drop.
blit_nd
	ldy #0
.bnd
	lda (gptr_l),y
	jsr do_shift
	ora (ptr_l),y
	sta (ptr_l),y
	lda ft_right
	beq .bnd0
	ora (ptr_r_l),y
	sta (ptr_r_l),y
	sta ft_spill
.bnd0
	iny
	cpy #8
	bne .bnd
	jmp .bps_col2

; Shifted, lowercase drop (rows 0–6 → dest 1–7, row 7 below).
blit_drop
	ldy #0
.bd
	lda (gptr_l),y
	jsr do_shift
	iny
	ora (ptr_l),y
	sta (ptr_l),y
	lda ft_right
	beq .bd0
	ora (ptr_r_l),y
	sta (ptr_r_l),y
	sta ft_spill
.bd0
	cpy #7
	bcc .bd
	ldy #7
	lda (gptr_l),y
	jsr do_shift
	ldy #0
	jsr ora_below_l
	lda ft_right
	beq .bd_cb
	jsr ora_below_r
	sta ft_spill
.bd_cb
	lda pr_setcol
	beq .bps_col2
	jsr color_below
	jmp .bps_col2
.bps_col2
	lda pr_setcol
	beq .bps_adv
	lda ft_spill
	beq .bps_adv
	lda pr_col
	cmp #39
	bcs .bps_adv
	lda ft_color
	ldy #1
	sta (aux_l),y
.bps_adv
	jmp bmp_advance

; 2× nearest-neighbour: expand 8×8 → 16×16 via dbl_hi/dbl_lo, shift, OR 3 cells × 2 rows.
blit_2x
	lda #0
	sta ft_spill2
	sta ft_src
	sta tmp0				; dest Y in cell
.b2_loop
	ldy ft_src
	lda (gptr_l),y
	tax
	lda dbl_hi,x
	sta ft_left
	lda dbl_lo,x
	sta ft_occ				; 16-bit lo; third byte after shift
	lda #0
	sta ft_hi				; shift spill into cell +2
	ldx pr_shift
	beq .b2_wr
.b2_sh
	lsr ft_left
	ror ft_occ
	ror ft_hi
	dex
	bne .b2_sh
.b2_wr
	ldy tmp0
	jsr blit_2x_line
	iny
	jsr blit_2x_line
	iny
	sty tmp0
	inc ft_src
	lda ft_src
	cmp #4
	bne .b2_n4
	lda #0
	sta tmp0
.b2_n4
	lda ft_src
	cmp #8
	bne .b2_loop
	jmp blit_2x_col

; Y = dest line in cell. ft_src < 4 → current row; else row below.
blit_2x_line
	sty tmp1
	lda ft_src
	cmp #4
	bcs .b2_bel
	ldy tmp1
	lda ft_left
	ora (ptr_l),y
	sta (ptr_l),y
	lda ft_occ
	beq .b2_c0
	ora (ptr_r_l),y
	sta (ptr_r_l),y
	sta ft_spill
.b2_c0
	lda ft_hi
	beq .b2_d0
	ora (ptr_r2_l),y
	sta (ptr_r2_l),y
	sta ft_spill2
.b2_d0
	rts
.b2_bel
	ldy tmp1
	lda ft_left
	jsr ora_below_l
	lda ft_occ
	beq .b2_c1
	jsr ora_below_r
	sta ft_spill
.b2_c1
	lda ft_hi
	beq .b2_d1
	jsr ora_below_r2
	sta ft_spill2
.b2_d1
	rts

blit_2x_col
	lda pr_setcol
	beq .b2x_adv
	lda ft_spill
	beq .b2_s2
	lda pr_col
	cmp #39
	bcs .b2_s2
	ldy #1
	lda ft_color
	sta (aux_l),y
.b2_s2
	lda ft_spill2
	beq .b2_bl
	lda pr_col
	cmp #38
	bcs .b2_bl
	ldy #2
	lda ft_color
	sta (aux_l),y
.b2_bl
	jsr color_below
	lda ft_spill2
	beq .b2x_adv
	lda pr_col
	cmp #38
	bcs .b2x_adv
	lda aux_h
	pha
	lda aux_l
	pha
	clc
	adc #42
	sta aux_l
	bcc .b2_c
	inc aux_h
.b2_c
	ldy #0
	lda ft_color
	sta (aux_l),y
	pla
	sta aux_l
	pla
	sta aux_h
.b2x_adv
	jmp bmp_advance

do_shift
	ldx #0
	stx ft_right
do_shift_j
	jmp shift0

shift0
	rts
shift1
	lsr
	ror ft_right
	rts
shift2
	lsr
	ror ft_right
	lsr
	ror ft_right
	rts
shift3
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	rts
shift4
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	rts
shift5
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	rts
shift6
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	rts
shift7
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	rts

shift_lo
	!byte <shift0, <shift1, <shift2, <shift3
	!byte <shift4, <shift5, <shift6, <shift7
shift_hi
	!byte >shift0, >shift1, >shift2, >shift3
	!byte >shift4, >shift5, >shift6, >shift7

; Ink already in cell below; set colour on that row when needed.
color_below
	lda aux_h
	pha
	lda aux_l
	pha
	clc
	adc #40
	sta aux_l
	bcc .cb_a
	inc aux_h
.cb_a
	ldy #0
	lda ft_color
	sta (aux_l),y
	lda ft_spill
	beq .cb_d
	lda pr_col
	cmp #39
	bcs .cb_d
	iny
	lda ft_color
	sta (aux_l),y
.cb_d
	pla
	sta aux_l
	pla
	sta aux_h
	rts

bmp_advance
	lda glyph_w
	ldx pr_mono
	bne .ba_g
	clc
	adc #FONT_GAP
.ba_g
	ldx pr_scale
	beq .ba_s
	asl
.ba_s
	clc
	adc pr_shift
	sta pr_shift
	lsr
	lsr
	lsr
	clc
	adc pr_col
	sta pr_col
	lda pr_shift
	and #7
	sta pr_shift
	rts

; pr_col/pr_shift -= 1px (hyphen following hyphen).
pix_back1
	lda pr_shift
	bne .pb_s
	lda pr_col
	beq .pb_d
	dec pr_col
	lda #7
	sta pr_shift
	rts
.pb_s
	dec pr_shift
.pb_d
	rts

; ptr/aux follow pr_col/pr_row. Step +8 when the column advances.
bmp_sync_ptr
	lda pr_row
	cmp ft_row
	bne .sp_re
	lda pr_col
	cmp ft_cell
	beq sync_ptr_r
	bcc .sp_re
.sp_fw
	inc ft_cell
	lda ptr_l
	clc
	adc #8
	sta ptr_l
	bcc .sp_p
	inc ptr_h
.sp_p
	lda pr_setcol
	beq .sp_a
	inc aux_l
	bne .sp_a
	inc aux_h
.sp_a
	lda pr_col
	cmp ft_cell
	bne .sp_fw
	jmp sync_ptr_r
.sp_re
	lda pr_col
	ldx pr_row
	jsr bmp_cell_addr
	lda pr_col
	sta ft_cell
	lda pr_row
	sta ft_row
sync_ptr_r
	clc
	lda ptr_l
	adc #<320
	sta ft_b_l
	sta ora_below_l + 1
	sta ora_below_l + 4
	lda ptr_h
	adc #>320
	sta ft_b_h
	sta ora_below_l + 2
	sta ora_below_l + 5
	lda pr_col
	cmp #39
	bcc .spr_ok
	jsr sync_sink_r
	jmp sync_sink_r2
.spr_ok
	lda ptr_l
	clc
	adc #8
	sta ptr_r_l
	lda ptr_h
	adc #0
	sta ptr_r_h
	clc
	lda ptr_r_l
	adc #<320
	sta ft_br_l
	sta ora_below_r + 1
	sta ora_below_r + 4
	lda ptr_r_h
	adc #>320
	sta ft_br_h
	sta ora_below_r + 2
	sta ora_below_r + 5
	lda pr_col
	cmp #38
	bcc .spr_r2
	jmp sync_sink_r2
.spr_r2
	lda ptr_l
	clc
	adc #16
	sta ptr_r2_l
	lda ptr_h
	adc #0
	sta ptr_r2_h
	clc
	lda ptr_r2_l
	adc #<320
	sta ft_br2_l
	sta ora_below_r2 + 1
	sta ora_below_r2 + 4
	lda ptr_r2_h
	adc #>320
	sta ft_br2_h
	sta ora_below_r2 + 2
	sta ora_below_r2 + 5
	rts

sync_sink_r
	lda #<ft_sink
	sta ptr_r_l
	sta ft_br_l
	sta ora_below_r + 1
	sta ora_below_r + 4
	lda #>ft_sink
	sta ptr_r_h
	sta ft_br_h
	sta ora_below_r + 2
	sta ora_below_r + 5
	rts

sync_sink_r2
	lda #<ft_sink
	sta ptr_r2_l
	sta ft_br2_l
	sta ora_below_r2 + 1
	sta ora_below_r2 + 4
	lda #>ft_sink
	sta ptr_r2_h
	sta ft_br2_h
	sta ora_below_r2 + 2
	sta ora_below_r2 + 5
	rts

; A = bits, Y = 0. Dest patched to ptr+320 / ptr_r+320 (BSS + abs,y).
ora_below_l
	ora $ffff,y
	sta $ffff,y
	rts
ora_below_r
	ora $ffff,y
	sta $ffff,y
	rts
ora_below_r2
	ora $ffff,y
	sta $ffff,y
	rts

glyph_lda
	lda $ffff,y
	rts

; ft_idx → gptr (left-justified cache, or raw font if mono) + ft_lc
font_set_gptr
	lda #0
	sta ft_hi
	sta ft_lc
	lda ft_idx
	tay
	lda pr_drop
	beq .fss
	cpy #'a' - ' '
	bcc .fss
	cpy #'z' - ' ' + 1
	bcs .fss
	inc ft_lc
.fss
	tya
	asl
	rol ft_hi
	asl
	rol ft_hi
	asl
	rol ft_hi
	clc
	ldx pr_mono
	bne .fss_raw
	adc #<glyph_lj
	sta gptr_l
	lda ft_hi
	adc #>glyph_lj
	sta gptr_h
	rts
.fss_raw
	adc #<menufont_udgs
	sta gptr_l
	lda ft_hi
	adc #>menufont_udgs
	sta gptr_h
	rts

; Build dbl_hi/dbl_lo at $8000: each source bit → two bits (AABBCCDD EEFFGGHH).
init_dbl_tabs
	ldx #0
.idt
	txa
	lsr
	lsr
	lsr
	lsr
	tay
	lda dbl_nib,y
	sta dbl_hi,x
	txa
	and #$0f
	tay
	lda dbl_nib,y
	sta dbl_lo,x
	inx
	bne .idt
	rts

dbl_nib
	!byte $00, $03, $0c, $0f, $30, $33, $3c, $3f
	!byte $c0, $c3, $cc, $cf, $f0, $f3, $fc, $ff

init_font_tabs
	jsr init_dbl_tabs
	lda #<menufont_udgs
	sta glyph_lda + 1
	lda #>menufont_udgs
	sta glyph_lda + 2
	lda #<glyph_lj
	sta gptr_l
	lda #>glyph_lj
	sta gptr_h
	ldx #0
.ift
	stx ft_idx
	jsr font_scan
	ldx ft_idx
	lda glyph_w
	sta glyph_w_tab,x
	ldy #0
.ift_c
	jsr glyph_lda
	ldx glyph_lead
	beq .ift_s
.ift_a
	asl
	dex
	bne .ift_a
.ift_s
	sta (gptr_l),y
	iny
	cpy #8
	bne .ift_c
	lda gptr_l
	clc
	adc #8
	sta gptr_l
	bcc .ift_g
	inc gptr_h
.ift_g
	lda glyph_lda + 1
	clc
	adc #8
	sta glyph_lda + 1
	bcc .ift1
	inc glyph_lda + 2
.ift1
	ldx ft_idx
	inx
	cpx #96
	bne .ift
	lda #$ff
	sta ft_row
	rts

; Occupancy of glyph_lda → glyph_lead, glyph_w (0 = empty / space)
font_scan
	lda #0
	sta ft_occ
	ldy #7
.fs_or
	jsr glyph_lda
	ora ft_occ
	sta ft_occ
	dey
	bpl .fs_or
	lda ft_occ
	bne .fs_ink
	lda #0
	sta glyph_lead
	sta glyph_w
	rts
.fs_ink
	ldx #0
.fs_lead
	lda ft_occ
	bmi .fs_gotl
	asl ft_occ
	inx
	cpx #8
	bcc .fs_lead
.fs_gotl
	stx glyph_lead
	ldx #0
	lda ft_occ
.fs_w
	inx
	asl
	bne .fs_w
	stx glyph_w
	rts

; !scr byte → font index (ascii-32). 1..26 = a..z; $20+ = ASCII.
scr_to_font
	cmp #27
	bcs .stf_asc
	cmp #1
	bcc .stf_sp
	clc
	adc #'a' - 1			; screencode → lowercase ASCII
	bne .stf_idx
.stf_asc
	cmp #' '
	bcc .stf_sp
	cmp #128
	bcc .stf_idx
.stf_sp
	lda #' '
.stf_idx
	sec
	sbc #' '
	rts

str_len
	ldy #0
.sl
	lda (ui_str_l),y
	beq .sl_d
	iny
	bne .sl
.sl_d
	tya
	rts

; X = font index. Add glyph_w+FONT_GAP to pr_len; `--` kerns 1px.
add_prop_w
	lda glyph_w_tab,x
	bne .apw_a
	lda #SPACE_W
.apw_a
	clc
	adc #FONT_GAP
	cpx pr_prev
	bne .apw_add
	cpx #HYPHEN_I
	bne .apw_add
	sec
	sbc #1
.apw_add
	stx pr_prev
	clc
	adc pr_len
	sta pr_len
	bcc .apw_d
	inc pr_len_h
.apw_d
	rts

; Pixel width of ui_str (incl. FONT_GAP per char) → pr_len / pr_len_h
str_pix_len
	lda #0
	sta pr_len
	sta pr_len_h
	lda #$ff
	sta pr_prev
	ldy #0
.spl
	lda (ui_str_l),y
	beq .spl_d
	sty ft_src
	jsr scr_to_font
	tax
	jsr add_prop_w
	ldy ft_src
	iny
	bne .spl
.spl_d
	lda pr_scale
	beq .spl_r
	asl pr_len
	rol pr_len_h
.spl_r
	rts

; Visible pixel width ignoring ^ markers → pr_len / pr_len_h
marked_str_pix_len
	lda #0
	sta pr_len
	sta pr_len_h
	sta pr_mono
	lda #$ff
	sta pr_prev
	ldy #0
.mspl
	lda (ui_str_l),y
	beq .mspl_d
	cmp #MARK_CARET
	bne .mspl_ch
	lda pr_mono
	eor #1
	sta pr_mono
	beq .mspl_s
	jsr pix_snap_len
	jmp .mspl_s
.mspl_ch
	ldx pr_mono
	bne .mspl_8
	sty ft_src
	jsr scr_to_font
	tax
	jsr add_prop_w
	ldy ft_src
	jmp .mspl_s
.mspl_8
	lda #$ff
	sta pr_prev
	lda pr_len
	clc
	adc #8
	sta pr_len
	bcc .mspl_s
	inc pr_len_h
.mspl_s
	iny
	bne .mspl
.mspl_d
	lda #0
	sta pr_mono
	rts

; Round pr_len up to a multiple of 8 (cell snap before mono).
pix_snap_len
	lda pr_len
	and #7
	beq .psn_r
	sta ft_hi
	lda #8
	sec
	sbc ft_hi
	clc
	adc pr_len
	sta pr_len
	bcc .psn_r
	inc pr_len_h
.psn_r
	rts

; Advance ui_str past current NUL-terminated string.
str_skip
	ldy #0
.ssk
	lda (ui_str_l),y
	beq .ssk_d
	iny
	bne .ssk
.ssk_d
	iny
	tya
	clc
	adc ui_str_l
	sta ui_str_l
	bcc .ssk_c
	inc ui_str_h
.ssk_c
	rts

; Hide full redraws: DEN off fills the screen with $d020. Sprites off.
; Border matches COL_MAIN / STORY_BG.
menu_blank
	lda $d011
	and #%11101111				; DEN off
	sta $d011
	lda clear_bg
	cmp #STORY_BG
	beq .mb_c
	lda #MENU_BORDER
.mb_c
	sta $d020
	sta $d021
	lda #0
	sta $d015
	sta hint_spr_en
	sta cursor_spr_en
	rts

; Reveal after paint. $d021 from clear_bg (story pages use STORY_BG).
menu_unblank
	lda #MENU_BORDER
	sta $d020
	lda clear_bg
	sta $d021
	lda $d011
	ora #%00010000				; DEN on
	sta $d011
	lda #0
	sta $d015
	rts

wait_raster
	lda $d012
.wr
	cmp $d012
	beq .wr
	rts

wait_frame
.wf_hi
	lda $d011
	bpl .wf_hi
.wf_lo
	lda $d011
	bmi .wf_lo
	jsr update_wip_spr
	inc cursor_tick
	lda cursor_tick
	cmp #CURSOR_TICK_MAX		; ~2.5 Hz skull overlay (was 5 ticks)
	bcc .wf_rts
	lda #0
	sta cursor_tick
	inc cursor_frame
	lda cursor_frame
	cmp #CURSOR_FRAMES
	bcc .wf_rts
	lda #0
	sta cursor_frame
.wf_rts
	rts

; DVD bounce on sprite 0. X is 16-bit (low + $d010 bit 0).
update_wip_spr
	lda wip_dx
	bpl .uw_xp
	lda wip_x
	bne .uw_xd
	dec wip_spr_xmsb
.uw_xd
	dec wip_x
	jmp .uw_xc
.uw_xp
	inc wip_x
	bne .uw_xc
	inc wip_spr_xmsb
.uw_xc
	lda wip_spr_xmsb
	bne .uw_xh
	lda wip_x
	cmp #WIP_X_MIN
	bcs .uw_xh
	lda #1
	sta wip_dx
	lda #WIP_X_MIN
	sta wip_x
	lda #0
	sta wip_spr_xmsb
	jmp .uw_y
.uw_xh
	lda wip_spr_xmsb
	beq .uw_y
	lda wip_x
	cmp #<(WIP_X_MAX + 1)
	bcc .uw_y
	lda #$ff
	sta wip_dx
	lda #<WIP_X_MAX
	sta wip_x
	lda #>WIP_X_MAX
	sta wip_spr_xmsb
.uw_y
	lda wip_y
	clc
	adc wip_dy
	sta wip_y
	cmp #WIP_Y_MIN
	bcc .uw_yl
	cmp #WIP_Y_MAX + 1
	bcc .uw_hw
	lda #$ff
	sta wip_dy
	lda #WIP_Y_MAX
	sta wip_y
	jmp .uw_hw
.uw_yl
	lda #1
	sta wip_dy
	lda #WIP_Y_MIN
	sta wip_y
.uw_hw
	lda wip_spr_en
	beq .uw_rts
	lda wip_x
	sta $d000
	lda wip_y
	sta $d001
	lda wip_spr_xmsb
	sta $d010
.uw_rts
	rts

wait_frames_x
.wf
	jsr wait_frame
	dex
	bne .wf
	rts

wait_key
.wk_up
	jsr ui_read_keys
	lda ui_keys
	bne .wk_up
.wk_dn
	jsr ui_read_keys
	lda ui_keys
	beq .wk_dn
.wk_rel
	jsr ui_read_keys
	lda ui_keys
	bne .wk_rel
	rts

; Any key (full keyboard matrix) — text screens.
; Wait for release + a few quiet frames so Return-to-enter doesn't bounce-dismiss.
; wait_frame each poll so the WIP sprite keeps bouncing.
wait_any_key
.wau
	jsr wait_frame
	lda #0
	sta $dc00
	lda $dc01
	cmp #$ff
	bne .wau
	ldx #2
.wau_s
	jsr wait_frame
	lda #0
	sta $dc00
	lda $dc01
	cmp #$ff
	bne .wau
	dex
	bne .wau_s
.wad
	jsr wait_frame
	lda #0
	sta $dc00
	lda $dc01
	cmp #$ff
	beq .wad
.war
	jsr wait_frame
	lda #0
	sta $dc00
	lda $dc01
	cmp #$ff
	bne .war
	rts

ui_read_keys
	lda ui_keys
	sta ui_old
	lda #0
	sta ui_keys

	lda #$fd
	sta $dc00
	lda $dc01
	tax
	and #$02
	bne .urk_now
	lda ui_keys
	ora #UI_UP
	sta ui_keys
.urk_now
	txa
	and #$20
	bne .urk_nos
	lda ui_keys
	ora #UI_DOWN
	sta ui_keys
.urk_nos
	txa
	and #$04
	bne .urk_noa
	lda ui_keys
	ora #UI_LEFT
	sta ui_keys
.urk_noa
	lda #$fb
	sta $dc00
	lda $dc01
	and #$04
	bne .urk_nod
	lda ui_keys
	ora #UI_RIGHT
	sta ui_keys
.urk_nod
	lda #$fe
	sta $dc00
	lda $dc01
	and #$02
	bne .urk_noret
	lda ui_keys
	ora #UI_SELECT
	sta ui_keys
.urk_noret
	lda #$7f
	sta $dc00
	lda $dc01
	and #$80
	bne .urk_noesc
	lda ui_keys
	ora #UI_ESC
	sta ui_keys
.urk_noesc
	lda ui_old
	eor #$ff
	and ui_keys
	sta ui_pressed
	rts

; --- state / strings --------------------------------------------------------
menu_id		!byte 0
menu_item	!byte 0
menu_prev	!byte 0
menu_size	!byte 0
menu_stack_d	!byte 0
menu_can_ret	!byte 0
hint_spr_en	!byte 0
cursor_spr_en	!byte 0
wip_spr_en	!byte 0
wip_spr_xmsb	!byte 0
wip_x		!byte 0
wip_y		!byte 0
wip_dx		!byte 0
wip_dy		!byte 0
cursor_frame	!byte 0
cursor_tick	!byte 0
menu_mux_phase	!byte 0
menu_raster_en	!byte 0
hint_spr_x	!byte 0, 0, 0
cursor_spr_x	!byte 0
cursor_spr_y	!byte 0
page_l		!byte 0
page_h		!byte 0
page_n		!byte 0
page_i		!byte 0
hint_tx		!byte 0, 0, 0
hint_px		!byte 0
hint_w0		!byte 0
hint_w1		!byte 0
hint_w2		!byte 0
menu_stk_m	!byte 0, 0, 0
menu_stk_i	!byte 0, 0, 0
box_top		!byte 0
box_left	!byte 0
box_width	!byte 0
box_height	!byte 0
ui_keys		!byte 0
ui_old		!byte 0
ui_pressed	!byte 0
ui_text_col	!byte 0
pr_row		!byte 0
pr_col		!byte 0
pr_shift	!byte 0
pr_mono		!byte 0
pr_drop		!byte 0
pr_scale	!byte 0			; 1 = 2× blit (option rows + titles)
pr_setcol	!byte 1				; 0 = ink only (story panel precoloured)
pr_si		!byte 0
pr_prev		!byte 0				; last prop font index ($ff = none)
pr_len		!byte 0
pr_len_h	!byte 0
glyph_lead	!byte 0
glyph_w		!byte 0
ft_cell		!byte 0
ft_row		!byte $ff
ft_color	!byte 0
ft_occ		!byte 0
ft_hi		!byte 0
ft_lc		!byte 0
ft_idx		!byte 0
ft_src		!byte 0
ft_left		!byte 0
ft_right	!byte 0
ft_spill	!byte 0
ft_spill2	!byte 0			; third cell (2× blit)
pix_max_l	!byte 0
pix_max_h	!byte 0
txt_ptr_l	!byte 0
txt_ptr_h	!byte 0
cell_bg		!byte 0
clear_bg	!byte COL_MAIN
glyph_w_tab	!fill 96, 0
ft_sink		!fill 8, 0			; dummy right-cell when col=39
ft_b_l		!byte 0				; ptr+320 (descender cell)
ft_b_h		!byte 0
ft_br_l		!byte 0				; ptr_r+320
ft_br_h		!byte 0
ft_br2_l	!byte 0				; ptr_r2+320
ft_br2_h	!byte 0

str_hint_move	!scr "move",0
str_hint_adjust	!scr "adjust",0
str_hint_select	!scr "select",0
str_new_game	!scr "New game",0
str_sound	!scr "Options",0
str_control	!scr "Controls",0
str_read_this	!scr "Read this!",0
str_credits	!scr "Credits",0
str_quit	!scr "Quit",0
str_back	!scr "Back",0
str_e1		!scr "Knee deep in the dead",0
str_e2		!scr "The shores of hell",0
str_e3		!scr "Inferno",0
str_fx_vol	!scr "Effects volume 15",0
str_mus_vol	!scr "Music volume 10",0
str_mouse	!scr "Mouse (port 1) off",0
str_itytd	!scr "I'm too young to die",0
str_hmp		!scr "Hurt me plenty",0
str_uv		!scr "Ultra-violence",0

str_sec_main	!scr "SquareDoom",0
str_sec_new	!scr "Which episode to play?",0
str_sec_skill	!scr "How tough are you?",0
str_sec_sound	!scr "Options",0

section_lo
	!byte <str_sec_main, <str_sec_new, <str_sec_skill, <str_sec_sound
section_hi
	!byte >str_sec_main, >str_sec_new, >str_sec_skill, >str_sec_sound

!source "tmp/menu_text.asm"

menu_str_lo
	!byte <str_new_game, <str_sound, <str_control, <str_read_this
	!byte <str_credits, <str_quit, 0, 0
	!byte <str_e1, <str_e2, <str_e3, <str_back
	!byte 0, 0, 0, 0
	!byte <str_itytd, <str_hmp, <str_uv, <str_back
	!byte 0, 0, 0, 0
	!byte <str_fx_vol, <str_mus_vol, <str_mouse, <str_back
	!byte 0, 0, 0, 0
menu_str_hi
	!byte >str_new_game, >str_sound, >str_control, >str_read_this
	!byte >str_credits, >str_quit, 0, 0
	!byte >str_e1, >str_e2, >str_e3, >str_back
	!byte 0, 0, 0, 0
	!byte >str_itytd, >str_hmp, >str_uv, >str_back
	!byte 0, 0, 0, 0
	!byte >str_fx_vol, >str_mus_vol, >str_mouse, >str_back
	!byte 0, 0, 0, 0

!source "tmp/menu_hint_spr.asm"
!source "tmp/menu_cursor_spr.asm"
!source "tmp/menu_wip_spr.asm"
!source "tmp/menu_logo_mcm.asm"
!source "tmp/menufont.asm"
!source "menu_playsound.asm"
!source "menu_sfx.asm"
!source "menu_pcsounds.asm"
!source "menu_pcsfreq.asm"

end_menu = *
!if end_menu > $4000 {
	!error "Menu overlaps SCREEN; end=$", end_menu
}
