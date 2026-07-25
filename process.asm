!zone process

; SoA thinkers: TIMER, RAISE/LOWER_CEIL, RAISE/LOWER_FLOOR.
; Sector specials: packed SEC_TYPE (trigger | single_shot | action).
; K-use: NESW neighbour with trigger=use.
; Walk: enter sector with trigger=walk_into.
; Switch: nearby switch item → sector under it with trigger=switch.
; Absolute JMPs used where relative branches would exceed ±127.

DOOR_OPEN_GAP = 5
DOOR_RECLOSE_5S_MS = 5000
DOOR_RECLOSE_10S_MS = 10000
DOOR_RECLOSE_30S_MS = 30000
; elev_mode when calling door_open_activate:
DOOR_MODE_FOREVER = 0
DOOR_MODE_5S = 1
DOOR_MODE_10S = 2
DOOR_MODE_30S = 3
MOTION_STEP_MS = 128			; 1 height unit per 128 ms
ITEM_TYPE_SWITCH = 21
SWITCH_USE_RADIUS = 6

player_prev_sec	!byte 0			; last player sector (walk trigger)
elev_mode	!byte 0			; floor: 0=lower/1=raise; door: DOOR_MODE_*
elev_remote	!byte 0			; 0 = K-use (local), 1 = walk target (remote)
elev_found	!byte 0
elev_home	!byte 0			; elevator return floor (scratch)
elev_cell_x	!byte 0
elev_cell_y	!byte 0
trig_sec	!byte 0			; sector that provided the trigger
trig_chain	!byte 0			; remote SEC_TARGET walk cursor
key_use_was	!byte 0			; previous-frame key_use (rising edge)

ELEV_RECLOSE_REMOTE_MS = 15000
ELEV_RECLOSE_LOCAL_MS = 5000

; Clear all process slots
proc_init
	ldx #0
	lda #PROC_FREE
.pi
	sta PROC_KIND,x
	inx
	cpx #PROC_NUM
	bne .pi
	rts

; Find free slot → C=0 Y=index; C=1 none
proc_find_free
	ldy #0
.pff
	lda PROC_KIND,y
	beq .pff_ok
	iny
	cpy #PROC_NUM
	bne .pff
	sec
	rts
.pff_ok
	clc
	rts

; Alloc: tmp0=kind tmp1=A tmp2=B tmp3=C tmp4=D → C=0 Y=slot; C=1 fail
; Clears PROC_E (set after alloc for elevator return timers).
proc_alloc
	jsr proc_find_free
	bcs .pa_fail
	lda tmp0
	sta PROC_KIND,y
	lda tmp1
	sta PROC_A,y
	lda tmp2
	sta PROC_B,y
	lda tmp3
	sta PROC_C,y
	lda tmp4
	sta PROC_D,y
	lda #0
	sta PROC_E,y
	clc
.pa_fail
	rts

; C=1 if any live proc has PROC_A == tmp1 (sector)
proc_sector_busy
	ldx #0
.psb
	lda PROC_KIND,x
	beq .psb_next
	lda PROC_A,x
	cmp tmp1
	beq .psb_yes
.psb_next
	inx
	cpx #PROC_NUM
	bne .psb
	clc
	rts
.psb_yes
	sec
	rts

; Count free slots → A
proc_count_free
	ldx #0
	lda #0
	sta tmp0
.pcf
	lda PROC_KIND,x
	bne .pcf_next
	inc tmp0
.pcf_next
	inx
	cpx #PROC_NUM
	bne .pcf
	lda tmp0
	rts

; local axis → tmp0=tile-local hi (0..7), tmp1=frac
.tu_get_x
	lda playerx_h
	and #7
	sta tmp0
	lda playerx
	sta tmp1
	rts

.tu_get_y
	lda playery_h
	and #7
	sta tmp0
	lda playery
	sta tmp1
	rts

; C=1 if local ≤ 4.0 (near low face; half a tile)
.tu_near_lo
	lda tmp0
	cmp #5
	bcs .tnl_no
	cmp #4
	bcc .tnl_yes
	lda tmp1
	bne .tnl_no
.tnl_yes
	sec
	rts
.tnl_no
	clc
	rts

