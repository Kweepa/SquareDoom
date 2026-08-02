; Menu UI overlay — screens/menu.prg at MENU_BASE (SCREEN+PATTERN+COL_CLIP pack)
; Entry: +0 run_menu, +3 show_text_screen (jmp stubs for stable exports)
!zone menu_overlay

MENU_Y = 15			; below 26x13 logo (rows 1–13)
MENU_CLR_TOP = 15
MENU_CLR_BOT = 23		; exclusive end row for menu-area clear
TEXT_COL = 2
HILITE_COL = 7
MENU_BORDER = 6			; blue border while in menus
NM_BACK = 256 - 66
NM_START = 256 - 10
NM_CRED = 256 - 1
NM_HELP = 256 - 2
NM_ORDER = 256 - 3

	jmp run_menu_body
	jmp show_text_screen_body

run_menu_body
	sta menu_can_ret
	; Pause key sampling in IRQ — ui_read_keys owns $dc00; SFX still ticks
	lda #1
	sta input_paused
	jsr ui_wait_esc_up
	jsr clear_screen
	jsr draw_title_banner
	lda #MENU_BORDER		; after LoadUiFile (LoadPrg clears $d020)
	sta $d020
	jsr sync_vol_strings
	lda #0
	sta menu_id
	sta menu_item
	sta menu_stack_d
	jsr draw_menu
.rm_loop
	jsr ui_read_keys
	jsr wait_raster

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
	cmp #2
	bne .rm_nov
	jsr menu_vol_input
.rm_nov
	lda #UI_ESC
	and ui_pressed
	beq .rm_noe
	jsr menu_esc
	bcs .rm_r0
.rm_noe
	lda #UI_SELECT
	and ui_pressed
	beq .rm_loop
	jsr menu_select
	bcc .rm_loop
	lda #1
	jmp menu_exit
.rm_r0
	lda #0
menu_exit
	pha
	; Resume key sampling in IRQ for gameplay
	lda #0
	sta input_paused
	lda #0				; black border for play / other UI
	sta $d020
	lda #1
	sta hud_dirty
	lda #$ff
	sta ui_buf_id			; gameplay will overwrite SCREENBUFFER
	pla
	rts

menu_vol_input
	lda menu_item
	cmp #2
	bcs .mvi_o
	lda #UI_RIGHT
	and ui_pressed
	bne .mvi_i
	lda #UI_SELECT
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
.mvi_o
	rts

menu_move_up
	ldx menu_item
	dex
	bpl .mmu
	ldx menu_size
	dex
.mmu
	stx menu_item
	lda #SOUND_STNMOV
	jsr play_sound
	jmp draw_menu

menu_move_down
	ldx menu_item
	inx
	cpx menu_size
	bcc .mmd
	ldx #0
.mmd
	stx menu_item
	lda #SOUND_STNMOV
	jsr play_sound
	jmp draw_menu

menu_esc
	lda menu_stack_d
	bne .me_p
	lda menu_can_ret
	bne .me_c
	clc
	rts
.me_c
	jsr ui_wait_esc_up
	sec
	rts
.me_p
	tax
	dex
	stx menu_stack_d
	lda menu_stk_m,x
	sta menu_id
	lda menu_stk_i,x
	sta menu_item
	jsr draw_menu
	clc
	rts

menu_select
	lda #SOUND_PISTOL
	jsr play_sound
	lda menu_id
	cmp #1
	bne .ms_se
	lda menu_item
	sta episode
.ms_se
	lda menu_id
	asl
	asl
	clc
	adc menu_item
	tax
	lda next_menu,x
	sta tmp0

	cmp #NM_BACK
	bne .ms_nb
	lda menu_can_ret
	beq .ms_st
	sec
	rts
.ms_nb
	lda tmp0
	cmp #NM_START
	bne .ms_nv
	lda menu_id
	cmp #3
	bne .ms_st
	lda menu_item
	sta difficulty
	jsr clear_screen
	jsr wait_frames_30
	sec
	rts
.ms_nv
	lda tmp0
	bmi .ms_tx
	cmp menu_id
	bcc .ms_po
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
	; NM_CRED/HELP/ORDER = $ff/$fe/$fd → text index 0/1/2
	lda tmp0
	eor #$ff
	jsr show_text_screen_body
	jsr clear_screen
	jsr draw_title_banner
	lda #MENU_BORDER
	sta $d020
	jsr draw_menu
.ms_st
	clc
	rts

next_menu
	!byte 1, 2, NM_CRED, NM_BACK
	!byte 3, NM_ORDER, NM_ORDER, 0
	!byte NM_START, NM_START, NM_HELP, 0
	!byte NM_START, NM_START, NM_START, 1

