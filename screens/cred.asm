; Credits text - load address $e000 (the SCREENBUFFER)
!to "screens/cred.prg", cbm
* = $e000
	!scr "^doom^ for the ^commodore 64^", 0
	!scr " ",0
	!scr "ported by ^steve mccrea^, jul-aug 2026.",0
	!scr " ",0
	!scr "art by ^paul docherty^.", 0
	!scr " ",0
	!scr "sid music by ^???^.",0
	!scr "played with ^sid wizard^ by ^hermit^.",0
	!scr " ",0
	!scr "developed using the ^acme^ assembler",0
	!scr "by ^marco baye^.",0
	!scr " ",0
	!scr "tested using the ^vice^ emulator",0
	!scr "by ^andreas boose^ and the ^vice team^.",0
	!scr " ",0
	!scr "^doom^ shareware by ^] software^:",0
	!scr "^john carmack^, ^john romero^, ^dave taylor^,",0
	!scr "^adrian carmack^, ^kevin cloud^,",0
	!scr "^sandy peterson^, ^jay wilbur^, and",0
	!scr "^shawn green^, with additional support", 0
	!scr "from ^bobby prince^, ^paul radek^, and", 0
	!scr "^gregor punchatz^.",0
	!scr " ",0
	!scr "press a key", 0
	!byte 0
