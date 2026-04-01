`default_nettype none
`timescale 1ns / 1ps

module uart_tx #(
    parameter DATA_WIDTH = 8,
    parameter EVEN_PARITY = 1,
    parameter CLOCK_RATE=12_000_000
    ) (
    input logic clock,
    input logic reset,

    input logic [DATA_WIDTH-1:0] data_send,
    input logic valid_data_send,

    // Other side is indicating a "clear to send" (active low)
    input logic cts,

    output logic tx,
    output logic done_tx
);

    // Baud generator

    logic baud_clock;

    baud_generator #(
        .CLOCK_RATE(CLOCK_RATE)
    ) baud_generator_inst (
        .clock,
        .reset,
        .baud_clock
    );

    logic [DATA_WIDTH+2:0] frame_data_send; // Accounts for start, parity, and stop bits
    logic frame_done_send;

    logic parity;

    assign parity = (EVEN_PARITY ? ^data_send : ~(^data_send));
    assign frame_data_send = {1'b1, parity, data_send, 1'b0};

    logic sr_reset, sr_enable;

    shift_register_reverse #(
        .LENGTH(DATA_WIDTH + 3), // Accounts for start, parity, and stop bits
        .START_BIT(1),
        .MSB_FIRST(0)
    ) inst_shift_register_reverse (
        .clock(baud_clock),
        .reset(sr_reset),
        .data(frame_data_send),
        .enable(sr_enable),
        .continuous(1'b0),
        .ready(frame_done_send),
        .out(tx)
    );

    always_ff @(posedge clock) begin
        if (sr_reset) begin
            sr_reset <= 0;
        end

        if (done_tx) begin
            done_tx <= 0;
        end

        if (frame_done_send) begin
            sr_reset <= 1;
            done_tx <= 1;
        end

        if (reset) begin
            sr_reset <= 1;
        end
    end

    // RTS and CTS are active low: (CTS == 0 [active] when RTS == 0 [active] on the other side)
    assign sr_enable = (valid_data_send && !cts);

endmodule