// 5-Stage Pipeline RISC-V CPU with Flush and Hazard Handling and Dual-Cache Stall Support
// Supports: R/I ALU, LW/SW, BEQ/BNE, JAL, JALR, NOP
module ALU(
    input  [3:0]        alu_ctrl,    // 0=ADD,1=SUB,2=AND,3=OR,4=XOR,5=SLL,6=SRL,7=SRA,8=SLT
    input  signed [31:0] data1,
    input  signed [31:0] data2,
    output        [31:0] alu_calc,
);  
    reg [31:0] temp;
    always @(*) begin
        case (alu_ctrl)
            4'd0:  temp = data1 + data2;
            4'd1:  temp = data1 - data2;
            4'd2:  temp = data1 & data2;
            4'd3:  temp = data1 | data2;
            4'd4:  temp = data1 ^ data2;
            4'd5:  temp = data1 << data2[4:0];
            4'd6:  temp = data1 >> data2[4:0];
            4'd7:  temp = data1 >>> data2[4:0];
            4'd8:  temp = data1 - data2;
            default: temp = 32'd0;
        endcase
    end

    assign alu_calc = (alu_ctrl == 4'd8)?{{31{1'b0}},temp[31]}:temp;

endmodule

module comparator(
    input  signed [31:0] data1,
    input  signed [31:0] data2,
    output zero
);
    assign zero = (data1 == data2)?1'b1:1'b0;

endmodule 

module RISCV_Pipeline(
    input         clk,
    input         rst_n,
    // I-cache interface
    output        ICACHE_ren,
    output        ICACHE_wen,
    output [29:0] ICACHE_addr,
    output [31:0] ICACHE_wdata,
    input         ICACHE_stall,
    input  [31:0] ICACHE_rdata,
    // D-cache interface
    output        DCACHE_ren,
    output        DCACHE_wen,
    output [29:0] DCACHE_addr,
    output [31:0] DCACHE_wdata,
    input         DCACHE_stall,
    input  [31:0] DCACHE_rdata,
    // PC output
    output [31:0] PC
);

// Global stall: any cache stall or load-use hazard
wire load_use_hazard;
wire stall;
assign stall = ICACHE_stall || DCACHE_stall || load_use_hazard;

// Pipeline registers
wire [31:0] PC_w;
reg [31:0] PC_reg;
reg        IF_valid;
reg [31:0] IF_pc;
reg [31:0] IF_inst;

reg        ID_valid;
reg [31:0] ID_pc;
reg [31:0] ID_inst;
reg [31:0] ID_rs1, ID_rs2, ID_imm;
reg [4:0]  ID_rd;
reg        ID_mem_to_reg, ID_mem_wen, ID_reg_wen, ID_alu_src;
reg [3:0]  ID_alu_ctrl;
reg        ID_branch, ID_jal, ID_jalr;

reg        EX_valid;
reg [31:0] EX_pc;
reg [31:0] EX_op1, EX_op2;
reg [31:0] EX_imm;
reg [4:0]  EX_rd;
reg        EX_mem_to_reg, EX_mem_wen, EX_reg_wen, EX_alu_src;
reg [3:0]  EX_alu_ctrl;
reg        EX_branch, EX_jal, EX_jalr;

reg        MEM_valid;
reg [31:0] MEM_pc;
reg [31:0] MEM_branch_target;
reg [31:0] MEM_alu_out;
reg [31:0] MEM_wdata;
reg [4:0]  MEM_rd;
reg        MEM_mem_to_reg, MEM_mem_ren, MEM_mem_wen, MEM_reg_wen;
reg        MEM_branch, MEM_jal, MEM_jalr;

reg        WB_reg_wen;
reg        WB_mem_to_reg;
reg [31:0] WB_alu_out;
reg [31:0] WB_mem_rdata;
reg [4:0]  WB_rd;

// Register file
reg [31:0] RF [0:31];

