`timescale 100ns/1ps

module tb();
    reg clock;

    top uut (
        .clock
    );

    initial begin
        $dumpfile("top_tb.vcd"); // Location to dump the signal samples
        $dumpvars;               // Asks to dump all signals
        clock = 0;
    end
    
    always #1 clock = ~clock;

    initial begin
        #1000000
        $finish;
    end
endmodule
