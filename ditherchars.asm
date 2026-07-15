; Auto-generated from lightingdither.png + itemudg.png — do not edit
; Wall UDGs $00–$07, floor $08 (tile 2 rot90 CW), item $09 (itemudg.png)
!zone ditherchars

dither_wall_glyphs
	!byte $ff,$ee,$ee,$ff,$ff,$bb,$bb,$ff	; light 0
	!byte $ee,$ee,$ee,$ee,$bb,$bb,$bb,$bb	; light 1
	!byte $aa,$ee,$ee,$aa,$aa,$bb,$bb,$aa	; light 2
	!byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa	; light 3
	!byte $88,$aa,$aa,$88,$22,$aa,$aa,$22	; light 4
	!byte $88,$88,$88,$88,$22,$22,$22,$22	; light 5
	!byte $00,$88,$88,$00,$00,$22,$22,$00	; light 6
	!byte $00,$00,$00,$00,$00,$00,$00,$00	; light 7
dither_floor_glyph
	!byte $ff,$06,$ff,$60,$ff,$06,$ff,$60
dither_item_glyph
	!byte $15,$f1,$8f,$a8,$8a,$f8,$1f,$15
