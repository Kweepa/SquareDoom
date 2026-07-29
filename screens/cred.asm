; Credits text — load address $c800 (FRAMEBUFFER)
!to "screens/cred.prg", cbm
* = $c800
	!scr "^doom^ for the ^commodore 64^", 0
	!scr " ",0
	!scr "ported by ^steve mccrea^, july 2026.",0
	!scr " ",0
	!scr "developed using the ^acme^ assembler",0
	!scr "by ^marco baye^.",0
	!scr " ",0
	!scr "tested using the ^vice^ emulator",0
	!scr "by ^andreas boose^ and the ^vice team^.",0
	!scr " ",0
	!scr "based on ^the keep^ and ^vicdoom^",0
	!scr "by ^steve mccrea^.", 0
	!scr " ",0
	!scr "press a key", 0
	!byte 0
