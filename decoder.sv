// R-type: funct7 rs2 rs1 funct3 rd opcode
// I-type: imm[11:0] rs1 funct3 rd opcode 
// S-type: imm[11:5] rs2 rs1 funct3 imm[4:0] opcode 
// B-type: imm[12|10:5] rs2 rs1 funct3 imm[4:1|11] opcode 
// U-type: imm[31:12] rd opcode 
// J-type: imm[20|10:1|11|19:12] rd opcode 

module decoder (
    input logic [31:0] instruction, 
    output logic isALUregister,
    output logic isALUimmediate,
    output logic isBranch,
    output logic isJALR,
    output logic isJAL,
    output logic isAUIPC,
    output logic isLUI,
    output logic isLoad,
    output logic isStore,
    output logic isSYSTEM,
    output logic [4:0] rs1ID,
    output logic [4:0] rs2ID,
    output logic [4:0] rdID,
    output logic [2:0] funct3,
    output logic [6:0] funct7,
    output logic [31:0] Uimmediate,
    output logic [31:0] Iimmediate,
    output logic [31:0] Simmediate,
    output logic [31:0] Bimmediate,
    output logic [31:0] Jimmediate
    );

    // the 7 LSBs convey the type of instruction
    assign isALUregister  =  (instruction[6:0] == 7'b0110011); // rd <- rs1 OP rs2
    assign isALUimmediate  =  (instruction[6:0] == 7'b0010011); // rd <- rs1 OP Iimm
    assign isBranch  =  (instruction[6:0] == 7'b1100011); // if(rs1 OP rs2) PC<-PC+Bimm
    assign isJALR    =  (instruction[6:0] == 7'b1100111); // rd <- PC+4; PC<-rs1+Iimm
    assign isJAL     =  (instruction[6:0] == 7'b1101111); // rd <- PC+4; PC<-PC+Jimm
    assign isAUIPC   =  (instruction[6:0] == 7'b0010111); // rd <- PC + Uimm
    assign isLUI     =  (instruction[6:0] == 7'b0110111); // rd <- Uimm
    assign isLoad    =  (instruction[6:0] == 7'b0000011); // rd <- mem[rs1+Iimm]
    assign isStore   =  (instruction[6:0] == 7'b0100011); // mem[rs1+Simm] <- rs2
    assign isSYSTEM  =  (instruction[6:0] == 7'b1110011); // special
    
    // registers for rs1, rs2, and rd are within fixed intervals of the instruction
    assign rs1ID = instruction[19:15];
    assign rs2ID = instruction[24:20];
    assign rdID  = instruction[11:7];

    // the funct3 and 7 are within fixed intervals of the instruction for more specific opcode
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];

    // the immediate values differ in location by opcode type of the instruction
    // extend immediates as CPU registers and ALU are 32 bits wide
    // syntax: 
    // - {a, b, c} → concatenates a, b, c
    // {N{X}} → repeats X N times
    assign Uimmediate = {instruction[31], instruction[30:12], {12{1'b0}}};
    assign Iimmediate = {{21{instruction[31]}}, instruction[30:20]};
    assign Simmediate = {{21{instruction[31]}}, instruction[30:25], instruction[11:7]};
    assign Bimmediate = {{20{instruction[31]}}, instruction[7], instruction[30:25] , instruction[11:8], 1'b0};
    assign Jimmediate = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};
    // * U_ and J-types append zero to LSB, because branch addresses are multiples of 2
endmodule

/*
instruction	description	algo
branch	conditional jump, 6 variants if(reg OP reg) PC<-PC+imm
-> compares two registers, if condition is true → jumps & if false → continues.
i.e. BEQ (equal), BNE (not equal), BLT (less than), BGE (greater or equal)
ex) BEQ x1, x2, +16 // if x1 == x2 → jump forward 16 bytes.

ALU reg	Three-registers ALU ops, 10 variants	reg <- reg OP reg
-> takes two registers, performs math/logic, stores result in rd.
i.e. ADD, SUB, AND, OR, XOR, SLL (shift left), SLT (set less than)
ex) ADD x5, x1, x2 // x5 = x1 + x2

ALU imm	Two-registers ALU ops, 9 variants	reg <- reg OP imm
-> same as ALU reg, but second operand is a constant (immediate)
ex) ADDI x5, x1, 10 // x5 = x1 + 10

load	Memory-to-register, 5 variants	reg <- mem[reg + imm]
-> computes address: rs1 + imm, reads memory at that address, and stores result in rd
i.e. LB (Load Byte), LBU (Load Byte Unsigned), LH (Load Halfword),
LHU (Load Halfword Unsigned), LW (Load Word)
ex) LW x5, 8(x1) // x5 = memory[x1 + 8]

store	Register-to-memory, 3 variants	mem[reg+imm] <- reg
-> computes address: rs1 + imm, writes rs2 value into memory
i.e. SB (Store Byte), SH (Store Halfword), SW (Store Word)
ex) SW x5, 8(x1) // memory[x1 + 8] = x5

LUI	load upper immediate	reg <- (im << 12)
-> loads a 20-bit immediate into upper bits of register, used to build large constants.
ex) LUI x5, 0x12345 // x5 = 0x12345000
* implemented to immediately load any 32-bit constant’s upper 20 bits.

AUIPC	add upper immediate to PC	reg <- PC+(im << 12)
-> like LUI, but adds PC, used for position-independent code and 
building addresses relative to current PC
* implemented as useful for jumps, global addresses, position-independent code in terms of PC-relative addressing

JAL	jump and link	reg <- PC+4 ; PC <- PC+imm
-> saves return address in rd and jumps to new location; used for function calls.
ex) JAL x1, +32 // x1 = return address and PC jumps forward 32 bytes

JALR	jump and link register	reg <- PC+4 ; PC <- reg+imm
-> like JAL, but jump target comes from register; used for returning from functions and function pointers
ex) JALR x0, 0(x1) //jump to address stored in x1 (return).

FENCE	memory-ordering for multicores	(not detailed here, skipped for now)
SYSTEM	system calls, breakpoints	(not detailed here, skipped for now)
*/