; C=1 if local ≥ 4.0 (near high face at 8; half a tile)
.tu_near_hi
	lda tmp0
	cmp #4
	bcc .tnh_no
	sec
	rts
.tnh_no
	clc
	rts

; NESW facing tables (index = (playera+32)>>6 & 3)
;   0=N 1=E 2=S 3=W
tu_dx
	!byte 0, 1, 0, $ff			; neighbour Δmapx
tu_dy
	!byte $ff, 0, 1, 0			; neighbour Δmapy
tu_axis
	!byte 1, 0, 1, 0			; 0 = X local, 1 = Y local
tu_face
	!byte 0, 1, 1, 0			; 0 = near_lo (≤4), 1 = near_hi (≥4)

; ------------------------------------------------------------------
; sec_trigger / sec_action — X = sector id → A
; ------------------------------------------------------------------
sec_trigger
	lda SEC_TYPE,x
	and #TRIG_MASK
	lsr
	lsr
	lsr
	lsr
	lsr
	rts

sec_action
	lda SEC_TYPE,x
	and #ACT_MASK
	rts

; If SHOT_BIT set on sector X, clear trigger bits (→ TRIG_NONE)
sec_oneshot_if
	lda SEC_TYPE,x
	bpl .soi_r			; bit7 clear → not single-shot
	and #$9f			; clear trigger[6:5]; keep action + shot
	sta SEC_TYPE,x
.soi_r
	rts

; ------------------------------------------------------------------
; try_use — K rising edge: NESW neighbour with trigger=use, within 4u
; ------------------------------------------------------------------
try_use
	lda key_use
	bne .tu_down
	sta key_use_was			; A = 0
.tu_far
	rts
.tu_down
	lda key_use_was
	bne .tu_far			; still held
	lda #1
	sta key_use_was
	jsr player_tile

	; Snap playera to NESW: (a+32)>>6 → 0=N 1=E 2=S 3=W
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
	sta tmp5
	tax

	; local along approach axis
	lda tu_axis,x
	bne .tu_ly
	jsr .tu_get_x
	jmp .tu_near
.tu_ly
	jsr .tu_get_y
.tu_near
	ldx tmp5
	lda tu_face,x
	bne .tu_nh
	jsr .tu_near_lo
	jmp .tu_near_done
.tu_nh
	jsr .tu_near_hi
.tu_near_done
	bcs .tu_near_ok
	jmp .tu_far
.tu_near_ok
	; neighbour cell; any axis overflow (≥ MAP_SIZE, incl. wrap from 0−1) → far
	ldx tmp5
	lda mapx
	clc
	adc tu_dx,x
	sta mapx
	cmp #MAP_SIZE
	bcc .tu_x_ok
	jmp .tu_far
.tu_x_ok
	lda mapy
	clc
	adc tu_dy,x
	sta mapy
	cmp #MAP_SIZE
	bcc .tu_have_cell
	jmp .tu_far

.tu_have_cell
	jsr sector_at_map
	bne .tu_got_id
	jmp .tu_far
.tu_got_id
	sta trig_sec			; trigger sector
	tax
	jsr sec_trigger
	cmp #TRIG_USE
	beq .tu_trig_ok
	jmp .tu_far
.tu_trig_ok
	; floor actions with target → walk-only
	ldx trig_sec
	jsr sec_action
	cmp #ACT_LOWER_FLOOR
	beq .tu_chk_local
	cmp #ACT_LOWER_FLOOR_FOREVER
	beq .tu_chk_local
	cmp #ACT_RAISE_FLOOR
	beq .tu_chk_local
	jmp .tu_go
.tu_chk_local
	ldx trig_sec
	lda SEC_TARGET,x
	beq .tu_go
	jmp .tu_far
.tu_go
	lda #0
	sta elev_remote
	jmp trigger_action

; Door open (tmp1 = door sector; elev_mode = DOOR_MODE_*).
; Key check via SEC_CCOL runs for use, walk-into, and switch alike — fine as
; long as red/yellow/blue doors are never remote (target) activations.
; Timed modes schedule reclose from door_reclose_*.
door_open_activate
	ldx tmp1
	lda SEC_CCOL,x
	ldx #0
.do_keyscan
	cmp door_key_cols,x
	beq .do_keydoor
	inx
	cpx #3
	bcc .do_keyscan
	jmp .do_ok
