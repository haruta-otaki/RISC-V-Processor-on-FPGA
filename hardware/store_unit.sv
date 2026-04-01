    // SW(rs2,rs1,imm)	store rs2 at address rs1+imm
    // SB(rs2,rs1,imm)	store 8 LSBs of rs2 at address rs1+imm
    // SH(rs2,rs1,imm)	store 16 LSBs of rs2 at address rs1+imm

    // write mask	Instruction
    // 4'b1111	SW
    // 4'b0011 or 4'b1100	SH, depending on writingAddress[1]
    // 4'b0001, 4'b0010, 4'b0100 or 4'b1000	SB, depending on writingAddress[1:0]

module store_unit (
    input logic [2:0] funct3,
    input logic [31:0] rs2,
    input logic [31:0] writingAddress,
    output logic [3:0] storeWritingMask,
    output logic [31:0] writingData
   );

    logic memoryByteAccess;
    logic memoryHalfwordAccess;

    assign memoryByteAccess     = (funct3[1:0] == 2'b00);
    assign memoryHalfwordAccess = (funct3[1:0] == 2'b01);

    // data to be written depends on the 2 LSBs of the address
    // no need to test because the write mask will ignore MSBs for byte and halfword write
    assign writingData[7:0] = rs2[7:0];
    assign writingData[15:8] = writingAddress[0] ? rs2[7:0] : rs2[15: 8];
    assign writingData[23:16] = writingAddress[1] ? rs2[7:0] : rs2[23:16];
    assign writingData[31:24] = writingAddress[0] ? rs2[7:0] :
                                    writingAddress[1] ? rs2[15:8] : rs2[31:24];

    assign storeWritingMask = 
                memoryByteAccess ? (writingAddress[1] ? 
                (writingAddress[0] ? 4'b1000 : 4'b0100) : (writingAddress[0] ? 4'b0010 : 4'b0001)) : 
                memoryHalfwordAccess ? (writingAddress[1] ? 4'b1100 : 4'b0011) : 4'b1111;

endmodule