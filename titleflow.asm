; Resident title / level flow / print / melt (menu UI loads from disk → MENU_BASE)
; Screen ptrs: scr_ptr = $0400 cell, col_ptr = $d800 cell, ui_str_l/h = string
!zone titleflow

TEXT_COL = 2
HILITE_COL = 7
UI_COL = 1

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
pr_row		!byte 0
pr_col		!byte 0
pr_len		!byte 0
melt_count	!byte 0, 0			; 16-bit melt loop counter
melt_col	!byte 0

; ==================================================================
game_start
	cli
	lda #$ff
	sta ui_buf_id
	jsr hide_weapon
	jsr clear_screen
	jsr LoadMenu
	bcs .gs_skip
	lda #0
	jsr run_menu
.gs_skip
	lda #1
	sta level_num
	lda #0
	sta health
	sta god_mode

next_level
	jsr hide_weapon
	jsr show_entering
	jsr FormatDosName
	jsr LoadLevel
	bcs .nl_fail
	lda #0
	sta end_level
	jsr start_level
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

after_level_end
	jsr hide_weapon
	lda clev
	beq .ale_normal
	lda #0
	sta clev
	jmp next_level			; idclev: skip summary / don't inc
.ale_normal
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
	jsr LoadMenu
	bcs .ale_gs
	lda #3				; endgame text index → UI_ENDG
	jsr show_text_screen
.ale_gs
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
	jsr LoadMenu
	bcs .gce_fail
	lda #1
	jsr run_menu
	cmp #1
	beq .gce_new
.gce_fail
	rts
.gce_new
	lda #1
	sta level_num
	lda #0
	sta health
	sta god_mode
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
	bne .pa
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
	bne .sl
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

; A=char → screen cell at (ptr_l),y with ui_text_col (levelstats / typed print)
store_asc
	sta tmp0
	jsr ascii_to_scr
	sta (ptr_l),y
	lda ui_text_col
	sta (aux_l),y
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

str_entering		!scr "entering",0
str_map_complete	!scr "map complete",0
str_finished		!scr "finished",0
str_kills		    !scr "kills",0
str_items		    !scr "items",0
str_secret		    !scr "secret",0
str_time		    !scr "time",0
str_par			    !scr "par",0
str_sucks		    !scr "sucks",0
str_press_key		!scr "press a key",0
