; Level stats counters + summary roll-in (kernal scrap; copied from MEM_LEVEL blob)
; BSS counters live in cassette buffer (zeropage.asm) — not in this PRG image.
!zone levelstats

; Summary columns (VicDoom 22-col +9)
STAT_SUM_LAB = 13
STAT_SUM_PCT = 23
STAT_SUM_TIME = 22

; ---------------------------------------------------------------------------
; init_level_stats — zero got/kills/time (totals are level_num_*)
; ---------------------------------------------------------------------------
init_level_stats
	lda #0
	sta num_kills
	sta num_items_got
	sta num_secrets_got
	sta map_time_ms
	sta map_time_ms + 1
	sta map_time_sec
	sta map_time_sec + 1
	rts

; ---------------------------------------------------------------------------
; update_map_time — add dt_ms; every ≥1000 ms bump map_time_sec
; ---------------------------------------------------------------------------
update_map_time
	lda map_time_ms
	clc
	adc dt_ms
	sta map_time_ms
	lda map_time_ms + 1
	adc #0
	sta map_time_ms + 1
.umt_chk
	lda map_time_ms
	cmp #<1000
	lda map_time_ms + 1
	sbc #>1000
	bcc .umt_rts
	lda map_time_ms
	sbc #<1000
	sta map_time_ms
	lda map_time_ms + 1
	sbc #>1000
	sta map_time_ms + 1
	inc map_time_sec
	bne .umt_chk
	inc map_time_sec + 1
	bne .umt_chk
.umt_rts
	rts

; ---------------------------------------------------------------------------
; stat_percent — A = got, Y = total → A = (100*got)/total (0 if total=0)
; ---------------------------------------------------------------------------
stat_percent
	cpy #0
	bne .sp_go
	lda #0
	rts
.sp_go
	sta tmp0
	sty tmp1
	lda #0
	sta aux_l
	sta aux_h
	ldx tmp0
	beq .sp_div
.sp_mul
	clc
	lda aux_l
	adc #100
	sta aux_l
	lda aux_h
	adc #0
	sta aux_h
	dex
	bne .sp_mul
.sp_div
	lda tmp1
	jmp udiv16x8

; ---------------------------------------------------------------------------
; summary_tick — VicDoom pistol click + ~2-frame pause
; ---------------------------------------------------------------------------
summary_tick
	lda #0
	sta sound_priority		; always allow the tally click
	lda #SOUND_PISTOL
	jsr play_sound
	ldx #2
	jmp wait_frames_x

; ---------------------------------------------------------------------------
; roll_in_percentage — A = target 0..100, X = row; VicDoom step +4
; ---------------------------------------------------------------------------
roll_in_percentage
	sta roll_target
	stx roll_row
	lda #0
	sta roll_cur
.rip_lp
	jsr put_pct_val
	jsr summary_tick
	lda roll_cur
	cmp roll_target
	bcs .rip_done
	clc
	adc #4
	bcs .rip_cap
	cmp roll_target
	bcc .rip_use
	beq .rip_use
.rip_cap
	lda roll_target
.rip_use
	sta roll_cur
	jmp .rip_lp
.rip_done
	rts

; $FD30–$FD4F is KERNAL's default I/O vector table (ROM). RESTOR reads it;
; lda/sta $FD30,x with KERNAL in copies that table into RAM under ROM.
; Snap: those 32 bytes replaced put_pct_val (jsr cell_addr → EA31…);
; PC FD39 executed F2 (BNE offset) as JAM. Emit zeros in the hole so the
; MEM_LEVEL staging blob stays contiguous for copy_kernal_blob.
!if * > $FD30 {
	!error "levelstats crossed FD30 before VECTOR hole; *=", *
}
	!fill $FD50 - *, 0

put_pct_val
	lda roll_cur
	sta tmp2
	lda #STAT_SUM_PCT
	ldx roll_row			; private row (not shared pr_row)
	jsr cell_addr
	lda #0
	sta tmp0
	sta tmp1
.pp_h
	lda tmp2
	cmp #100
	bcc .pp_t
	sbc #100
	sta tmp2
	inc tmp0
	bne .pp_h
.pp_t
	lda tmp2
	cmp #10
	bcc .pp_o
	sbc #10
	sta tmp2
	inc tmp1
	bne .pp_t
.pp_o
	lda tmp0
	clc
	adc #'0'
	ldy #0
	jsr store_asc
	iny
	lda tmp1
	clc
	adc #'0'
	jsr store_asc
	iny
	lda tmp2
	clc
	adc #'0'
	jsr store_asc
	iny
	lda #'%'
	jmp store_asc

; ---------------------------------------------------------------------------
; roll_in_time — roll_time_l/h = target seconds, X = row; VicDoom step +5
; ---------------------------------------------------------------------------
roll_in_time
	stx pr_row
	lda #0
	sta roll_cur
	sta roll_cur + 1
.rit_lp
	jsr put_time_val
	jsr summary_tick
	lda roll_cur
	cmp roll_time_l
	lda roll_cur + 1
	sbc roll_time_h
	bcs .rit_done
	lda roll_cur
	clc
	adc #5
	sta roll_cur
	lda roll_cur + 1
	adc #0
	sta roll_cur + 1
	lda roll_time_l
	cmp roll_cur
	lda roll_time_h
	sbc roll_cur + 1
	bcs .rit_lp			; roll_time >= roll_cur
	lda roll_time_l
	sta roll_cur
	lda roll_time_h
	sta roll_cur + 1
	jmp .rit_lp