; ==================================================================
draw_title_banner
	; fall through
; Packed RLE in SCREENBUFFER: token = index[7:3] | (run-1)[2:0]
draw_logo
	lda #UI_LOGO
	jsr LoadUiFile
	bcs .dl_fail
	lda #0
	sta tmp2			; RLE stream index
	lda #LOGO_ROW
	sta pr_row
	lda #LOGO_H
	sta tmp3			; rows remaining
.dl_row
	lda #LOGO_COL
	ldx pr_row
	jsr cell_addr
	lda #LOGO_W
	sta tmp4			; cells left in row
.dl_cell
	ldy tmp2
	lda LOGO_RLE,y
	tax
	and #7
	clc
	adc #1
	sta tmp5			; run length 1..8
	txa
	lsr
	lsr
	lsr
	tay				; pair index
	lda LOGO_PAIR_CHARS,y
	sta tmp0
	lda LOGO_PAIR_COLS,y
	sta tmp1
	inc tmp2
.dl_run
	lda tmp0
	ldy #0
	sta (ptr_l),y
	lda tmp1
	sta (aux_l),y
	inc ptr_l
	bne .dl_p1
	inc ptr_h
.dl_p1
	inc aux_l
	bne .dl_p2
	inc aux_h
.dl_p2
	dec tmp4
	beq .dl_next
	dec tmp5
	bne .dl_run
	jmp .dl_cell
.dl_next
	inc pr_row
	dec tmp3
	bne .dl_row
.dl_fail
	rts

draw_menu
	; cell_addr clobbers X — use pr_row as loop index
	lda #MENU_CLR_TOP
	sta pr_row
.dm_c
	ldx pr_row
	jsr clear_row
	inc pr_row
	lda pr_row
	cmp #MENU_CLR_BOT
	bcc .dm_c

	lda #4
	sta menu_size
	lda menu_stack_d
	bne .dm_s
	lda menu_can_ret
	bne .dm_s
	lda #3
	sta menu_size
.dm_s
	lda menu_can_ret
	bne .dm_nh
	lda #TEXT_COL
	sta ui_text_col
	lda #<str_hint
	ldy #>str_hint
	ldx #24
	jsr print_centered
.dm_nh
	ldx #0
.dm_l
	stx tmp4
	jsr draw_menu_item
	ldx tmp4
	inx
	cpx menu_size
	bcc .dm_l
	rts

draw_menu_item
	lda tmp4
	asl
	clc
	adc #MENU_Y
	sta pr_row
	tax
	jsr clear_row

	lda tmp4
	cmp menu_item
	beq .di_h
	lda #TEXT_COL
	sta ui_text_col
	jmp .di_g
.di_h
	lda #HILITE_COL
	sta ui_text_col
	ldx pr_row
	lda #8
	jsr cell_addr
	lda #MENU_CURSOR			; skull (@)
	ldy #0
	sta (ptr_l),y
	lda #HILITE_COL
	sta (aux_l),y
.di_g
	lda menu_id
	asl
	asl
	clc
	adc tmp4
	tax
	lda menu_str_lo,x
	ldy menu_str_hi,x
	ldx pr_row
	jmp print_centered

; ==================================================================
vol_fx_inc
	inc effects_vol
	lda effects_vol
	and #15
	sta effects_vol
	jmp sync_redraw
vol_fx_dec
	dec effects_vol
	lda effects_vol
	and #15
	sta effects_vol
	jmp sync_redraw
vol_mus_inc
	inc music_vol
	lda music_vol
	and #15
	sta music_vol
	jmp sync_redraw
vol_mus_dec
	dec music_vol
	lda music_vol
	and #15
	sta music_vol
sync_redraw
	; Apply music volume immediately when no SFX is playing
	lda sound_index
	cmp #$ff
	bne .sr_ui
	lda music_vol
	sta $d418
.sr_ui
	lda #SOUND_STNMOV
	jsr play_sound
	jsr sync_vol_strings
	jmp draw_menu

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

; ==================================================================
; A = text screen index (0=credits 1=help 2=order 3=endgame)
; Types out character-by-character (VicDoom style); red default, ^ → yellow
show_text_screen_body
	clc
	adc #1				; UI_CRED..UI_ENDG
	jsr LoadUiFile
	bcs .st_fail
	lda #MENU_BORDER		; LoadPrg cleared border
	sta $d020
	jsr clear_screen
	jsr wait_frames_30
	lda #<SCREENBUFFER
	sta ui_str_l
	lda #>SCREENBUFFER
	sta ui_str_h
	lda #TEXT_COL			; red default
	sta ui_text_col
	ldx #1
