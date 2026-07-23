; Title / menus / entering / summary / melt / outer game flow (VicDoom-style)
; Screen ptrs: scr_ptr = $0400 cell, col_ptr = $d800 cell, ui_str_l/h = string
!zone titlemenus

MSG_LET0 = 192
MENU_CURSOR = 218			; skull (@); wall dither owns charset 0
MENU_Y = 11
TEXT_COL = 2
HILITE_COL = 7
UI_COL = 1
NM_BACK = 256 - 66
NM_START = 256 - 10
NM_CRED = 256 - 1
NM_HELP = 256 - 2
NM_ORDER = 256 - 3

LEVEL_ITEMS_BYTES = MAX_ITEMS * ITEM_BYTES

difficulty	!byte 2
episode		!byte 0
level_num	!byte 1
end_level	!byte 0
effects_vol	!byte 15
music_vol	!byte 10
menu_can_ret	!byte 0
menu_id		!byte 0
menu_item	!byte 0
menu_size	!byte 4
menu_stack_d	!byte 0
menu_stk_m	!byte 0, 0, 0
menu_stk_i	!byte 0, 0, 0
ui_text_col	!byte TEXT_COL
items_bak_ok	!byte 0
pr_row		!byte 0
pr_col		!byte 0
pr_len		!byte 0
melt_count	!byte 0, 0			; 16-bit melt loop counter
melt_col	!byte 0

; ==================================================================
game_start
	cli
	lda #0
	sta items_bak_ok
	jsr hide_weapon
	jsr clear_screen
	lda #0
	jsr run_menu
	lda #1
	sta level_num
	lda #0
	sta health

next_level
	jsr hide_weapon
	jsr show_entering
	jsr FormatDosName
	jsr LoadLevel
	bcs .nl_fail
	lda #0
	sta items_bak_ok
	jsr begin_level_play
	jmp gameloop
.nl_fail
	jmp game_start

; clear + "entering" / level title
show_entering
	jsr clear_screen
	lda #TEXT_COL
	sta ui_text_col
	lda #<str_entering
	ldy #>str_entering
	ldx #8
	jsr print_centered
	lda #UI_COL
	sta ui_text_col
	jsr get_level_title
	ldx #10
	jmp print_centered

begin_level_play
	lda items_bak_ok
	bne .blp_rest
	ldx #0
.blp_snap
	lda level_items,x
	sta level_items_bak,x
	inx
	cpx #LEVEL_ITEMS_BYTES
	bne .blp_snap
	lda #1
	sta items_bak_ok
	jmp .blp_go
.blp_rest
	ldx #0
.blp_copy
	lda level_items_bak,x
	sta level_items,x
	inx
	cpx #LEVEL_ITEMS_BYTES
	bne .blp_copy
.blp_go
	lda #0
	sta end_level
	jmp start_level

after_level_end
	jsr hide_weapon
	lda #TEXT_COL
	sta ui_text_col
	lda #<str_map_complete
	ldy #>str_map_complete
	ldx #12
	jsr print_centered
	jsr wait_frames_60
	jsr melt_screen
	jsr wait_frames_120		; hold blank after melt ~2s
	jsr summary_screen
	lda level_num
	cmp #8
	beq .ale_end
	inc level_num
	lda level_num
	cmp #10
	bcc .ale_next
	jmp game_start
.ale_end
	lda #3				; txt_endgame
	jsr show_text_screen
	jmp game_start
.ale_next
	jmp next_level

gameloop_check_esc
	jsr ui_read_keys
	lda ui_pressed
	and #UI_ESC
	bne .gce_go
	rts
.gce_go
	jsr hide_weapon
	jsr ui_wait_esc_up
	lda #1
	jsr run_menu
	cmp #1
	beq .gce_new
	rts
.gce_new
	lda #1
	sta level_num
	lda #0
	sta health
	pla
	pla
	jmp next_level

; Rising edge of IRQ-latched F1 (key_map from read_input)
gameloop_check_map
	lda key_map
	beq .gcm_up
	lda key_map_was
	bne .gcm_held
	lda #1
	sta key_map_was
	jsr mapscreen
	; mapscreen waits for F1 up; clear so we need a fresh press
	lda #0
	sta key_map_was
	sta key_map
	sta in_map
	rts