.do_keydoor
	lda door_key_masks,x
	bit keys
	bne .do_ok
	txa
	jmp door_need_msg
.do_ok
	jsr proc_sector_busy
	bcc .do_free
	rts
.do_free
	lda elev_mode
	bne .do_need2
	jsr proc_count_free
	cmp #1
	bcs .do_slots
	rts
.do_need2
	jsr proc_count_free
	cmp #2
	bcs .do_slots
	rts
.do_slots
	ldx tmp1
	lda SEC_FLOOR,x
	clc
	adc #DOOR_OPEN_GAP
	sta tmp2				; dest ceil
	lda SEC_CEIL,x
	cmp tmp2
	bcc .do_closed
	rts					; already open
.do_closed
	lda #PROC_RAISE_CEIL
	sta tmp0
	lda #0
	sta tmp3
	sta tmp4
	jsr proc_alloc
	bcs .do_fail
	lda #SOUND_DOROPN
	jsr play_sound
	ldx elev_mode
	beq .do_fail			; forever: no reclose timer
	lda #PROC_TIMER
	sta tmp0
	lda #PROC_LOWER_CEIL
	sta tmp2
	lda door_reclose_lo,x
	sta tmp3
	lda door_reclose_hi,x
	sta tmp4
	jmp proc_alloc
.do_fail
	rts

; Index = DOOR_MODE_*; [0] unused (forever)
door_reclose_lo
	!byte 0
	!byte <DOOR_RECLOSE_5S_MS
	!byte <DOOR_RECLOSE_10S_MS
	!byte <DOOR_RECLOSE_30S_MS
door_reclose_hi
	!byte 0
	!byte >DOOR_RECLOSE_5S_MS
	!byte >DOOR_RECLOSE_10S_MS
	!byte >DOOR_RECLOSE_30S_MS

; Ceiling colour → key bit (matches HUD key_masks / SEC_CCOL)
door_key_cols
	!byte 2, 7, 6			; red, yellow, blue
door_key_masks
	!byte $01, $02, $04

; ------------------------------------------------------------------
; try_walk_into — sector change → trigger=walk_into actions
; ------------------------------------------------------------------
try_walk_into
	jsr player_tile
	jsr map_sector_id
	cmp player_prev_sec
	beq .twi_rts
	sta player_prev_sec
	tax
	beq .twi_rts
	stx trig_sec			; trigger sector
	jsr sec_trigger
	cmp #TRIG_WALK
	bne .twi_rts
	; lower / remote timed|forever doors require SEC_TARGET
	ldx trig_sec
	jsr sec_action
	cmp #ACT_LOWER_FLOOR
	beq .twi_need_tgt
	cmp #ACT_OPEN_DOOR_10S
	beq .twi_need_tgt
	cmp #ACT_OPEN_DOOR_30S
	beq .twi_need_tgt
	cmp #ACT_OPEN_DOOR_FOREVER
	beq .twi_need_tgt
	jmp .twi_go
.twi_need_tgt
	ldx trig_sec
	lda SEC_TARGET,x
	beq .twi_rts
.twi_go
	lda #1
	sta elev_remote
	jmp trigger_action
.twi_rts
	rts

; ------------------------------------------------------------------
; try_switch — K held near switch item → sector under switch (trigger=switch)
; ------------------------------------------------------------------
try_switch
	lda key_use
	bne .ts_g
	rts
.ts_g
	ldx #0
.ts_l
	lda level_item_type,x
	cmp #ITEM_TYPE_SWITCH
	bne .ts_n
	lda level_item_x,x
	sta tmp0
	lda level_item_y,x
	sta tmp1
	lda tmp0
	sec
	sbc playerx_h
	bcs .ts_x
	eor #$ff
	clc
	adc #1
.ts_x
	cmp #SWITCH_USE_RADIUS
	bcs .ts_n
	lda tmp1
	sec
	sbc playery_h
	bcs .ts_y
	eor #$ff
	clc
	adc #1
