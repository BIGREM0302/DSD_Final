// Supports: R/I ALU, LW/SW, BEQ/BNE, JAL, JALR, NOP
module ALU(
    input  [3:0]        alu_ctrl,    // 0=ADD,1=SUB,2=AND,3=OR,4=XOR,5=SLL,6=SRL,7=SRA,8=SLT
    input  signed [31:0] data1,
    input  signed [31:0] data2,
    output signed [31:0] alu_calc
);  

    // I think we should not use zero, because zero is in the comparator, and the branch logic is in ID/EX
    reg signed [31:0]  temp;

    always @(*) begin
        case (alu_ctrl) // synopsys parallel_case full_case
            4'd0:       temp = data1 + data2;
            4'd3,4'd2:  temp = data1 - data2;
            4'd7:       temp = data1 & data2;
            4'd6:       temp = data1 | data2;
            4'd4:       temp = data1 ^ data2;
            4'd1:       temp = data1 << data2[4:0];
            4'd5:       temp = data1 >> data2[4:0];
            4'd8:       temp = data1 >>> data2[4:0];
        endcase
    end

    assign alu_calc = (alu_ctrl == 4'd2)?{31'd0,temp[31]}:temp;

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

wire stall;
assign stall = ICACHE_stall || DCACHE_stall; // Global stall signal

//IF
reg [31:0] PC_w;
reg [31:0] PC_reg;
reg        IF_valid_w;
reg [31:0] IF_pc_w,IF_pc_r;
reg [31:0] IF_inst_w,IF_inst_r;

assign PC = PC_reg; // Output current PC value
assign ICACHE_ren = 1'b1;
assign ICACHE_wen = 1'b0; 
assign ICACHE_addr = PC_reg[31:2];
assign ICACHE_wdata = 32'd0; 

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
reg [4:0]  ID_rs1_addr_w,ID_rs1_addr_r,ID_rs2_addr_w,ID_rs2_addr_r,ID_rd_w,ID_rd_r;
reg        ID_mem_to_reg_w,ID_mem_to_reg_r, ID_mem_wen_D_w,ID_mem_wen_D_r, ID_Reg_write_w,ID_Reg_write_r, ID_ALU_src_w,ID_ALU_src_r;
reg [3:0]  ID_alu_ctrl_w,ID_alu_ctrl_r;
reg        ID_jalr_w,ID_jalr_r;

// Hazard detection
wire hazard;
reg [1:0] cnt_w, cnt_r;

//zero
wire zero;

// Branch target calculation
reg [31:0] branch_jal_addr;

//EX
wire [31:0] rs1_val, rs2_val,EX_op1, EX_op2;
reg  [31:0] EX_out_w, EX_out_r;
reg  [31:0] EX_rs2_w, EX_rs2_r;
reg   [4:0] EX_rd_w, EX_rd_r;
reg         EX_mem_to_reg_w,EX_mem_to_reg_r, EX_mem_wen_D_w, EX_mem_wen_D_r,EX_Reg_write_w, EX_Reg_write_r;
wire [31:0] alu_result;

// Forwarding logic
reg [1:0] forwardA, forwardB;

//MEM
wire [31:0] MEM_alu_out;
reg [31:0] MEM_alu_out_real_w,MEM_alu_out_real_r;
assign MEM_alu_out = EX_out_r;

wire [31:0] MEM_wdata;
assign MEM_wdata = EX_rs2_r; // Data to write to memory

reg [31:0] MEM_rdata_w, MEM_rdata_r;
reg [4:0]  MEM_rd_w, MEM_rd_r;
reg        MEM_mem_to_reg_w, MEM_mem_to_reg_r,MEM_Reg_write_w, MEM_Reg_write_r;

//WB
wire [31:0] WB_alu_out;
assign WB_alu_out = (MEM_mem_to_reg_r)? MEM_rdata_r : MEM_alu_out_real_r; // Choose between memory read data and ALU output

// Register file
reg [31:0] RF_r [0:31]; 



