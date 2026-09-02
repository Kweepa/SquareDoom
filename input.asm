!zone input

; CIA1 keys (sampled by Timer A IRQ ~every SAMPLE_MS binary-ms):
;   J = turn left (PA4/PB2), L = turn right (PA5/PB2)
;   K = use (PA4/PB5) — open door
;   SPACE = fire (PA7/PB4); F1 = map (PA0/PB4)
;   W/A/S = PA1 column; D = PA2 column; 3 = shotgun (PA1/PB0)
;   2 = pistol (PA7/PB3); 4 = minigun (PA1/PB3); 5 = rocket (PA2/PB0)
;   W forward, S back, A strafe left, D strafe right
; Facing matches editor: forward = (sin θ, −cos θ)
; 1351 Port 1: POTX sampled at TA IRQ entry (mux parked $7F); LMB = FIRE (PB4).
; Yaw delta accumulates in mouse_turn; gameloop applies it once before render.
; LMB pulls PB4 on every column, so F1 is ignored when SPACE-column PB4 is down.
;
; Why SPACE / F1 (C64 matrix ghosting):
;   The keyboard is an undioded 8×8 matrix. Three corners of a rectangle
;   make the fourth read as pressed. Typical chord W+A+J sits at
;   PA1/PB1, PA1/PB2, PA4/PB2 — so PA4/PB1 (I) ghosts; W+A+L ghosts P.
;   Old fire-on-I therefore shot while strafing left and turning.
;   SPACE (PA7/PB4) is outside that 2×2, so W+(A|D)+(J|L) and W+K do
;   not invent fire. F1 (PA0/PB4) is likewise outside those chords and
;   physically away from JKL (M fat-fingered next to turn/use).
;   (SPACE and F1 share PB4 on different PA rows — both still readable.)
;
; IRQ accumulates hold times into in_*; read_input snapshots under SEI and
; scales turn/wish by those times (not full-frame dt_ms):
;   turn 90°/sec = 64 angle/sec → turn_acc += vel_ms<<6, deliver >>10
;   move 1 tile/sec = 8 world/sec → delta_8_8 = (sintab * vel_ms) >> 5
; sintab AMP=64; identity: sin=64, dt=1024 → 2048 = 8.0 world.
;
; Use/fire/map: OR-latch if held on any sample this frame.
;
; CIA1 Timer B runs separately at ~140 Hz for PC speaker SFX (update_sfx).
; Music play skipped (no SID on level PRG).

SAMPLE_MS = 20
; Timer A load = SAMPLE_MS * 1024 - 1 (binary-ms, φ2 ticks) → 50 Hz
SAMPLE_TA_LO = <$4FFF
SAMPLE_TA_HI = >$4FFF
; Timer B: ~140 Hz PC speaker step (7 binary-ms)
SFX_TB_LO = <$1BFF
SFX_TB_HI = >$1BFF

; No SID on the level PRG (map owns $9000)
MUSIC_INIT
MUSIC_PLAY
	rts

; Menus set this so Timer A skips $dc00 (ui_read_keys); music + TB SFX still run
; input_paused…key_wpn_* — cassette scrap BSS (zeropage.asm)

; ------------------------------------------------------------------
; input_irq_init — CIA1 TA @ SAMPLE_MS (keys+music), TB @ ~140 Hz (SFX)
; ------------------------------------------------------------------
input_irq_init
	lda #0
	sta in_turn_l
	sta in_turn_r
	sta in_fwd
	sta in_back
	sta in_strafel
	sta in_strafer
	sta in_use
	sta in_fire
	sta in_map
	sta in_wpn_fist
	sta in_wpn_pistol
	sta in_wpn_shotgun
	sta in_wpn_minigun
	sta in_wpn_rocket
	sta input_paused
	sta key_map_was
	sta music_tick
	sta io_depth
	sta mouse_turn
	; music_enabled preserved across re-init (LoadPrg path)
	; mouse_en preserved (menu Options; level loads re-call this)
	sta $d01a				; no VIC IRQs

	lda #$7f
	sta $dc00				; park Port 1 paddle mux
	lda $d419				; seed so first IRQ delta is 0 ($01=$35)
	sta mouse_x

	lda #$7f
	sta $dc0d				; clear CIA1 IRQ enables
	lda $dc0d				; ack
	lda #SAMPLE_TA_LO
	sta $dc04
	lda #SAMPLE_TA_HI
	sta $dc05
	lda #SFX_TB_LO
	sta $dc06
	lda #SFX_TB_HI
	sta $dc07
	lda #<input_irq
	sta $fffe
	lda #>input_irq
	sta $ffff
	; KERNAL out ($01=$34/$35): own NMI in RAM (do not JMP into ROM $FE43).
	; Also fill soft NMI ($0318) so a stray JMP ($0318) is safe — music
	; shadows live at $02f8/$02f9, not on the vector page.
	lda #<nmi_stub
	sta $fffa
	sta $0318
	lda #>nmi_stub
	sta $fffb
	sta $0319
	lda #$83				; set + enable Timer A + Timer B IRQ
	sta $dc0d
	lda #$11				; start + force load, continuous φ2
	sta $dc0e				; Timer A
	sta $dc0f				; Timer B
	rts