.gcm_up
	sta key_map_was			; A = 0
.gcm_held
	rts

; ==================================================================
run_menu
	sta menu_can_ret
	; Pause key sampling in IRQ — ui_read_keys owns $dc00; SFX still ticks
	lda #1
	sta input_paused
	lda #TEXT_COL			; red border while in menus
	sta $d020
	jsr ui_wait_esc_up
	jsr clear_screen
	jsr draw_title_banner
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
	jsr show_text_screen
	jsr clear_screen
	jsr draw_title_banner
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
	lda #6 ; blue
	sta ui_text_col
	lda #<str_title
	ldy #>str_title
	ldx #2
	jsr print_centered
	lda #8 ; orange
	sta ui_text_col
	lda #<str_subtitle
	ldy #>str_subtitle
	ldx #4
	jmp print_centered

draw_menu
	; cell_addr clobbers X — use pr_row as loop index
	lda #11
	sta pr_row
.dm_c
	ldx pr_row
	jsr clear_row
	inc pr_row
	lda pr_row
	cmp #19
	bcc .dm_c

	jsr draw_title_banner

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
	ldx #21
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
show_text_screen
	sta tmp5
	jsr clear_screen
	jsr wait_frames_30
	ldx tmp5
	lda text_scr_lo,x
	sta ui_str_l
	lda text_scr_hi,x
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
	; reset colour for each new line (VicDoom keeps c across lines —
	; keep toggle sticky within the dump instead)
	ldx pr_row
	inx
	cpx #22
	bcc .st_l
.st_d
	jmp wait_key

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
	; delay: none for space; ~8 cps (@60Hz); longer for punctuation
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
	cpy #40
	bcc .pt
.pt_d
	rts
.pt_tog
	lda #TEXT_COL + HILITE_COL
	sec
	sbc ui_text_col
	sta ui_text_col
	iny
	bne .pt

summary_screen
	jsr clear_screen
	lda #UI_COL
	sta ui_text_col
	jsr get_level_title
	ldx #1
	jsr print_centered
	lda #TEXT_COL
	sta ui_text_col
	lda #<str_finished
	ldy #>str_finished
	ldx #2
	jsr print_centered

	; VicDoom layout (22-col) +9 to centre on 40-col
SUM_LAB = 13
SUM_PCT = 23
SUM_TIME = 22

	lda #<str_kills
	sta ui_str_l
	lda #>str_kills
	sta ui_str_h
	ldx #5
	lda #SUM_LAB
	jsr print_at
	lda #<str_items
	sta ui_str_l
	lda #>str_items
	sta ui_str_h
	ldx #7
	lda #SUM_LAB
	jsr print_at
	lda #<str_secret
	sta ui_str_l
	lda #>str_secret
	sta ui_str_h
	ldx #9
	lda #SUM_LAB
	jsr print_at
	lda #<str_time
	sta ui_str_l
	lda #>str_time
	sta ui_str_h
	ldx #12
	lda #SUM_LAB
	jsr print_at
	lda #<str_par
	sta ui_str_l
	lda #>str_par
	sta ui_str_h
	ldx #14
	lda #SUM_LAB
	jsr print_at

	ldx #5
	jsr put_pct0
	jsr wait_frames_60
	ldx #7
	jsr put_pct0
	jsr wait_frames_60
	ldx #9
	jsr put_pct0
	jsr wait_frames_60
	ldx #12
	jsr put_time0
	jsr wait_frames_60
	ldx #14
	jsr put_time0
	jsr wait_frames_60

	lda #HILITE_COL
	sta ui_text_col
	lda #<str_press_key
	ldy #>str_press_key
	ldx #20
	jsr print_centered
	jsr wait_key
	jmp clear_screen

put_pct0
	stx pr_row
	lda #SUM_PCT
	ldx pr_row
	jsr cell_addr
	lda #' '
	ldy #0
	jsr store_asc
	iny
	lda #' '
	jsr store_asc
	iny
	lda #'0'
	jsr store_asc
	iny
	lda #'%'
	jmp store_asc

