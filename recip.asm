; ============================================================================
; recip.asm — 65536/z reciprocal table for item/enemy billboard projection
; ============================================================================
; recip[z] = min(65535, 65536/z); recip[0] = $FFFF (unused; ITEM_DEPTH_MIN=1).
; Projection without division: screen_offset ≈ (world * recip[z]) >> 11
; (= world*32/z). Technique from Andreas Larsson's C64 Doom workstage /
; Andropolis portal engine.
; ============================================================================

recip_lo
	!byte $ff, $ff				; z=0 unused; z=1 → 65535
!for .z, 2, 255 {
	!byte <(65536 / .z)
}
recip_hi
	!byte $ff, $ff				; z=0 unused; z=1 → 65535
!for .z, 2, 255 {
	!byte >(65536 / .z)
}