; Minimal KERNAL-NMI equivalent with KERNAL banked out. Disable then ack:
; FLAG held low re-latches on ICR read if the enable bit is still set, which
; storms NMI and never returns from init_weapon. (ROM $FE43 JMPs into ROM.)
nmi_stub
	pha
	lda $01
	pha
	lda #$35
	sta $01
	lda #$7f
	sta $dd0d
	sta $dc0d
	lda $dd0d				; ack CIA2
	lda $dc0d
	pla
	sta $01
	pla
	rti

; Until input_irq_init writes $FFFE. SEI should mask IRQ; this is if I is clear.
irq_rti_stub
	pha
	lda $01
	pha
	lda #$35
	sta $01
	lda $dc0d
	lda #$ff
	sta $d019
	pla
	sta $01
	pla
	rti

; ------------------------------------------------------------------
; input_irq — TB → SFX; TA → music (every other) + sfx_restore_voice3 + keys.
; No main-thread tmp* (IRQ scratch only).
; ------------------------------------------------------------------
input_irq
	pha
	txa
	pha
	tya
	pha
	lda $01
	pha
	lda #$35
	sta $01

	lda $dc0d				; ack + source (bit0=TA, bit1=TB)
	sta irq_ifr
	and #$02
	beq .irq_check_ta
	jsr update_sfx
.irq_check_ta
	lda irq_ifr
	and #$01
	bne .irq_ta
	jmp .irq_rti				; TB-only: leave mux parked
.irq_ta
	; Sample SID POTX before anything below touches $DC00. CIA1 PA6/PA7
	; switch the paddle mux; the previous TA / ui_read_keys parked $7F
	; for a whole sample period, so this reading is settled.
	lda $d419
	tax
	lda input_paused
	beq .irq_mouse_chk
	stx mouse_x				; keep baseline so unpause does not snap
	jmp .irq_park
.irq_mouse_chk
	lda mouse_en
	beq .irq_keys
	; 1351 POTX wrap-delta. |dx|<=2 noise; |dx|>=33 = wrap (keep mouse_x, no look)
	txa
	sec
	sbc mouse_x
	stx mouse_x
	tay
	bpl .irq_mpos
	cpy #$fe
	bcs .irq_keys
	cpy #$e0
	bcc .irq_keys
	tya
	bcs .irq_mdx
.irq_mpos
	cpy #3
	bcc .irq_keys
	cpy #33
	bcs .irq_keys
	tya
.irq_mdx
	cmp #$80				; signed /2 into mouse_turn (applied once/frame)
	ror
	clc
	adc mouse_turn
	sta mouse_turn

.irq_keys

	; J / K (PA4 = $EF)
	lda #$ef
	sta $dc00
	lda $dc01
	tax
	and #$04
	bne .irq_noj
	lda in_turn_l
	jsr .irq_add_ms
	sta in_turn_l
.irq_noj
	txa
	and #$20
	bne .irq_nok
	lda #1
	sta in_use
.irq_nok

	; L (PA5 = $DF)
	lda #$df
	sta $dc00
	lda $dc01
	and #$04
	bne .irq_nol
	lda in_turn_r
	jsr .irq_add_ms
	sta in_turn_r
.irq_nol

	; W / A / S / 3 / 4 (PA1 = $FD)
	lda #$fd
	sta $dc00
	lda $dc01
	tax
	and #$02
	bne .irq_now
	lda in_fwd
	jsr .irq_add_ms
	sta in_fwd