.st_l
	stx pr_row
	ldy #0
	lda (ui_str_l),y
	beq .st_d			; empty line = end of screen
	ldx pr_row
	lda #0
	jsr print_at_typed
	; advance ui_str past this line’s NUL
	ldy #0
.st_a
	lda (ui_str_l),y
	beq .st_n
	iny
	bne .st_a
.st_n
	iny
	tya
	clc
	adc ui_str_l
	sta ui_str_l
	bcc .st_c
	inc ui_str_h
.st_c
	ldx pr_row
	inx
	bne .st_l
.st_d
	jmp wait_key
.st_fail
	rts

; Like print_at but some non-space glyphs per second (VicDoom typing feel)
print_at_typed
	sta pr_col
	stx pr_row
	jsr cell_addr
	ldy #0
.pt
	lda (ui_str_l),y
	beq .pt_d
	cmp #30				; !scr '^'
	beq .pt_tog
	sty tmp1
	sta tmp0			; raw char for pause pick
	jsr ascii_to_scr
	ldy #0
	sta (ptr_l),y
	lda ui_text_col
	sta (aux_l),y
	inc ptr_l
	bne .pt_p1
	inc ptr_h
.pt_p1
	inc aux_l
	bne .pt_p2
	inc aux_h
.pt_p2
	lda tmp0
	cmp #' '
	beq .pt_nx
	ldx #2				; delay per glyph
	cmp #'.'
	beq .pt_long
	cmp #'?'
	beq .pt_long
	cmp #'!'
	beq .pt_long
	cmp #','
	bne .pt_do
	ldx #16				; brief comma pause
	bne .pt_do
.pt_long
	ldx #36				; sentence / emphasis pause
.pt_do
	jsr wait_frames_x
.pt_nx
	ldy tmp1
	iny
	bne .pt
.pt_d
	rts
.pt_tog
	lda #TEXT_COL + HILITE_COL
	sec
	sbc ui_text_col
	sta ui_text_col
	iny
	bne .pt

; UI file indices (LoadUiFile / ui_buf_id)
UI_LOGO = 0
UI_CRED = 1
UI_HELP = 2
UI_ORDR = 3
UI_ENDG = 4

ui_dos_names
	!text "LOGO"
	!text "CRED"
	!text "HELP"
	!text "ORDR"
	!text "ENDG"

load_ui_pending	!byte 0

; LoadUiFile — A = UI_LOGO..UI_ENDG. Skip if ui_buf_id matches. C=0 ok, C=1 error.
; Copies the 4-char DOS name into resident ui_name_buf first — ui_dos_names lives
; under KERNAL and is invisible once LoadPrg sets $01=$36 for SETNAM/LOAD.
LoadUiFile
	cmp ui_buf_id
	beq .lui_ok
	sta load_ui_pending
	asl
	asl					; index * 4
	tay
	ldx #0
.lui_cp
	lda ui_dos_names,y
	sta ui_name_buf,x
	iny
	inx
	cpx #4
	bne .lui_cp
	lda #0
	sta load_do_pad
	lda #4
	ldx #<ui_name_buf
	ldy #>ui_name_buf
	jsr LoadPrg
	bcs .lui_fail
	lda load_ui_pending
	sta ui_buf_id
.lui_ok
	clc
	rts
.lui_fail
	lda #$ff
	sta ui_buf_id
	sec
	rts

str_hint		    !scr "w s move   return select",0
str_new_game		!scr "new  game",0
str_options		    !scr "options",0
str_credits		    !scr "credits",0
str_back		    !scr "back",0
str_e1			    !scr "knee deep in the dead",0
str_e2			    !scr "the shores of hell",0
str_e3			    !scr "inferno",0
str_fx_vol		    !scr "effects volume 15",0
str_mus_vol		    !scr "music volume 10",0
str_controls		!scr "controls",0
str_itytd		    !scr "i'm too young to die",0
str_hmp			    !scr "hurt me plenty",0
str_uv			    !scr "ultra-violence",0

menu_str_lo
	!byte <str_new_game, <str_options, <str_credits, <str_back
	!byte <str_e1, <str_e2, <str_e3, <str_back
	!byte <str_fx_vol, <str_mus_vol, <str_controls, <str_back
	!byte <str_itytd, <str_hmp, <str_uv, <str_back
menu_str_hi
	!byte >str_new_game, >str_options, >str_credits, >str_back
	!byte >str_e1, >str_e2, >str_e3, >str_back
	!byte >str_fx_vol, >str_mus_vol, >str_controls, >str_back
	!byte >str_itytd, >str_hmp, >str_uv, >str_back
