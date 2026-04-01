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
    logic [31:0] ioReadingData; 
    logic [7:0] uartReadingData; 

    logic [31:0] address;

    logic isIO; 
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

    localparam DEPTH = 1 << (15-2);
    // do not understand CTS, RTS, and the use of STATUS in-register data

    // localparam INTERRUPT = 7;
    // localparam FIFO_TX_FULL = 5; 
    // localparam FIFO_TX_EMPTY = 4; 
    // localparam FIFO_RX_FULL = 3;
    // localparam FIFO_RX_EMPTY = 2;
    // localparam WAIT_RX = 1;    
    // localparam WAIT_TX = 0;       
       
    assign isRX = isUART & (address[1:0] == 2'b01);
    assign isTX = isUART & (address[1:0] == 2'b00);
    assign isSTATUS = isUART & (address[1:0] == 2'b10);

    assign address = readingSignal ? readingAddress : writingAddress; 
    assign isIO = (address[21:10] == 11'b0 && address[9:8] == 2'b11);
    assign isRAM = (address[15] == 0 && !isIO);
    assign isROM = (!isRAM & !isIO); 

    assign isDevice0 = isIO & (address[7:6] == 2'b00);
    assign isDevice1 = isIO & (address[7:6] == 2'b01);
    assign isDevice2 = isIO & (address[7:6] == 2'b10);
    assign isDevice3 = isIO & (address[7:6] == 2'b11);

    assign isUART = isDevice1; 
    assign readingData = isIO ? ioReadingData : 
                            isRAM ? ramReadingData : romReadingData;

    always @(*) begin
        if (isRX & !RXfull)
            ioReadingData <= {24'b0, uartReadingData}; 
        if (isSTATUS) 
            ioReadingData <= {30'b0, RXfull, TXbusy}; 
    end

    //--------------------------------------------------
    // RAM
    //--------------------------------------------------   
    
    // synchronous duo port - support   
    bram_sdp #(
    //custom change 
    .WIDTH(32),
    .DEPTH(DEPTH),
    .INIT("")
    ) RAM (
        .clock_write(clock),
        .clock_read(clock),
        .reset(RESET),
        .write_enable(isRAM & writingSignal),
        .read_enable(isRAM & readingSignal),
        .addr_write(writingAddress[$clog2(DEPTH) + (2 - 1):2]),
        // as PC increments by 4, disregard PC[2:0]
        .addr_read(readingAddress[$clog2(DEPTH) + (2 - 1):2]),
        .memoryWritingMask(writingMask),
        .data_in(writingData),
        .data_out(ramReadingData)
    );

    //--------------------------------------------------
    // ROM
    //--------------------------------------------------   
    
    // synchronous duo port - support   
    bram_sdp #(
    //custom change 
    .WIDTH(32),
    .DEPTH(DEPTH),
    .INIT(MEMORY_INIT)
    ) ROM (
        .clock_write(clock),
        .clock_read(clock),
        .reset(RESET),
        .write_enable(isROM & writingSignal),
        .read_enable(isROM & readingSignal),
        .addr_write(writingAddress[$clog2(DEPTH) + (2 - 1):2]),
        // as PC increments by 4, disregard PC[2:0]
        .addr_read(readingAddress[$clog2(DEPTH) + (2 - 1):2]),
        .memoryWritingMask(writingMask),
        .data_in(writingData),
        .data_out(romReadingData)
    );

    processor #(
    .MEMORY_INIT(MEMORY_INIT)
    ) processor_inst (
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

    uart #(
        .CLKS_PER_BIT(217)
    ) UART (
        .clock(clock),
        .reset(RESET),
        .uartReadingData(uartReadingData),
        .uartWritingData(writingData[7:0]), // bottom 8 bits matter as UART sends one byte at a time
        .isTX(isTX),
        .RXserial(RXserial),
        .TXserial(TXserial),
        .RXfull(RXfull),
        .TXbusy(TXbusy)
    );
endmodule