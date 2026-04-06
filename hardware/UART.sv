`default_nettype none
`timescale 1ns / 1ps

module uart #(
    parameter ADDR_WIDTH=2,
    parameter DATA_WIDTH=8,
    parameter FIFO_SIZE=16,
    parameter CLOCK_RATE=12_000_000
) (
    // Internal interface

    input logic clock,
    input logic reset,

    input logic [ADDR_WIDTH-1:0] addr,
    inout wire logic [DATA_WIDTH-1:0] data,

    input logic cs,
    input logic rwb,

    output logic interrupt,

    // External interface

    input logic rx,
    output logic tx,

    input logic cts,
    output logic rts,

    output logic use_bus
);
    // Transmission control

    logic use_transmission, done_transmission;
    logic transmitting;

    logic wait_tx;
    logic wait_rx;

    logic [DATA_WIDTH-1:0] status_register;


    // Send logic

    logic [DATA_WIDTH-1:0] fifo_tx_data_in, fifo_tx_data_out;
    logic fifo_tx_write_enable, fifo_tx_read_enable;

    logic fifo_tx_empty, fifo_tx_full;

    // Recv logic

    logic [DATA_WIDTH-1:0] fifo_rx_data_in, fifo_rx_data_out;
    logic fifo_rx_write_enable, fifo_rx_read_enable;

    logic fifo_rx_empty, fifo_rx_full;

    // Bus interface

    logic r_external, w_external;
    
    logic bus_outgoing, bus_incoming;
    logic [DATA_WIDTH-1:0] bus_incoming_data;
    
    // r_pending is used to linger using the bus in multicycle implementations (like RISC-V)
    // w_pending is used to notify a write mid-cycle in single-cycle implementations (like 6502)
    logic r_pending, w_pending;

    logic [ADDR_WIDTH-1:0] r_addr; // Sequential
    logic [ADDR_WIDTH-1:0] w_addr; // Sequential

    logic [DATA_WIDTH-1:0] r_data; // Sequential
    logic [DATA_WIDTH-1:0] w_data; // Sequential

    logic [DATA_WIDTH-1:0] r_data_comb; // Combinatorial

    assign transmitting = (use_transmission && !done_transmission);

    assign wait_tx = fifo_tx_full;
    assign wait_rx = fifo_rx_empty & !interrupt;

    // UART registers
    // 0: Last byte received (valid when interrupt == 1; clears interrupts when read)
    // 1: Byte to send (the only writeable byte in the register)
    // 2: Status register
    // 3: Not used

    assign status_register = {interrupt, 1'b0, fifo_tx_full, fifo_tx_empty, fifo_rx_full, fifo_rx_empty, wait_rx, wait_tx};

    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(FIFO_SIZE)
    ) fifo_tx (
        .clock,
        .reset,
        .write_enable(fifo_tx_write_enable),
        .read_enable(fifo_tx_read_enable),
        .data_in(fifo_tx_data_in),
        .data_out(fifo_tx_data_out),
        .empty(fifo_tx_empty),
        .full(fifo_tx_full)
    );

    uart_tx #(
        .DATA_WIDTH(DATA_WIDTH),
        .EVEN_PARITY(1),
        .CLOCK_RATE(CLOCK_RATE)
    ) uart_tx_inst (
        .clock,
        .reset,
        .data_send(fifo_tx_data_out),
        .valid_data_send(use_transmission),
        .cts, // RTS and CTS are active low: (CTS == 0 [active] when RTS == 0 [active] on the other side)
        .tx,
        .done_tx(done_transmission)
    );

    uart_rx #(
        .DATA_WIDTH(DATA_WIDTH),
        .EVEN_PARITY(1),
        .CLOCK_RATE(CLOCK_RATE)
    ) uart_rx_inst (
        .clock,
        .reset,
        .rx,
        .data_recv(fifo_rx_data_in),
        .done_recv(fifo_rx_write_enable)
    );

    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(FIFO_SIZE)
    ) fifo_rx (
        .clock,
        .reset,
        .write_enable(fifo_rx_write_enable),
        .read_enable(fifo_rx_read_enable),
        .data_in(fifo_rx_data_in),
        .data_out(fifo_rx_data_out),
        .empty(fifo_rx_empty),
        .full(fifo_rx_full)
    );

    // Main loop

    always_ff @(posedge clock, posedge reset) begin
        if (reset) begin
            fifo_rx_read_enable <= 0;
            fifo_tx_read_enable <= 0;
            fifo_tx_write_enable <= 0;

            use_transmission <= 0;

            interrupt <= 0;
        end
        else begin
            // Starts send upon application-incoming data or non-empty transmission queue,
            // but only when a trasmission is not pending to be completed

            if ((fifo_tx_write_enable || !fifo_tx_empty) && !transmitting) begin
                fifo_tx_read_enable <= 1;
            end

            // Starts recv for application upon network-incoming data or non-empty receive queue,
            // but only when an interrupt is not pending to be collected

            if ((fifo_rx_write_enable || !fifo_rx_empty) && !interrupt) begin
                fifo_rx_read_enable <= 1;
            end

            // Clears signals that should only last one clock cycle 

            if (fifo_rx_read_enable) begin
                fifo_rx_read_enable <= 0;

                interrupt <= 1;
            end

            if (fifo_tx_write_enable) begin
                fifo_tx_write_enable <= 0;
            end

            if (fifo_tx_read_enable) begin
                fifo_tx_read_enable <= 0;

                use_transmission <= 1;
            end

            if (done_transmission) begin
                use_transmission <= 0;
            end

            if (bus_outgoing) begin
                interrupt <= 0;
            end

            if (bus_incoming) begin
                fifo_tx_write_enable <= 1;
                fifo_tx_data_in <= bus_incoming_data;
            end
        end
    end


    assign r_external = (cs && rwb);
    assign w_external = (cs && !rwb);

    assign bus_outgoing = r_external && (addr == 'b00);


    always_comb begin
        // Zero-valued reads unless reading from address 0 or 2
        // The default value is important because a combinatorial path without a default value
        // must retain the old state, therefore necessitating a latch to react properly in a combinatorial manner
        // Latches are hard to reason with timing, and will require more resources due to the storage aspect.

        case (addr)
            'b00:
                r_data_comb = fifo_rx_data_out;
            'b10:
                r_data_comb = status_register;
            default:
                r_data_comb = 0;
        endcase
    end

`ifdef TARGET_6502
    // Combinatorial reads with address available in the posedge
    // Sequential write with address available in the posedge and data available in the negedge

    always_ff @(negedge clock) begin
        // Clear the write pending signal
        w_pending <= 0;

        if (w_external) begin
            w_addr <= addr; // Was available earlier, but still available here
            w_data <= data;

            // Schedules the writes on the upcoming posedge
            w_pending <= 1;
        end
    end

    // Writes are performed in the posedge

    always_ff @(posedge clock, posedge reset) begin
        if(reset) begin
            w_addr <= '0;
            w_data <= '0;
            w_pending <= 0;
        end
    end

    assign bus_incoming = w_pending && (addr == 'b01);
    assign bus_incoming_data = w_data;

    assign use_bus = r_external;
    assign data = (r_external ? r_data_comb : 'bz);
`else
    always_ff @(posedge clock, posedge reset) begin
        if(reset) begin
            r_data <= '0;
            r_pending <= 0;
        end
        else begin
            // Clear the read pending signal
            r_pending <= 0;

            if (r_external) begin
                    r_pending <= 1;

                    case (addr)
                        'b00: begin
                            r_data <= fifo_rx_data_out;
                        end
                        'b10: begin
                            r_data <= status_register;
                        end
                    endcase
            end
        end
    end

    assign bus_incoming = w_external && (addr == 'b01);
    assign bus_incoming_data = data;

    assign use_bus = r_external | r_pending;
    assign data = (r_external ? r_data_comb : (r_pending ? r_data : 'bz));
`endif

    // RTS and CTS are active low: (RTS == 0 [active] when fifo_rx not full)
    // By default, fifo_rx notifies being full at 80% of load
    assign rts = fifo_rx_full;

endmodule


// module uart   
//   # (parameter CLKS_PER_BIT = 217)
//   (
//     input logic clock, 
//     input logic reset, 
//     output logic [7:0] uartReadingData,
//     input logic [7:0] uartWritingData,  
//     input logic isRX, 
//     input logic isTX, 
//     input logic RXserial, 
//     output logic TXserial,
//     output logic RXfull,
//     output logic TXbusy,
//     input logic readingSignal
//   );
  
//   logic [7:0] currentReadingData;
//   logic waitingRX; 
//   logic currentTXserial; 

//   uart_RX #(
//     .CLKS_PER_BIT(CLKS_PER_BIT)
//   )
//   UART_RX
//     (
//     .clock(clock),
//     .reset(reset),
//     .RXserial(RXserial),
//     .RXvalid(RXfull),
//     .RXbyte(currentReadingData)
//     );

//   always @(posedge clock or posedge reset) 
//   begin
//     if (reset)
//     begin
//       uartReadingData <= 0; 
//       waitingRX <= 0; 
//     end
//     else 
//     begin 
//       if (RXfull)
//       begin 
//           uartReadingData  <= currentReadingData;
//           waitingRX <= 1;
//       end
//       if (isRX & readingSignal) 
//       begin
//         waitingRX <= 0; 
//       end
//     end
//   end

//   uart_TX #(
//     .CLKS_PER_BIT(CLKS_PER_BIT)
//   )
//   UART_TX
//     (
//       .clock(clock),
//       .reset(reset),
//       .TXvalid(isTX),
//       .TXbyte(uartWritingData),
//       .TXactive(TXbusy),
//       .TXserial(currentTXserial)
//     );

//   // drive UART transmitter high when transmitter is inactive
//   assign TXserial = TXbusy ? currentTXserial : 1'b1; 

// endmodule
