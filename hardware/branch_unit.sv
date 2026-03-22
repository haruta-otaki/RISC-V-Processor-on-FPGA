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

module branch_unit (
    input logic [2:0] funct3,
    input logic EQ,
    input logic LT, 
    input logic LTU, 
    output logic branchOutput
   );
    // branches: jumps that compare two registers and update PC based on the result
    // BEQ rs1,rs2,imm	if(rs1 == rs2) PC <- PC+Bimm
    // BNE rs1,rs2,imm	if(rs1 != rs2) PC <- PC+Bimm
    // BLT rs1,rs2,imm	if(rs1 < rs2) PC <- PC+Bimm (signed comparison)
    // BGE rs1,rs2,imm	if(rs1 >= rs2) PC <- PC+Bimm (signed comparison)
    // BLTU rs1,rs2,imm	if(rs1 < rs2) PC <- PC+Bimm (unsigned comparison)
    // BGEU rs1,rs2,imm	if(rs1 >= rs2) PC <- PC+Bimm (unsigned comparison)
    
    always_comb begin
        case(funct3)
        3'b000: branchOutput = EQ;
        3'b001: branchOutput = !EQ;
        3'b100: branchOutput = LT;
        3'b101: branchOutput = !LT;
        3'b110: branchOutput = LTU;
        3'b111: branchOutput = !LTU;
        default: branchOutput = 1'b0;
        endcase
    end
endmodule