// ALU wires
wire [31:0] alu_result;
wire [31:0] WB_write_data;

// instantiate ALU
ALU alu_u(
    .alu_ctrl(EX_alu_ctrl),
    .data1(EX_op1),
    .data2(EX_op2),
    .alu_calc(alu_result)
);

// Forwarding logic
reg [1:0] forwardA, forwardB;
always @(*) begin
    forwardA = 2'b00;
    forwardB = 2'b00;
    if (MEM_reg_wen && MEM_rd!=0) begin
        if (MEM_rd==ID_inst[19:15]) forwardA = 2'b10;
        if (MEM_rd==ID_inst[24:20]) forwardB = 2'b10;
    end
    if (WB_reg_wen && WB_rd!=0) begin
        if (WB_rd==ID_inst[19:15] && forwardA==2'b00) forwardA=2'b01;
        if (WB_rd==ID_inst[24:20] && forwardB==2'b00) forwardB=2'b01;
    end
end

// Hazard detection
assign load_use_hazard = ID_valid && EX_mem_to_reg &&
    ((EX_rd==IF_inst[19:15]) || (EX_rd==IF_inst[24:20]));

// PC output
assign PC = PC_reg;

// PC update
always @(posedge clk) begin
    if (!rst_n)
        PC_reg <= 32'd0;
    else if (!stall) begin
        if (MEM_branch && ((IF_inst[14:12]==3'b000 && alu_zero) || (IF_inst[14:12]==3'b001 && ~alu_zero)))
            PC_reg <= MEM_branch_target;
        else if (MEM_jal)
            PC_reg <= MEM_branch_target;
        else if (MEM_jalr)
            PC_reg <= MEM_alu_out;
        else
            PC_reg <= PC_reg + 4;
    end
end

// IF stage
always @(posedge clk) begin
    if (!rst_n) begin
        IF_valid<=1'b0; IF_pc<=32'd0; IF_inst<=32'd0;
    end else if (!stall) begin
        IF_valid<=1'b1;
        IF_pc   <=PC_reg;
        IF_inst <=ICACHE_rdata;
    end
end

// I-cache interface
assign ICACHE_ren   = !ICACHE_stall;
assign ICACHE_wen   = 1'b0;
assign ICACHE_addr  = PC_reg[31:2];
assign ICACHE_wdata = 32'd0;

// ID stage (decode)
always @(*) begin
    ID_valid = IF_valid;
    ID_pc    = IF_pc;
    ID_inst  = IF_inst;
    ID_rs1   = RF[IF_inst[19:15]];
    ID_rs2   = RF[IF_inst[24:20]];
    ID_rd    = IF_inst[11:7];
    case(IF_inst[6:0])
        7'b0000011,7'b1100111: ID_imm = {{21{IF_inst[31]}},IF_inst[30:20]};
        7'b0100011:           ID_imm = {{21{IF_inst[31]}},IF_inst[30:25],IF_inst[11:7]};
        7'b1100011:           ID_imm = {{20{IF_inst[31]}},IF_inst[7],IF_inst[30:25],IF_inst[11:8],1'b0};
        7'b1101111:           ID_imm = {{12{IF_inst[31]}},IF_inst[19:12],IF_inst[20],IF_inst[30:21],1'b0};
        default:               ID_imm = 32'd0;
    endcase
    EX_mem_to_reg=0; EX_mem_wen=0; EX_reg_wen=0; EX_alu_src=0;
    EX_branch=0; EX_jal=0; EX_jalr=0; EX_alu_ctrl=4'd0;
    case(IF_inst[6:0])
        7'b0110011: begin
            EX_reg_wen=1;
            case({IF_inst[14:12],IF_inst[30]})
                4'b0000: EX_alu_ctrl=4'd0; 4'b0001: EX_alu_ctrl=4'd1;
                4'b1110: EX_alu_ctrl=4'd2; 4'b1100: EX_alu_ctrl=4'd3;
                4'b1000: EX_alu_ctrl=4'd4; 4'b0010: EX_alu_ctrl=4'd5;
                4'b1010: EX_alu_ctrl=4'd6; 4'b1011: EX_alu_ctrl=4'd7;
                4'b0100: EX_alu_ctrl=4'd8;
            endcase
        end
        7'b0010011: begin
            EX_reg_wen=1; EX_alu_src=1;
            case({IF_inst[14:12],IF_inst[30]})
                4'b0000: EX_alu_ctrl=4'd0; 4'b1110: EX_alu_ctrl=4'd2;
                4'b1100: EX_alu_ctrl=4'd3; 4'b1000: EX_alu_ctrl=4'd4;
                4'b0010: EX_alu_ctrl=4'd5; 4'b1010: EX_alu_ctrl=4'd6;
                4'b1011: EX_alu_ctrl=4'd7; 4'b0100: EX_alu_ctrl=4'd8;
            endcase
        end
        7'b0000011: begin EX_mem_to_reg=1; EX_reg_wen=1; EX_alu_src=1; EX_alu_ctrl=4'd0; end
        7'b0100011: begin EX_mem_wen=1; EX_alu_src=1; EX_alu_ctrl=4'd0; end
        7'b1100011: begin EX_branch=1; EX_alu_ctrl=4'd1; end
        7'b1101111: begin EX_jal=1; EX_reg_wen=1; end
        7'b1100111: begin EX_jalr=1; EX_reg_wen=1; EX_alu_src=1; EX_alu_ctrl=4'd0; end
    endcase
