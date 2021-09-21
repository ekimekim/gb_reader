
include "macros.asm"

SECTION "Reader state", SRAM

; These 8 bytes must match "gbreader". If they don't, we assume SRAM is uninitialized.
SaveMagic ds 8

; Head refers to the position immediately following the most-forward rendered line.
; Tail refers to the position at the start of the most-back rendered line.
; Each is a pair consisting of a bank byte and an addr. Addr is assumed to always
; be a ROMX addr (ie. 0x4000-0x7fff).
ReadHeadBank ds 1
ReadHeadAddr ds 2
ReadTailBank ds 1
ReadTailAddr ds 2


SECTION "Reader methods", ROM0

SaveMagicCheck db "gbreader"

; Initialize graphics and other state.
; Assumes screen is off.
ReadInit::
	call SRAMInit

	; Start drawing lines from row 0.
	xor A
	ld [ScrollY], A
	ld [ReadTopRow], A

	; Draw initial 32 lines
	ld B, 0
REPT 32
	call DrawNextLine
ENDR

	ret


; Initalize SRAM state if needed
SRAMInit:
	; Check if SaveMagic is correct
	ld HL, SaveMagic
	ld DE, SaveMagicCheck
	ld B, 8
.magic_check
	ld A, [DE]
	cp [HL]
	jr nz, .magic_fail
	inc DE
	inc HL
	dec B
	jr nz, .magic_check

	; magic passed
	ret

.magic_failed
	; init head and tail
	xor A
	ld HL, ReadHeadBank
REPT 6
	ld [HL+], A
ENDR
	; write magic. we only do this once sram is initialized to prevent races.
	ld HL, SaveMagicCheck
	ld DE, SaveMagic
	ld B, 8
	Copy

	ret


; Render the line starting at ReadHead to screen at TileGrid pointer DE,
; and advance ReadHead and DE.
; It is up to the caller to update ReadTail to account for any overwritten value,
; or to scroll / update ReadTopRow.
DrawNextLine:
	ret ; TODO. copy-pasted from elsewhere:
	ld HL, ReadHeadBank
	ld A, [HL+] ; A = bank, HL = ReadHeadAddr
	SetRomBank

	ld A, [HL+]
	ld L, [HL]
	ld H, A	; HL = [ReadHeadAddr]


; Render the line starting at HL to tilemap at row starting at DE.
; C must be set to "\n" (this is preserved to speed up repeated calls).
; Advances HL and DE to start of next line / next row.
; Worst case cycle count: 249 not counting call or ret.
DrawLine:
	; We copy chars until we find a newline, then switch to copying spaces.
	; If we don't find a newline within 20 chars, assume next one is one.
	ld B, 20
.copy_loop
	ld A, [HL+]
	cp C ; set z if newline
	jr z, .break
	ld [DE], A ; copy char to tilemap
	inc E ; safe since rows are aligned, E won't wrap except at end of row (and we only go to 20)
	dec B
	jr nz, .copy_loop

	; skip next char as it must be a newline
	inc HL
.post_copy
	; DE += 12. This may wrap, and manually carrying is expensive (and so is setting up a 16-bit add),
	; so we first add 11 to E (won't carry) then inc DE.
	ld A, 11
	add E
	ld E, A
	inc DE

.break
	; Fill remainder of line with spaces. We know B is not 0 here.
	; We also know A = \n, which renders as a space. So we fill with that.
.fill_loop
	ld [DE], A
	inc E ; safe, see above
	dec B
	jr nz, .fill_loop
	jr .post_copy