.irq_now
	txa
	and #$04
	bne .irq_noa
	lda in_strafel
	jsr .irq_add_ms
	sta in_strafel
.irq_noa
	txa
	and #$20
	bne .irq_nos
	lda in_back
	jsr .irq_add_ms
	sta in_back
.irq_nos
	txa
	and #$01
	bne .irq_no3
	lda #1
	sta in_wpn_shotgun
.irq_no3
	txa
	and #$08				; 4 = minigun
	bne .irq_no4
	lda #1
	sta in_wpn_minigun
.irq_no4

	; D / 5 (PA2 = $FB)
	lda #$fb
	sta $dc00
	lda $dc01
	tax
	and #$04
	bne .irq_nod
	lda in_strafer
	jsr .irq_add_ms
	sta in_strafer
.irq_nod
	txa
	and #$01				; 5 = rocket
	bne .irq_no5
	lda #1
	sta in_wpn_rocket
.irq_no5

	; 2 / SPACE / 1 (PA7 = $7F)
	lda #$7f
	sta $dc00
	lda $dc01
	tax
	and #$08
	bne .irq_no2
	lda #1
	sta in_wpn_pistol
.irq_no2
	txa
	and #$01				; 1 = fist/chainsaw
	bne .irq_no1
	lda #1
	sta in_wpn_fist
.irq_no1
	txa
	and #$10				; SPACE / 1351 LMB (PB4)
	bne .irq_nospc
	lda #1
	sta in_fire
.irq_nospc

	; F1 (PA0 = $FE, PB4) = map
	; 1351 LMB pulls PB4 on every column — skip if SPACE column also saw PB4
	lda #$fe
	sta $dc00
	lda $dc01
	and #$10
	bne .irq_nof1
	txa
	and #$10
	beq .irq_nof1				; LMB or SPACE: not a real F1
	lda #1
	sta in_map
.irq_nof1

	jsr update_weapon_irq
	lda health
	beq .irq_park
	jsr check_cheats

.irq_park
	lda #$7f
	sta $dc00				; mux parked for next TA POTX sample
.irq_rti
	pla
	sta $01
	pla
	tay
	pla
	tax
	pla
	rti

; A = counter → A = min(A + SAMPLE_MS, 255)
.irq_add_ms
	clc
	adc #SAMPLE_MS
	bcc .irq_add_ok
	lda #255
.irq_add_ok
	rts

; ------------------------------------------------------------------
; read_input — snapshot IRQ accumulators; build turn + wish from hold ms
; ------------------------------------------------------------------
read_input
	lda #0
	sta turn
	sta wish_x_l
	sta wish_x_h
	sta wish_y_l
	sta wish_y_h

	sei
	lda in_use
	sta key_use
	lda in_fire
	sta key_fire
	lda in_map
	sta key_map
	lda in_wpn_fist
	sta key_wpn_fist
	lda in_wpn_pistol
	sta key_wpn_pistol
	lda in_wpn_shotgun
	sta key_wpn_shotgun
	lda in_wpn_minigun
	sta key_wpn_minigun
	lda in_wpn_rocket
	sta key_wpn_rocket
	lda in_turn_l
	sta tmp3
	lda in_turn_r
	sta tmp4
	lda in_fwd
	pha
	lda in_back
	pha
	lda in_strafel
	pha
	lda in_strafer
	pha
	lda #0
	sta in_turn_l
	sta in_turn_r
	sta in_fwd
	sta in_back
	sta in_strafel
	sta in_strafer
	sta in_use
	sta in_fire
	sta in_map
	sta in_wpn_fist
	sta in_wpn_pistol
	sta in_wpn_shotgun
	sta in_wpn_minigun
	sta in_wpn_rocket
	cli

	; --- weapon select: 1=fist/saw toggle 2=pistol 3=shotgun 4=minigun 5=rocket ---
	lda key_wpn_fist
	beq .no_wpn1
	lda cur_weapon
	cmp #0
	bne .w1_not_fist
	; on fist → chainsaw if owned
	lda owned_weapons
	and #$01
	beq .no_wpn1
	ldx #1
	jsr switch_weapon
	jmp .no_wpn1
.w1_not_fist
	cmp #1
	bne .w1_other
	; on chainsaw → fist
	ldx #0
	jsr switch_weapon
	jmp .no_wpn1
