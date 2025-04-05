module top (
    input wire clock,
    output wire led1,
    output wire led2,
    output wire led3,
    output wire led4,
    output wire led5
);

    reg [25:0] counter = 0;

    assign led1 = counter[11];
    assign led2 = counter[12];
    assign led3 = counter[13];
    assign led4 = counter[14];
    assign led5 = counter[15];

    always @(posedge clock) begin
        counter <= counter + 1;
    end
endmodule