.rit_done
	rts

; Write MM:SS from roll_cur. store_asc clobbers tmp0 — save seconds first.
put_time_val
	lda roll_cur
	sta tmp0
	lda roll_cur + 1
	sta tmp1
	lda #0
	sta tmp2			; minutes
.ptv_div
	lda tmp0
	sec
	sbc #60
	tay
	lda tmp1
	sbc #0
	bcc .ptv_rem
	sta tmp1
	sty tmp0
	inc tmp2
	bne .ptv_div
.ptv_rem
	lda tmp0
	pha				; seconds (store_asc uses tmp0)
	lda #STAT_SUM_TIME
	ldx pr_row
	jsr cell_addr
	lda tmp2
	ldy #0
	jsr print_2dig_at_y
	lda #':'
	ldy #2
	jsr store_asc
	pla
	ldy #3
	jmp print_2dig_at_y

; A = 0..99, Y = column offset into (ptr_l)
print_2dig_at_y
	sta tmp3
	lda #0
	sta tmp4
.p2_t
	lda tmp3
	cmp #10
	bcc .p2_o
	sbc #10
	sta tmp3
	inc tmp4
	bne .p2_t
.p2_o
	lda tmp4
	clc
	adc #'0'
	jsr store_asc
	iny
	lda tmp3
	clc
	adc #'0'
	jmp store_asc

put_sucks
	stx pr_row
	lda #STAT_SUM_TIME
	ldx pr_row
	jsr cell_addr
	lda #<str_sucks
	sta ui_str_l
	lda #>str_sucks
	sta ui_str_h
	ldy #0
.ps_lp
	lda (ui_str_l),y
	beq .ps_d
	sty tmp1
	jsr store_asc
	ldy tmp1
	iny
	bne .ps_lp
.ps_d
	rts

; ---------------------------------------------------------------------------
; summary_screen — intermission (in high; mid is tight)
; ---------------------------------------------------------------------------
summary_screen
	cld				; binary math in put_pct / roll_in (music uses SED)
	lda music_enabled
	pha
	lda #0
	sta music_enabled		; no MUSIC_PLAY during UI (Timer B SFX ok)
	cli
	lda #1
	sta input_paused		; Timer A skips $dc00; Timer B still ticks SFX
	jsr io_push
	; Re-assert CIA1 timers (SFX needs Timer B @ ~140 Hz)
	lda #$83
	sta $dc0d
	lda #$11
	sta $dc0e
	sta $dc0f
	jsr io_pop
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

	lda #<str_kills
	sta ui_str_l
	lda #>str_kills
	sta ui_str_h
	ldx #5
	lda #STAT_SUM_LAB
	jsr print_at
	lda #<str_items
	sta ui_str_l
	lda #>str_items
	sta ui_str_h
	ldx #7
	lda #STAT_SUM_LAB
	jsr print_at
	lda #<str_secret
	sta ui_str_l
	lda #>str_secret
	sta ui_str_h
	ldx #9
	lda #STAT_SUM_LAB
	jsr print_at
	lda #<str_time
	sta ui_str_l
	lda #>str_time
	sta ui_str_h
	ldx #12
	lda #STAT_SUM_LAB
	jsr print_at
	lda #<str_par
	sta ui_str_l
	lda #>str_par
	sta ui_str_h
	ldx #14
	lda #STAT_SUM_LAB
	jsr print_at

	lda #TEXT_COL
	sta ui_text_col

	lda num_kills
	ldy level_num_enemies
	jsr stat_percent
	ldx #5
	jsr roll_in_percentage
	jsr wait_frames_60

	lda num_items_got
	ldy level_num_items
	jsr stat_percent
	ldx #7
	jsr roll_in_percentage
	jsr wait_frames_60

	lda num_secrets_got
	ldy level_num_secrets
	jsr stat_percent
	ldx #9
	jsr roll_in_percentage
	jsr wait_frames_60

	; time — VicDoom "sucks" if ≥ 10:00
	lda map_time_sec
	cmp #<600
	lda map_time_sec + 1
	sbc #>600
	bcc .sum_time
	ldx #12
	jsr put_sucks
	jsr summary_tick
	jmp .sum_par
.sum_time
	lda map_time_sec
	sta roll_time_l
	lda map_time_sec + 1
	sta roll_time_h
	ldx #12
	jsr roll_in_time
.sum_par
	jsr wait_frames_60
	lda level_par_time
	sta roll_time_l
	lda #0
	sta roll_time_h
	ldx #14
	jsr roll_in_time
	jsr wait_frames_60

	lda #HILITE_COL
	sta ui_text_col
	lda #<str_press_key
	ldy #>str_press_key
	ldx #20
	jsr print_centered
	jsr wait_key
	lda #0
	sta input_paused
	pla
	sta music_enabled
	jsr io_push
	; Re-assert CIA1 timers + IRQs for next level / menu
	lda #$83
	sta $dc0d
	lda #$11
	sta $dc0e
	sta $dc0f
	jsr io_pop
	cli
	lda #0
	sta sound_priority
	lda #SOUND_PISTOL
	jsr play_sound
	jmp clear_screen
