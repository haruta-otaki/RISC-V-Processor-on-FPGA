module soc #(
    parameter MEMORY_INIT
    ) (
    input logic clock,        // system clock
    input logic RESET,      // reset button
    input logic RXserial,        // UART receive
    output logic TXserial         // UART transmit
    );
    // memory map: 0x400 (1 kB) for memory-mapped I/O registers; 31KB of SRAM; 32KB of ROM from (0x8000);
    parameter [31:0] IO_MEMORY_SIZE = 32'h400;
    parameter [31:0] IO_BASE = 32'h340;

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
    logic isRX; 
    logic isTX; 
    logic isTXactive; 
    logic [7:0] ioReadingData;
    logic [31:0] ramReadingData;


    //--------------------------------------------------
    // BRAM
    //--------------------------------------------------   
    
    // synchronous duo port - support   
    bram_sdp #(
    //custom change 
    .WIDTH(32),
    .DEPTH(8192),
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
    // assign isIO  = memoryReadingAddress < IO_MEMORY_SIZE || memoryWritingAddress < IO_MEMORY_SIZE;
    // assign isRAM = !isIO;
    assign isRAM = 1; 

    // 1-hot encoding: data is routed to device number n if bit n is set in the address, ignoring the two LSBs
    parameter UART_RX_ADDRESS  = 0;  // address for RX (bit 0)
    parameter UART_TX_ADDRESS  = 1;  // address for TX (bit 1)
    parameter IO_UART_CONTROL_ADDRESS = 2;  // address for RXw (bit 3) -> (busy: 1, ready:0)
    
    // //check
    // assign isTX = isIO & memoryWritingSignal & memoryWritingAddress[UART_TX_ADDRESS + 2];

    // // check
    // // wire [31:0] IO_rdata = mem_wordaddr[IO_UART_CONTROL_ADDRESS] ? { 22'b0, !uart_ready, 9'b0} : 32'b0;
    
    // unsure where memoryReadingAddress[IO_UART_CONTROL_ADDRESS] is supposed to be used
    assign memoryReadingData = isRAM ? ramReadingData : 
        memoryReadingAddress[IO_UART_CONTROL_ADDRESS] ? {29'b0, isTXactive, 2'b0} :
        (isRX & memoryReadingSignal) ? {24'b0, ioReadingData} : 32'b0;

    // uart #(
    //     .CLKS_PER_BIT(217)
    // ) UART (
    //     .clock(clock),
    //     .reset(RESET),
    //     .ioReadingData(ioReadingData),
    //     .ioWritingData(memoryWritingData[7:0]), // bottom 8 bits matter as UART sends one byte at a time
    //     .isRX(isRX),
    //     .isTX(isTX),
    //     .RXserial(RXserial),
    //     .TXserial(TXserial),
    //     .TXactive(isTXactive)
    // );

endmodule

// /*
// $readmemh() command loads the data to initialize a memory from an external file. 
//    initial begin
//        $readmemh("firmware.hex",MEM);
//    end
// where firmware.hex is an ASCII file with the initial content of MEM in hexadecimal.
//     // Converts an IO_xxx_bit constant into an offset in IO page. 
//     // e.g. SW(a0,gp,IO_BIT_TO_OFFSET(IO_LEDS_bit));
//     function [31:0] IO_BIT_TO_OFFSET;
//         input [31:0] bit;
//         IO_BIT_TO_OFFSET = 1 << (bit + 2);
//     endfunction
// */