YOSYS		?= yosys
NEXTPNR 	?= nextpnr-ice40

DEVICE		?= hx8k
PACKAGE		?= tq144:4k
PROGRAMMER	?= ./program.sh
PCF_FILE	?= pinmap.pcf

# Use yosys to perform synthesis
%.json : %.v
	$(YOSYS) -p "synth_ice40 -top top -json $@" $<

# Use nextpnr-ice40 to perform place-and-route
%.asc : %.json
	$(NEXTPNR) --$(DEVICE) --package $(PACKAGE) --pcf $(PCF_FILE) --asc $@ --json $<

# Use icepack to generate bitstream
%.bin : %.asc
	icepack $< $@

# Use Icarus to compile a simulator
top_tb.vvp : top_tb.v top.v
	iverilog -o $@ $^

# Simulate (using Icarus' tools)
run: top_tb.vvp
	vvp top_tb.vvp

# Graph (using GTKWave)
plot: top_tb.vcd
	gtkwave $^

# Program
program: top.bin
	sudo $(PROGRAMMER) $^

# Clean
clean:
	rm -f *.bin *.vvp *.vcd *.asc *.blif *.json
