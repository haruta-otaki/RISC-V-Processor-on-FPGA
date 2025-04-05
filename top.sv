module top (
    input logic clock,
    output logic led1,
    output logic led2,
    output logic led3,
    output logic led4,
    output logic led5
);

    logic [25:0] counter = 0;

    assign led1 = counter[11];
    assign led2 = counter[12];
    assign led3 = counter[13];
    assign led4 = counter[14];
    assign led5 = counter[15];

    always @(posedge clock) begin
        counter <= counter + 1;
    end
endmodule
