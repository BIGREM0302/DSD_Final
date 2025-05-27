// Supports: R/I ALU, LW/SW, BEQ/BNE, JAL, JALR, NOP
module ALU(
    input  [3:0]        alu_ctrl,    // 0=ADD,1=SUB,2=AND,3=OR,4=XOR,5=SLL,6=SRL,7=SRA,8=SLT
    input  signed [31:0] data1,
    input  signed [31:0] data2,
    output reg    [31:0] alu_calc,
);  

    // i think we should not use zero, because zero is in the comparator, and the branch logic is in ID/EX

    always @(*) begin
        case (alu_ctrl)
            4'd0:  alu_calc = data1 + data2;
            4'd1:  alu_calc = data1 - data2;
            4'd2:  alu_calc = data1 & data2;
            4'd3:  alu_calc = data1 | data2;
            4'd4:  alu_calc = data1 ^ data2;
            4'd5:  alu_calc = data1 << data2[4:0];
            4'd6:  alu_calc = data1 >> data2[4:0];
            4'd7:  alu_calc = data1 >>> data2[4:0];
            4'd8:  alu_calc = (data1 - data2)? 32'd1 : 32'd0;
            default: alu_calc = 32'd0;
        endcase
    end

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

//IF
wire [31:0] PC_w;
reg [31:0] PC_reg;
reg        IF_valid;
reg [31:0] IF_pc;
reg [31:0] IF_inst;

//ID -> Branch here ...
reg        ID_valid;
reg [31:0] ID_pc;
reg [31:0] ID_inst;
reg [31:0] ID_rs1, ID_rs2, ID_imm;
reg [4:0]  ID_rd;
reg        ID_mem_to_reg, ID_mem_wen, ID_reg_wen, ID_alu_src;
reg [3:0]  ID_alu_ctrl;
reg        ID_branch, ID_jal, ID_jalr;

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

// Global stall: any cache stall or load-use hazard

// Register file
reg [31:0] RF [0:31];

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