put_time0
	stx pr_row
	lda #SUM_TIME
	ldx pr_row
	jsr cell_addr
	lda #'0'
	ldy #0
	jsr store_asc
	iny
	lda #'0'
	jsr store_asc
	iny
	lda #':'
	jsr store_asc
	iny
	lda #'0'
	jsr store_asc
	iny
	lda #'0'
	jmp store_asc

store_asc
	sta tmp0
	jsr ascii_to_scr
	sta (ptr_l),y
	lda ui_text_col
	sta (aux_l),y
	rts

; 1000 column drips at max speed; no raster waits
melt_screen
	lda #<1000
	sta melt_count
	lda #>1000
	sta melt_count + 1
.ms_a
	jsr melt_one_col
	lda melt_count
	bne .ms_lo
	dec melt_count + 1
.ms_lo
	dec melt_count
	lda melt_count
	ora melt_count + 1
	bne .ms_a
	rts

; Slide one random column down one row (all 25 rows); +40 addressing
melt_one_col
	jsr GetRandom16
	lda random
.ms_mod
	cmp #40
	bcc .ms_got
	sbc #40
	jmp .ms_mod
.ms_got
	sta melt_col
	; scr_ptr = $0400 + col + 23*40 (start at row 23)
	lda melt_col
	clc
	adc #<$0400
	sta scr_ptr
	lda #0
	adc #>$0400
	sta scr_ptr + 1
	lda scr_ptr
	clc
	adc #<$0398			; 23*40
	sta scr_ptr
	lda scr_ptr + 1
	adc #>$0398
	sta scr_ptr + 1
	; col_ptr = screen + $d400
	lda scr_ptr
	sta col_ptr
	lda scr_ptr + 1
	clc
	adc #($d800 - $0400) >> 8
	sta col_ptr + 1
	; 24 copies: row23→24 … row0→1
	ldx #24
.ms_r
	lda scr_ptr
	clc
	adc #40
	sta tmp2
	lda scr_ptr + 1
	adc #0
	sta tmp3
	lda col_ptr
	clc
	adc #40
	sta tmp4
	lda col_ptr + 1
	adc #0
	sta tmp5
	ldy #0
	lda (scr_ptr),y
	sta (tmp2),y
	lda (col_ptr),y
	sta (tmp4),y
	lda scr_ptr
	sec
	sbc #40
	sta scr_ptr
	lda scr_ptr + 1
	sbc #0
	sta scr_ptr + 1
	lda col_ptr
	sec
	sbc #40
	sta col_ptr
	lda col_ptr + 1
	sbc #0
	sta col_ptr + 1
	dex
	bne .ms_r
	; clear top cell (black)
	lda melt_col
	clc
	adc #<$0400
	sta scr_ptr
	lda #0
	adc #>$0400
	sta scr_ptr + 1
	lda scr_ptr
	sta col_ptr
	lda scr_ptr + 1
	clc
	adc #($d800 - $0400) >> 8
	sta col_ptr + 1
	lda #32
	ldy #0
	sta (scr_ptr),y
	lda #0
	sta (col_ptr),y
	rts

; ==================================================================
; A/Y=string X=row → centered
; '^' in strings toggles colour red ↔ yellow (not drawn; VicDoom style)
print_centered
	sta ui_str_l
	sty ui_str_h
	stx pr_row
	jsr str_len
	lsr
	sta pr_len
	lda #20
	sec
	sbc pr_len
	bcs .pc
	lda #0
.pc
	ldx pr_row
	; A=col X=row ui_str set
print_at
	sta pr_col
	stx pr_row
	jsr cell_addr
	ldy #0
.pa
	lda (ui_str_l),y
	beq .pa_d
	cmp #30				; !scr '^' → screen code 30
	beq .pa_tog
	sty tmp1
	jsr ascii_to_scr
	ldy #0
	sta (ptr_l),y
	lda ui_text_col
	sta (aux_l),y
	; advance screen + colour one cell
	inc ptr_l
	bne .pa_p1
	inc ptr_h
.pa_p1
	inc aux_l
	bne .pa_p2
	inc aux_h
.pa_p2
	ldy tmp1
	iny
	cpy #40
	bcc .pa
.pa_d
	rts
