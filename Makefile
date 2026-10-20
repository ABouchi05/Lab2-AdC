TOP := game_top
SRC := $(wildcard rtl/*.v rtl/espino_core/*.v)
.PHONY: all assemble test prog clean
all: build/game.bin
assemble:
	python tools/assembler.py sw/game.s sw/game.hex
test: assemble
	python -m unittest discover -s tests -v
	python tests/simulate.py
build/game.json: $(SRC) sw/game.s tools/assembler.py
	python tools/assembler.py sw/game.s sw/game.hex
	mkdir -p build
	yosys -l build/yosys.log -p 'read_verilog $(SRC); synth_ice40 -top $(TOP) -run begin:map_luts; abc -lut 4; ice40_wrapcarry -unwrap; opt_lut -tech ice40; techmap -map +/ice40/ff_map.v -map +/ice40/cells_map.v; clean; check; stat; blackbox =A:whitebox; write_json $@'
build/game.asc: build/game.json goboard.pcf
	nextpnr-ice40 --hx1k --package vq100 --freq 25 --json $< --pcf goboard.pcf --asc $@ --log build/nextpnr.log
build/game.bin: build/game.asc
	icepack $< $@
prog: all
	iceprog build/game.bin
clean:
	rm -rf build


