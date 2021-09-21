IF !DEF(_G_HRAM)
_G_HRAM EQU "true"

RSSET $ff80

; The row number in tilemap which is the current most-back rendered line.
ReadTopRow rb 1

ENDC
