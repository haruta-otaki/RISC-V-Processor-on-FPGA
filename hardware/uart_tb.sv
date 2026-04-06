`default_nettype none
`timescale 1ns / 1ps

`define SIMULATION

module uart_tb #(
    parameter ADDR_WIDTH = 2,
    parameter DATA_WIDTH = 8,
    parameter FIFO_SIZE  = 16
);
    // Clock and reset
    logic clock;
    logic clock4x;
    logic reset;

    // Internal bus signals for sender
    logic [ADDR_WIDTH-1:0] addr_s;
    tri   [DATA_WIDTH-1:0] data_s;
    logic cs_s;
    logic rwb_s;
    logic interrupt_s;

    // External UART signals
    logic rx_s;
    logic tx_s;
    logic cts_s;
    logic rts_s;

    // Internal bus for receiver
    logic [ADDR_WIDTH-1:0] addr_r;
    tri   [DATA_WIDTH-1:0] data_r;
    logic cs_r;
    logic rwb_r;
    logic interrupt_r;

    logic tx_r;
    logic rx_r;
    logic cts_r;
    logic rts_r;

    // Drive clock
    initial clock = 0;
    initial clock4x = 0;

    localparam CLOCK_HALF_PERIOD = 40;  // 12.5 MHz
    localparam CLOCK_4X_HALF_PERIOD = 10;  // 50 MHz

    always #(CLOCK_HALF_PERIOD) clock = ~clock;
    always #(CLOCK_4X_HALF_PERIOD) clock4x = ~clock4x;

    // Instantiate sender UART
    uart #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_SIZE(FIFO_SIZE)
    ) uut_s (
        .clock,
        .clock4x,
        .reset,
        .addr(addr_s),
        .data(data_s),
        .cs(cs_s),
        .rwb(rwb_s),
        .interrupt(interrupt_s),
        .rx(rx_s),
        .tx(tx_s),
        .cts(cts_s),
        .rts(rts_s)
    );

    // Instantiate receiver UART
    uart #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_SIZE(FIFO_SIZE)
    ) uut_r (
        .clock,
        .clock4x,
        .reset,
        .addr(addr_r),
        .data(data_r),
        .cs(cs_r),
        .rwb(rwb_r),
        .interrupt(interrupt_r),
        .rx(rx_r),
        .tx(tx_r),
        .cts(cts_r),
        .rts(rts_r)
    );

    // Link uarts
    assign rx_r = tx_s;
    assign rx_s = tx_r;

    assign cts_r = rts_s;
    assign cts_s = rts_r;

    // Bidirectional data bus for sender
    logic [DATA_WIDTH-1:0] data_out_s;
    assign data_s = (!rwb_s && cs_s) ? data_out_s : 'bz;

    logic [DATA_WIDTH-1:0] data_in_s;
    always_comb if (rwb_s && cs_s) data_in_s = data_s;

    // Bidirectional data bus for receiver
    logic [DATA_WIDTH-1:0] data_out_r;
    assign data_r = (!rwb_r && cs_r) ? data_out_r : 'bz;

    logic [DATA_WIDTH-1:0] data_in_r;
    always_comb if (rwb_r && cs_r) data_in_r = data_r;

    // Read received value
    logic [DATA_WIDTH-1:0] received_byte;

    // Test sequence
    initial begin
        $dumpfile("uart_tb.vcd");   // Output file for GTKWave
        $dumpvars(0, uut_s);        // Dump everything under the sender
        $dumpvars(0, uut_r);        // Dump everything under the receiver

        $display("Starting UART test...");

        reset = 0;
        #CLOCK_HALF_PERIOD;
        reset = 1;
        #CLOCK_HALF_PERIOD;
        reset = 0;
        #CLOCK_HALF_PERIOD;

        cs_s = 0;
        rwb_s = 1;
        addr_s = 0;
        data_out_s = 'b0;

        cs_r = 0;
        rwb_r = 1;
        addr_r = 0;
        data_in_r = 'b0;

        // Send characters
        write_uart(2'b01, 8'h41);
        write_uart(2'b01, 8'h51);
        write_uart(2'b01, 8'h61);
        write_uart(2'b01, 8'h71);
        write_uart(2'b01, 8'h81);
        write_uart(2'b01, 8'h91);

        // Wait for receive interrupt, print characters
        receive();
        receive();
        receive();
        receive();
        receive();
        receive();

        $display("UART test finished.");
        $finish;
    end

    task receive;
        begin
            wait (interrupt_r == 1);
            read_uart_r(2'b00, received_byte);
            $display("Received byte: %h", received_byte);
        end
    endtask

    // UART bus write task (sender)
    task write_uart(input logic [ADDR_WIDTH-1:0] a, input logic [DATA_WIDTH-1:0] d);
        begin
            @(negedge clock);
                #10;
                addr_s = a;
                #10;
                data_out_s = d;
                #10;
                rwb_s = 0;
                #10;
                cs_s = 1;
            @(posedge clock);

            @(negedge clock);
                #40;
                cs_s = 0;
                #10;
            @(posedge clock);
        end
    endtask

    // UART bus read task (receiver)
    task read_uart_r(input logic [ADDR_WIDTH-1:0] a, output logic [DATA_WIDTH-1:0] d);
        begin
            @(negedge clock);
                #40;
                addr_r = a;
                #10;
                rwb_r = 1;
                #10;
                cs_r = 1;
            @(posedge clock);

            @(negedge clock);
                d = data_r;
                #40;
                cs_r = 0;
                #10;
            @(posedge clock);
        end
    endtask
endmodule

