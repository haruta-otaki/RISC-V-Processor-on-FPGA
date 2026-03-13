module soc #(
    parameter MEMORY_INIT
    ) (
    input logic clock,        // system clock
    input logic RESET,      // reset button
    input logic RXD,        // UART receive
    output logic TXD         // UART transmit
    );
    logic [31:0] memoryReadingAddress;
    logic [31:0] memoryReadingData;
    logic memoryReadingSignal;
    logic [31:0] memoryWritingAddress;
    logic [31:0] memoryWritingData;
    logic memoryWritingSignal;
    logic [3:0] memoryWritingMask;
    logic [31:0] x1;

    //--------------------------------------------------
    // BRAM
    //--------------------------------------------------   
    
    // synchronous duo port - support   
    bram_sdp #(
    //custom change 
    .WIDTH(32),
    .DEPTH(4096),
    .INIT(MEMORY_INIT)
    ) bram_inst (
        .clock_write(clock),
        .clock_read(clock),
        .write_enable(memoryWritingSignal),
        .read_enable(memoryReadingSignal),
        .addr_write(memoryWritingAddress[31:2]),
        // as PC increments by 4, disregard PC[2:0]
        .addr_read(memoryReadingAddress[31:2]),
        .memoryWritingMask(memoryWritingMask),
        .data_in(memoryWritingData),
        .data_out(memoryReadingData)
    );

    processor #(
    .MEMORY_INIT(MEMORY_INIT)
    ) processor_inst (
    .clock(clock),
    .reset(RESET),
    .memoryWritingAddress(memoryWritingAddress),
    .memoryWritingData(memoryWritingData),
    .memoryWritingSignal(memoryWritingSignal),
    .memoryWritingMask(memoryWritingMask),
    .memoryReadingAddress(memoryReadingAddress),
    .memoryReadingData(memoryReadingData),
    .memoryReadingSignal(memoryReadingSignal),
    .x1(x1)
    );

    assign TXD  = 1'b0; // not used for now
endmodule