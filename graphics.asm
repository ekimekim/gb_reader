include "macros.asm"
include "vram.asm"
include "ioregs.asm"
include "longcalc.asm"

SECTION "Graphics staging area 1", WRAMX[$D000]
StagingData::
	ds 16 * 20 * 9 ; 9 rows of tiles
SECTION "Graphics staging area 2", WRAMX[$D000]
StagingData2::
	ds 16 * 20 * 9 ; 9 rows of tiles

SECTION "Graphics methods", ROM0

GraphicsInit::
	; Palette init: 0 is white, all others are black
	ld A, $80 ; auto-increment
	ld [TileGridPaletteIndex], A
	ld A, $ff
	ld [TileGridPaletteData], A
	ld [TileGridPaletteData], A
	xor A
	ld [TileGridPaletteData], A
	ld [TileGridPaletteData], A
	ld [TileGridPaletteData], A
	ld [TileGridPaletteData], A
	ld [TileGridPaletteData], A
	ld [TileGridPaletteData], A

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
	ld A, %00010001
	ld [LCDControl], A

	ret


; Copy the data in the staging area to screen using DMA
CopyStagingData::
	; Set first bank
	xor A
	ld [CGBVRAMBank], A
	ld A, BANK(StagingData)
	ld [CGBWRAMBank], A

	; Clear any pending vblank, just in case
	xor A
	ld [InterruptFlags], A
	; Disable all non-vblank interrupts
	ld A, IntEnableVBlank
	ld [InterruptsEnabled], A

	; Set source and dest
	ld A, HIGH(StagingData)
	ld [CGBDMASourceHi], A
	ld A, HIGH(BaseTileMap)
	ld [CGBDMADestHi], A
	xor A ; both source and dest are 256-aligned
	ld [CGBDMASourceLo], A
	ld [CGBDMADestLo], A

	; We want to copy 18 * 20 * 16 = 5760 bytes total,
	; 2880 for each bank. In one vblank we can copy 2280 bytes.
	; We can do this in 3 frames, copying 1920 bytes each frame.
	; Note the middle frame will be split in two as we need to stop to switch banks,
	; so we do 4 DMAs of 1920, 960, 960, 1920.

	halt ; wait for vblank
	ld A, 119 ; copy 1920 bytes (120x16)
	ld [CGBDMAControl], A ; first copy

	halt ; wait for next vblank
	ld A, 59 ; copy 960 bytes (60x16)
	ld [CGBDMAControl], A ; second copy, finishing first bank

	; Switch banks
	ld A, 1
	ld [CGBVRAMBank], A
	ld A, BANK(StagingData2)
	ld [CGBWRAMBank], A

	; Re-set source and dest
	ld A, HIGH(StagingData)
	ld [CGBDMASourceHi], A
	ld A, HIGH(BaseTileMap)
	ld [CGBDMADestHi], A
	xor A ; both source and dest are 256-aligned
	ld [CGBDMASourceLo], A
	ld [CGBDMADestLo], A

	ld A, 59
	ld [CGBDMAControl], A ; third copy

	halt ; wait for next vblank
	ld A, 119
	ld [CGBDMAControl], A ; final copy, finishing second bank

	ret
