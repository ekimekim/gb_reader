; Defines a default non-maskable interrupt handler as an empty function

section "Nonmaskable interrupt handler", ROM0 [$66]
	NMIHandler::
		retn
