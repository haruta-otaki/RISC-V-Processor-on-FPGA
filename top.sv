module top (
    input logic clock,
    output logic led1,
    output logic led2,
    output logic led3,
    output logic led4,
    output logic led5
);

    logic [25:0] counter = 0;

    assign led1 = counter[0];
    assign led2 = counter[22];
    assign led3 = counter[23];
    assign led4 = counter[24];
    assign led5 = counter[25];

    always @(posedge clock) begin
        counter <= counter + 1;
    end
endmodule