.w1_other
	; other gun → chainsaw if owned else fist
	lda owned_weapons
	and #$01
	beq .w1_fist
	ldx #1
	jsr switch_weapon
	jmp .no_wpn1
.w1_fist
	ldx #0
	jsr switch_weapon
.no_wpn1
	lda key_wpn_pistol
	beq .no_wpn2
	ldx #2
	jsr switch_weapon
.no_wpn2
	lda key_wpn_shotgun
	beq .no_wpn3
	ldx #3
	jsr switch_weapon
.no_wpn3
	lda key_wpn_minigun
	beq .no_wpn4
	ldx #4
	jsr switch_weapon
.no_wpn4
	lda key_wpn_rocket
	beq .no_wpn5
	ldx #5
	jsr switch_weapon
.no_wpn5

	; --- turn: net hold ms (right − left) ---
	lda tmp4
	cmp tmp3
	beq .turn_done
	bcs .turn_right
	; left wins: vel = left − right
	lda tmp3
	sec
	sbc tmp4
	sta vel_ms
	jsr turn_deliver
	eor #$ff
	clc
	adc #1
	sta turn
	jmp .turn_done
.turn_right
	lda tmp4
	sec
	sbc tmp3
	sta vel_ms
	jsr turn_deliver
	sta turn
.turn_done

	; stack: strafer, strafel, back, fwd (top = strafer)
	pla					; strafer
	beq .no_d
	sta vel_ms
	ldy playera
	lda costab,y
	jsr wish_add_x
	ldy playera
	lda sintab,y
	jsr wish_add_y
.no_d
	pla					; strafel
	beq .no_a
	sta vel_ms
	ldy playera
	lda costab,y
	jsr neg_a
	jsr wish_add_x
	ldy playera
	lda sintab,y
	jsr neg_a
	jsr wish_add_y
.no_a
	pla					; back
	beq .no_s
	sta vel_ms
	ldy playera
	lda sintab,y
	jsr neg_a
	jsr wish_add_x
	ldy playera
	lda costab,y
	jsr wish_add_y
.no_s
	pla					; fwd
	beq .no_w
	sta vel_ms
	ldy playera
	lda sintab,y
	jsr wish_add_x
	ldy playera
	lda costab,y
	jsr neg_a
	jsr wish_add_y
.no_w
	rts

; turn_acc += vel_ms<<6; A = turn_acc>>10; turn_acc &= $03FF
turn_deliver
	lda vel_ms
	tax
	lsr
	lsr
	sta tmp1				; hi = vel>>2
	txa
	and #3
	asl
	asl
	asl
	asl
	asl
	asl
	sta tmp0				; lo = (vel&3)<<6 = vel*64 lo
	clc
	lda turn_acc_l
	adc tmp0
	sta turn_acc_l
	lda turn_acc_h
	adc tmp1
	sta turn_acc_h
	tay					; delivered hi before mask
	and #3
	sta turn_acc_h
	tya
	lsr
	lsr					; A = delivered = acc>>10
	rts

; A = signed sintab → scale (A * vel_ms) >> 5 → add into wish_x
wish_add_x
	jsr scale_vel
	clc
	lda wish_x_l
	adc tmp0
	sta wish_x_l
	lda wish_x_h
	adc tmp1
	sta wish_x_h
	rts

; A = signed sintab → add scaled into wish_y
wish_add_y
	jsr scale_vel
	clc
	lda wish_y_l
	adc tmp0
	sta wish_y_l
	lda wish_y_h
	adc tmp1
	sta wish_y_h
	rts

; A = signed unit → tmp0/tmp1 = (A * vel_ms) >>> 5 (arithmetic)
scale_vel
	sta tmp2
	bpl .sv_abs
	eor #$ff
	clc
	adc #1
.sv_abs
	tay
	lda vel_ms
	jsr mul_8x8				; X=lo A=hi
	sta tmp1
	stx tmp0
	; unsigned >>5 via <<3 take high 16 of 24-bit
	lda #0
	sta tmp3
	asl tmp0
	rol tmp1
	rol tmp3
	asl tmp0
	rol tmp1
	rol tmp3
	asl tmp0
	rol tmp1
	rol tmp3
	lda tmp1
	sta tmp0
	lda tmp3
	sta tmp1
	lda tmp2
	bpl .sv_done
	sec
	lda #0
	sbc tmp0
	sta tmp0
	lda #0
	sbc tmp1
	sta tmp1
