
# avoid implicit rules for clarity
.SUFFIXES: .asm .o .gb
.PHONY: bgb clean debug tests testroms

NAME := untitled
ASMS := $(wildcard *.asm)
OBJS := $(ASMS:.asm=.o)
DEBUGOBJS := $(addprefix build/debug/,$(OBJS))
RELEASEOBJS := $(addprefix build/release/,$(OBJS))
INCLUDES := $(wildcard include/*.asm)
ASSETS := $(shell find assets/ -type f)
TESTS := $(wildcard tests/*.py)
FIXARGS :=

all: build/release/rom.gb

tests/.uptodate: $(TESTS) tools/unit_test_gen.py $(DEBUGOBJS)
	python tools/unit_test_gen.py .
	touch "$@"

testroms: tests/.uptodate

tests: testroms
	tools/runtests

include/assets/varfont.asm: assets/varfont.png tools/generate_var_masks.py
	python tools/generate_var_masks.py assets/varfont.png > $@

include/assets/.uptodate: $(ASSETS) tools/assets_to_asm.py include/assets/varfont.asm
	python tools/assets_to_asm.py assets/ include/assets/
	touch $@

build/debug/%.o: %.asm $(INCLUDES) include/assets/.uptodate build/debug
	rgbasm -DDEBUG=1 -i include/ -v -o $@ $<

build/release/%.o: %.asm $(INCLUDES) include/assets/.uptodate build/release
	rgbasm -DDEBUG=0 -i include/ -v -o $@ $<

build/debug/rom.gb: $(DEBUGOBJS)
# note padding with 0x40 = ld b, b = BGB breakpoint
	rgblink -n $(@:.gb=.sym) -o $@ -p 0x40 $^
	rgbfix -v -p 0x40 $(FIXARGS) $@

build/release/rom.gb: $(RELEASEOBJS)
	rgblink -n $(@:.gb=.sym) -o $@ $^
	rgbfix -v -p 0 $(FIXARGS) $@

build/debug build/release:
	mkdir -p $@

debug: build/debug/rom.gb
	bgb $<

bgb: build/release/rom.gb
	bgb $<

gambatte: build/release/rom.gb
	gambatte_sdl $<

copy: build/release/rom.gb
	copy-rom $(NAME) $<

clean:
	rm -f build/*/*.o build/*/rom.sym build/*/rom.gb rom.gb include/assets/.uptodate include/assets/*.asm tests/*/*.{asm,o,sym,gb}
