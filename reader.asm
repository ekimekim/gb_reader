
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
; Worst case takes 9 (prelude) + 15*9 (loop) + 12 (last loop, taking jump) + 26 (cleanup) = 182 cycles
DrawNextLine:
	ret ; TODO. copy-pasted from elsewhere:
	ld HL, ReadHeadBank
	ld A, [HL+] ; A = bank, HL = ReadHeadAddr
	SetRomBank

	ld A, [HL+]
	ld L, [HL]
	ld H, A	; HL = [ReadHeadAddr]


; Render the line starting at HL to tilemap at row starting at DE.
; Advances DE and HL to start of next line / next row.
; Interrupts must be disabled.
DrawLine:
	; We copy chars until we find a newline, then switch to copying spaces.
	; If we don't find a newline within 20 chars, assume next one is one.

	; Stash SP, transfer HL into SP, then DE into HL.
	ld [SavedStack], SP
	ld SP, HL
	ld H, D
	ld L, E

	; Cleanup code ends up repeated in a few places.
	; We need to set DE to HL+12 or +13 (\1 = 11 or 12),
	; and HL to SP or SP-1 (\2 = SP or SP-1).
_Cleanup: MACRO
	ld D, H
	ld A, \1
	add L
	ld E, A ; DE = HL + 11. We know this won't wrap because HL is only 20 through a 32-byte aligned row.
	inc DE ; then finally increment for a total of +12. this one might carry.
	ld HL, \2
	ld B, H
	ld C, L ; BC = HL, stashed while we restore SP
	ld A, [SavedStack]
	ld L, A
	ld A, [SavedStack+1]
	ld H, A ; HL = [SavedStack]
	ld SP, HL ; restore SP
	ld H, B
	ld L, C ; HL = BC
ENDM

	; now SP = line data, HL = tilemap
SET copied = 0
REPT 9
	pop DE ; get 2 chars, E then D
	ld A, E
	and A ; set z if 0
	jr z, .fill_even + copied
	ld [HL+], A
	ld A, D
	and A ; set z if 0
	jr z, .fill_odd + copied
	ld [HL+], A
SET copied = copied + 2
ENDR
	; final loop is special-cased, no need to jump to fill if only the last value needs it
	pop DE ; get 2 chars, E then D
	ld A, E
	and A ; set z if 0
	jr z, .fill_even + copied
	ld [HL+], A
	; if D is 0, we're writing the blank as needed. if not we're writing the last char.
	; we'll need to inc HL by 1 extra during cleanup since we're skipping the inc HL here.
	ld [HL], D

	_Cleanup 12, SP
	ret

; These runs copying A to HL are jumped into depending on how many tiles we've already filled.
; Note in the even case we need to adjust SP back by 1 as we overshot.
.fill_even
REPT 20
	ld [HL+], A
ENDR
	_Cleanup 11, SP-1
	ret

.fill_odd
REPT 19
	ld [HL+], A
ENDR
	_Cleanup 11, SP
	ret