.pa_tog
	; toggle TEXT_COL(2) ↔ HILITE_COL(7): c = 9 - c
	lda #TEXT_COL + HILITE_COL
	sec
	sbc ui_text_col
	sta ui_text_col
	iny
	bne .pa

; Visible length: skip '^' toggles
str_len
	ldy #0
	ldx #0
.sl
	lda (ui_str_l),y
	beq .sl_d
	cmp #30
	beq .sl_sk
	inx
.sl_sk
	iny
	cpy #40
	bcc .sl
.sl_d
	txa
	rts

ascii_to_scr
	cmp #' '
	beq .a2
	cmp #'0'
	bcc .a2a
	cmp #'9'+1
	bcs .a2a
	rts
.a2a
	cmp #'A'
	bcc .a2b
	cmp #'Z'+1
	bcs .a2b
	sec
	sbc #'A'
	clc
	adc #MSG_LET0
	rts
.a2b
	cmp #'a'
	bcc .a2c
	cmp #'z'+1
	bcs .a2c
	sec
	sbc #'a'
	clc
	adc #MSG_LET0
	rts
.a2c
	cmp #27
	bcs .a2
	cmp #1
	bcc .a2
	clc
	adc #MSG_LET0-1
.a2
	rts

; A=col X=row → ptr=screen aux=colour
cell_addr
	sta pr_col
	stx pr_row
	lda #0
	sta ptr_h
	lda pr_row
	asl
	asl
	asl
	sta tmp0			; *8
	lda pr_row
	sta ptr_l
	lda #0
	sta ptr_h
	ldx #5
.ca32
	asl ptr_l
	rol ptr_h
	dex
	bne .ca32			; *32
	lda ptr_l
	clc
	adc tmp0
	sta ptr_l
	bcc .ca1
	inc ptr_h
.ca1
	lda ptr_l
	clc
	adc pr_col
	sta ptr_l
	bcc .ca2
	inc ptr_h
.ca2
	lda ptr_l
	clc
	adc #<$0400
	sta ptr_l
	lda ptr_h
	adc #>$0400
	sta ptr_h
	lda ptr_l
	sta aux_l
	lda ptr_h
	clc
	adc #($d800-$0400)>>8
	sta aux_h
	rts

clear_screen
	ldx #0
	lda #32
.cs1
	sta $0400,x
	sta $0500,x
	sta $0600,x
	sta $06e8,x
	inx
	bne .cs1
	ldx #0
	lda #TEXT_COL
.cs2
	sta $d800,x
	sta $d900,x
	sta $da00,x
	sta $dae8,x
	inx
	bne .cs2
	rts

clear_row
	txa
	pha
	lda #0
	jsr cell_addr
	ldy #39
.cr
	lda #32
	sta (ptr_l),y
	lda #TEXT_COL
	sta (aux_l),y
	dey
	bpl .cr
	pla
	tax
	rts

wait_raster
	lda $d012
.wr
	cmp $d012
	beq .wr
	rts

; Wait one full video frame (vsync)
wait_frame
.wf_hi
	lda $d011
	bpl .wf_hi			; wait until raster ≥ 256
.wf_lo
	lda $d011
	bmi .wf_lo			; wait until raster < 256
	rts

wait_frames_30
	ldx #30
	bne wait_frames_x
wait_frames_60
	ldx #60
	bne wait_frames_x
wait_frames_90
	ldx #90
	bne wait_frames_x
wait_frames_120
	ldx #120			; ~2s @ 60Hz / 2.4s @ 50Hz
wait_frames_x
.wf
	jsr wait_frame
	dex
	bne .wf
	rts

wait_key
.wk0
	jsr ui_read_keys
	lda ui_keys
	bne .wk0
.wk1
	jsr ui_read_keys
	lda ui_pressed
	beq .wk1
	rts

; ==================================================================
; get_level_title — A/Y = ptr to title for level_num (1..9)
get_level_title
	lda level_num
	sec
	sbc #1
	cmp #9
	bcc .glt_ok
	lda #0
.glt_ok
	tax
	lda level_title_lo,x
	ldy level_title_hi,x
	rts

level_title_lo
	!byte <str_e1m1, <str_e1m2, <str_e1m3, <str_e1m4, <str_e1m5
	!byte <str_e1m6, <str_e1m7, <str_e1m8, <str_e1m9
