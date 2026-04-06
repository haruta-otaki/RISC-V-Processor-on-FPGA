`default_nettype none
`timescale 1ns / 1ps

module synchronizer (
    input logic signal_async,
    input logic clock,

    output logic signal_sync
);

    logic registerA, registerB;
    
    always_ff @(posedge clock) begin
        registerA <= signal_async;
        registerB <= registerA;
    end

    assign signal_sync = registerB;
endmodule
