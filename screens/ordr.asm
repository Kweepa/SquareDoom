; Order screen text - load address $c800 (the framebuffer)
!to "screens/ordr.prg", cbm
* = $c800
	!scr "sure, don't order ^doom^. sit back with",0
	!scr "your milk and cookies and let the",0
	!scr "universe go to hell. don't face the",0
	!scr "onslaught of demons and spectres that",0
	!scr "await you on ^the shores of hell^.",0
	!scr "avoid the terrifying confrontations",0
	!scr "with cacodemons and lost souls that",0
	!scr "infest ^inferno^.",0
	!scr " ",0
	!scr "or, act like a man! slap a few shells",0
	!scr "into your shotgun and let's kick some",0
	!scr "demonic butt. order the entire ^doom^",0
	!scr "trilogy now! after all, you'll probably",0
	!scr "end up in hell eventually. shouldn't",0
	!scr "you know your way around before you",0
	!scr "make the extended visit?",0
	!scr " ",0
	!scr "to order ^doom^, call ^1-800-]games^.",0
	!scr " ",0
	!scr "press a key",0
	!byte 0
