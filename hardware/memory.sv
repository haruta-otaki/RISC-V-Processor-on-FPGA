`default_nettype none
`timescale 1ns / 1ps

`define SRAM_EMULATION

module memory #(
    parameter DATAW = 32,
    parameter SRAMW = 15, // 32 KB = 2^15 bytes
    parameter BRAMW = 15, // 32 KB = 2^15 bytes
    parameter INIT="memory_state.mem",

    localparam ADDRW = (SRAMW + 1),   // 64 KB = 2^16 bytes
    localparam MASKW = (DATAW / 8)    // 4 for 32-bit words
    ) (
    input logic clock,
    input logic clock4x,
    input logic reset,

    input logic cs,

    input logic write_enable,
    input logic read_enable,

    input logic [MASKW-1:0] mask_write,

    input logic [ADDRW-1:0] addr_write,
    input logic [ADDRW-1:0] addr_read,

    input logic [DATAW-1:0] data_write,
    output logic [DATAW-1:0] data_read

    // SRAM pins

`ifndef SRAM_EMULATION
    , // continuation of previous inputs
    input logic cs_n,
    input logic oe_n,
    input logic we_n,
    input logic lb_n,
    input logic ub_n
`endif
);

    // Determine if operation is for BRAM or SRAM

    logic bram_operation_r;
    logic bram_operation_w;

    assign bram_operation_r = addr_read[ADDRW-1];
    assign bram_operation_w = addr_write[ADDRW-1];

    logic bram_r, bram_w, sram_r, sram_w;

    assign bram_r = (bram_operation_r & read_enable);
    assign bram_w = (bram_operation_w & write_enable);
    assign sram_r = (!bram_operation_r & read_enable);
    assign sram_w = (!bram_operation_w & write_enable);


    //////////
    // BRAM //
    //////////

    // Offset -2 for 32-bit words
    localparam NUMBER_WORDS_BRAM = (1 << (BRAMW - 2));

    logic [DATAW-1:0] bram [NUMBER_WORDS_BRAM];

    initial begin
        $display("Load memory file '%s' into memory.", INIT);
        $readmemh(INIT, bram);
    end

`ifdef SRAM_EMULATION
    // Offset -2 for 32-bit words
    localparam NUMBER_WORDS_SRAM = (1 << (SRAMW - 2));

    logic [DATAW-1:0] sram [NUMBER_WORDS_SRAM];

    initial begin
        for (int i = 0; i < NUMBER_WORDS_SRAM; i++) begin
            sram[i] = '0;
        end
    end
`endif

    // Port A: Sync Write
    always_ff @(posedge clock) begin
        if (cs & bram_w) begin
            if (mask_write[0]) bram[addr_write[BRAMW-1:2]][7:0] <= data_write[7:0];
            if (mask_write[1]) bram[addr_write[BRAMW-1:2]][15:8] <= data_write[15:8];
            if (mask_write[2]) bram[addr_write[BRAMW-1:2]][23:16] <= data_write[23:16];
            if (mask_write[3]) bram[addr_write[BRAMW-1:2]][31:24] <= data_write[31:24];
        end
`ifdef SRAM_EMULATION
        else if (cs & sram_w) begin
            if (mask_write[0]) sram[addr_write[SRAMW-1:2]][7:0] <= data_write[7:0];
            if (mask_write[1]) sram[addr_write[SRAMW-1:2]][15:8] <= data_write[15:8];
            if (mask_write[2]) sram[addr_write[SRAMW-1:2]][23:16] <= data_write[23:16];
            if (mask_write[3]) sram[addr_write[SRAMW-1:2]][31:24] <= data_write[31:24];
        end
`endif
    end

    // Port B: Sync Read
    always_ff @(posedge clock, posedge reset) begin
        if (reset) begin
            data_read <= {DATAW{1'b0}};
        end
        else begin
            if (cs & bram_r) begin
                data_read <= bram[addr_read[BRAMW-1:2]];
            end
`ifdef SRAM_EMULATION
            else if (cs & sram_r) begin
                data_read <= sram[addr_read[SRAMW-1:2]];
            end
`endif
        end
    end
endmodule