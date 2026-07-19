!zone process

; SoA thinkers: TIMER, RAISE/LOWER_CEIL, RAISE/LOWER_FLOOR.
; Door / elevator K-use: NESW neighbour within 4 world units of the shared face.
; Elevator walk: enter typed source with SEC_TARGET → move that sector.
; Absolute JMPs used where relative branches would exceed ±127.

DOOR_OPEN_GAP = 5
DOOR_RECLOSE_MS = 5000
MOTION_STEP_MS = 128			; 1 height unit per 128 ms

player_prev_sec	!byte 0			; last player sector (walk trigger)
elev_mode	!byte 0			; 0 = lower, 1 = raise
elev_remote	!byte 0			; 0 = K-use (local), 1 = walk target (remote)
elev_found	!byte 0
elev_home	!byte 0
elev_cell_x	!byte 0
elev_cell_y	!byte 0

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
; try_use — K held: NESW neighbour door / self-elevator (target 0) within 4u
; ------------------------------------------------------------------
try_use
	lda key_use
	bne .tu_go
.tu_far
	rts
.tu_go
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
	sta tmp1
	tax
	lda SEC_TYPE,x
	cmp #DOOR_TYPE
	beq .tu_is_door
	cmp #ELEVATOR_LOWER_TYPE
	beq .tu_elev
	cmp #ELEVATOR_RAISE_TYPE
	beq .tu_elev
	jmp .tu_far
.tu_elev
	lda SEC_TARGET,x
	bne .tu_far			; target set → walk-only
	lda #0
	sta elev_remote
	lda SEC_TYPE,x
	cmp #ELEVATOR_RAISE_TYPE
	beq .tu_elev_r
	lda #0
	sta elev_mode
	jmp elevator_activate
.tu_elev_r
	lda #1
	sta elev_mode
	jmp elevator_activate
.tu_is_door
	lda SEC_FLOOR,x
	clc
	adc #DOOR_OPEN_GAP
	sta tmp0
	lda SEC_CEIL,x
	cmp tmp0
	bcc .tu_closed
	jmp .tu_far
.tu_closed
	jsr proc_sector_busy
	bcc .tu_free
	jmp .tu_far
.tu_free
	jsr proc_count_free
	cmp #2
	bcs .tu_slots
	jmp .tu_far
.tu_slots
	ldx tmp1
	lda SEC_FLOOR,x
	clc
	adc #DOOR_OPEN_GAP
	sta tmp2
	lda #PROC_RAISE_CEIL
	sta tmp0
	lda #0
	sta tmp3
	sta tmp4
	jsr proc_alloc
	bcc .tu_got_raise
	jmp .tu_far
.tu_got_raise
	lda #PROC_TIMER
	sta tmp0
	lda #PROC_LOWER_CEIL
	sta tmp2
	lda #<DOOR_RECLOSE_MS
	sta tmp3
	lda #>DOOR_RECLOSE_MS
	sta tmp4
	jmp proc_alloc

; ------------------------------------------------------------------
; try_walk_elevator — sector change into elevator+target → move target
; ------------------------------------------------------------------
try_walk_elevator
	jsr player_tile
	jsr map_sector_id
	cmp player_prev_sec
	beq .twe_rts
	sta player_prev_sec
	tax
	beq .twe_rts
	lda SEC_TYPE,x
	cmp #ELEVATOR_LOWER_TYPE
	beq .twe_src
	cmp #ELEVATOR_RAISE_TYPE
	beq .twe_src
.twe_rts
	rts
.twe_src
	lda SEC_TARGET,x
	beq .twe_rts
	sta tmp1				; moved = target
	lda #1
	sta elev_remote
	lda SEC_TYPE,x
	cmp #ELEVATOR_RAISE_TYPE
	beq .twe_r
	lda #0
	sta elev_mode
	jmp elevator_activate
.twe_r
	lda #1
	sta elev_mode
	jmp elevator_activate

; ------------------------------------------------------------------
; elevator_activate — tmp1 = moved sector, elev_mode = 0 lower / 1 raise
; elev_remote = 0 → ELEV_RECLOSE_LOCAL_MS, 1 → ELEV_RECLOSE_REMOTE_MS
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
