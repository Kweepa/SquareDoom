!zone util

; Map I/O in ($35), saving previous $01. Nested-safe with io_pop.
; Do not PHA $01: a subroutine RTS would pull that byte as the return PCL
; (setup_pistol's first jsr io_push returned to $6936 BRK in sprite data).
io_depth	!byte 0
io_stk		!byte 0, 0, 0, 0
io_tmp_a	!byte 0
io_tmp_x	!byte 0

io_push
	sta io_tmp_a
	stx io_tmp_x
	ldx io_depth
	lda $01
	sta io_stk,x
	inx
	stx io_depth
	lda #$35
	sta $01
	ldx io_tmp_x
	lda io_tmp_a
	rts

io_pop
	sta io_tmp_a
	stx io_tmp_x
	ldx io_depth
	dex
	stx io_depth
	lda io_stk,x
	sta $01
	ldx io_tmp_x
	lda io_tmp_a
	rts

; A = border colour
set_border
	tax
	jsr io_push
	txa
	sta $d020
	jmp io_pop

; VIC bank 3, screen $C400 / charset $D800. Caller must have I/O in.
; Drop menu leftover BMM/MCM. Leave DEN off — HIGH loadraw writes the
; $C400 screen hole; unblank after show_entering (locode) or in LoadPrg.
; Absolute $dd00 write: Krill DDRA=$03 makes bits 2–5 inputs. RMW latches
; live IEC pins and the next loadraw hangs (BIT $DD00 / BVC). Quake64 vic.asm.
set_vic_bank3
	lda #$00				; VIC bank 3; upper 6 bits 0
	sta $dd00
	lda #D018_VIC
	sta $d018
	lda #$0b				; text, 25 rows, YSCROLL=3, DEN off
	sta $d011
	lda #$08				; CSEL, MCM off
	sta $d016
	rts

; A = colour. I/O must be in. Fills $d800–$dbe7.
fill_color_ram
	ldx #0
.fcr
	sta $d800,x
	sta $d900,x
	sta $da00,x
	sta $dae8,x
	inx
	bne .fcr
	rts

; mapx/mapy → A = sector id
; Uses maprowlo/hi = level_map + y*32
; Leaves ptr_l/h at the cell (setup_player_tile caches it as plr_tile).
; level_map must be 32-byte aligned so mapx add never carries into ptr_h.
map_sector_id
	ldy mapy
	lda maprowlo,y
	clc
	adc mapx
	sta ptr_l
	lda maprowhi,y
	sta ptr_h
	ldy #0
	lda (ptr_l),y
	rts

; mapx/mapy → A = item layer byte; ptr_l/h at the cell (map hi + 4)
item_layer_id
	jsr item_layer_ptr
	ldy #0
	lda (ptr_l),y
	rts

item_layer_ptr
	ldy mapy
	lda maprowlo,y
	clc
	adc mapx
	sta ptr_l
	lda maprowhi,y
	adc #4				; $90..$93 → $94..$97
	sta ptr_h
	rts

; mapx/mapy → tmp0/tmp1 = tile-center world XY
item_tile_xy
	lda mapx
	asl
	asl
	asl
	clc
	adc #4
	sta tmp0
	lda mapy
	asl
	asl
	asl
	clc
	adc #4
	sta tmp1
	rts

player_tile
	lda playerx_h
	lsr
	lsr
	lsr
	sta mapx
	lda playery_h
	lsr
	lsr
	lsr
	sta mapy
	rts

; playera → A = NESW face: 0=N 1=E 2=S 3=W  ((a+32)>>6 & 3)
player_face_nesw
	lda playera
	clc
	adc #32
	lsr
	lsr
	lsr
	lsr
	lsr
	lsr
	and #3
	rts

; Fill colour+pattern column: A = colour, ytop..ybot-1
; Clobbers X (colour kept in X across the dual-FB store).
; Cyan (3) → sky_cols[sky_col][row] via sky_put (see fill_sky path).
fill_col_span
	ldy ybot
	sty fill_y1
	ldy ytop
	sty fill_y0			; Y already = fill_y0 for the loop
!if PROFILE = 1 {
	inc span_lo
	bne .fcs_go
	inc span_hi
.fcs_go
}
	tax
	cpx #3
	beq .fs_sky_test
	jmp .fs_loop_test
; A = colour, fill_pat = screen code; fill_y0..fill_y1-1 into both FBs
; Clobbers X. Empty span (fill_y0 == fill_y1) is a no-op.
fill_span
!if PROFILE = 1 {
	inc span_lo
	bne .fs_go
	inc span_hi
.fs_go
}
	tax				; colour in X — avoids pha/pla per row (30→25 cy)
	cpx #3
	beq .fs_sky
	ldy fill_y0
	jmp .fs_loop_test
.fs_sky
	ldy fill_y0
	jmp .fs_sky_test
.fs_loop
	txa
	sta (col_base_l),y
	lda fill_pat
	sta (pat_base_l),y
	iny
.fs_loop_test
	cpy fill_y1
	bne .fs_loop
	rts

; Cyan span: sample sky_ptr (row clamped to 0..11), FLOOR_PAT_BASE UDG.
.fs_sky_loop
	cpy #12
	bcs .fs_sky_hi
	lda (sky_ptr_l),y
	jsr sky_put
	iny
.fs_sky_test
	cpy fill_y1
	bne .fs_sky_loop
	rts
.fs_sky_hi
	sty tmp0			; FB row ≥12 → clamp sample to row 11
	ldy #11
	lda (sky_ptr_l),y
	ldy tmp0
	jsr sky_put
	iny
	jmp .fs_sky_test

; A = sky colour, Y = FB row — colour from map, brightest floor dither UDG
sky_put
	sta (col_base_l),y
	lda #FLOOR_PAT_BASE
	sta (pat_base_l),y
	rts

; col_base = FRAMEBUFFER + col * 25; pat_base = LIGHTFRAME + col * 25
; (LIGHTFRAME hi = FRAMEBUFFER hi + 4)
set_col_base
	ldy col
	lda colbaselo,y
	sta col_base_l
	sta pat_base_l
	lda colbasehi,y
	sta col_base_h
	clc
	adc #4
	sta pat_base_h
	rts

; sky_ptr = sky_cols + ((sky_col_base+col) mod 40) * 12
; sky_col_base=(playera*5/8) mod 40 is hoisted into rebuild_col_rays.
; *12 is 16-bit (8-bit mul broke sky_col ≥ 22). Clobbers tmp0–tmp2.
set_sky_ptr
	lda sky_col_base
	clc
	adc col
	cmp #40
	bcc .ssp_col
	sbc #40
.ssp_col
	tax				; sky_col 0..39
	lda #0
	sta tmp1
	txa
	asl
	rol tmp1
	asl
	rol tmp1
	asl
	rol tmp1			; *8 → A/tmp1
	sta tmp0
	lda tmp1
	sta tmp2			; *8 hi
	lda #0
	sta tmp1
	txa
	asl
	rol tmp1
	asl
	rol tmp1			; *4 → A/tmp1
	clc
	adc tmp0
	sta tmp0			; *12 lo
	lda tmp1
	adc tmp2
	sta tmp1			; *12 hi
	clc
	lda tmp0
	adc #<sky_cols
	sta sky_ptr_l
	lda tmp1
	adc #>sky_cols
	sta sky_ptr_h
	rts

; wall_pat / fill_pat from SEC_WDARK[cur] + min(15, wallz_h).
; SEC_WDARK $FF = full bright (pattern 0, ignore wallz). Inlined at on_cell .edge.
; bright_to_wdark: SEC_BRIGHT 0..15 → darken 15..0; 16 → $FF
bright_to_wdark
	!byte 15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0
	!byte $ff

; build_sec_wdark — SEC_WDARK[id] from SEC_BRIGHT (level load)
build_sec_wdark
	lda #0
	sta SEC_WDARK			; void
	lda level_sector_max
	beq .bw_done
	ldx #1
.bw_l
	lda SEC_BRIGHT,x
	tay
	lda bright_to_wdark,y
	sta SEC_WDARK,x
	cpx level_sector_max
	bcs .bw_done
	inx
	bne .bw_l
.bw_done
	rts

; SEC_BRIGHT 0..16 → floor pattern (FLOOR_PAT_BASE + darken; 16 → base)
bright_to_fpat
	!byte FLOOR_PAT_BASE+15, FLOOR_PAT_BASE+14, FLOOR_PAT_BASE+13, FLOOR_PAT_BASE+12
	!byte FLOOR_PAT_BASE+11, FLOOR_PAT_BASE+10, FLOOR_PAT_BASE+9, FLOOR_PAT_BASE+8
	!byte FLOOR_PAT_BASE+7, FLOOR_PAT_BASE+6, FLOOR_PAT_BASE+5, FLOOR_PAT_BASE+4
	!byte FLOOR_PAT_BASE+3, FLOOR_PAT_BASE+2, FLOOR_PAT_BASE+1, FLOOR_PAT_BASE
	!byte FLOOR_PAT_BASE

; pat_clamp[i] = min(15, i) for i = 0..30 (max depth15 + darken15)
pat_clamp
	!byte 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
	!byte 15,15,15,15,15,15,15,15,15,15,15,15,15,15,15

; Deathchase GetRandom8 — new = 9 * old + 193
GetRandom8
	lda random8
	asl
	asl
	asl
	clc
	adc random8
	clc
	adc #193
	sta random8
	rts

; From Stephen Judd's Fridge rand1.s (Deathchase); new = 5 * old + $3611
; Clobber: A, tmp0. Result in random / random+1.
GetRandom16
	lda random + 1
	sta tmp0
	lda random
	asl
	rol tmp0
	asl
	rol tmp0
	clc
	adc random
	pha
	lda tmp0
	adc random + 1
	sta random + 1
	pla
	clc				; kweepa fix vs Judd
	adc #$11
	sta random
	lda random + 1
	adc #$36
	sta random + 1
	rts

random	!word $a3b7			; 16-bit LCG state

; ------------------------------------------------------------------
; Passive sector specials (damage floor / flash lights) — sim tick, low mem
; FLASH_MAX = 2 registered at level load; SEC_BRIGHT + SEC_WDARK toggled in place.
; ------------------------------------------------------------------
FLASH_MAX = 2
FLASH_PERIOD_MS = 1000
DAMAGE_PERIOD_MS = 1000
DAMAGE_PER_TICK = 5
RADSUIT_MS = 60000
RADSUIT_WARN_MS = 5000

; flash_* / dmg_ms / radsuit_ms — under-stack scrap (zeropage.asm)

; Scan sectors for ACT_FLASH_LIGHTS → flash_sec/base (max 2). Call at level start.
flash_lights_init
	lda #0
	sta flash_sec
	sta flash_sec + 1
	sta flash_base
	sta flash_base + 1
	sta flash_lit
	sta flash_ms
	sta flash_ms + 1
	sta dmg_ms
	sta dmg_ms + 1
	sta radsuit_ms
	sta radsuit_ms + 1
	ldy #0				; slot
	ldx #1
.fli_l
	jsr sec_action
	cmp #ACT_FLASH_LIGHTS
	bne .fli_n
	cpy #FLASH_MAX
	bcs .fli_n
	txa
	sta flash_sec,y
	lda SEC_BRIGHT,x
	sta flash_base,y
	iny
.fli_n
	cpx level_sector_max
	bcs .fli_done
	inx
	bne .fli_l
.fli_done
	rts

; Per-frame: damage if standing on ACT_DAMAGE_FLOOR; toggle flash lights.
; Sector id from player_prev_sec (try_walk_into already resolved it this frame).
sector_specials_update
	; --- damage ---
	lda player_prev_sec
	beq .ssu_dmg_clr
	tax
	jsr sec_action
	cmp #ACT_DAMAGE_FLOOR
	bne .ssu_dmg_clr
	lda radsuit_ms
	ora radsuit_ms + 1
	bne .ssu_dmg_clr			; suit: ignore sludge
	lda dmg_ms
	clc
	adc dt_ms
	sta dmg_ms
	lda dmg_ms + 1
	adc #0
	sta dmg_ms + 1
	cmp #>DAMAGE_PERIOD_MS
	bcc .ssu_flash
	bne .ssu_dmg_fire
	lda dmg_ms
	cmp #<DAMAGE_PERIOD_MS
	bcc .ssu_flash
.ssu_dmg_fire
	lda dmg_ms
	sbc #<DAMAGE_PERIOD_MS
	sta dmg_ms
	lda dmg_ms + 1
	sbc #>DAMAGE_PERIOD_MS
	sta dmg_ms + 1
	lda #DAMAGE_PER_TICK
	jsr damage_player
	jmp .ssu_flash
.ssu_dmg_clr
	lda #0
	sta dmg_ms
	sta dmg_ms + 1
.ssu_flash
	lda flash_sec
	ora flash_sec + 1
	beq .ssu_rts				; none registered
	lda flash_ms
	clc
	adc dt_ms
	sta flash_ms
	lda flash_ms + 1
	adc #0
	sta flash_ms + 1
	cmp #>FLASH_PERIOD_MS
	bcc .ssu_rts
	bne .ssu_flash_fire
	lda flash_ms
	cmp #<FLASH_PERIOD_MS
	bcc .ssu_rts
.ssu_flash_fire
	lda flash_ms
	sbc #<FLASH_PERIOD_MS
	sta flash_ms
	lda flash_ms + 1
	sbc #>FLASH_PERIOD_MS
	sta flash_ms + 1
	lda flash_lit
	eor #1
	sta flash_lit
	ldx #0
.ssu_fa
	ldy flash_sec,x
	beq .ssu_fn
	lda flash_lit
	bne .ssu_fhi
	lda flash_base,x
	jmp .ssu_fset
.ssu_fhi
	lda #16
.ssu_fset
	sta SEC_BRIGHT,y
	stx tmp0				; flash slot; Y = sector
	tax
	lda bright_to_wdark,x
	sta SEC_WDARK,y
	ldx tmp0
.ssu_fn
	inx
	cpx #FLASH_MAX
	bcc .ssu_fa
.ssu_rts
	rts

; ------------------------------------------------------------------
; closet_activate — tmp1 = sector; raise floor+ceil by CLOSET_RAISE
; Two RAISE procs after one busy check. No reclose / no height clamp.
; (In low — mid is tight.)
; ------------------------------------------------------------------
CLOSET_RAISE = 6

closet_activate
	jsr proc_sector_busy
	bcc .ca_free
	rts
.ca_free
	jsr proc_count_free
	cmp #2
	bcs .ca_slots
	rts
.ca_slots
	ldx tmp1
	lda SEC_FLOOR,x
	clc
	adc #CLOSET_RAISE
	sta tmp2
	lda #PROC_RAISE_FLOOR
	sta tmp0
	lda #0
	sta tmp3
	sta tmp4
	jsr proc_alloc
	bcs .ca_fail
	ldx tmp1
	lda SEC_CEIL,x
	clc
	adc #CLOSET_RAISE
	sta tmp2
	lda #PROC_RAISE_CEIL
	sta tmp0
	lda #0
	sta tmp3
	sta tmp4
	jsr proc_alloc
	bcs .ca_fail
	lda #SOUND_STNMOV
	jmp play_sound
.ca_fail
	rts

; ------------------------------------------------------------------
; radsuit_tick — subtract dt_ms from radsuit_ms (clamp at 0)
; ------------------------------------------------------------------
radsuit_tick
	lda radsuit_ms
	ora radsuit_ms + 1
	beq .rst_rts
	lda radsuit_ms
	sec
	sbc dt_ms
	sta radsuit_ms
	lda radsuit_ms + 1
	sbc #0
	sta radsuit_ms + 1
	bcs .rst_rts
	lda #0
	sta radsuit_ms
	sta radsuit_ms + 1
.rst_rts
	rts

; ------------------------------------------------------------------
; radsuit_set_border — green while active; green/black flash in last 5s
; Caller must not call when hurt_flash is showing red.
; ------------------------------------------------------------------
radsuit_set_border
	lda radsuit_ms
	ora radsuit_ms + 1
	beq .rsb_black
	lda radsuit_ms + 1
	cmp #>RADSUIT_WARN_MS
	bcc .rsb_flash
	bne .rsb_green
	lda radsuit_ms
	cmp #<RADSUIT_WARN_MS
	bcc .rsb_flash
.rsb_green
	jsr io_push
	lda #5				; green
	sta $d020
	jmp io_pop
.rsb_flash
	lda radsuit_ms + 1
	lsr				; ~512 ms phase
	bcc .rsb_black
	jsr io_push
	lda #5
	sta $d020
	jmp io_pop
.rsb_black
	jsr io_push
	lda #0
	sta $d020
	jmp io_pop

; Locked-door key messages (moved from pickup — mid headroom)
door_msg_lo
	!byte <msg_need_red, <msg_need_yellow, <msg_need_blue
door_msg_hi
	!byte >msg_need_red, >msg_need_yellow, >msg_need_blue
door_msg_len
	!byte 36, 39, 37			; screen columns (no trailing NUL)
msg_need_red
	!scr "you need a red key to open this door"
	!byte 0
msg_need_yellow
	!scr "you need a yellow key to open this door"
	!byte 0
msg_need_blue
	!scr "you need a blue key to open this door"
	!byte 0
