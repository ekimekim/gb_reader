; Defines restart call handlers as empty functions

section "Restart handler 0", ROM0 [$00]
	Restart0::
		ret
section "Restart handler 1", ROM0 [$00]
	Restart1::
		ret
section "Restart handler 2", ROM0 [$00]
	Restart2::
		ret
section "Restart handler 3", ROM0 [$00]
	Restart3::
		ret
section "Restart handler 4", ROM0 [$00]
	Restart4::
		ret
section "Restart handler 5", ROM0 [$00]
	Restart5::
		ret
section "Restart handler 6", ROM0 [$00]
	Restart6::
		ret
section "Restart handler 7", ROM0 [$00]
	Restart7::
	Mode1InterruptHandler::
		ret
