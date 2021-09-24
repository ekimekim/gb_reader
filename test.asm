
SECTION "Test text data", ROMX[$4000], BANK[1]

;   01234567890123456789
ds "\0"
ds "Call me Ishmael.\0"
ds "Several years ago,\0"
ds "nevermind how long\0"
ds "precisely, having\0",
ds "little to no money\0",
ds "in my purse and\0",
ds "nothing to\0"
ds "particularly\0"
ds "interest me on\0",
ds "shore, I thought I\0",
ds "would <max len line>\0"
ds "sail around a bit\0",
ds "and see the watery\0",
ds "part of the world.\0",
ds "It is a way I have\0",
ds "of driving off the\0",
ds "spleen and\0"
ds "reinvigorating the\0",
ds "circulation.\0"
REPT 32
ds "\0"
ENDR
