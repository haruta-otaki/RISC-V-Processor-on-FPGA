/*
funct3	operation
3'b000	ADD or SUB
3'b001	left shift
3'b010	signed comparison (<)
3'b011	unsigned comparison (<)
3'b100	XOR
3'b101	logical right shift or arithmetic right shift
3'b110	OR
3'b111	AND
*/

module ALU (
    input logic [31:0] instruction, 
    input logic [2:0] state, 
    input logic isALUregister,
    input logic isALUimmediate,
    input logic isBranch,
    input logic [31:0] rs1,
    input logic [31:0] rs2,
    input logic [2:0] funct3,
    input logic [6:0] funct7,
    input logic [31:0] Iimmediate,
    output logic EQ,
    output logic LT,
    output logic LTU,
    output logic [31:0] aluPlus,
    output logic [31:0] aluOutput
   );
    // Rtype: rd <- rs1 OP rs2 (recognized by isALUreg)
    // Itype: rd <- rs1 OP Iimm (recognized by isALUimm) 
    logic [31:0] aluInput1; 
    assign aluInput1 = rs1;

    logic [31:0] aluInput2; 
    assign aluInput2 = (isALUregister || isBranch) ? rs2 : Iimmediate;

    logic [32:0] aluMinus; 
    //A-B in Verilog corresponds to A+~B+1 (negate all the bits of B before adding, and add 1)
    assign aluMinus = {1'b1, ~aluInput2} + {1'b0,aluInput1} + 33'b1;
    assign aluPlus = aluInput1 + aluInput2;

    //EQ, goes high when aluInput1 and aluInput2 have the same value, or aluMinus == 0
    assign EQ = (aluMinus[31:0] == 32'b0);
    //LTU, unsigned comparison, is given by the sign bit of our 33-bits subtraction,
    //true if 33rd bit is 1 or aluMinus is negative and A-B<0, hence A<B; false if otherwise
    assign LTU = aluMinus[32];
    // if the signs differ, then LT goes high if aluInput1 is negative, low otherwise;
    // else it is given by the sign bit of our 33-bits subtraction, same as LTU. 
    assign LT  = (aluInput1[31] ^ aluInput2[31]) ? aluInput1[31] : aluMinus[32];
    
    // Flip (reverse) a 32 bit word. 
    function [31:0] flip32;
        input [31:0] x;
        flip32 = {x[ 0], x[ 1], x[ 2], x[ 3], x[ 4], x[ 5], x[ 6], x[ 7], 
            x[ 8], x[ 9], x[10], x[11], x[12], x[13], x[14], x[15], 
            x[16], x[17], x[18], x[19], x[20], x[21], x[22], x[23],
            x[24], x[25], x[26], x[27], x[28], x[29], x[30], x[31]};
    endfunction


    // uses the shifter for left and right shift by manipulating the input
    // leverages the trick with flip32() for left shift:
    // original -> shift left is the same as reverse original -> shift right -> reverse shifted output
    logic [31:0] shift_input;
    assign shift_input = (funct3 == 3'b001) ? flip32(aluInput1) : aluInput1;

    // shifter merge the two right shifts by creating a 33 bits shifter with the additional bit set to 0 or 1 
    // depending on input's bit 31 and on whether it is a logical shift or an arithmetic shift
    // note that aluInput2[4:0] represents the shift amount
    logic [31:0] shifter;
    assign shifter = $signed({instruction[30] & aluInput1[31], shift_input}) >>> aluInput2[4:0];
    logic [31:0] leftShift;
    assign leftShift = flip32(shifter);

    // replaced always_comb with always @(*)
    // as per the error: "sorry: constant selects in always_* processes are not currently supported"
    always @(*) begin
        case(funct3)
        //for an ALU register operation, the ADD and SUB is determined by testing bit 5 of funct7 (1 for SUB)
        //for an ALU immediate operation, the ADD and SUB is determined by testing bit 5 of instruction (1 for SUB)
        3'b000: aluOutput = (funct7[5] & instruction[5]) ? aluMinus[31:0] : aluPlus;
        3'b001: aluOutput = leftShift;
        3'b010: aluOutput = {31'b0, LT};
        3'b011: aluOutput = {31'b0, LTU};
        3'b100: aluOutput = (aluInput1 ^ aluInput2);
        //logical or arithmetic right shift is determined by testing bit 5 of funct7: 
        // 1 for arithmetic (with sign expansion) and 0 for logical shifts.
        3'b101: aluOutput = shifter;
        3'b110: aluOutput = (aluInput1 | aluInput2);
        3'b111: aluOutput = (aluInput1 & aluInput2);
        endcase
    end
endmodule