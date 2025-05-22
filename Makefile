YOSYS		?= yosys
NEXTPNR 	?= nextpnr-ice40

DEVICE		?= hx8k
PACKAGE		?= tq144:4k
PROGRAMMER	?= ./spi_volatile_programmer.py
#PROGRAMMER	?= ./spi_flash_programmer.sh
PCF_FILE	?= pinmap.pcf

# Use yosys to perform synthesis
%.json : %.sv
	$(YOSYS) -p "synth_ice40 -top top -json $@" $<

# Use nextpnr-ice40 to perform place-and-route
%.asc : %.json
	$(NEXTPNR) --$(DEVICE) --package $(PACKAGE) --pcf $(PCF_FILE) --asc $@ --json $<

# Use icepack to generate bitstream
%.bin : %.asc
	icepack $< $@

# Use Icarus to generate a simulator
top_tb.vvp : top_tb.sv top.sv
	iverilog -g2012 -o $@ $^

# Use Icarus to run the simulation
run: top_tb.vvp
	vvp top_tb.vvp

# Graph (using GTKWave)
graph: top_tb.vcd
	gtkwave $^

# Program (using GPIO/program.sh and flashrom)
program: top.bin
	$(PROGRAMMER) $^

# Clean
clean:
	rm -f *.bin *.vvp *.vcd *.asc *.blif *.json
