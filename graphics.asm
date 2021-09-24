include "macros.asm"
include "vram.asm"
include "ioregs.asm"

SECTION "Graphics textures", ROM0

GraphicsTextures:

; First 32 chars are blank (non-printing)
REPT 32
REPT 8
	dw `00000000
ENDR
ENDR

; printable ascii
include "assets/font.asm"

EndGraphicsTextures:

TEXTURES_SIZE EQU EndGraphicsTextures - GraphicsTextures

SECTION "Graphics methods", ROM0

GraphicsInit::
	; Identity palette
    ld A, %11100100
    ld [TileGridPalette], A
    ld [SpritePalette0], A

    ; Textures into unsigned tilemap
    ld HL, GraphicsTextures
    ld BC, TEXTURES_SIZE
    ld DE, BaseTileMap
    LongCopy

	ret
