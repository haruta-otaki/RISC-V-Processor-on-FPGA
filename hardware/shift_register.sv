`default_nettype none
`timescale 1ns / 1ps

module shift_register #(
	parameter LENGTH=8,
	parameter logic START_BITS=0, // Have to put the type otherwise it's interpreted as 32-bit and the initialization of "out" fails!
	parameter logic MSB_FIRST=1
	) (
    input logic clock,
    input logic reset,
    input logic data,
    input logic enable,
	input logic continuous,

    output logic ready,
	output logic [LENGTH-1:0] out
);

	logic [$clog2(LENGTH+1)-1:0] counter; // One extra counter space included

    always_ff @(posedge clock, posedge reset) begin // Asynchronous reset
		if (reset) begin
			counter <= 0;

			ready <= 0;
			out <= {LENGTH{START_BITS}};
		end
		else if (enable) begin
			if (ready) begin
				ready <= 0;
			end

			if (counter <= LENGTH - 1) begin
				if (MSB_FIRST) begin
					out <= {out[LENGTH-2:0], data};
				end
				else begin
					out <= {data, out[LENGTH-1:1]};
				end

				counter <= counter + 1;
			end
			
			if (counter == LENGTH - 1) begin
				ready <= 1;

                if (continuous) begin
                    counter <= 0;
                end
			end
		end
	end
endmodule