end

// ID/EX pipeline register
always @(posedge clk) begin
    if (!rst_n) EX_valid<=0; else if (!stall) begin
        EX_valid<=ID_valid; EX_pc<=ID_pc; EX_op1<= (forwardA==2'b10)?MEM_alu_out:(forwardA==2'b01)?WB_write_data:ID_rs1;
        EX_op2<= EX_alu_src?ID_imm:((forwardB==2'b10)?MEM_alu_out:(forwardB==2'b01)?WB_write_data:ID_rs2);
        EX_rd<=ID_rd; EX_imm<=ID_imm;
    end
end

// compute branch target
wire [31:0] EX_branch_target = EX_pc + EX_imm;

// EX/MEM pipeline register
always @(posedge clk) begin
    if (!rst_n) MEM_valid<=0; else if (!stall) begin
        MEM_valid<=EX_valid; MEM_pc<=EX_pc; MEM_branch_target<=EX_branch_target;
        MEM_alu_out<=alu_result; MEM_wdata<=EX_op2; MEM_rd<=EX_rd;
        MEM_mem_to_reg<=EX_mem_to_reg; MEM_mem_wen<=EX_mem_wen; MEM_mem_ren<=EX_mem_to_reg && !EX_mem_wen;
        MEM_reg_wen<=EX_reg_wen; MEM_branch<=EX_branch; MEM_jal<=EX_jal; MEM_jalr<=EX_jalr;
    end
end

// D-cache interface
assign DCACHE_ren   = MEM_mem_ren;
assign DCACHE_wen   = MEM_mem_wen;
assign DCACHE_addr  = MEM_alu_out[31:2];
assign DCACHE_wdata = MEM_wdata;

// MEM/WB pipeline register and write-back
always @(posedge clk) begin
    if (!rst_n) WB_reg_wen<=0; else if (!stall) begin
        WB_reg_wen<=MEM_valid && MEM_reg_wen; WB_mem_to_reg<=MEM_mem_to_reg;
        WB_alu_out<=MEM_alu_out; WB_mem_rdata<=DCACHE_rdata; WB_rd<=MEM_rd;
        if (WB_reg_wen && WB_rd!=0) RF[WB_rd]<=WB_write_data;
    end
end

assign WB_write_data = WB_mem_to_reg?WB_mem_rdata:WB_alu_out;

endmodule
