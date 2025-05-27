// Supports: R/I ALU, LW/SW, BEQ/BNE, JAL, JALR, NOP
module ALU(
    input  [3:0]        alu_ctrl,    // 0=ADD,1=SUB,2=AND,3=OR,4=XOR,5=SLL,6=SRL,7=SRA,8=SLT
    input  signed [31:0] data1,
    input  signed [31:0] data2,
    output signed [31:0] alu_calc,
);  

    // I think we should not use zero, because zero is in the comparator, and the branch logic is in ID/EX
    reg signed [31:0]  temp;

    always @(*) begin
        case (alu_ctrl) // synopsys parallel_case full_case
            4'd0:       temp = data1 + data2;
            4'd1,4'd8:  temp = data1 - data2;
            4'd2:       temp = data1 & data2;
            4'd3:       temp = data1 | data2;
            4'd4:       temp = data1 ^ data2;
            4'd5:       temp = data1 << data2[4:0];
            4'd6:       temp = data1 >> data2[4:0];
            4'd7:       temp = data1 >>> data2[4:0];
        endcase
    end

    assign alu_calc = (alu_ctrl == 4'd8)?{31'd0,temp[31]}:temp;

endmodule

module comparator(
    input  signed [31:0] data1,
    input  signed [31:0] data2,
    output zero
);
    // for branch logic in ID/EX
    assign zero = (data1 == data2)? 1'b1 : 1'b0;

endmodule 

module RISCV_Pipeline(
    input         clk,
    input         rst_n,
    // I-cache interface
    output        ICACHE_ren,   // Read enable for instruction cache
    output        ICACHE_wen,   // Write enable for instruction cache (not used)
    output [29:0] ICACHE_addr,  // Address for instruction cache
    output [31:0] ICACHE_wdata, // Data to write to instruction cache (not used)
    input         ICACHE_stall, // Stall signal from instruction cache
    input  [31:0] ICACHE_rdata, // Data read from instruction cache
    // D-cache interface
    output        DCACHE_ren,   // Read enable for data cache
    output        DCACHE_wen,   // Write enable for data cache
    output [29:0] DCACHE_addr,  // Address for data cache
    output [31:0] DCACHE_wdata, // Data to write to data cache
    input         DCACHE_stall, // Stall signal from data cache
    input  [31:0] DCACHE_rdata, // Data read from data cache
    // PC output
    output [31:0] PC    
);

// Pipeline registers

wire stall;
assign stall = ICACHE_stall || DCACHE_stall; // Global stall signal

//IF
reg [31:0] PC_w;
reg [31:0] PC_reg;
reg        IF_valid_w;
reg [31:0] IF_pc_w,IF_pc_r;
reg [31:0] IIF_inst_w,F_inst_r;

assign ICACHE_ren = 1'b1;
assign ICACHE_wen = 1'b0; 
assign ICACHE_addr = PC_reg[31:2];
assign ICACHE_wdata = 32'd0; 

always@(*) begin
    PC_w = PC_reg + 32'd4; // Increment PC by 4 for next instruction
    IF_valid_w = 1'b1; // Set IF stage valid flag
    IF_pc_w = PC_reg; // Update IF stage PC
    IF_inst_w = {ICACHE_rdata[7:0],ICACHE_rdata[15:8],ICACHE_rdata[23:16],ICACHE_rdata[31:24]}; // Read instruction from I-cache

    if(stall) begin
        PC_w = PC_reg; // Hold PC if stalled
        IF_pc_w = IF_pc_r;
        IF_inst_w = IF_inst_r; // Hold instruction if stalled
    end 

    else if ((bne&(!zero))|(branch&zero)|jal) begin
        PC_w = branch_jal_addr;
        IF_valid_w = 1'b0;
    end

    else if (jalr) begin
        PC_w = jalr_addr;
        IF_valid_w = 1'b0;
    end
end

