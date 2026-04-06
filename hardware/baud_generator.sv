`default_nettype none
`timescale 1ns / 1ps

module baud_generator #(
    parameter CLOCK_RATE=12000000,
    parameter BAUD_RATE=115200
) (
    input logic clock,
    input logic reset,

    output logic baud_clock
);

    // I divide the tick count by two because I toggle the baud signal at each full count,
    // so a full phase happens every two full counts
    localparam TICK_COUNT = (CLOCK_RATE / BAUD_RATE) / 2;
    localparam TICK_COUNT_LENGTH = $clog2(TICK_COUNT);

    logic [TICK_COUNT_LENGTH-1:0] tick_count;

    always_ff @(posedge clock) begin
        if (reset) begin
            tick_count <= 0;
            baud_clock <= 0;
        end
        else begin
            tick_count <= tick_count + 1;

            if (tick_count == TICK_COUNT - 1) begin
                tick_count <= 0;
                baud_clock <= ~baud_clock;
            end
        end
    end

endmodule