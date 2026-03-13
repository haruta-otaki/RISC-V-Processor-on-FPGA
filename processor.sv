module processor #(
    parameter MEMORY_INIT
    ) (
    input logic clock,
    input logic reset,
    output logic [31:0] memoryWritingData,
    output logic [31:0] memoryWritingAddress,
    output logic memoryWritingSignal,
    output logic [3:0] memoryWritingMask,
    input logic [31:0] memoryReadingData,
    output logic [31:0] memoryReadingAddress,
    output logic memoryReadingSignal,
    output logic [31:0] x1
    );
    
    //clear comb logic from seq (always_ff block)

    //the synthesizer automatically computes all variables relating to the sequential logic 
    // after the combinatorial logic per clock cycle automatically, hence there is a lot of bloat to be cut down! 

    logic [31:0] PC;
    logic [31:0] nextPC; 
    logic [31:0] PCImmediate;

    parameter HALT = 3'b000;
    parameter INIT = 3'b001;
    parameter FETCH = 3'b010;
    parameter DECODE = 3'b011;
    parameter EXECUTE = 3'b100;
    parameter MEMORY = 3'b101;
    parameter WRITE_BACK = 3'b110;

    logic [2:0] state;
    logic [31:0] RegisterBank [0:31];

    logic [31:0] rs1;
    logic [31:0] rs2;

    logic [31:0] writeBackData;
    logic writeBackEnable;
    logic [31:0] writeBackAddress; 

    logic [31:0] LOAD_address;
    logic [31:0] LOAD_data;
    
    logic [3:0] storeWritingMask;
    
    logic [31:0] aluOutput;
    logic branchOutput;
    logic [31:0] aluSum;
    logic EQ; 
    logic LT; 
    logic LTU;

    logic [31:0] instruction;
    logic [31:0] fetched_instruction;

    logic isALUregister;
    logic isALUimmediate;
    logic isBranch;
    logic isJALR;
    logic isJAL;
    logic isAUIPC;
    logic isLUI;
    logic isLoad;
    logic isStore;
    logic isSYSTEM;

    logic [4:0] rs1ID;
    logic [4:0] rs2ID;
    logic [4:0] rdID;

    logic [2:0] funct3;
    logic [6:0] funct7;

    logic [31:0] Uimmediate;
    logic [31:0] Iimmediate;
    logic [31:0] Simmediate;
    logic [31:0] Bimmediate;
    logic [31:0] Jimmediate;

    //--------------------------------------------------
    // DECODER
    //--------------------------------------------------  

    decoder decoder_inst(
    .instruction(instruction), 
    .isALUregister(isALUregister),
    .isALUimmediate(isALUimmediate),
    .isBranch(isBranch),
    .isJALR(isJALR),
    .isJAL(isJAL),
    .isAUIPC(isAUIPC),
    .isLUI(isLUI),
    .isLoad(isLoad),
    .isStore(isStore),
    .isSYSTEM(isSYSTEM),
    .rs1ID(rs1ID),
    .rs2ID(rs2ID),
    .rdID(rdID),
    .funct3(funct3),
    .funct7(funct7),
    .Uimmediate(Uimmediate),
    .Iimmediate(Iimmediate),
    .Simmediate(Simmediate),
    .Bimmediate(Bimmediate),
    .Jimmediate(Jimmediate)
    );

    //--------------------------------------------------
    // ALU
    //--------------------------------------------------   

    ALU ALU_inst (
    .instruction(instruction), 
    .state(state), 
    .isALUregister(isALUregister),
    .isALUimmediate(isALUimmediate),
    .isBranch(isBranch),
    .rs1(rs1),
    .rs2(rs2),
    .funct3(funct3),
    .funct7(funct7),
    .Iimmediate(Iimmediate),
    .EQ(EQ),
    .LT(LT),
    .LTU(LTU),
    // in the context used, aluSum = rs1 + Immediate
    .aluPlus(aluSum),
    .aluOutput(aluOutput)
    );

    //--------------------------------------------------
    // Branch Unit
    //--------------------------------------------------   

    branch_unit branch_unit_inst (
    .funct3(funct3),
    .EQ(EQ),
    .LT(LT),
    .LTU(LTU),
    .branchOutput(branchOutput)
    );

    //--------------------------------------------------
    // Load Unit
    //--------------------------------------------------   

    load_unit load_unit_inst (
    .funct3(funct3),
    .LOAD_address(LOAD_address),
    .memoryReadingData(memoryReadingData),
    .LOAD_data(LOAD_data)
   );

    //--------------------------------------------------
    // Store Unit
    //--------------------------------------------------   

    store_unit store_unit_inst (
    .funct3(funct3),
    .rs2(rs2),
    .memoryWritingAddress(memoryWritingAddress),
    .storeWritingMask(storeWritingMask),
    .memoryWritingData(memoryWritingData)
   );

    assign instruction = (state == DECODE ? memoryReadingData : fetched_instruction);
    assign memoryReadingAddress = (state == FETCH) ? PC : LOAD_address;
    assign memoryWritingMask = {4{(state == MEMORY)}} & storeWritingMask;

    // fetch rs1 and rs2 
    assign rs1 = RegisterBank[rs1ID];
    assign rs2 = RegisterBank[rs2ID];

    assign nextPC = PC + 4;

    //--------------------------------------------------
    // Finite State Machine
    //--------------------------------------------------   

    always @(posedge clock or posedge reset)
    begin
    if (reset)
    begin
        state <= INIT; 
        for(int i=0; i<32; i++) 
            RegisterBank[i] <= 0;
    end 
    else 
    begin
    case (state)
        HALT :
            begin
            // //display results 
            // $display("x1:%d expected:5", RegisterBank[1]);
            // $display("x2:%d expected:5", RegisterBank[2]);
            // $display("x6:%d expected:0", RegisterBank[6]);
            // $display("x7:%d expected:3", RegisterBank[7]);
            // $display("x9:%d expected:5", RegisterBank[9]);

            `ifdef SIMULATION
                $finish;
            `endif
            end     
        INIT :
            begin
                memoryReadingSignal <= 1; 
                PC <= 0; 
                state <= FETCH;
            end

        FETCH :
            begin
                // fetched_instruction <= instruction; 
                memoryReadingSignal <= 0; 
                state <= DECODE;
            end 

        DECODE :
            begin
                //instruction isn't updated until FETCH; why? 
                fetched_instruction <= instruction; 
                $display("PC: %d, instruction:%h", PC/4, instruction);
                
                if(isSYSTEM || $isunknown(instruction)) 
                    state <= HALT;
                else 
                    state <= EXECUTE;

                PCImmediate <= PC + (isJAL? Jimmediate[31:0] :
                            isAUIPC ? Uimmediate[31:0] :
                            Bimmediate[31:0]);

                case (1'b1)
                isALUregister: $display("isALUregister rdID=%d rs1ID=%d rs2ID=%d funct3=%b",rdID, rs1ID, rs2ID, funct3);
                isALUimmediate: $display("isALUimmediate rdID=%d rs1ID=%d imm=%0d funct3=%b",rdID, rs1ID, Iimmediate, funct3);
                isBranch: $display("BRANCH");
                isJAL:    $display("JAL");
                isJALR:   $display("JALR");
                isAUIPC:  $display("AUIPC");
                isLUI:    $display("LUI");
                isLoad:   $display("LOAD");
                isStore:  $display("STORE");
                isSYSTEM: $display("SYSTEM");
                endcase
            end 
        
        EXECUTE :
            begin
                // compute rs1 OP rs2
                // The signal writeBackEnable is asserted whenever writeBackData should be written to register rdId. 
                // The data to be written back will be obtained from the ALU or current PC dependent on a case-by-case basis

                // Jumps: 
                // JAL rd,imm rd<-PC+4; PC<-PC+Jimm
                // JALR rd,rs1,imm	rd<-PC+4; PC<-rs1+Iimm
                // Load Upper Immediates: 
                // LUI rd, imm	rd <= Uimm
                // AUIPC rd, imm rd <= PC + Uimm
                writeBackData <= (isJAL || isJALR) ? (nextPC) :
                                (isLUI) ? Uimmediate :
                                (isAUIPC) ? PCImmediate :
                                aluOutput;

                if (isLoad)
                begin
                    memoryReadingSignal <= 1; 
                    LOAD_address <= rs1 + Iimmediate;
                end 
                if (isStore)
                begin 
                    memoryWritingSignal <= 1; 
                    memoryWritingAddress <= rs1 + Simmediate;
                end

                if (isLoad || isALUregister || isALUimmediate || isJALR || isJAL || isAUIPC || isLUI)
                    writeBackEnable <= 1; 
                state <= MEMORY;
                
                // as instruction = 4 bytes PC increments by 4 to reach next instruction
                PC <= ((isBranch && branchOutput) || isJAL) ? PCImmediate :
                        // The least significant bit (bit 0) of the JALR target address must be zero
                        // as instructions are 4 bytes and PC must be 4-byte aligned
                        isJALR ? {aluSum[31:1], 1'b0} :
                        nextPC;
            end 
        
        MEMORY :
            begin
                if (isLoad)
                    memoryReadingSignal <= 0;

                if (isStore)
                begin 
                    $display("Mask: (store): %b, (writing): %b", storeWritingMask, memoryWritingMask);
                    memoryWritingSignal <= 0; 
                end
                state <= WRITE_BACK;
            end

        WRITE_BACK :
            begin
                //store the result in rd
                // rdId != 0 as writing to register 0 has no effect
                if(writeBackEnable && rdID != 0) 
                begin
                    if(isLoad)
                    begin
                        RegisterBank[rdID] <= LOAD_data;
                        $display("writeBackData (D)=%d, (H)=%h",LOAD_data, LOAD_data);
                    end
                    else
                    begin
                        RegisterBank[rdID] <= writeBackData;
                        $display("writeBackData (D)=%d, (H)=%h",writeBackData, writeBackData);
                    end
                end

                // register X0 must strictly be 0
                RegisterBank[0] <= 0;
                writeBackEnable <= 0; 
                memoryReadingSignal <= 1; 
                state <= FETCH;
            end
    endcase
    end
    end    
endmodule

/*
$display("PC: %0d, Instruction: %h", pc, instruction);

    if (instruction_type == "OP") begin
        $display("  Type: OP");
        $display("    rd:  x%02d", rd);
        $display("    rs1: x%02d = %0d", rs1, rs1_data);
        $display("    rs2: x%02d = %0d", rs2, rs2_data);
        $display("    funct3 = %03b, funct7 = %07b", funct3, funct7);
    end
*/

/* 
    Makefile: a file used by the make tool to automate building (compiling) projects. 
    Abbreviates manually typing all the gcc or g++ commands manually
    by defining rules in a Makefile, and make figures out what needs to be done.

    $make clean - remove everything without touching source files
    $make run - first build program if necessary, then it executes ./myprogram
*/