.ts_y
	cmp #SWITCH_USE_RADIUS
	bcs .ts_n
	; map switch world → tile → sector
	lda tmp0
	lsr
	lsr
	lsr
	sta mapx
	lda tmp1
	lsr
	lsr
	lsr
	sta mapy
	stx tmp5				; save item index
	jsr map_sector_id
	beq .ts_n2
	sta trig_sec
	tax
	jsr sec_trigger
	cmp #TRIG_SWITCH
	bne .ts_n2
	lda #1
	sta elev_remote
	jmp trigger_action
.ts_n2
	ldx tmp5
.ts_n
	inx
	cpx #MAX_ITEMS
	bcc .ts_l
	rts

; ------------------------------------------------------------------
; stairs_activate — tmp1 = Raise Stairs sector (walk-into; often single_shot)
; Raise SEC_TARGET chain: +1, +2, … while Continue Stairs & target ≠ 0.
; ------------------------------------------------------------------
stairs_activate
	lda tmp1
	sta elev_home			; start sector
	tax
	lda SEC_TARGET,x
	bne .sa_dry_go
.sa_abort
	rts
.sa_dry_go
	; Dry-run: count hops, abort if any sector busy
	ldx #0
	stx elev_found			; hop count
.sa_dry
	sta elev_cell_x
	sta tmp1
	jsr proc_sector_busy
	bcs .sa_abort
	inc elev_found
	ldx elev_cell_x
	jsr sec_action
	cmp #ACT_CONTINUE_STAIRS
	bne .sa_dry_done
	lda SEC_TARGET,x
	bne .sa_dry
.sa_dry_done
	jsr proc_count_free
	cmp elev_found
	bcc .sa_abort
	; Enough slots — oneshot start, raise chain
	ldx elev_home
	jsr sec_oneshot_if
	lda #1
	sta elev_mode			; amount
	ldx elev_home
	lda SEC_TARGET,x
.sa_raise
	sta elev_cell_x
	sta tmp1
	tax
	lda SEC_FLOOR,x
	clc
	adc elev_mode
	cmp #32
	bcc .sa_clamp
	lda #31
.sa_clamp
	sta tmp2				; dest height
	lda SEC_FLOOR,x
	cmp tmp2
	bcs .sa_chain			; already at/above
	lda #PROC_RAISE_FLOOR
	sta tmp0
	lda #0
	sta tmp3
	sta tmp4
	jsr proc_alloc
.sa_chain
	ldx elev_cell_x
	jsr sec_action
	cmp #ACT_CONTINUE_STAIRS
	bne .sa_snd
	lda SEC_TARGET,x
	beq .sa_snd
	inc elev_mode
	lda SEC_TARGET,x
	jmp .sa_raise
.sa_snd
	lda #SOUND_STNMOV
	jmp play_sound

; ------------------------------------------------------------------
; raise_floor_activate — tmp1 = sector; permanent raise to highest adjacent
; lower_floor_forever_activate — permanent lower to lowest adjacent
; ------------------------------------------------------------------
raise_floor_activate
	lda #1
	sta elev_mode
	jmp floor_forever_activate

lower_floor_forever_activate
	lda #0
	sta elev_mode
	; fall through
floor_forever_activate
	jsr proc_sector_busy
	bcc .rf_free
	rts
.rf_free
	jsr elevator_find_dest
	sta tmp2
	ldx tmp1
	lda SEC_FLOOR,x
	cmp tmp2
	bne .rf_move
	rts
.rf_move
	lda elev_mode
	bne .rf_raise_k
	lda #PROC_LOWER_FLOOR
	bne .rf_kind
.rf_raise_k
	lda #PROC_RAISE_FLOOR
.rf_kind
	sta tmp0
	lda #0
	sta tmp3
	sta tmp4
	jsr proc_alloc
	bcs .rf_fail
	lda #SOUND_STNMOV
	jmp play_sound
.rf_fail
	rts

; ------------------------------------------------------------------
; elevator_activate — tmp1 = moved sector, elev_mode = 0 lower / 1 raise
; elev_remote = 0 → ELEV_RECLOSE_LOCAL_MS, 1 → ELEV_RECLOSE_REMOTE_MS
; Only used for ACT_LOWER_FLOOR (raise-with-return unused; raise is permanent).
; ------------------------------------------------------------------
elevator_activate
	jsr proc_sector_busy
	bcc .ea_free
	rts