////////////////////////// IF Stage //////////////////////////
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

    else if ((bne & ~zero)| (branch & zero)| jal) begin
        PC_w = branch_jal_addr;
        IF_valid_w = 1'b0;
    end

    else if (ID_jalr_r) begin
        PC_w = alu_result;
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

    else if(cnt_w != 2'd0) begin
        PC_reg <= PC_reg; // Update PC if not stalled
        IF_pc_r <= IF_pc_r;
        IF_inst_r <= IF_inst_r;
    end

    else begin
        PC_reg <= PC_w; // Update PC if not stalled
        IF_pc_r <= IF_pc_w;
        IF_inst_r <= IF_inst_w; // Update instruction if not stalled
    end
end

////////////////////////// ID Stage //////////////////////////
assign hazard = ID_mem_to_reg_r && ((ID_rs1_addr_w == ID_rd_r) || (ID_rs2_addr_w == ID_rd_r));

always@(*) begin
    cnt_w = cnt_r; // Default to hold the counter value
    if(cnt_r == 2'd3) begin
        cnt_w = 2'd0; // Reset counter if it reaches 3
    end

    else if(cnt_r != 2'd0 || hazard) begin
        cnt_w = cnt_r + 2'd1; // Increment counter if not stalled or hazard detected
    end
end


always@(posedge clk) begin
    if (!rst_n) begin
        cnt_r <= 2'd0; // Reset counter
    end 
    else begin
        cnt_r <= cnt_w; // Reset counter when not stalled
    end
end

always@(posedge clk) begin
    if (!rst_n || (cnt_r != 2'd0)) begin
        ID_rs1_r <= 32'd0;
        ID_rs2_r <= 32'd0;
        ID_rs1_addr_r <= 5'd0; // Reset rs1 address
        ID_rs2_addr_r <= 5'd0; // Reset rs2 address
        ID_rd_r <= 5'd0;
        ID_imm_r <= 32'd0;
        ID_mem_to_reg_r <= 1'b0;
        ID_mem_wen_D_r <= 1'b0;
        ID_Reg_write_r <= 1'b0;
        ID_ALU_src_r <= 1'b0;
        ID_alu_ctrl_r <= 4'd7; 
        ID_jalr_r <= 1'b0;
    end 
    
    else begin
        ID_rs1_r <= ID_rs1_w; // Update rs1
        ID_rs2_r <= ID_rs2_w; // Update rs2
        ID_rs1_addr_r <= ID_rs1_addr_w; // Update rs1 address
        ID_rs2_addr_r <= ID_rs2_addr_w; // Update rs2 address
        ID_rd_r <= ID_rd_w; // Update rd
        ID_imm_r <= ID_imm_w; // Update immediate value
        ID_mem_to_reg_r <= ID_mem_to_reg_w; // Update mem_to_reg flag
        ID_mem_wen_D_r <= ID_mem_wen_D_w; // Update mem write enable flag
        ID_Reg_write_r <= ID_Reg_write_w; // Update Reg write flag
        ID_ALU_src_r <= ID_ALU_src_w; // Update ALU source flag
        ID_alu_ctrl_r <= ID_alu_ctrl_w; // Update ALU control signal
        ID_jalr_r <= ID_jalr_w;
    end

end

always@(*)begin


    ID_rs1_w = (jal)?  IF_pc_r :
               (IF_inst_r[19:15] == MEM_rd_r && MEM_Reg_write_r && MEM_rd_r != 5'd0)? WB_alu_out : RF_r[{IF_inst_r[19:15]}] ;

    ID_rs2_w = (jal)?  32'd4 :
               (IF_inst_r[24:20] == MEM_rd_r && MEM_Reg_write_r && MEM_rd_r != 5'd0)? WB_alu_out : RF_r[{IF_inst_r[24:20]}] ;
    ID_rs1_addr_w = (jal)? 5'd0:IF_inst_r[19:15];
    ID_rs2_addr_w = (jal)? 5'd0:IF_inst_r[24:20];
    ID_rd_w = IF_inst_r[11:7]; 

    //decode
    ID_imm_w = immediate;
    ID_mem_to_reg_w = mem_to_reg;
    ID_mem_wen_D_w = mem_wen_D;
    ID_Reg_write_w = Reg_write;
    ID_ALU_src_w = ALU_src;
    ID_alu_ctrl_w = alu_ctrl;
    ID_jalr_w = jalr;

    if(stall) begin
        ID_rs1_w = ID_rs1_r;
        ID_rs2_w = ID_rs2_r;
        ID_rs1_addr_w = ID_rs1_addr_r;
        ID_rs2_addr_w = ID_rs2_addr_r;
        ID_rd_w = ID_rd_r;
        ID_imm_w = ID_imm_r;
        ID_mem_to_reg_w = ID_mem_to_reg_r;
        ID_mem_wen_D_w = ID_mem_wen_D_r;
        ID_Reg_write_w = ID_Reg_write_r;
        ID_ALU_src_w = ID_ALU_src_r;
        ID_alu_ctrl_w = ID_alu_ctrl_r;
        ID_jalr_w = ID_jalr_r;
    end

    else if (ID_jalr_r) begin
        ID_rs1_w = 32'd0;
        ID_rs2_w = 32'd0;
        ID_rs1_addr_w = 5'd0; // Reset rs1 address
        ID_rs2_addr_w = 5'd0; // Reset rs2 address
        ID_rd_w = 5'd0;
        ID_imm_w = 32'd0;
        ID_mem_to_reg_w = 1'b0;
        ID_mem_wen_D_w = 1'b0;
        ID_Reg_write_w = 1'b0;
        ID_ALU_src_w = 1'b0;
        ID_alu_ctrl_w = 4'd7; 
        ID_jalr_w = 1'b0;
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
    alu_ctrl    = 4'd7;

    // 0=ADD,1=SUB,2=AND,3=OR,4=XOR,5=SLL,6=SRL,7=SRA,8=SLT

    case(IF_inst_r[6:0])  // R: add,sub,and,or,xor,slli,srai,srli,slt  I:addi,andi,ori,xori,slti,lw,jalr  S:sw  B:beq,bne  J:jal
    
        // R: add,sub,and,or,xor,slt
        7'b0110011: begin   
            Reg_write   = 1;
            alu_ctrl    = (IF_inst_r[30])? 4'd3 : {1'b0, IF_inst_r[14:12]};
        end

        // I:addi, andi, ori, xori, slti, slli,srli,srai
        7'b0010011: begin
            ALU_src     = 1;
            Reg_write   = 1;
            if(~IF_inst_r[13] & IF_inst_r[12])begin // for shift
                immediate   = {27'd0,IF_inst_r[24:20]};
                alu_ctrl    = (IF_inst_r[30])? 4'd8 : {1'b0, IF_inst_r[14:12]};
            end
            else begin
                immediate   = {{21{IF_inst_r[31]}},IF_inst_r[30:25],IF_inst_r[24:21],IF_inst_r[20]};
                alu_ctrl    = {1'b0, IF_inst_r[14:12]};
            end
        end

        // I:lw
        7'b0000011: begin
            ALU_src    = 1;
            mem_to_reg = 1;
            Reg_write  = 1;
            immediate  = {{21{IF_inst_r[31]}},IF_inst_r[30:25],IF_inst_r[24:21],IF_inst_r[20]};
            alu_ctrl   = 4'd0;
        end       

        // I:jalr
        7'b1100111: begin
            jalr      = 1;
            Reg_write = 1;
            ALU_src   = 1;
            immediate = {{21{IF_inst_r[31]}},IF_inst_r[30:25],IF_inst_r[24:21],IF_inst_r[20]};
            alu_ctrl    = 4'd0;
        end  

        // S:sw
        7'b0100011: begin
            ALU_src   = 1;
            mem_wen_D = 1;
            immediate = {{21{IF_inst_r[31]}},IF_inst_r[30:25],IF_inst_r[11:8],IF_inst_r[7]};
            alu_ctrl  = 4'd0;
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
            alu_ctrl    = 4'd0;
        end

    endcase
end

comparator cpr(
    .data1(ID_rs1_w),
    .data2(ID_rs2_w),
    .zero(zero)
);

// Branch address calculation
always@(*) begin
    branch_jal_addr = IF_pc_r + immediate;
end

////////////////////////// EX Stage //////////////////////////

// instantiate ALU
ALU alu_u(
    .alu_ctrl(ID_alu_ctrl_r),
    .data1(EX_op1),
    .data2(EX_op2),
    .alu_calc(alu_result)
);


always @(*) begin
    forwardA = 2'b00;
    forwardB = 2'b00;
    if (EX_Reg_write_r && EX_rd_r!=5'd0) begin
        if (EX_rd_r==ID_rs1_addr_r) forwardA = 2'b10;
        if (EX_rd_r==ID_rs2_addr_r) forwardB = 2'b10;
    end
    if (MEM_Reg_write_r && MEM_rd_r!=5'd0) begin
        if (MEM_rd_r==ID_rs1_addr_r && forwardA==2'b00) forwardA=2'b01;
        if (MEM_rd_r==ID_rs2_addr_r && forwardB==2'b00) forwardB=2'b01;
    end
end

assign rs1_val = (forwardA==2'b00) ? ID_rs1_r : 
                 (forwardA==2'b01) ? WB_alu_out : 
                 (forwardA==2'b10) ? MEM_alu_out : 32'd0;

assign rs2_val = (forwardB==2'b00) ? ID_rs2_r :
                 (forwardB==2'b01) ? WB_alu_out : 
                 (forwardB==2'b10) ? MEM_alu_out : 32'd0;

assign EX_op1 = rs1_val; 
assign EX_op2 = (ID_ALU_src_r) ? ID_imm_r : rs2_val; 

always@(posedge clk) begin
    if (!rst_n) begin
        EX_rd_r <= 5'd0;
        EX_mem_to_reg_r <= 1'b0;
        EX_mem_wen_D_r <= 1'b0;
        EX_Reg_write_r <= 1'b0;
        EX_out_r <= 32'd0;
        EX_rs2_r <= 32'd0; // Reset rs2 value
    end 
    
    else begin
        EX_rd_r <= EX_rd_w; // Update rd
        EX_mem_to_reg_r <= EX_mem_to_reg_w; // Update mem_to_reg flag
        EX_mem_wen_D_r <= EX_mem_wen_D_w; // Update mem write enable flag
        EX_Reg_write_r <= EX_Reg_write_w; // Update Reg write flag
        EX_out_r <= EX_out_w; // Update ALU result
        EX_rs2_r <= EX_rs2_w; // Update rs2 value
    end

end

always@(*) begin
    EX_rd_w = ID_rd_r; // Forward rd from ID stage
    EX_mem_to_reg_w = ID_mem_to_reg_r; // Forward mem_to_reg flag from ID stage
    EX_mem_wen_D_w = ID_mem_wen_D_r; // Forward mem write enable flag from ID stage
    EX_Reg_write_w = ID_Reg_write_r; // Forward Reg write flag from ID stage
    EX_out_w = alu_result; // ALU result
    EX_rs2_w = rs2_val; // Forward rs2 value

    if(stall) begin
        EX_rd_w = EX_rd_r;
        EX_mem_to_reg_w = EX_mem_to_reg_r;
        EX_mem_wen_D_w = EX_mem_wen_D_r;
        EX_Reg_write_w = EX_Reg_write_r;
        EX_out_w = EX_out_r;
        EX_rs2_w = EX_rs2_r; // Hold rs2 value if stalled
    end
end

////////////////////////// MEM Stage //////////////////////////

assign DCACHE_ren = !EX_mem_wen_D_r; // Read enable for D-cache
assign DCACHE_wen = EX_mem_wen_D_r; // Write enable for D-cache
assign DCACHE_addr = MEM_alu_out[31:2]; // Address for D-cache
assign DCACHE_wdata = {MEM_wdata[7:0],MEM_wdata[15:8],MEM_wdata[23:16],MEM_wdata[31:24]}; // Data to write to D-cache

always@(*) begin
    MEM_alu_out_real_w = MEM_alu_out;
    MEM_rdata_w = {DCACHE_rdata[7:0],DCACHE_rdata[15:8],DCACHE_rdata[23:16],DCACHE_rdata[31:24]}; // Data read from D-cache
    MEM_rd_w = EX_rd_r; // Forward rd from EX stage
    MEM_mem_to_reg_w = EX_mem_to_reg_r; // Forward mem_to_reg flag from EX stage
    MEM_Reg_write_w = EX_Reg_write_r; // Forward Reg write flag from EX stage

    if(stall) begin
        MEM_alu_out_real_w = MEM_alu_out_real_r;
        MEM_rdata_w = MEM_rdata_r;
        MEM_rd_w = MEM_rd_r;
        MEM_mem_to_reg_w = MEM_mem_to_reg_r;
        MEM_Reg_write_w = MEM_Reg_write_r; // Hold values if stalled
    end

end

always@(posedge clk) begin
    if (!rst_n) begin
        MEM_rdata_r <= 32'd0; // Reset memory read data
        MEM_alu_out_real_r <= 32'd0;
        MEM_rd_r <= 5'd0; // Reset rd
        MEM_mem_to_reg_r <= 1'b0; // Reset mem_to_reg flag
        MEM_Reg_write_r <= 1'b0; // Reset Reg write flag
    end 
    
    else begin
        MEM_rdata_r <= MEM_rdata_w; // Update memory read data
        MEM_alu_out_real_r <= MEM_alu_out_real_w;
        MEM_rd_r <= MEM_rd_w; // Update rd
        MEM_mem_to_reg_r <= MEM_mem_to_reg_w; // Update mem_to_reg flag
        MEM_Reg_write_r <= MEM_Reg_write_w; // Update Reg write flag
    end

end

////////////////////////// WB Stage //////////////////////////
integer i;
always@(posedge clk) begin
    if (!rst_n) begin
        // Reset register file to zero
        for (i = 0; i < 32; i = i + 1) begin
            RF_r[i] <= 32'd0;
        end
    end 
    else if (MEM_Reg_write_r && MEM_rd_r != 5'd0) begin
        RF_r[MEM_rd_r] <= WB_alu_out; 
    end
end

endmodule
