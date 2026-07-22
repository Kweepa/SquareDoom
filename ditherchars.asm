; Auto-generated from lightingdither.png (floors = walls 90° CW) + itemudg.png — do not edit
; Wall UDGs $00–$0F; floors → chars 219–234 (rotated); item → 235
!zone ditherchars

dither_wall_glyphs
	!byte $ff,$ef,$fe,$ff,$ff,$bf,$fb,$ff	; light 0
	!byte $ef,$ee,$fe,$ff,$bf,$bb,$fb,$ff	; light 1
	!byte $ef,$ee,$ee,$fe,$bf,$bb,$bb,$fb	; light 2
	!byte $ef,$ee,$ee,$ae,$ba,$bb,$bb,$fb	; light 3
	!byte $eb,$ee,$ee,$ae,$aa,$ba,$bb,$bb	; light 4
	!byte $aa,$ea,$ee,$ae,$aa,$ba,$bb,$ab	; light 5
	!byte $aa,$ea,$ae,$aa,$aa,$ba,$ab,$aa	; light 6
	!byte $aa,$aa,$55,$55,$aa,$aa,$55,$55	; light 7
	!byte $aa,$aa,$a2,$aa,$2a,$a8,$8a,$aa	; light 8
	!byte $a8,$88,$8a,$aa,$a2,$22,$2a,$aa	; light 9
	!byte $a8,$88,$88,$8a,$a2,$22,$22,$2a	; light 10
	!byte $28,$88,$88,$88,$82,$22,$22,$22	; light 11
	!byte $08,$88,$88,$80,$02,$22,$22,$20	; light 12
	!byte $00,$08,$88,$80,$00,$02,$22,$20	; light 13
	!byte $00,$08,$80,$00,$00,$02,$20,$00	; light 14
	!byte $00,$00,$00,$00,$00,$00,$00,$00	; light 15
dither_floor_glyphs
	!byte $ff,$df,$ff,$fd,$ff,$bf,$ff,$fb	; floor light 0
	!byte $ff,$cf,$ff,$fc,$ff,$9f,$ff,$f9	; floor light 1
	!byte $ff,$8f,$ff,$f8,$ff,$1f,$ff,$f1	; floor light 2
	!byte $ff,$87,$ff,$f0,$ff,$0f,$ff,$e1	; floor light 3
	!byte $ff,$07,$ff,$e0,$ff,$0e,$ff,$c1	; floor light 4
	!byte $ff,$06,$ff,$60,$ff,$0c,$ff,$c0	; floor light 5
	!byte $ff,$02,$ff,$20,$ff,$04,$ff,$40	; floor light 6
	!byte $33,$cc,$33,$cc,$33,$cc,$33,$cc	; floor light 7
	!byte $ef,$00,$bf,$00,$fb,$00,$df,$00	; floor light 8
	!byte $9f,$00,$f9,$00,$cf,$00,$fc,$00	; floor light 9
	!byte $1f,$00,$f1,$00,$8f,$00,$f8,$00	; floor light 10
	!byte $1e,$00,$e1,$00,$0f,$00,$f0,$00	; floor light 11
	!byte $0e,$00,$e0,$00,$07,$00,$70,$00	; floor light 12
	!byte $0c,$00,$c0,$00,$06,$00,$60,$00	; floor light 13
	!byte $04,$00,$40,$00,$02,$00,$20,$00	; floor light 14
	!byte $00,$00,$00,$00,$00,$00,$00,$00	; floor light 15
dither_item_glyph
	!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
