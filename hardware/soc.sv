/*
MEMORY LAYOUT 
    0x000 (1 kB)
        memory-mapped I/O registers 
        x   Base    address Device
        0   0x0300  dev0
        1   0x0340  dev1 (UART)
            | `0x0340` | `UART_TX` | byte to transmit out |
            | `0x0341` | `UART_RX` | byte received from serial line |
            | `0x0342` | `UART_STATUS` | 8 flag bits| 
                bit 7  INTERRUPT       — an interrupt event is pending
                bit 5  FIFO_TX_FULL    — transmit buffer is full, don't write
                bit 4  FIFO_TX_EMPTY   — transmit buffer is empty
                bit 3  FIFO_RX_FULL    — receive buffer is full
                bit 2  FIFO_RX_EMPTY   — receive buffer is empty, nothing to read
                bit 1  WAIT_RX         — UART is busy receiving
                bit 0  WAIT_TX         — UART is busy transmitting
        2   0x0380  dev2
        3   0x03C0  dev3

    0x400 (31KB) 
        RAM 
    0x8000 (32KB) 
        ROM
*/

module soc #(
    parameter MEMORY_INIT
    ) (
    input logic clock,        // system clock
    input logic RESET,      // reset button
    input logic RXserial,        // UART receive
    output logic TXserial,         // UART transmit
    output logic RTS,
    input logic CTS
    );
    localparam MEMORY_DEPTH = 1 << (15-2);
    localparam MEMORY_ADDRESS_WIDTH = $clog2(MEMORY_DEPTH + 1);

    logic [31:0] x1;

    logic [31:0] readingAddress;
    logic [31:0] readingData;
    logic readingSignal;

    logic [31:0] writingAddress;
    logic [31:0] writingData;
    logic writingSignal;
    logic [3:0] writingMask;

    logic [31:0] ramReadingData;
    logic [31:0] romReadingData;

    logic [31:0] ramReadingAddress;
    logic [31:0] romReadingAddress;
    logic [31:0] ramWritingAddress;
    logic [31:0] romWritingAddress;

    logic [31:0] ioReadingData; 
    logic [7:0] uartReadingData; 
    logic [7:0] uartWritingData; 

    logic [31:0] address;

    logic isIO; 
    logic isWaitingIO; 
    logic isRAM;
    logic isROM; 

    logic isDevice0;
    logic isDevice1;
    logic isDevice2;
    logic isDevice3;

    logic isUART; 
    logic isRX; 
    logic isTX; 
    logic isSTATUS; 

    logic RXfull; 
    logic TXbusy; 

    localparam IO_BASE = 32'h340;
    localparam RAM_BASE = 32'h400;
    localparam ROM_BASE = 32'h8000;

    logic uart_interrupt;
    logic uart_use_bus;
    inout [7:0] uart_data_inout;

    logic wasRAM;
    logic wasROM;
    logic wasUART;

    // localparam INTERRUPT = 7;
    // localparam FIFO_TX_FULL = 5; 
    // localparam FIFO_TX_EMPTY = 4; 
    // localparam FIFO_RX_FULL = 3;
    // localparam FIFO_RX_EMPTY = 2;
    // localparam WAIT_RX = 1;    
    // localparam WAIT_TX = 0;       
       
    assign isRX = isUART & (address[1:0] == 2'b01) & readingSignal;
    assign isTX = isUART & (address[1:0] == 2'b00) & writingSignal;
    assign isSTATUS = isUART & (address[1:0] == 2'b10);

    assign address = readingSignal ? readingAddress : (writingSignal ? writingAddress : 0); 
    assign isIO = (address[31:10] == 22'b0 && address[9:8] == 2'b11);
    assign isRAM = ((address[15] == 0 && !isIO) && (readingSignal || writingSignal));
    assign isROM = (address[15] == 1) && (readingSignal || writingSignal); 

    assign isDevice0 = isIO & (address[7:6] == 2'b00);
    assign isDevice1 = isIO & (address[7:6] == 2'b01);
    assign isDevice2 = isIO & (address[7:6] == 2'b10);
    assign isDevice3 = isIO & (address[7:6] == 2'b11);

    assign isUART = isDevice1; 

    // always @(posedge clock) 
    // begin
    //     $display("address: %h", address);
    //     $display("isROM: %b", isROM);
    //     $display("isRAM: %b", isRAM);
    //     $display("isUART: %b", isUART);
    // end

    // always @(posedge clock or posedge RESET) 
    // begin
    //     if (RESET)
    //         isWaitingIO <= 0; 
    //     else
    //     begin
    //         isWaitingIO <= isIO & readingSignal; 

    //         if (isRX)
    //             ioReadingData <= {uartReadingData, uartReadingData, uartReadingData, uartReadingData}; 
    //         if (isSTATUS & readingSignal) 
    //             ioReadingData <= {30'b0, !RXfull, TXbusy}; 
    //         if (isTX)
    //             uartWritingData <= writingData[7:0]; 
    //     end
    // end

    assign ramReadingAddress = readingAddress - RAM_BASE;
    assign ramWritingAddress = writingAddress - RAM_BASE;
    assign romReadingAddress = readingAddress - ROM_BASE;
    assign romWritingAddress = writingAddress - ROM_BASE;

    always_ff @(posedge clock) begin
        wasRAM  <= isRAM  & readingSignal;
        wasROM  <= isROM  & readingSignal;
        wasUART <= isUART & readingSignal;
    end

    always @(*) begin
        if      (wasUART) readingData <= {24'b0, uart_data_inout};
        else if (wasRAM)  readingData <= ramReadingData;
        else              readingData <= romReadingData;
    end

    //--------------------------------------------------
    // RAM
    //--------------------------------------------------   
    
    // synchronous duo port - support   
    bram #(
    //custom change 
    .WIDTH(32),
    .DEPTH(MEMORY_DEPTH),
    .INIT(""),
    .ADDR_WIDTH(MEMORY_ADDRESS_WIDTH)
    ) RAM (
        .clock_write(clock),
        .clock_read(clock),
        .reset(RESET),
        .write_enable(isRAM & writingSignal),
        .read_enable(isRAM & readingSignal),
        .addr_write(ramWritingAddress[MEMORY_ADDRESS_WIDTH - 1:2]),
        // as PC increments by 4, disregard PC[2:0]
        .addr_read(ramReadingAddress[MEMORY_ADDRESS_WIDTH - 1:2]),
        .memoryWritingMask(writingMask),
        .data_in(writingData),
        .data_out(ramReadingData)
    );

    
    //--------------------------------------------------
    // ROM
    //--------------------------------------------------   
    
    // synchronous duo port - support   
    bram #(
    //custom change 
    .WIDTH(32),
    .DEPTH(MEMORY_DEPTH),
    .INIT(MEMORY_INIT),
    .ADDR_WIDTH(MEMORY_ADDRESS_WIDTH)
    ) ROM (
        .clock_write(clock),
        .clock_read(clock),
        .reset(RESET),
        .write_enable(isROM & writingSignal),
        .read_enable(isROM & readingSignal),
        .addr_write(romWritingAddress[MEMORY_ADDRESS_WIDTH - 1:2]),
        // as PC increments by 4, disregard PC[2:0]
        .addr_read(romReadingAddress[MEMORY_ADDRESS_WIDTH - 1:2]),
        .memoryWritingMask(writingMask),
        .data_in(writingData),
        .data_out(romReadingData)
    );

    processor #(
    .MEMORY_INIT(MEMORY_INIT),
    .ROM_BASE(ROM_BASE)
    ) CPU (
    .clock(clock),
    .reset(RESET),
    .writingAddress(writingAddress),
    .writingData(writingData),
    .writingSignal(writingSignal),
    .writingMask(writingMask),
    .readingAddress(readingAddress),
    .readingData(readingData),
    .readingSignal(readingSignal),
    .x1(x1)
    );

    // Bus drives here on !rwb & cs
    // UART drives here rwb & cs
    assign uart_data_inout = (writingSignal & isUART) ? writingData[7:0] : 8'bz;

    uart #(
        .ADDR_WIDTH(2),
        .DATA_WIDTH(8),
        .CLOCK_RATE(12_000_000)
    ) uart_inst (
        .clock(clock),
        .reset(RESET),
        .addr(address[1:0]),
        .data(uart_data_inout),
        .cs(isUART),
        .rwb(!writingSignal),
        .interrupt(uart_interrupt),
        .rx(RXserial),
        .tx(TXserial),
        .cts(CTS),
        .rts(RTS),
        .use_bus(uart_use_bus)
    );

    // uart #(
    //     .CLKS_PER_BIT(104)
    // ) UART (
    //     .clock(clock),
    //     .reset(RESET),
    //     .uartReadingData(uartReadingData),
    //     .uartWritingData(uartWritingData), // bottom 8 bits matter as UART sends one byte at a time
    //     .isRX(isRX),
    //     .isTX(isTX),
    //     .RXserial(RXserial),
    //     .TXserial(TXserial),
    //     .RXfull(RXfull),
    //     .TXbusy(TXbusy),
    //     .readingSignal(readingSignal)
    // );
endmodule