.ea_free
	jsr proc_count_free
	cmp #2
	bcs .ea_slots
	rts
.ea_slots
	jsr elevator_find_dest		; A = dest floor
	sta tmp2
	ldx tmp1
	lda SEC_FLOOR,x
	cmp tmp2
	bne .ea_move
	rts					; already at dest
.ea_move
	sta elev_home
	lda elev_mode
	bne .ea_raise
	; lower then return raise
	lda #PROC_LOWER_FLOOR
	sta tmp0
	lda #PROC_RAISE_FLOOR
	sta elev_found			; reuse as return kind scratch
	jmp .ea_alloc
.ea_raise
	lda #PROC_RAISE_FLOOR
	sta tmp0
	lda #PROC_LOWER_FLOOR
	sta elev_found
.ea_alloc
	; tmp1 = sector, tmp2 = dest, tmp0 = motion kind
	lda #0
	sta tmp3
	sta tmp4
	jsr proc_alloc
	bcs .ea_fail
	lda #SOUND_STNMOV
	jsr play_sound
	lda #PROC_TIMER
	sta tmp0
	lda elev_found
	sta tmp2
	lda elev_remote
	bne .ea_rem
	lda #<ELEV_RECLOSE_LOCAL_MS
	sta tmp3
	lda #>ELEV_RECLOSE_LOCAL_MS
	sta tmp4
	jmp .ea_timer
.ea_rem
	lda #<ELEV_RECLOSE_REMOTE_MS
	sta tmp3
	lda #>ELEV_RECLOSE_REMOTE_MS
	sta tmp4
.ea_timer
	jsr proc_alloc
	bcs .ea_fail
	lda elev_home
	sta PROC_E,y
.ea_fail
	rts

; ------------------------------------------------------------------
; trigger_action — trig_sec = trigger sector; run its action
; Used by try_switch / try_use / try_walk_into.
; Resolves SEC_TARGET (0 → self, single) for floor/door. Remote targets
; walk the SEC_TARGET sibling chain (same-tag fan-out from cook).
; Caller sets elev_remote for ACT_LOWER_FLOOR. Stairs uses trig_sec as
; start (not target resolve).
; ------------------------------------------------------------------
trigger_action
	ldx trig_sec
	jsr sec_action
	cmp #ACT_END_LEVEL
	beq .ta_end
	cmp #ACT_OPEN_DOOR
	beq .ta_door5
	cmp #ACT_OPEN_DOOR_FOREVER
	beq .ta_door_f
	cmp #ACT_OPEN_DOOR_10S
	beq .ta_door10
	cmp #ACT_OPEN_DOOR_30S
	beq .ta_door30
	cmp #ACT_LOWER_FLOOR
	bne .ta_nl
	jmp .ta_lower
.ta_nl
	cmp #ACT_LOWER_FLOOR_FOREVER
	bne .ta_nlf
	jmp .ta_lower_f
.ta_nlf
	cmp #ACT_RAISE_FLOOR
	bne .ta_nr
	jmp .ta_raise
.ta_nr
	cmp #ACT_RAISE_STAIRS
	bne .ta_none
	jmp .ta_stairs
.ta_none
	rts
.ta_end
	lda #1
	sta end_level
	jmp .ta_shot
.ta_door5
	lda #DOOR_MODE_5S
	jmp .ta_door_go
.ta_door_f
	lda #DOOR_MODE_FOREVER
	jmp .ta_door_go
.ta_door10
	lda #DOOR_MODE_10S
	jmp .ta_door_go
.ta_door30
	lda #DOOR_MODE_30S
.ta_door_go
	sta elev_mode
	ldx trig_sec
	lda SEC_TARGET,x
	bne .ta_door_walk
	lda trig_sec
	sta tmp1
	jsr door_open_activate
	jmp .ta_shot
.ta_door_walk
	sta trig_chain
	sta tmp1
	jsr door_open_activate
	ldx trig_chain
	lda SEC_TARGET,x
	bne .ta_door_walk
	jmp .ta_shot
.ta_lower
	ldx trig_sec
	lda SEC_TARGET,x
	bne .ta_lower_walk
	lda trig_sec
	sta tmp1
	lda #0
	sta elev_mode
	jsr elevator_activate
	jmp .ta_shot
