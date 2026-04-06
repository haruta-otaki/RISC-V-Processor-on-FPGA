`default_nettype none
`timescale 1ns / 1ps

module uart_rx #(
    parameter DATA_WIDTH = 8,
    parameter EVEN_PARITY = 1,
    parameter CLOCK_RATE=12_000_000
    ) (
    input logic clock,
    input logic reset,

    input logic rx,

    output logic [DATA_WIDTH-1:0] data_recv,
    output logic done_recv
);

    // Baud generator

    logic baud_clock;
    logic bg_reset;

    baud_generator #(
        .CLOCK_RATE(CLOCK_RATE)
    ) baud_generator_inst (
        .clock,
        .reset(bg_reset),
        .baud_clock
    );

    logic [DATA_WIDTH+2:0] frame_data_recv; // Accounts for start, parity, and stop bits
    logic frame_done_recv;

    logic parity_ok, well_formed;

    assign parity_ok = (EVEN_PARITY ? ~(^frame_data_recv[DATA_WIDTH+1:1]) : ^frame_data_recv[DATA_WIDTH+1:1]);
    assign well_formed = ((frame_data_recv[0] == 1'b0) && parity_ok && (frame_data_recv[DATA_WIDTH+2] == 1'b1));

    logic sr_reset, sr_enable;

    shift_register #(
        .LENGTH(DATA_WIDTH + 3), // Accounts for start, parity, and stop bits
        .START_BITS(1),
        .MSB_FIRST(0)
    ) inst_shift_register (
        .clock(baud_clock),
        .reset(sr_reset),
        .data(rx),
        .enable(sr_enable),
        .continuous(1'b1),
        .ready(frame_done_recv),
        .out(frame_data_recv)
    );

    logic receiving;

    always_ff @(posedge clock) begin
        if (sr_reset) begin
            sr_reset <= 0;
        end

        if (bg_reset) begin
            bg_reset <= 0;
        end

        if (!receiving && rx == 1'b0) begin
            sr_reset <= 1;
            bg_reset <= 1;

            receiving <= 1;
        end

        if (frame_done_recv) begin
            sr_reset <= 1;

            receiving <= 0;
        end

        if (reset) begin
            bg_reset <= 1;
            sr_reset <= 1;

            receiving <= 0;
        end
    end

    // The receiving register is always enabled: "well-formedness" triggers a receive
    assign sr_enable = 1;

    assign data_recv = frame_data_recv[DATA_WIDTH:1];
    assign done_recv = (frame_done_recv & well_formed);

endmodule


// module uart_RX
// 	// CLKS_PER_BIT = (Frequency of clock)/(Frequency of UART)
// 	//(25 MHz Clock)/(115200 baud) = 217
// 	#(parameter CLKS_PER_BIT = 217)
// 	(
// 		input logic clock,
// 		input logic reset, 
// 		// raw 1-bit serial line coming in from the outside world
// 		input logic RXserial,
// 		// pulses high for one clock when a full valid byte has been received
// 		output logic  RXvalid,
// 		// fully assembled received byte
// 		output logic  [7:0] RXbyte
// 	);

// 	// receive 8 bits of serial data, one start bit, one stop bit, and no parity bit.
// 	parameter IDLE         = 3'b000;
// 	parameter RX_START_BIT = 3'b001;
// 	parameter RX_DATA_BITS = 3'b010;
// 	parameter RX_STOP_BIT  = 3'b011;
// 	parameter CLEANUP      = 3'b100;

// 	// counts clock cycles within the current bit period. 
// 	logic [$clog2(CLKS_PER_BIT):0] clockCount;
// 	// tracks which of the 8 data bits you're currently receiving
// 	logic [2:0] index; 
// 	// holds the current state
// 	logic [2:0] state;

// 	//Control RX state machine
// 	always @(posedge clock or posedge reset)
// 	begin
// 	if (reset)
// 	begin
// 		state <= IDLE; 
// 		clockCount <= 0;
// 		index <= 0;
// 		RXvalid <= 1'b0;
// 	end
// 	else 
// 	begin
// 	case (state)
// 		IDLE :
// 		begin
// 			clockCount <= 0;
// 			index <= 0;
// 			RXvalid <= 1'b0;

// 			if (RXserial == 1'b0) // Start bit detected
// 				state <= RX_START_BIT;
// 			else
// 				state <= IDLE;
// 		end

// 		RX_START_BIT :
// 		begin
// 			// check middle of start bit to make sure it's still low
// 			if (clockCount == (CLKS_PER_BIT-1)/2)
// 			begin
// 				if (RXserial == 1'b0)
// 				begin
// 					// reset counter, found the middle 
// 					clockCount <= 0; 
// 					state <= RX_DATA_BITS;
// 				end
// 				else
// 				begin
// 					// error, wait for the next data byte  
// 					state <= IDLE; 	
// 				end
// 			end
// 			else
// 			begin
// 				// if not yet in the middle, wait for the increment the counter and maintain state (avoid sampling at edges)
// 				clockCount <= clockCount + 1;
// 				state <= RX_START_BIT;
// 			end
// 		end
		
// 		// Wait CLKS_PER_BIT-1 clock cycles to sample serial data
// 		RX_DATA_BITS :
// 		begin
// 			// check for when the clock count is at its limit
// 			if (clockCount < CLKS_PER_BIT-1)
// 			begin
// 				// if not, increment clock count and maintain state
// 				clockCount <= clockCount + 1;
// 				state <= RX_DATA_BITS;
// 			end
// 			else
// 			begin
// 				// sample line and reset counter 
// 				clockCount <= 0;
// 				// update which bit in the byte we are loading 
// 				RXbyte[index] <= RXserial;
// 				// Check if we have received all bits
// 				if (index < 7)
// 				begin
// 					// increment index 
// 					index <= index + 1;
// 					state <= RX_DATA_BITS;
// 				end
// 				else
// 				begin
// 					// stop receiving 
// 					state <= RX_STOP_BIT;
// 				end
// 			end
// 		end 
		
// 		// receive Stop bit. 
// 		RX_STOP_BIT :
// 		begin
// 			if (clockCount < CLKS_PER_BIT-1)
// 			begin
// 			clockCount <= clockCount + 1;
// 			state <= RX_STOP_BIT;
// 			end
// 			else
// 			begin
// 				clockCount <= 0;
// 				// check stop bit is high
// 				if (RXserial == 1'b1)
// 				begin
// 					RXvalid <= 1'b1;
// 					state <= CLEANUP;
// 				end
// 				else
// 				begin
// 					// framing error: stop bit not high, discard byte
// 					RXvalid <= 1'b0;
// 					state <= IDLE;
// 				end
// 			end
// 		end 
// 		// wait 1 clock cycle before returning to idle state 
// 		CLEANUP :
// 		begin
// 			// the RXvalid is verification that the received byte is valid  
// 			state <= IDLE;
// 			RXvalid <= 1'b0;
// 		end
// 		default :
// 			state <= IDLE;
// 		endcase
// 		end
// 	end    
// endmodule 