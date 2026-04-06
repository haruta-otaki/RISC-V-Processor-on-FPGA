`default_nettype none
`timescale 1ns / 1ps

module uart_tx #(
    parameter DATA_WIDTH = 8,
    parameter EVEN_PARITY = 1,
    parameter CLOCK_RATE=12_000_000
    ) (
    input logic clock,
    input logic reset,

    input logic [DATA_WIDTH-1:0] data_send,
    input logic valid_data_send,

    // Other side is indicating a "clear to send" (active low)
    input logic cts,

    output logic tx,
    output logic done_tx
);

    // Baud generator

    logic baud_clock;

    baud_generator #(
        .CLOCK_RATE(CLOCK_RATE)
    ) baud_generator_inst (
        .clock,
        .reset,
        .baud_clock
    );

    logic [DATA_WIDTH+2:0] frame_data_send; // Accounts for start, parity, and stop bits
    logic frame_done_send;

    logic parity;

    assign parity = (EVEN_PARITY ? ^data_send : ~(^data_send));
    assign frame_data_send = {1'b1, parity, data_send, 1'b0};

    logic sr_reset, sr_enable;

    shift_register_reverse #(
        .LENGTH(DATA_WIDTH + 3), // Accounts for start, parity, and stop bits
        .START_BIT(1),
        .MSB_FIRST(0)
    ) inst_shift_register_reverse (
        .clock(baud_clock),
        .reset(sr_reset),
        .data(frame_data_send),
        .enable(sr_enable),
        .continuous(1'b0),
        .ready(frame_done_send),
        .out(tx)
    );

    always_ff @(posedge clock) begin
        if (sr_reset) begin
            sr_reset <= 0;
        end

        if (done_tx) begin
            done_tx <= 0;
        end

        if (frame_done_send) begin
            sr_reset <= 1;
            done_tx <= 1;
        end

        if (reset) begin
            sr_reset <= 1;
        end
    end

    // RTS and CTS are active low: (CTS == 0 [active] when RTS == 0 [active] on the other side)
    assign sr_enable = (valid_data_send && !cts);

endmodule

// module uart_TX 
//     // CLKS_PER_BIT = (Frequency of clock)/(Frequency of UART)
//     // (25 MHz Clock)/(115200 baud) = 217
//     #(parameter CLKS_PER_BIT = 217)
//     (
//     input logic clock,
//     input logic reset, 
//     input logic TXvalid,
//     input logic [7:0] TXbyte, 
//     output logic TXactive,
//     output logic TXserial
//     );

//     parameter IDLE         = 2'b00;
//     parameter TX_START_BIT = 2'b01;
//     parameter TX_DATA_BITS = 2'b10;
//     parameter TX_STOP_BIT  = 2'b11;

//     logic [1:0] state;
//     logic [$clog2(CLKS_PER_BIT):0] clockCount;
//     logic [2:0] index;
//     logic [7:0] TXdata;

//     // Control TX state machine
//     always @(posedge clock or posedge reset)
//     begin
//         if (reset)
//         begin
//             state <= IDLE; 
//             clockCount <= 0;
//             index <= 0;
//             TXserial <= 1'b1;
//             TXactive   <= 1'b0;
//         end
//         else 
//         begin
//             case (state)
//                 IDLE :
//                 begin
//                     TXserial <= 1'b1; // Drive Line High for Idle
//                     clockCount <= 0;
//                     index <= 0;
                    
//                     if (TXvalid == 1'b1)
//                     begin
//                         TXactive <= 1'b1;
//                         // prevents conflicts for when TXbyte changes during processing
//                         TXdata <= TXbyte;
//                         state <= TX_START_BIT;
//                     end
//                     else
//                         state <= IDLE;
//                 end 

//                 // Send out Start Bit, wait CLKS_PER_BIT-1 clock cycles 
//                 TX_START_BIT :
//                 begin
//                     TXserial <= 1'b0;
//                     if (clockCount < CLKS_PER_BIT-1)
//                     begin
//                         clockCount <= clockCount + 1;
//                         state <= TX_START_BIT;
//                     end
//                     else
//                     begin
//                         clockCount <= 0;
//                         state <= TX_DATA_BITS;
//                     end
//                 end 
                
//                 TX_DATA_BITS :
//                 begin
//                     TXserial <= TXdata[index];
                    
//                     if (clockCount < CLKS_PER_BIT-1)
//                     begin
//                         clockCount <= clockCount + 1;
//                         state <= TX_DATA_BITS;
//                     end
//                     else
//                     begin
//                         clockCount <= 0;
//                         // check if we have sent out all bits
//                         if (index < 7)
//                         begin
//                             index <= index + 1;
//                             state <= TX_DATA_BITS;
//                         end
//                         else
//                             state <= TX_STOP_BIT;
//                     end 
//                 end 
                
//                 // Send out Stop bit
//                 TX_STOP_BIT :
//                 begin
//                     TXserial <= 1'b1;
//                     if (clockCount < CLKS_PER_BIT-1)
//                     begin
//                         clockCount <= clockCount + 1;
//                         state <= TX_STOP_BIT;
//                     end
//                     else
//                     begin
//                         TXactive   <= 1'b0;
//                         state     <= IDLE;
//                     end 
//                 end 
                
//                 default :
//                 state <= IDLE;
//             endcase
//         end
//   end
// endmodule