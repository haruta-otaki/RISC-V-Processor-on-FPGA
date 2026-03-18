module soc #(
    parameter MEMORY_INIT
    ) (
    input logic clock,        // system clock
    input logic RESET,      // reset button
    input logic RXserial,        // UART receive
    output logic TXserial         // UART transmit - physical wire 
    );

    // memory map: 0x400 (1 kB) for memory-mapped I/O registers; 31KB of SRAM; 32KB of ROM from (0x8000);
    parameter [31:0] IO_MEMORY_SIZE = 32'h400;

    logic [31:0] memoryReadingAddress;
    logic [31:0] memoryReadingData;
    logic memoryReadingSignal;
    logic [31:0] memoryWritingAddress;
    logic [31:0] memoryWritingData;
    logic memoryWritingSignal;
    logic [3:0] memoryWritingMask;
    logic [31:0] x1;
    logic isIO; 
    logic isRAM;
    logic isUART; 
    logic isTX; //(busy: 1, ready:0)
    logic [31:0] ioReadingData;
    logic [31:0] ramReadingData;

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
        .read_enable(isRAM & memoryReadingSignal),
        .addr_write(memoryWritingAddress[31:2]),
        // as PC increments by 4, disregard PC[2:0]
        .addr_read(memoryReadingAddress[31:2]),
        .memoryWritingMask({4{isRAM}} & memoryWritingMask),
        .data_in(memoryWritingData),
        .data_out(ramReadingData)
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
    
    
    // method: dedicate a special address in memory that is not really actual RAM but that has a register plugged to the hardware devices
    // address decoding hardware that routes the data to the right device
    
    // constraints: must be above your RAM's address range & must match what your software uses (C code must use the same base address (`IO_BASE = 1 << N`))
    assign isIO  = memoryReadingAddress < IO_MEMORY_SIZE || memoryWritingAddress < IO_MEMORY_SIZE;
    assign isRAM = !isIO;

    // 1-hot encoding: data is routed to device number n if bit n is set in the address, ignoring the two LSBs
    parameter IO_UART_DATA_bit  = 0;  // address for TX (bit 2)
    parameter IO_UART_CNTL_bit = 1;  // address for RX (bit 3) -> (busy: 1, ready:0)

    // Converts an IO_xxx_bit constant into an offset in IO page. 
    // e.g. SW(a0,gp,IO_BIT_TO_OFFSET(IO_LEDS_bit));
    function [31:0] IO_BIT_TO_OFFSET;
        input [31:0] bit;
        IO_BIT_TO_OFFSET = 1 << (bit + 2);
    endfunction
    
    assign isUART = isIO & memoryWritingSignal & memoryWritingAddress[IO_UART_DATA_bit];

    assign ioReadingData = 
        memoryReadingAddress[IO_UART_CNTL_bit] ? {22'b0, !isUART, 9'b0} : 32'b0;

    assign memoryReadingData = isRAM ? ramReadingData : ioReadingData ;

    uart #(
        .CLKS_PER_BIT(217)
    ) UART (
        .clock(clock),
        .reset(RESET),
        .ioWritingData(memoryWritingData[7:0]), // bottom 8 bits matter as UART sends one byte at a time
        .isUART(isUART),
        .isTX(isTX),
        .RXserial(RXserial)
        .TXserial(TXserial)
    );
endmodule