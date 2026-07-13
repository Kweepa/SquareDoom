!zone basicstub

; BASIC at $0801: 10 SYS 2061 → $080d
*=$0801
	!byte $0b,$08		; next line at $080b
	!byte $0a,$00		; line 10
	!byte $9e		; SYS
	!text "2061"
	!byte $00		; end of line
	!byte $00,$00		; end of program

entry
	jmp warmstart
