
SECTION "Test text data", ROMX[$4000], BANK[1]

Line: MACRO
	db "\1"
	db 0
ENDM

;     01234567890123456789
	db 0
	Line "Call me Ishmael."
	Line "Several years ago,"
	Line "nevermind how long"
	Line "precisely, having"
	Line "little to no money"
	Line "in my purse and"
	Line "nothing to"
	Line "particularly"
	Line "interest me on"
	Line "shore, I thought I"
	Line "would <max len line>"
	Line "sail around a bit"
	Line "and see the watery"
	Line "part of the world."
	Line "It is a way I have"
	Line "of driving off the"
	Line "spleen and"
	Line "reinvigorating the"
	Line "circulation."
REPT 32
	db 0
ENDR
