; Auto-generated from lightingdither.png + floorudg.png + itemudg.png — do not edit
; Wall UDGs $00–$0F, floor $10 (floorudg.png), item $11 (itemudg.png)
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
dither_floor_glyph
	!byte $22,$ff,$88,$ff,$22,$ff,$11,$ff
dither_item_glyph
	!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
