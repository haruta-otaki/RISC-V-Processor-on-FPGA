`default_nettype none
`timescale 1ns / 1ps

// This code is based on Project F's line drawing tutorial (projectF.io)
// with modifications and cleanup

module bram_sdp #(
    parameter WIDTH=32, 
    parameter DEPTH=3072, 
    parameter INIT=""
    ) (
    input logic clock_write,
    input logic clock_read,
    input logic write_enable,
    // set to 1 when reading from memory 
    input logic read_enable,
    input logic [ADDR_WIDTH-1:0] addr_write,
    // address to be read
    input logic [ADDR_WIDTH-1:0] addr_read,
    // 4-bits signal that indicates which byte should be written
    input logic [3:0] memoryWritingMask,
    input logic [WIDTH-1:0] data_in,
    // read memory
    output logic [WIDTH-1:0] data_out
);

    localparam ADDR_WIDTH=$clog2(DEPTH);

    logic [WIDTH-1:0] memory [DEPTH];

    initial begin
        if (INIT != "") begin
            $display("Load init file '%s' into bram_sdp.", INIT);
            $readmemh(INIT, memory);
            // $readmemb(INIT, memory);
        end
    end

    // Port A: Sync Write
    always_ff @(posedge clock_write) begin
        if (write_enable) 
        begin 
            // the masked write to memory is synthesized on the device by
            // BRAMs (on most FPGAs) directly supportting masked writes, 
            // e.g. Yosys' "technology mapping" allows multiple reads (2) and partial writes
            if(memoryWritingMask[0]) 
                memory[addr_write][7:0] <= data_in[7:0];
            if(memoryWritingMask[1]) 
                memory[addr_write][15:8] <= data_in[15:8];
            if(memoryWritingMask[2]) 
                memory[addr_write][23:16] <= data_in[23:16];
            if(memoryWritingMask[3]) 
                memory[addr_write][31:24] <= data_in[31:24];

            $display("storedData (3H)=%h, (2H)=%h, (1H)=%h, (0H)=%h",data_in[31:24], data_in[23:16], data_in[15:8], data_in[7:0]);
        end
    end

    // Port B: Sync Read
    always_ff @(posedge clock_read) begin
        if (read_enable) data_out <= memory[addr_read];
    end
endmodule