.ta_lower_walk
	sta trig_chain
	sta tmp1
	lda #0
	sta elev_mode
	jsr elevator_activate
	ldx trig_chain
	lda SEC_TARGET,x
	bne .ta_lower_walk
	jmp .ta_shot
.ta_lower_f
	ldx trig_sec
	lda SEC_TARGET,x
	bne .ta_lower_f_walk
	lda trig_sec
	sta tmp1
	jsr lower_floor_forever_activate
	jmp .ta_shot
.ta_lower_f_walk
	sta trig_chain
	sta tmp1
	jsr lower_floor_forever_activate
	ldx trig_chain
	lda SEC_TARGET,x
	bne .ta_lower_f_walk
	jmp .ta_shot
.ta_raise
	ldx trig_sec
	lda SEC_TARGET,x
	bne .ta_raise_walk
	lda trig_sec
	sta tmp1
	jsr raise_floor_activate
	jmp .ta_shot
.ta_raise_walk
	sta trig_chain
	sta tmp1
	jsr raise_floor_activate
	ldx trig_chain
	lda SEC_TARGET,x
	bne .ta_raise_walk
	jmp .ta_shot
.ta_stairs
	lda trig_sec
	sta tmp1
	jmp stairs_activate		; oneshot inside on success only
.ta_shot
	ldx trig_sec
	jmp sec_oneshot_if

; ------------------------------------------------------------------
; elevator_find_dest — min/max neighbouring open floor for sector tmp1
; elev_mode 0 = lowest, 1 = highest. → A = dest (current floor if none)
; Clobbers mapx/mapy, tmp2–tmp4, elev_* scratch, ptr.
; ------------------------------------------------------------------
elevator_find_dest
	lda #0
	sta elev_found
	lda elev_mode
	bne .ef_imax
	lda #$1f
	sta tmp2
	jmp .ef_scan
.ef_imax
	lda #0
	sta tmp2
.ef_scan
	lda #0
	sta mapy
.ef_y
	lda #0
	sta mapx
.ef_x
	jsr map_sector_id
	cmp tmp1
	bne .ef_xn
	lda mapx
	sta elev_cell_x
	lda mapy
	sta elev_cell_y
	lda #0
	sta tmp3				; dir 0..3
.ef_dir
	ldx tmp3
	lda elev_cell_x
	clc
	adc tu_dx,x
	sta mapx
	cmp #MAP_SIZE
	bcs .ef_dn
	lda elev_cell_y
	clc
	adc tu_dy,x
	sta mapy
	cmp #MAP_SIZE
	bcs .ef_dn
	jsr sector_at_map
	beq .ef_dn
	cmp tmp1
	beq .ef_dn
	tax
	lda SEC_FLOOR,x
	ldx elev_mode
	bne .ef_max
	cmp tmp2
	bcs .ef_dn
	sta tmp2
	lda #1
	sta elev_found
	jmp .ef_dn
.ef_max
	cmp tmp2
	bcc .ef_dn
	beq .ef_dn
	sta tmp2
	lda #1
	sta elev_found
.ef_dn
	inc tmp3
	lda tmp3
	cmp #4
	bcc .ef_dir
	lda elev_cell_x
	sta mapx
	lda elev_cell_y
	sta mapy
.ef_xn
	inc mapx
	lda mapx
	cmp #MAP_SIZE
	beq .ef_xnxt
	jmp .ef_x
.ef_xnxt
	inc mapy
	lda mapy
	cmp #MAP_SIZE
	beq .ef_done_scan
	jmp .ef_y
.ef_done_scan
	lda elev_found
	bne .ef_ok
	ldx tmp1
	lda SEC_FLOOR,x
	rts
.ef_ok
	lda tmp2
	rts

; ------------------------------------------------------------------
; proc_update — tick all slots (SMC jump table by PROC_KIND)
; ------------------------------------------------------------------
proc_update
	ldx #0
.pu_loop
	lda PROC_KIND,x
	asl					; kind*2
	tay
	lda .pu_jmptab,y
	sta .pu_smc + 1
	lda .pu_jmptab + 1,y
	sta .pu_smc + 2
.pu_smc
	jmp $ffff				; patched per kind