.sv_done
	rts

neg_a
	eor #$ff
	clc
	adc #1
	rts

; Apply wish 8.8; push 1 unit from blocking faces (slide); axis fallback
; Blocking = void/OOB, headroom < 4, step-up > 2, or portal opening < 4.
apply_move
	lda wish_x_l
	ora wish_x_h
	ora wish_y_l
	ora wish_y_h
	bne .am_go
	rts
.am_go
	lda playerx
	sta save_xl
	lda playerx_h
	sta save_xh
	lda playery
	sta save_yl
	lda playery_h
	sta save_yh

	jsr player_tile
	jsr map_sector_id
	beq .am_void_fl
	tax
	lda SEC_FLOOR,x
	sta old_floor
	lda SEC_CEIL,x
	sta old_ceil
	jmp .am_have_fl
.am_void_fl
	lda #0
	sta old_floor
	sta old_ceil
.am_have_fl
	clc
	lda playerx
	adc wish_x_l
	sta playerx
	lda playerx_h
	adc wish_x_h
	sta playerx_h
	clc
	lda playery
	adc wish_y_l
	sta playery
	lda playery_h
	adc wish_y_h
	sta playery_h

	; Wish consumed — reuse wish_* as post-wish XY for axis fallback
	lda playerx
	sta wish_x_l
	lda playerx_h
	sta wish_x_h
	lda playery
	sta wish_y_l
	lda playery_h
	sta wish_y_h

	jsr push_walls
	jsr standing_blocked
	bcc .am_ok

	; X-new + Y-old
	lda wish_x_l
	sta playerx
	lda wish_x_h
	sta playerx_h
	lda save_yl
	sta playery
	lda save_yh
	sta playery_h
	jsr push_walls
	jsr standing_blocked
	bcc .am_ok

	; X-old + Y-new
	lda save_xl
	sta playerx
	lda save_xh
	sta playerx_h
	lda wish_y_l
	sta playery
	lda wish_y_h
	sta playery_h
	jsr push_walls
	jsr standing_blocked
	bcc .am_ok

	lda save_xl
	sta playerx
	lda save_xh
	sta playerx_h
	lda save_yl
	sta playery
	lda save_yh
	sta playery_h
.am_ok
	rts

; A = sector id → C=1 blocked, C=0 walkable (vs old_floor / old_ceil)
tile_blocked
	beq .tb_yes
	tax
	jsr sec_action
	cmp #ACT_WINDOW
	beq .tb_yes			; window: bodies stop, shots pass
	lda SEC_CEIL,x
	sec
	sbc SEC_FLOOR,x
	cmp #4
	bcc .tb_yes
	lda SEC_FLOOR,x
	cmp old_floor
	bcc .tb_portal
	beq .tb_portal
	sec
	sbc old_floor
	cmp #3
	bcs .tb_yes
.tb_portal
	; opening = min(old_ceil, dest_ceil) - max(old_floor, dest_floor)
	lda old_floor
	cmp SEC_FLOOR,x
	bcs .tb_maxf
	lda SEC_FLOOR,x
.tb_maxf
	sta tmp3				; max floor (tmp0/1 live in p_try_move)
	lda old_ceil
	cmp SEC_CEIL,x
	bcc .tb_minc
	lda SEC_CEIL,x
.tb_minc
	sec
	sbc tmp3				; min ceil - max floor
	bcc .tb_yes			; negative opening (ceil below floor) → solid
	cmp #4
	bcc .tb_yes
.tb_no
	clc
	rts
.tb_yes
	sec
	rts

; mapx/mapy → A = sector id; OOB → 0
sector_at_map
	lda mapx
	ora mapy
	and #$e0				; MAP_SIZE=32: either ≥32 → OOB
	bne .sam_oob
	jmp map_sector_id
.sam_oob
	lda #0
	rts

; C=1 if player tile blocking
standing_blocked
	jsr player_tile
	jsr sector_at_map
	jmp tile_blocked