always@(posedge clk) begin
    if (!rst_n) begin
        PC_reg <= 32'd0; // Reset PC to 0
        IF_pc_r <= 32'd0;
        IF_inst_r <= {{25{1'b0}},{7'b0010011}};  // 25 個 0 + 0010011 -> NOP
    end 

    else if (!IF_valid_w) begin
        PC_reg <= PC_w; // Update PC if not stalled
        IF_pc_r <= IF_pc_w; // Hold PC if stalled
        IF_inst_r <= {{25{1'b0}},{7'b0010011}};
    end

    else begin
        PC_reg <= PC_w; // Update PC if not stalled
        IF_pc_r <= IF_pc_w;
        IF_inst_r <= IF_inst_w; // Update instruction if not stalled
    end
end

//ID -> Branch here ...

// wire :)
reg    jal;
reg    jalr;
reg    branch;
reg    ALU_src;
reg    Reg_write;
reg    mem_to_reg;
reg    mem_wen_D;
reg    bne;
reg    [31:0] immediate;
reg    [3:0] alu_ctrl;

reg [31:0] ID_rs1_w,ID_rs1_r, ID_rs2_w,ID_rs2_r,ID_imm_w,ID_imm_r;
reg [4:0]  ID_rd_w,ID_rd_r;
reg        ID_mem_to_reg_w,ID_mem_to_reg_r, ID_mem_wen_D_w,ID_mem_wen_D_r, ID_Reg_write_w,ID_Reg_write_r, ID_ALU_src_w,ID_ALU_src_r;
reg [3:0]  ID_alu_ctrl_w,ID_alu_ctrl_r;
reg        ID_branch_w,ID_branch_r, ID_jal_w,ID_jal_r, ID_jalr_w,ID_jalr_r;


always@(posedge clk) begin
    if (!rst_n) begin
        ID_rs1_r <= 32'd0;
        ID_rs2_r <= 32'd0;
        ID_rd_r <= 5'd0;
        ID_imm_r <= 32'd0;
        ID_mem_to_reg_r <= 1'b0;
        ID_mem_wen_D_r <= 1'b0;
        ID_Reg_write_r <= 1'b0;
        ID_ALU_src_r <= 1'b0;
        ID_alu_ctrl_r <= 4'd2;
        ID_branch_r <= 1'b0;
        ID_jal_r <= 1'b0;
        ID_jalr_r <= 1'b0;  
    end 
    
    else begin
        ID_rs1_r <= ID_rs1_w; // Update rs1
        ID_rs2_r <= ID_rs2_w; // Update rs2
        ID_rd_r <= ID_rd_w; // Update rd
        ID_imm_r <= ID_imm_w; // Update immediate value
        ID_mem_to_reg_r <= ID_mem_to_reg_w; // Update mem_to_reg flag
        ID_mem_wen_D_r <= ID_mem_wen_D_w; // Update mem write enable flag
        ID_Reg_write_r <= ID_Reg_write_w; // Update Reg write flag
        ID_ALU_src_r <= ID_ALU_src_w; // Update ALU source flag
        ID_alu_ctrl_r <= ID_alu_ctrl_w; // Update ALU control signal
        ID_branch_r <= ID_branch_w; // Update branch flag
        ID_jal_r <= ID_jal_w; // Update jal flag
        ID_jalr_r <= ID_jalr_w; // Update jalr flag
    end

end

always@(*)begin

    ID_rs1_w = RF_r[{IF_inst_r[19:15]}];
    ID_rs2_w = RF_r[{IF_inst_r[24:20]}];
    ID_rd_w = IF_inst_r[11:7];

    //decode
    ID_imm_w = immediate;
    ID_mem_to_reg_w = mem_to_reg;
    ID_mem_wen_D_w = mem_wen_D;
    ID_Reg_write_w = Reg_write;
    ID_ALU_src_w = ALU_src;
    ID_alu_ctrl_w = alu_ctrl;
    ID_branch_w = branch;
    ID_jal_w = jal;
    ID_jalr_w = jalr;

    if(stall) begin
        ID_rs1_w = ID_rs1_r;
        ID_rs2_w = ID_rs2_r;
        ID_rd_w = ID_rd_r;
        ID_imm_w = ID_imm_r;
        ID_mem_to_reg_w = ID_mem_to_reg_r;
        ID_mem_wen_D_w = ID_mem_wen_D_r;
        ID_Reg_write_w = ID_Reg_write_r;
        ID_ALU_src_w = ID_ALU_src_r;
        ID_alu_ctrl_w = ID_alu_ctrl_r;
        ID_branch_w = ID_branch_r;
        ID_jal_w = ID_jal_r;
        ID_jalr_w = ID_jalr_r;
    end

end

//decode
always@(*) begin      

    jal         = 0;
    jalr        = 0;
    branch      = 0;
    ALU_src     = 0;
    Reg_write   = 0;
    mem_to_reg  = 0;
    mem_wen_D   = 0;
    bne         = 0;
    immediate   = 32'd0;
    alu_ctrl    = 4'b0010;

    // 0=ADD,1=SUB,2=AND,3=OR,4=XOR,5=SLL,6=SRL,7=SRA,8=SLT

    case(inst[6:0])  // R: add,sub,and,or,xor,slli,srai,srli,slt  I:addi,andi,ori,xori,slti,lw,jalr  S:sw  B:beq,bne  J:jal
    
        // R: add,sub,and,or,xor,slli,srli,srai,slt
        7'b0110011: begin
            Reg_write  = 1;
            immediate  = {27'd0,IF_inst_r[4:0]}; // for shift
        end

        // I:addi
        7'b: begin
            
            immediate  = {{21{IF_inst_r[31]}},IF_inst_r[30:25],IF_inst_r[24:21],IF_inst_r[20]};
        end

        // I:andi
        7'b: begin
            
            immediate  = {{21{IF_inst_r[31]}},IF_inst_r[30:25],IF_inst_r[24:21],IF_inst_r[20]};
        end

        // I:ori
        7'b: begin
            
            immediate  = {{21{IF_inst_r[31]}},IF_inst_r[30:25],IF_inst_r[24:21],IF_inst_r[20]};
        end

        // I:xori
        7'b: begin
            
            immediate  = {{21{IF_inst_r[31]}},IF_inst_r[30:25],IF_inst_r[24:21],IF_inst_r[20]};
        end  

        // I:slti
        7'b: begin
           
            immediate  = {{21{IF_inst_r[31]}},IF_inst_r[30:25],IF_inst_r[24:21],IF_inst_r[20]};
        end  

        // I:lw
        7'b0000011: begin
            ALU_src    = 1;
            mem_to_reg = 1;
            Reg_write  = 1;
            immediate  = {{21{IF_inst_r[31]}},IF_inst_r[30:25],IF_inst_r[24:21],IF_inst_r[20]};
        end       

        // I:jalr
        7'b1100111: begin
            jalr      = 1;
            Reg_write = 1;
            immediate = {{21{IF_inst_r[31]}},IF_inst_r[30:25],IF_inst_r[24:21],IF_inst_r[20]};
        end  

        // S:sw
        7'b0100011: begin
            ALU_src   = 1;
            mem_wen_D = 1;
            immediate = {{21{IF_inst_r[31]}},IF_inst_r[30:25],IF_inst_r[11:8],IF_inst_r[7]};
        end


        // B:beq , bne
        7'b1100011: begin
            branch    = !IF_inst_r[12];
            bne       = IF_inst_r[12];
            immediate = {{20{IF_inst_r[31]}},IF_inst_r[7],IF_inst_r[30:25],IF_inst_r[11:8],1'b0};
        end

        // J:jal
        7'b1101111: begin
            jal       = 1;
            Reg_write = 1;
            immediate = {{12{IF_inst_r[31]}},IF_inst_r[19:12],IF_inst_r[20],IF_inst_r[30:21],1'b0};
        end

    endcase
end

wire zero;
comparator cpr(
    .data1(ID_rs1_w),
    .data2(ID_rs2_w),
    .zero(zero)
);

// Branch target calculation
reg [31:0] branch_jal_addr;
reg [31:0] jalr_addr;
always@(*) begin
    branch_jal_addr = IF_pc_r + immediate;
    jalr_addr = ID_rs1_w + immediate;
end

//EX
reg        EX_valid;
reg [31:0] EX_pc;
reg [31:0] EX_op1, EX_op2;
reg [31:0] EX_imm;
reg [4:0]  EX_rd;
reg        EX_mem_to_reg, EX_mem_wen, EX_reg_wen, EX_alu_src;
reg [3:0]  EX_alu_ctrl;
reg        EX_branch, EX_jal, EX_jalr;

//MEM
reg        MEM_valid;
reg [31:0] MEM_pc;
reg [31:0] MEM_branch_target;
reg [31:0] MEM_alu_out;
reg [31:0] MEM_wdata;
reg [4:0]  MEM_rd;
reg        MEM_mem_to_reg, MEM_mem_ren, MEM_mem_wen, MEM_reg_wen;
reg        MEM_branch, MEM_jal, MEM_jalr;

//WB
reg        WB_reg_wen;
reg        WB_mem_to_reg;
reg [31:0] WB_alu_out;
reg [31:0] WB_mem_rdata;
reg [4:0]  WB_rd;



// Register file
reg [31:0] RF_r [0:31];

// ALU wires

// instantiate ALU
ALU alu_u(
    .alu_ctrl(EX_alu_ctrl),
    .data1(EX_op1),
    .data2(EX_op2),
    .alu_calc(alu_result)
);

// Forwarding logic

// Hazard detection


// PC output


// PC update


// IF stage


// I-cache interface

// ID stage (decode)


// ID/EX pipeline register


// compute branch target


// EX/MEM pipeline register


// D-cache interface


// MEM/WB pipeline register and write-back


endmodule
