IF !DEF(_G_HRAM)
_G_HRAM EQU "true"

RSSET $ff80

Scratch rb 1

; Scratch for storing stack pointer during shennanigans
SavedStack rb 2

; The row number in tilemap which is the current most-back rendered line.
ReadTopRow rb 1

ENDC