; Push player 1 world unit away from each adjacent blocking face
push_walls
	jsr player_tile
	lda mapx
	sta tmp4
	lda mapy
	sta tmp5

	; West: neighbor (mapx-1, mapy)
	lda tmp4
	sec
	sbc #1
	sta mapx
	lda tmp5
	sta mapy
	jsr sector_at_map
	jsr tile_blocked
	bcc .pw_east
	lda playerx_h
	and #7
	bne .pw_east			; local_x >= 1.0
	lda tmp4
	asl
	asl
	asl
	ora #1
	sta playerx_h
	lda #0
	sta playerx

.pw_east
	lda tmp4
	clc
	adc #1
	sta mapx
	lda tmp5
	sta mapy
	jsr sector_at_map
	jsr tile_blocked
	bcc .pw_north
	lda playerx_h
	and #7
	cmp #7
	bne .pw_north
	lda playerx
	beq .pw_north			; local_x == 7.0 exactly
	lda tmp4
	asl
	asl
	asl
	ora #7
	sta playerx_h
	lda #0
	sta playerx

.pw_north
	; map Y−1 (smaller playery)
	lda tmp4
	sta mapx
	lda tmp5
	sec
	sbc #1
	sta mapy
	jsr sector_at_map
	jsr tile_blocked
	bcc .pw_south
	lda playery_h
	and #7
	bne .pw_south
	lda tmp5
	asl
	asl
	asl
	ora #1
	sta playery_h
	lda #0
	sta playery

.pw_south
	lda tmp4
	sta mapx
	lda tmp5
	clc
	adc #1
	sta mapy
	jsr sector_at_map
	jsr tile_blocked
	bcc .pw_done
	lda playery_h
	and #7
	cmp #7
	bne .pw_done
	lda playery
	beq .pw_done
	lda tmp5
	asl
	asl
	asl
	ora #7
	sta playery_h
	lda #0
	sta playery
.pw_done
	rts

; ------------------------------------------------------------------
; UI keys (menus / pause) — direct CIA1 sample, edge in ui_pressed
; Bits: UP=1 DOWN=2 LEFT=4 RIGHT=8 SELECT=16 ESC=32 MAP=64
; ------------------------------------------------------------------
UI_UP = 1
UI_DOWN = 2
UI_LEFT = 4
UI_RIGHT = 8
UI_SELECT = 16
UI_ESC = 32
UI_MAP = 64

; ui_keys / ui_old / ui_pressed — cassette scrap BSS (zeropage.asm)

; ui_read_keys — set ui_keys / ui_pressed (new presses this call)
ui_read_keys
	sei
	jsr io_push
	lda ui_keys
	sta ui_old
	lda #0
	sta ui_keys

	; W / A / S (PA1 = $FD)
	lda #$fd
	sta $dc00
	lda $dc01
	tax
	and #$02				; W
	bne .urk_now
	lda ui_keys
	ora #UI_UP
	sta ui_keys
.urk_now
	txa
	and #$20				; S
	bne .urk_nos
	lda ui_keys
	ora #UI_DOWN
	sta ui_keys
.urk_nos
	txa
	and #$04				; A
	bne .urk_noa
	lda ui_keys
	ora #UI_LEFT
	sta ui_keys
.urk_noa

	; D (PA2 = $FB)
	lda #$fb
	sta $dc00
	lda $dc01
	and #$04
	bne .urk_nod
	lda ui_keys
	ora #UI_RIGHT
	sta ui_keys
.urk_nod

	; RETURN / F1 (PA0 = $FE) — F1 = map
	lda #$fe
	sta $dc00
	lda $dc01
	tax
	and #$02
	bne .urk_noret
	lda ui_keys
	ora #UI_SELECT
	sta ui_keys
.urk_noret
	txa
	and #$10				; F1
	bne .urk_nomap
	lda ui_keys
	ora #UI_MAP
	sta ui_keys
.urk_nomap

	; Run/Stop (PA7 = $7F, PB7)
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
	jsr io_pop
	cli
	rts

; C=1 if bit A set in ui_pressed
ui_pressed_bit
	and ui_pressed
	beq .upb_no
	sec
	rts
.upb_no
	clc
	rts

; Wait until ESC (Run/Stop) released
ui_wait_esc_up
	jsr ui_read_keys
	lda ui_keys
	and #UI_ESC
	bne ui_wait_esc_up
	rts

; Wait until F1 (map) released
ui_wait_map_up
	jsr ui_read_keys
	lda ui_keys
	and #UI_MAP
	bne ui_wait_map_up
	rts
