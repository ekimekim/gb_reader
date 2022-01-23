include "macros.asm"
include "vram.asm"
include "ioregs.asm"

SECTION "Graphics methods", ROM0

GraphicsInit::
	; TODO palette

	; Map each background tile to a unique tilemap texture.
	; Because we only have 256 options, we need to use the CGB second bank
	; to fully accomplish this.
	; We map rows 0-8 to bank 0 and 9-17 to bank 1.
	ld D, 0 ; tile flags (nothing special, palette 0)
	ld HL, TileGrid
.loopstart
	ld B, 9 ; row number
	ld C, 0 ; tile number
.rowloop
	ld E, 20 ; col number
.colloop
	ld [HL], C
	ld A, 1
	ld [CGBVRAMBank], A
	ld A, D
	ld [HL+], A
	xor A
	ld [CGBVRAMBank], A
	inc C
	dec E
	jr nz, .colloop
	; end of col
	LongAdd HL, 12, HL
	dec B
	jr nz, .rowloop

	; Is D zero? if so, switch to other bank flag and do another 9 rows
	ld A, D
	and A
	jr nz, .break
	ld D, 8
	jr .loopstart
.break

	; background only, unsigned tilemap. Don't turn it on yet.
	ld A, %0001001
	ld [LCDControl], A

	ret
