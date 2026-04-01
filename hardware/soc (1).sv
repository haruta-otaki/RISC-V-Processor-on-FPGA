module soc #(
    parameter MEMORY_INIT="memory_state.mem"
    ) (
    input logic clock12m,
`ifdef SIMULATION
    input logic clock48m,
`endif
    input logic reset_button,

    // UART external interface
    input logic rx,
    output logic tx,

    input logic cts,
    output logic rts
);

    // Clock and reset setup
    logic reset;

`ifdef SIMULATION
    assign reset = reset_button;
`else
    logic clock48m;
    logic clocks_locked;

    clock_multiplier clock_multiplier_inst (
        .clock_in(clock12m),
        .clock_out(clock48m),
        .locked(clocks_locked)
    );
    
    assign reset = reset_button | !clocks_locked;
`endif

    ////////////////
    // System Bus //
    ////////////////

    logic bus_write_enable;
    logic bus_read_enable;

    logic [3:0] bus_mask_write;

    logic [21:0] bus_addr_write;
    logic [21:0] bus_addr_read;

    logic [31:0] bus_data_write;
    logic [31:0] bus_data_read;

    //////////////////////////////////////////////
    // Address decoding and chip select signals //
    //////////////////////////////////////////////

    // Address for decoding (use read address if reading, write address if writing)
    logic [21:0] address;
    assign address = (bus_read_enable ? bus_addr_read : (bus_write_enable ? bus_addr_write : 'd0));

    // Decode I/O region (0x0300 - 0x03FF)
    logic is_io;
    assign is_io = (&(~address[21:10]) & &address[9:8]) == 1'b1;

    // Decode individual device regions
    logic is_dev0; // 0x0300 - 0x033F
    logic is_dev1; // 0x0340 - 0x037F
    logic is_dev2; // 0x0380 - 0x03BF
    logic is_dev3; // 0x03C0 - 0x03FF

    assign is_dev0 = is_io & (address[7:6] == 2'b00);
    assign is_dev1 = is_io & (address[7:6] == 2'b01);
    assign is_dev2 = is_io & (address[7:6] == 2'b10);
    assign is_dev3 = is_io & (address[7:6] == 2'b11);

    // Chip select signals
    logic memory_cs;
    logic uart_cs;

    assign memory_cs = !is_io;
    assign uart_cs = is_io & is_dev1;

    ///////////////
    // Processor //
    ///////////////

    processor processor_inst (
        .clock(clock12m),
        .reset(reset),
        .mem_write_enable(bus_write_enable),
        .mem_read_enable(bus_read_enable),
        .mem_mask_write(bus_mask_write),
        .mem_addr_write(bus_addr_write),
        .mem_addr_read(bus_addr_read),
        .mem_data_write(bus_data_write),
        .mem_data_read(bus_data_read)
    );

    ////////////
    // Memory //
    ////////////

    logic [31:0] mem_data_read_out;

    memory #(
        .INIT(MEMORY_INIT)
    ) memory_inst (
        .clock(clock12m),
        .clock4x(clock48m),
        .reset(reset),
        .cs(memory_cs),
        .read_enable(bus_read_enable),
        .write_enable(bus_write_enable),
        .mask_write(bus_mask_write),
        .addr_write(bus_addr_write),
        .addr_read(bus_addr_read),
        .data_write(bus_data_write),
        .data_read(mem_data_read_out)
    );

    //////////
    // UART //
    //////////

    logic uart_interrupt;
    logic uart_use_bus;

    // Bus drives here on !rwb & cs
    // UART drives here rwb & cs
    inout [7:0] uart_data_inout;
    assign uart_data_inout = (bus_write_enable & uart_cs) ? bus_data_write[7:0] : 8'bz;

    uart #(
        .ADDR_WIDTH(2),
        .DATA_WIDTH(8),
        .CLOCK_RATE(12_000_000)
    ) uart_inst (
        .clock(clock12m),
        .clock4x(clock48m),
        .reset(reset),
        .addr(address[1:0]),
        .data(uart_data_inout),
        .cs(uart_cs),
        .rwb(!bus_write_enable),
        .interrupt(uart_interrupt),
        .rx,
        .tx,
        .cts,
        .rts,
        .use_bus(uart_use_bus)
    );

    ///////////////////////////////
    // Bus Read Data Multiplexer //
    ///////////////////////////////

    always_comb begin
        if (uart_cs || uart_use_bus) begin
            // UART read data (8-bit, copied into 32-bit)
            bus_data_read = {uart_data_inout, uart_data_inout, uart_data_inout, uart_data_inout};
        end
        else begin
            bus_data_read = mem_data_read_out;
        end
    end

endmodule
