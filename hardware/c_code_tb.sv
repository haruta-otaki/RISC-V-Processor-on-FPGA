`default_nettype none
`timescale 1ns / 1ps

`define SIMULATION

module c_code_tb ();
    parameter MEMORY_INIT="firmware.mem";

    logic clock;
    // logic clock4x;

    initial clock = 0;
    // initial clock4x = 0;

    
    localparam CLOCK_HALF_PERIOD = 80;  // 12.5 MHz (40) 25 MHz (80)
    // localparam CLOCK_4X_HALF_PERIOD = 10;  // 50 MHz

    always #(CLOCK_HALF_PERIOD) clock = ~clock;
    // always #(CLOCK_4X_HALF_PERIOD) clock4x = ~clock4x;

    logic reset;

    // soc #(
    //     .MEMORY_INIT(MEMORY_INIT)
    // ) soc_inst (
    //     .clock12m(clock),
    //     // .clock48m(clock4x),
    //     .reset_button(reset)
    // );

    logic RXserial = 1;
    // initial 
    // begin
    //     RXserial = 1; 
    // end

    logic TXserial;

    soc #(
    .MEMORY_INIT(MEMORY_INIT)
    ) soc_inst (
    .clock(clock),
    .RESET(reset),
    .RXserial(RXserial),
    .TXserial(TXserial)
    );

    initial begin
        $dumpfile("c_code_tb.vcd");

        $dumpvars(0, soc_inst.processor_inst, soc_inst.bram_inst);
        // Give SOC a moment to load MEM_INIT
        repeat (10) @(posedge clock);

        // after writing directly to the memory array, wait to let any internal BRAM registered outputs or pipeline stages settle before reset is applied.
        repeat (3) @(posedge clock);

        // Apply reset
        @(negedge clock);
        reset = 1;
        @(negedge clock);
        reset = 0;

        // Execute the remaining of the initialization state
        @(posedge clock);

        // Execute through the FE state
        @(posedge clock);

        // Run for up to 10 million cycles then give up
        repeat (10_000_000) @(posedge clock);

        $display("Timeout - processor ran but produced no output");
        $finish;
        end
endmodule