// LW(rd,rs1,imm)	Load word at address (rs1+imm) into rd
// LBU(rd,rs1,imm)	Load byte at address (rs1+imm) into rd (without sign extend)
// LHU(rd,rs1,imm)	Load half-word at address (rs1+imm) into rd (without sign extend)
// LB(rd,rs1,imm)	Load byte at address (rs1+imm) into rd then sign extend
// LH(rd,rs1,imm)	Load half-word at address (rs1+imm) into rd then sign extend

module load_unit (
    input logic [2:0] funct3,
    input logic [31:0] LOAD_address,
    input logic [31:0] memoryReadingData,
    output logic [31:0] LOAD_data
   );
    // addresses are aligned on word boundaries for LW (multiple of 4 bytes) 
    // and halfword boundaries for LH, LHU (multiple of 2 bytes)

    // when loading a byte, find which one among 4, and a halfword, which one among 2,
    // done by examining the 2 LSBs of the address of the data to be loaded (rs1 + Iimm)
    logic [15:0] LOAD_halfword; 
    assign LOAD_halfword = LOAD_address[1] ? memoryReadingData[31:16] : memoryReadingData[15:0];
    
    logic [7:0] LOAD_byte; 
    assign LOAD_byte = LOAD_address[0] ? LOAD_halfword[15:8] : LOAD_halfword[7:0];

    logic memoryByteAccess;
    logic memoryHalfwordAccess;

    assign memoryByteAccess     = (funct3[1:0] == 2'b00);
    assign memoryHalfwordAccess = (funct3[1:0] == 2'b01);

    // insert sign expansion for instructions LB,LH, 
    // characterized by funct3[2]=0, and the MSB of the loaded value
    logic LOAD_sign;
    assign LOAD_sign = !funct3[2] & (memoryByteAccess ? LOAD_byte[7] : LOAD_halfword[15]);

    assign LOAD_data = memoryByteAccess ? {{24{LOAD_sign}},     LOAD_byte} :
                memoryHalfwordAccess ? {{16{LOAD_sign}}, LOAD_halfword} :
                memoryReadingData;

endmodule