.pu_next
	inx
	cpx #PROC_NUM
	bne .pu_loop
	rts

; lo/hi interleaved; index = kind*2 (0=FREE → next)
.pu_jmptab
	!word .pu_next
	!word .pu_timer
	!word .pu_raise_c
	!word .pu_lower_c
	!word .pu_raise_f
	!word .pu_lower_f

.pu_to_next
	jmp .pu_next

.pu_timer
	lda PROC_C,x
	sec
	sbc dt_ms
	sta PROC_C,x
	lda PROC_D,x
	sbc #0
	sta PROC_D,x
	bcc .pu_tim_fire
	ora PROC_C,x
	bne .pu_to_next
.pu_tim_fire
	lda PROC_A,x
	sta tmp1
	lda PROC_B,x
	sta tmp0
	cmp #PROC_LOWER_CEIL
	bne .pu_tim_ns
	lda #SOUND_DORCLS
	jsr play_sound
	lda tmp0
.pu_tim_ns
	cmp #PROC_RAISE_FLOOR
	beq .pu_tim_fl
	cmp #PROC_LOWER_FLOOR
	beq .pu_tim_fl
	lda #0
	jmp .pu_tim_b
.pu_tim_fl
	lda PROC_E,x
.pu_tim_b
	sta tmp2
	lda #PROC_FREE
	sta PROC_KIND,x
	lda #0
	sta tmp3
	sta tmp4
	stx tmp5
	jsr proc_alloc
	ldx tmp5
	jmp .pu_next

.pu_raise_c
	jsr .pu_accum
	bcc .pu_to_next
	ldy PROC_A,x
	lda SEC_CEIL,y
	cmp PROC_B,x
	bcs .pu_raise_c_done
	clc
	adc #1
	sta SEC_CEIL,y
	cmp PROC_B,x
	bcc .pu_to_next
.pu_raise_c_done
	lda #PROC_FREE
	sta PROC_KIND,x
	jmp .pu_next

.pu_lower_c
	stx tmp5
	jsr player_tile
	jsr map_sector_id
	ldx tmp5
	cmp PROC_A,x
	beq .pu_next_far
	jsr .pu_accum
	bcc .pu_next_far
	ldy PROC_A,x
	lda SEC_CEIL,y
	cmp SEC_FLOOR,y
	beq .pu_lower_c_done
	bcc .pu_lower_c_done
	sec
	sbc #1
	sta SEC_CEIL,y
	cmp SEC_FLOOR,y
	bne .pu_next_far
.pu_lower_c_done
	lda #PROC_FREE
	sta PROC_KIND,x
	jmp .pu_next

.pu_raise_f
	jsr .pu_accum
	bcc .pu_next_far
	ldy PROC_A,x
	lda SEC_FLOOR,y
	cmp PROC_B,x
	bcs .pu_raise_f_done
	clc
	adc #1
	sta SEC_FLOOR,y
	cmp PROC_B,x
	bcc .pu_next_far
.pu_raise_f_done
	lda #PROC_FREE
	sta PROC_KIND,x
	jmp .pu_next

.pu_lower_f
	jsr .pu_accum
	bcc .pu_next_far
	ldy PROC_A,x
	lda SEC_FLOOR,y
	cmp PROC_B,x
	beq .pu_lower_f_done
	bcc .pu_lower_f_done
	sec
	sbc #1
	sta SEC_FLOOR,y
	cmp PROC_B,x
	bne .pu_next_far
.pu_lower_f_done
	lda #PROC_FREE
	sta PROC_KIND,x
	jmp .pu_next

.pu_next_far
	jmp .pu_next

; Add dt_ms to accum; if ≥ MOTION_STEP_MS subtract and C=1 else C=0
.pu_accum
	lda PROC_C,x
	clc
	adc dt_ms
	sta PROC_C,x
	lda PROC_D,x
	adc #0
	sta PROC_D,x
	lda PROC_C,x
	cmp #MOTION_STEP_MS
	lda PROC_D,x
	sbc #0
	bcc .pua_no
	lda PROC_C,x
	sec
	sbc #MOTION_STEP_MS
	sta PROC_C,x
	lda PROC_D,x
	sbc #0
	sta PROC_D,x
	sec
	rts
.pua_no
	clc
	rts
