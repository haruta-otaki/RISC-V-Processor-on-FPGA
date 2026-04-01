`default_nettype none
`timescale 1ns / 1ps

module uart_rx #(
    parameter DATA_WIDTH = 8,
    parameter EVEN_PARITY = 1,
    parameter CLOCK_RATE=12_000_000
    ) (
    input logic clock,
    input logic reset,

    input logic rx,

    output logic [DATA_WIDTH-1:0] data_recv,
    output logic done_recv
);

    // Baud generator

    logic baud_clock;
    logic bg_reset;

    baud_generator #(
        .CLOCK_RATE(CLOCK_RATE)
    ) baud_generator_inst (
        .clock,
        .reset(bg_reset),
        .baud_clock
    );

    logic [DATA_WIDTH+2:0] frame_data_recv; // Accounts for start, parity, and stop bits
    logic frame_done_recv;

    logic parity_ok, well_formed;

    assign parity_ok = (EVEN_PARITY ? ~(^frame_data_recv[DATA_WIDTH+1:1]) : ^frame_data_recv[DATA_WIDTH+1:1]);
    assign well_formed = ((frame_data_recv[0] == 1'b0) && parity_ok && (frame_data_recv[DATA_WIDTH+2] == 1'b1));

    logic sr_reset, sr_enable;

    shift_register #(
        .LENGTH(DATA_WIDTH + 3), // Accounts for start, parity, and stop bits
        .START_BITS(1),
        .MSB_FIRST(0)
    ) inst_shift_register (
        .clock(baud_clock),
        .reset(sr_reset),
        .data(rx),
        .enable(sr_enable),
        .continuous(1'b1),
        .ready(frame_done_recv),
        .out(frame_data_recv)
    );

    logic receiving;

    always_ff @(posedge clock) begin
        if (sr_reset) begin
            sr_reset <= 0;
        end

        if (bg_reset) begin
            bg_reset <= 0;
        end

        if (!receiving && rx == 1'b0) begin
            sr_reset <= 1;
            bg_reset <= 1;

            receiving <= 1;
        end

        if (frame_done_recv) begin
            sr_reset <= 1;

            receiving <= 0;
        end

        if (reset) begin
            bg_reset <= 1;
            sr_reset <= 1;

            receiving <= 0;
        end
    end

    // The receiving register is always enabled: "well-formedness" triggers a receive
    assign sr_enable = 1;

    assign data_recv = frame_data_recv[DATA_WIDTH:1];
    assign done_recv = (frame_done_recv & well_formed);

endmodule