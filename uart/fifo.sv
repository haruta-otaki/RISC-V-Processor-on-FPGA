`default_nettype none
`timescale 1ns / 1ps

module fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 16,
    parameter int FULL_FLAG_DEPTH = DEPTH * 0.8
) (
    input logic clock,
    input logic reset,
    input logic write_enable,
    input logic read_enable,
    input logic [DATA_WIDTH-1:0] data_in,
    output logic [DATA_WIDTH-1:0] data_out,
    output logic empty,
    output logic full
);

    localparam ADDR_WIDTH = $clog2(DEPTH);

    logic [ADDR_WIDTH-1:0] pos_r, pos_w;
    logic [ADDR_WIDTH:0] count;

    bram_sdp #(
        .WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) inst_bram_sdp (
        .clock_write(clock),
        .clock_read(clock),
        .write_enable(write_enable && !full),
        .read_enable(read_enable && !empty),
        .addr_write(pos_w),
        .addr_read(pos_r),
        .data_in,
        .data_out
    );

    always_ff @(posedge clock) begin
        if (reset) begin
            pos_r <= 0;
            pos_w <= 0;

            count <= 0;
        end
        else begin
            if (write_enable && !full) begin
                // Data already written in memory, now update counters
                pos_w <= pos_w + 1;

                if (pos_w == DEPTH - 1) begin
                    pos_w <= 0;
                end
            end

            if (read_enable && !empty) begin
                // Data already read from memory, now update counters
                pos_r <= pos_r + 1;

                if (pos_r == DEPTH - 1) begin
                    pos_r <= 0;
                end
            end

            // Single assignment to avoid conflict on simultaneous read/write
            count <= count + (write_enable && !full ? 1 : 0) - (read_enable && !empty ? 1 : 0);
        end
    end

    assign empty = (count == 0);
    assign full  = (count >= FULL_FLAG_DEPTH);
endmodule