level_title_hi
	!byte >str_e1m1, >str_e1m2, >str_e1m3, >str_e1m4, >str_e1m5
	!byte >str_e1m6, >str_e1m7, >str_e1m8, >str_e1m9

str_e1m1		!scr "hangar",0
str_e1m2		!scr "nuclear plant",0
str_e1m3		!scr "toxin refinery",0
str_e1m4		!scr "command control",0
str_e1m5		!scr "phobos lab",0
str_e1m6		!scr "central processing",0
str_e1m7		!scr "computer station",0
str_e1m8		!scr "phobos anomaly",0
str_e1m9		!scr "military base",0

str_title		    !scr "doom",0
str_subtitle		!scr "logo",0
str_entering		!scr "entering",0
str_map_complete	!scr "map complete",0
str_finished		!scr "finished",0
str_kills		    !scr "kills",0
str_items		    !scr "items",0
str_secret		    !scr "secret",0
str_time		    !scr "time",0
str_par			    !scr "par",0
str_press_key		!scr "press a key",0
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

text_scr_lo
	!byte <txt_credits, <txt_help, <txt_order, <txt_endgame
text_scr_hi
	!byte >txt_credits, >txt_help, >txt_order, >txt_endgame

txt_credits
	!scr "^doom^ for the ^commodore 64^", 0
    !scr " ",0
    !scr "ported by ^steve mccrea^, july 2026.",0
    !scr " ",0
    !scr "developed using the ^acme^ assembler",0
    !scr "by ^marco baye^.",0
    !scr " ",0
    !scr "tested using the ^vice^ emulator",0
    !scr "by ^andreas boose^ and the ^vice team^.",0
    !scr " ",0
	!scr "based on ^the keep^ and ^vicdoom^",0
    !scr "by ^steve mccrea^.", 0
    !scr " ",0
	!scr "press a key", 0
	!byte 0

txt_help
	!scr "^controls^",0
    !scr " ",0
	!scr "move forward      w",0
	!scr "move backward     s",0
	!scr "strafe left       a",0
	!scr "strafe right      d",0
	!scr "turn left         j",0
	!scr "turn right        l",0
	!scr "use               k",0
	!scr "fire              space",0
	!scr "toggle map        f1",0
    !scr " ",0
	!scr "switch weapon     2345",0
	!scr "menu              runstop",0
    !scr " ",0
	!scr "press a key",0
	!byte 0

txt_order
    !scr "sure, don't order ^doom^. sit back with",0
    !scr "your milk and cookies and let the",0
    !scr "universe go to hell. don't face the",0
    !scr "onslaught of demons and spectres that",0
    !scr "await you on ^the shores of hell^.",0
    !scr "avoid the terrifying confrontations",0
    !scr "with cacodemons and lost souls that",0
    !scr "infest ^inferno^.",0
    !scr " ",0
    !scr "or, act like a man! slap a few shells",0
    !scr "into your shotgun and let's kick some",0
    !scr "demonic butt. order the entire ^doom^",0
    !scr "trilogy now! after all, you'll probably",0
    !scr "end up in hell eventually. shouldn't",0
    !scr "you know your way around before you",0
    !scr "make the extended visit?",0
    !scr " ",0
    !scr "to order ^doom^, call ^1-800-]games^.",0
    !scr " ",0
    !scr "press a key",0
	!byte 0

txt_endgame
	!scr "once you beat the big badasses and",0
	!scr "clean out the moon base you're supposed",0
	!scr "to win, aren't you? aren't you? where's",0
	!scr "your fat reward and ticket home? what",0
	!scr "the hell is this? it's not supposed to",0
	!scr "end this way!",0
	!scr " ",0
	!scr "it stinks like rotten meat, but looks",0
	!scr "like the lost deimos base. looks like",0
	!scr "you're stuck on ^the shores of hell^.",0
	!scr "the only way out is through.",0
	!scr " ",0
	!scr "to continue the ^doom^ experience, play",0
	!scr "^the shores of hell^ and its amazing",0
	!scr "sequel, ^inferno^!",0
	!scr " ",0
	!scr "press a key",0
	!byte 0
