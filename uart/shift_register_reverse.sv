`default_nettype none
`timescale 1ns / 1ps

module shift_register_reverse #(
	parameter LENGTH=8,
	parameter logic MSB_FIRST=1, // Have to put the type to specify it's a bit, not an integer 1
	parameter logic START_BIT=0
	) (
    input logic clock,
    input logic reset,
    input logic [LENGTH-1:0] data,
    input logic enable,
	input logic continuous,

    output logic ready,
	output logic out
);

	logic [$clog2(LENGTH+1)-1:0] counter; // One extra counter space included

    always_ff @(posedge clock, posedge reset) begin // Asynchronous reset
		if (reset) begin
			counter <= 0;

			ready <= 0;
			out <= START_BIT;
		end
		else if (enable) begin
			if (ready) begin
				ready <= 0;
			end

			if (counter <= LENGTH - 1) begin
				if (MSB_FIRST) begin
					out <= data[LENGTH - 1 - counter];
				end
				else begin
					out <= data[counter];
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
