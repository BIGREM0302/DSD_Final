module ALU(
    input  [3:0]        alu_ctrl,    // 0=ADD,1=SUB,2=AND,3=OR,4=XOR,5=SLL,6=SRL,7=SRA,8=SLT
    input  signed [31:0] data1,
    input  signed [31:0] data2,
    output signed [31:0] alu_calc
);  

    // I think we should not use zero, because zero is in the comparator, and the branch logic is in ID/EX
    reg signed [31:0]  temp;

    always @(*) begin
        case (alu_ctrl)
            4'd0:       temp = data1 + data2;
            4'd3,4'd2:  temp = data1 - data2;
            4'd7:       temp = data1 & data2;
            4'd6:       temp = data1 | data2;
            4'd4:       temp = data1 ^ data2;
            4'd1:       temp = data1 << data2[4:0];
            4'd5:       temp = data1 >> data2[4:0];
            4'd8:       temp = data1 >>> data2[4:0];
            default:    temp = data1 & data2;
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
    assign zero = (data1 == data2);

endmodule 

module PredictionUnit (
    output BrPre,          
    input  clk,
    input  rst_n,
    input  stall,          
    input  PreWrong,       
    input  B               
);
    // 2-bit saturating counter：00,01,10,11
    // 00 : Strongly Not-Taken
    // 01 : Weakly Not-Taken
    // 10 : Weakly Taken
    // 11 : Strongly Taken

    reg [1:0] ctr_r;
    assign BrPre = ctr_r[1]; 
    always @(posedge clk) begin
        if (!rst_n) begin
            ctr_r <= 2'b01;
        end
        else if (!stall && B) begin
            if (BrPre) begin                
                if (PreWrong) begin
                        ctr_r <= (ctr_r - 2'b01);
                end
                else begin
                        ctr_r <= 2'b11;
                end   
            end
            else begin
                if (PreWrong) begin
                        ctr_r <= (ctr_r + 2'b01);
                end
                else begin
                        ctr_r <= 2'b00;
                end
            end
        end
    end

endmodule

module BoothMul (
    clk,
    rst_n,
    stall,
    a,
    b,
    m
);


input wire        clk, rst_n, stall;
input wire [31:0] a, b; //a be multiplicand, b be multiplier
output     [31:0] m; // m = a * b (unsigned)

reg [33:0] PProd [0:15];
reg [63:0] shifted [0:15];

reg [63:0] temp1 [0:11];
reg [63:0] temp2 [0:7];
reg [63:0] temp3 [0:5];
reg [63:0] temp4 [0:3];
reg [63:0] temp5 [0:2];
reg [63:0] temp6 [0:1];

// we will test EX : stage1 , MEM: stage 2->3 , WB: stage 4->5->6
// so that we need to mannually give "hazard" for those who can't use forwarding to rescue

reg [63:0] temp2_w [0:7];
reg [63:0] temp2_r [0:7];
reg [63:0] temp4_w [0:3];
reg [63:0] temp4_r [0:3];

reg overflow;

wire [56:0] upper_sum = temp6[0][63:8] + temp6[1][63:8];
assign m = {upper_sum[23:0], temp6[0][7:0]};

////////////////////////////////// Booth Encoding //////////////////////////////////

//partial product generation
function [33:0] cal_PProd;
    input [2:0] mul;
    input [32:0] M; //M should include sign bit
    reg [33:0] MX0, MX1, MX2, MX_2, MX_1;
begin

    MX0 = 34'd0;
    MX1 = {1'b0, M};
    MX_1 = ~{1'b0, M}+1'b1; //need to reconsider this
    MX2 = {M, 1'b0};
    MX_2 = ~{M, 1'b0}+1'b1; //need to reconsider this

    case(mul)
        3'd0, 3'd7: cal_PProd = MX0;
        3'd1, 3'd2: cal_PProd = MX1;
        3'd3: cal_PProd = MX2;
        3'd4: cal_PProd = MX_2;
        3'd5, 3'd6: cal_PProd = MX_1;
        default: cal_PProd = MX0;
    endcase
end
endfunction

function [1:0] HA_compress;
    input a;
    input b;
    reg [1:0] result;
begin
    result[1] = a & b;
    result[0] = a ^ b;
    HA_compress = result;
end
endfunction

function [1:0] FA_compress;
    input a;
    input b;
    input cin;
    reg [1:0] result;
begin
    result[1] = (a&b) | (b&cin) | (a&cin); // cout
    result[0] = (a) ^ (b) ^ (cin);
    FA_compress = result;
end
endfunction

integer i, j;

always@(*) begin
    for( i = 0; i < 16; i = i + 1) begin
        PProd[i] = cal_PProd({b[2*i+1], b[2*i], (i==0 ? 1'b0:b[2*i-1])}, {1'b0, a});
        shifted[i] = {{30{PProd[i][33]}}, PProd[i]} << (2*i);
    end

// Tree

// ================================== stage 1 ==========================================================
    for (i = 0; i < 11; i = i + 1)begin
        //initialize
        temp1[i] = 64'd0;
    end

    for(j = 0; j <= 4; j = j + 1) begin        
        for(i = j*6; i < 64; i = i + 1) begin
            if( i == j*6 || i == (j*6+1))begin
                temp1[2*j][i] = shifted[3*j][i];
            end
            else if(i == (j*6+2) || i == (j*6+3)) begin
                {temp1[2*j+1][i+1], temp1[2*j][i]} = HA_compress(shifted[3*j][i], shifted[3*j+1][i]);
            end
            else if (i == 63) begin
                {overflow, temp1[(2*j)][i]} = FA_compress(shifted[3*j][i], shifted[3*j+1][i], shifted[3*j+2][i]);
            end
            else begin
                {temp1[(2*j+1)][i+1], temp1[(2*j)][i]} = FA_compress(shifted[3*j][i], shifted[3*j+1][i], shifted[3*j+2][i]);
            end
        end
    end

    temp1[10] = shifted[15];

// ================================== stage 2 ==========================================================
    for (i = 0; i < 8; i = i + 1)begin
        //initialize
        temp2[i] = 64'd0;
    end
    // for 0, 1
    j = 0;
    for(i = 0; i < 64; i = i + 1) begin
        if( i < 3 )begin
            temp2[2*j][i] = temp1[3*j][i];
        end
        else if(i >= 3 && i < 6) begin
            {temp2[2*j+1][i+1], temp2[2*j][i]} = HA_compress(temp1[3*j][i], temp1[3*j+1][i]);
        end
        else if (i == 63) begin
            {overflow, temp2[(2*j)][i]} = FA_compress(temp1[3*j][i], temp1[3*j+1][i], temp1[3*j+2][i]);
        end
        else begin
            {temp2[(2*j+1)][i+1], temp2[(2*j)][i]} = FA_compress(temp1[3*j][i], temp1[3*j+1][i], temp1[3*j+2][i]);
        end
    end
    j = 1;
    // for 2, 3
    for(i = 9; i < 64; i = i + 1) begin
        if( i < 12 )begin
            temp2[2*j][i] = temp1[3*j][i];
        end
        else if(i >= 12 && i < 15) begin
            {temp2[2*j+1][i+1], temp2[2*j][i]} = HA_compress(temp1[3*j][i], temp1[3*j+1][i]);
        end
        else if (i == 63) begin
            {overflow, temp2[(2*j)][i]} = FA_compress(temp1[3*j][i], temp1[3*j+1][i], temp1[3*j+2][i]);
        end
        else begin
            {temp2[(2*j+1)][i+1], temp2[(2*j)][i]} = FA_compress(temp1[3*j][i], temp1[3*j+1][i], temp1[3*j+2][i]);
        end
    end
    j = 2;
    // for 4, 5
    for(i = 18; i < 64; i = i + 1) begin
        if( i < 21 )begin
            temp2[2*j][i] = temp1[3*j][i];
        end
        else if(i >= 21 && i < 24) begin
            {temp2[2*j+1][i+1], temp2[2*j][i]} = HA_compress(temp1[3*j][i], temp1[3*j+1][i]);
        end
        else if (i == 63) begin
            {overflow, temp2[(2*j)][i]} = FA_compress(temp1[3*j][i], temp1[3*j+1][i], temp1[3*j+2][i]);
        end
        else begin
            {temp2[(2*j+1)][i+1], temp2[(2*j)][i]} = FA_compress(temp1[3*j][i], temp1[3*j+1][i], temp1[3*j+2][i]);
        end
    end

    // for 6, 7
    temp2[6] = temp1[9];
    temp2[7] = temp1[10];

// ================================== stage 3 ==========================================================
    for (i = 0; i < 6; i = i + 1)begin
        //initialize
        temp3[i] = 64'd0;
    end
    // for 0, 1
    j = 0;
    for(i = 0; i < 64; i = i + 1) begin
        if( i < 4 )begin
            temp3[2*j][i] = temp2_r[3*j][i];
        end
        else if(i >= 4 && i < 9) begin
            {temp3[2*j+1][i+1], temp3[2*j][i]} = HA_compress(temp2_r[3*j][i], temp2_r[3*j+1][i]);
        end
        else if (i == 63) begin
            {overflow, temp3[(2*j)][i]} = FA_compress(temp2_r[3*j][i], temp2_r[3*j+1][i], temp2_r[3*j+2][i]);
        end
        else begin
            {temp3[(2*j+1)][i+1], temp3[(2*j)][i]} = FA_compress(temp2_r[3*j][i], temp2_r[3*j+1][i], temp2_r[3*j+2][i]);
        end
    end
    // for 2, 3
    j = 1;
    for(i = 13; i < 64; i = i + 1) begin
        if( i < 18 )begin
            temp3[2*j][i] = temp2_r[3*j][i];
        end
        else if(i >= 18 && i < 22) begin
            {temp3[2*j+1][i+1], temp3[2*j][i]} = HA_compress(temp2_r[3*j][i], temp2_r[3*j+1][i]);
        end
        else if (i == 63) begin
            {overflow, temp3[(2*j)][i]} = FA_compress(temp2_r[3*j][i], temp2_r[3*j+1][i], temp2_r[3*j+2][i]);
        end
        else begin
            {temp3[(2*j+1)][i+1], temp3[(2*j)][i]} = FA_compress(temp2_r[3*j][i], temp2_r[3*j+1][i], temp2_r[3*j+2][i]);
        end
    end
    // for 4, 5
    temp3[4] = temp2_r[6];
    temp3[5] = temp2_r[7];

// ================================== stage 4 ==========================================================
    for (i = 0; i < 4; i = i + 1)begin
        //initialize
        temp4[i] = 64'd0;
    end
    // for 0, 1
    j = 0;
    for(i = 0; i < 64; i = i + 1) begin
        if( i < 5 )begin
            temp4[2*j][i] = temp3[3*j][i];
        end
        else if(i >= 5 && i < 13) begin
            {temp4[2*j+1][i+1], temp4[2*j][i]} = HA_compress(temp3[3*j][i], temp3[3*j+1][i]);
        end
        else if (i == 63) begin
            {overflow, temp4[(2*j)][i]} = FA_compress(temp3[3*j][i], temp3[3*j+1][i], temp3[3*j+2][i]);
        end
        else begin
            {temp4[(2*j+1)][i+1], temp4[(2*j)][i]} = FA_compress(temp3[3*j][i], temp3[3*j+1][i], temp3[3*j+2][i]);
        end
    end
    // for 2, 3
    j = 1;
    for(i = 19; i < 64; i = i + 1) begin
        if( i < 27 )begin
            temp4[2*j][i] = temp3[3*j][i];
        end
        else if(i >= 27 && i < 30) begin
            {temp4[2*j+1][i+1], temp4[2*j][i]} = HA_compress(temp3[3*j][i], temp3[3*j+1][i]);
        end
        else if (i == 63) begin
            {overflow, temp4[(2*j)][i]} = FA_compress(temp3[3*j][i], temp3[3*j+1][i], temp3[3*j+2][i]);
        end
        else begin
            {temp4[(2*j+1)][i+1], temp4[(2*j)][i]} = FA_compress(temp3[3*j][i], temp3[3*j+1][i], temp3[3*j+2][i]);
        end
    end

// ================================== stage 5 ==========================================================
    for (i = 0; i < 3; i = i + 1)begin
        //initialize
        temp5[i] = 64'd0;
    end
    // for 0, 1
    j = 0;
    for(i = 0; i < 64; i = i + 1) begin
        if( i < 6 )begin
            temp5[2*j][i] = temp4_r[3*j][i];
        end
        else if(i >= 6 && i < 19) begin
            {temp5[2*j+1][i+1], temp5[2*j][i]} = HA_compress(temp4_r[3*j][i], temp4_r[3*j+1][i]);
        end
        else if (i == 63) begin
            {overflow, temp5[(2*j)][i]} = FA_compress(temp4_r[3*j][i], temp4_r[3*j+1][i], temp4_r[3*j+2][i]);
        end
        else begin
            {temp5[(2*j+1)][i+1], temp5[(2*j)][i]} = FA_compress(temp4_r[3*j][i], temp4_r[3*j+1][i], temp4_r[3*j+2][i]);
        end
    end
    // for 2
    temp5[2] = temp4_r[3];

// ================================== stage 6 ==========================================================
    for (i = 0; i < 2; i = i + 1)begin
        //initialize
        temp6[i] = 64'd0;
    end
    j = 0;
    for(i = 0; i < 64; i = i + 1) begin
        if( i < 7 )begin
            temp6[2*j][i] = temp5[3*j][i];
        end
        else if(i >= 7 && i < 28) begin
            {temp6[2*j+1][i+1], temp6[2*j][i]} = HA_compress(temp5[3*j][i], temp5[3*j+1][i]);
        end
        else if (i == 63) begin
            {overflow, temp6[(2*j)][i]} = FA_compress(temp5[3*j][i], temp5[3*j+1][i], temp5[3*j+2][i]);
        end
        else begin
            {temp6[(2*j+1)][i+1], temp6[(2*j)][i]} = FA_compress(temp5[3*j][i], temp5[3*j+1][i], temp5[3*j+2][i]);
        end
    end
end

always@(*) begin
    if(stall) begin
        for (i = 0; i < 8; i = i + 1) begin
            temp2_w[i] = temp2_r[i];
        end
        
        for (i = 0; i < 4; i = i + 1) begin
            temp4_w[i] = temp4_r[i];
        end
    end

    else begin
        for (i = 0; i < 8; i = i + 1) begin
            temp2_w[i] = temp2[i];
        end

        for (i = 0; i < 4; i = i + 1) begin
            temp4_w[i] = temp4[i];
        end
    end
end

always@(posedge clk) begin

    if(!rst_n) begin
        for (i = 0; i < 8; i = i + 1) begin
            temp2_r[i] <= 64'd0;
        end
        for (i = 0; i < 4; i = i + 1) begin
            temp4_r[i] <= 64'd0;
        end
    end 

    else begin
        for (i = 0; i < 8; i = i + 1) begin
            temp2_r[i] <= temp2_w[i];
        end

        for (i = 0; i < 4; i = i + 1) begin
            temp4_r[i] <= temp4_w[i];
        end
    end
end

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

///////////////////// Global variable //////////////////////

reg RST_n;
always@(posedge clk) begin
    RST_n <= rst_n;
end

wire stall;
assign stall = ICACHE_stall || DCACHE_stall; 

/////////////////////////////////////////// IF Stage Variable //////////////////////////////////////////

// Program Counter
wire signed [31:0] PC_temp_add;
reg  signed [31:0] PC_w, PC_reg;
reg                IF_valid_w;
reg  signed [31:0] IF_pc_plus_four_w,IF_pc_plus_four_r;
reg         [31:0] IF_inst_w,IF_inst_r;

// Branch prediction
reg [31:0] IF_branch_always_addr_w, IF_branch_always_addr_r; // if we pred: no, but branch need to be taken -> we can directly use this!!
wire [31:0] IF_immediate;
wire IF_B;
wire IF_BrPre_container;
wire IF_BrPre;
reg  IF_BrPre_w, IF_BrPre_r;
reg  IF_B_w, IF_B_r;

/////////////////////////////////////////// ID Stage Variable //////////////////////////////////////////

// Instruction Decode Signal
reg                 jal;
reg                 jalr;
reg                 beq;
reg                 bne;
reg                 ALU_src;
reg                 Reg_write;
reg                 mem_to_reg;
reg                 mem_wen_D;
reg  signed [31:0]  immediate;
reg         [3:0 ]  alu_ctrl;
reg                 mul;

reg         [31:0]  ID_rs1_w                  , ID_rs1_r;
reg         [31:0]  ID_rs2_w                  , ID_rs2_r;
reg         [31:0]  ID_imm_w                  , ID_imm_r;
reg         [4:0 ]  ID_rs1_addr_w             , ID_rs1_addr_r;
reg         [4:0 ]  ID_rs2_addr_w             , ID_rs2_addr_r;
reg         [4:0 ]  ID_rd_w                   , ID_rd_r;
reg                 ID_mem_to_reg_w           , ID_mem_to_reg_r;
reg                 ID_mem_wen_D_w            , ID_mem_wen_D_r;
reg                 ID_Reg_write_w            , ID_Reg_write_r;
reg                 ID_ALU_src_w              , ID_ALU_src_r;
reg                 ID_mul_w                  , ID_mul_r;

reg         [3:0 ]  ID_alu_ctrl_w             , ID_alu_ctrl_r;
reg                 ID_jump_w                 , ID_jump_r;
reg         [31:0]  ID_pc_plus_four_w         , ID_pc_plus_four_r;
wire signed [31:0]  ID_pc_w;
assign ID_pc_w = $signed(IF_pc_plus_four_r) - $signed(32'd4);

// Branch, check whether Prediction is correct or wrong ?
wire                branch;
wire signed [31:0]  branch_addr;
wire                zero;
wire                brahcn_wrong;    
wire        [31:0]  ID_rs1_br       , ID_rs2_br;
wire                ID_B;

comparator cpr(.data1(ID_rs1_br), .data2(ID_rs2_br), .zero(zero));


// Load use Hazard detection -> PC & IF need to stall 1 cycle, and ID need flush 1 cycle
wire       hazard;
/////////////////////////////////////////// EX Stage Variable //////////////////////////////////////////

// ALU source and execution
wire        [31:0] alu_result;
wire        [31:0] rs1_val, rs2_val,EX_op1, EX_op2;
reg  signed [31:0] EX_out_w, EX_out_r;
reg         [31:0] EX_rs2_w, EX_rs2_r;
reg         [4:0 ] EX_rd_w, EX_rd_r;
reg                EX_mem_to_reg_w,EX_mem_to_reg_r;
reg                EX_mem_wen_D_w, EX_mem_wen_D_r;
reg                EX_Reg_write_w, EX_Reg_write_r;
reg                EX_mul_w, EX_mul_r;

// Forwarding logic
reg [1:0] forwardA, forwardB;

// Jump Address for jal/jalr
wire [31:0] jump_addr;

/////////////////////////////////////////// MEM Stage Variable //////////////////////////////////////////

wire [31:0] MEM_wdata;

reg [31:0] MEM_alu_out_w,MEM_alu_out_r;
reg [31:0] MEM_rdata_w, MEM_rdata_r;
reg [4:0 ] MEM_rd_w, MEM_rd_r;
reg        MEM_mem_to_reg_w, MEM_mem_to_reg_r;
reg        MEM_Reg_write_w, MEM_Reg_write_r;
reg        MEM_mul_w, MEM_mul_r;

/////////////////////////////////////////// WB Stage Variable //////////////////////////////////////////

// Write-back 
wire signed [31:0] Booth_mul;
wire        [31:0] WB_out_w;

// Register file
reg         [31:0] RF_r [0:31]; 

/////////////////////////////////////////// Trash :) //////////////////////////////////////////


assign PC_temp_add = $signed(PC_reg) + $signed(32'd4);
assign PC = PC_reg; 
assign ICACHE_ren = 1'b1;
assign ICACHE_wen = 1'b0; 
assign ICACHE_addr = PC_reg[31:2];
assign ICACHE_wdata = 32'd0; 

assign IF_immediate = {{20{IF_inst_w[31]}},IF_inst_w[7],IF_inst_w[30:25],IF_inst_w[11:8],1'b0};
assign IF_B = (IF_inst_w[6:0] == 7'b1100011); 
assign IF_BrPre = IF_BrPre_container & IF_B;

assign branch                = (beq & (zero)) | (bne & (~zero));
assign branch_addr           = (IF_BrPre_r)? IF_pc_plus_four_r : IF_branch_always_addr_r; // jump back or jump to target !
assign brahcn_wrong          = ID_B & ((branch & (~IF_BrPre_r)) | (IF_BrPre_r & (~branch)));
assign ID_B                  = IF_B_r;

// we need to debug this !!! branch / load hazard
assign ID_rs1_br             = (IF_inst_r[19:15] == ID_rd_r  && ID_Reg_write_r  && ID_rd_r  != 5'd0)? EX_out_w : 
                               (IF_inst_r[19:15] == EX_rd_r  && EX_Reg_write_r  && EX_rd_r  != 5'd0)? MEM_alu_out_w :
                               (IF_inst_r[19:15] == MEM_rd_r && MEM_Reg_write_r && MEM_rd_r != 5'd0)? WB_out_w : RF_r[{IF_inst_r[19:15]}];
assign ID_rs2_br             = (IF_inst_r[24:20] == ID_rd_r  && ID_Reg_write_r  && ID_rd_r  != 5'd0)? EX_out_w : 
                               (IF_inst_r[24:20] == EX_rd_r  && EX_Reg_write_r  && EX_rd_r  != 5'd0)? MEM_alu_out_w :
                               (IF_inst_r[24:20] == MEM_rd_r && MEM_Reg_write_r && MEM_rd_r != 5'd0)? WB_out_w : RF_r[{IF_inst_r[24:20]}];
assign hazard = (ID_mem_to_reg_r | ID_mul_r ) && ((ID_rs1_addr_w == ID_rd_r) || (ID_rs2_addr_w == ID_rd_r));
assign jump_addr = alu_result;
assign MEM_wdata = EX_rs2_r; // SW use rs2
assign WB_out_w = (MEM_mem_to_reg_r)? MEM_rdata_r : 
                  (MEM_mul_r)? Booth_mul : MEM_alu_out_r; // Choose between memory read data and ALU output


////////////////////////// IF Stage //////////////////////////

PredictionUnit br_pred(
    .BrPre(IF_BrPre_container),
    .clk(clk),
    .rst_n(RST_n),
    .stall(stall | hazard),
    .PreWrong(brahcn_wrong),
    .B(ID_B) 
);

always@(*) begin

    IF_branch_always_addr_w = $signed(PC_reg) + $signed(IF_immediate); 
    PC_w                 = (IF_BrPre)? IF_branch_always_addr_w : PC_temp_add;
    IF_valid_w           = 1'b1; 
    IF_pc_plus_four_w    = PC_temp_add; 
    IF_inst_w            = {ICACHE_rdata[7:0],ICACHE_rdata[15:8],ICACHE_rdata[23:16],ICACHE_rdata[31:24]}; 
    IF_BrPre_w           = (IF_B)? IF_BrPre : IF_BrPre_r;
    IF_B_w               = IF_B;

    // Case1: D$,I$ stall or Load-use hazard
    if(stall | hazard) begin
        PC_w = PC_reg; 
        IF_pc_plus_four_w = IF_pc_plus_four_r;
        IF_inst_w = IF_inst_r; 
        IF_branch_always_addr_w = IF_branch_always_addr_r; 
        IF_BrPre_w = IF_BrPre_r;
        IF_B_w = IF_B_r;
    end 

    // Case2: Branch predict wrong -> need to flush IF, and jump to right address
    else if (brahcn_wrong) begin
        PC_w = branch_addr;
        IF_valid_w = 1'b0;
        // IF_BrPre_w = 1'b0 we can use this instead of ID_B & ... for brahcn_wrong;
    end

    // Case3: Jal/Jalr -> need to flush IF,ID
    else if (ID_jump_r) begin
        PC_w = jump_addr;
        IF_valid_w = 1'b0;
    end

end

always@(posedge clk) begin

    if (!RST_n) begin
        PC_reg <= 32'd0; 
        IF_pc_plus_four_r <= 32'd0;
        IF_inst_r <= {{25{1'b0}},{7'b0010011}};  
        IF_branch_always_addr_r <= 32'd0;
        IF_BrPre_r <= 1'b0; 
        IF_B_r <= 1'b0; 
    end 

    else if (!IF_valid_w) begin
        PC_reg <= PC_w; 
        IF_pc_plus_four_r <= IF_pc_plus_four_w; 
        IF_inst_r <= {{25{1'b0}},{7'b0010011}};
        IF_branch_always_addr_r <= 32'd0;
        IF_BrPre_r <= IF_BrPre_w;
        IF_B_r <= IF_B_w; 
    end

    else begin
        PC_reg <= PC_w; 
        IF_pc_plus_four_r <= IF_pc_plus_four_w;
        IF_inst_r <= IF_inst_w; 
        IF_branch_always_addr_r <= IF_branch_always_addr_w; 
        IF_BrPre_r <= IF_BrPre_w; 
        IF_B_r <= IF_B_w; 
    end

end

////////////////////////// ID Stage //////////////////////////

// Combinational 
always@(*)begin

    // WB half cycle :) -> directly choose it from WB 
    ID_rs1_w = (jal)? ID_pc_w:(IF_inst_r[19:15] == MEM_rd_r && MEM_Reg_write_r && MEM_rd_r != 5'd0)? WB_out_w : RF_r[{IF_inst_r[19:15]}] ;
    ID_rs2_w = (IF_inst_r[24:20] == MEM_rd_r && MEM_Reg_write_r && MEM_rd_r != 5'd0)? WB_out_w : RF_r[{IF_inst_r[24:20]}] ;

    ID_rs1_addr_w             = (jal)? 5'd0  :  IF_inst_r[19:15];
    ID_rs2_addr_w             = (jal)? 5'd0  :  IF_inst_r[24:20];
    ID_rd_w                   =                 IF_inst_r[11:7]; 
    ID_imm_w                  =                 immediate;
    ID_mem_to_reg_w           =                 mem_to_reg;
    ID_mem_wen_D_w            =                 mem_wen_D;
    ID_Reg_write_w            =                 Reg_write;
    ID_ALU_src_w              =                 ALU_src;
    ID_alu_ctrl_w             =                 alu_ctrl;
    ID_mul_w                  =                 mul; 
    ID_jump_w                 =                 jalr | jal;
    ID_pc_plus_four_w         =                 IF_pc_plus_four_r; 

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
        ID_mul_w = ID_mul_r;
        ID_jump_w = ID_jump_r;
        ID_pc_plus_four_w = ID_pc_plus_four_r;
    end

end

// Instruction Decode
always@(*) begin 

    // Default -> use "AND" operation
    jal         = 0;
    jalr        = 0;
    beq         = 0;
    bne         = 0;
    ALU_src     = 0;
    Reg_write   = 0;
    mem_to_reg  = 0;
    mem_wen_D   = 0;
    immediate   = 32'd0;
    alu_ctrl    = 4'd7;
    mul         = 0;

    // We are going to decode !!!
    case(IF_inst_r[6:0])  
    
        // (case 1) R: add, sub, and, or, xor, slt
        7'b0110011: begin   
            Reg_write   = 1;
            alu_ctrl    = (IF_inst_r[30])? 4'd3 : {1'b0, IF_inst_r[14:12]};
        end

        // (case 2) I: addi, andi, ori, xori, slti, slli, srli, srai
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

        // (case 3) I: lw
        7'b0000011: begin
            ALU_src    = 1;
            mem_to_reg = 1;
            Reg_write  = 1;
            immediate  = {{21{IF_inst_r[31]}},IF_inst_r[30:25],IF_inst_r[24:21],IF_inst_r[20]};
            alu_ctrl   = 4'd0;
        end       

        // (case 4) I: jalr
        7'b1100111: begin
            jalr      = 1;
            Reg_write = 1;
            ALU_src   = 1;
            immediate = {{21{IF_inst_r[31]}},IF_inst_r[30:25],IF_inst_r[24:21],IF_inst_r[20]};
            alu_ctrl    = 4'd0;
        end  

        // (case 5) S: sw
        7'b0100011: begin
            ALU_src   = 1;
            mem_wen_D = 1;
            immediate = {{21{IF_inst_r[31]}},IF_inst_r[30:25],IF_inst_r[11:8],IF_inst_r[7]};
            alu_ctrl  = 4'd0;
        end

        // (case 6) B: beq , bne
        7'b1100011: begin
            beq       = !IF_inst_r[12];
            bne       = IF_inst_r[12];
            immediate = {{20{IF_inst_r[31]}},IF_inst_r[7],IF_inst_r[30:25],IF_inst_r[11:8],1'b0};
        end

        // (case 7) J: jal
        7'b1101111: begin
            jal       = 1;
            Reg_write = 1;
            ALU_src   = 1;
            immediate = {{12{IF_inst_r[31]}},IF_inst_r[19:12],IF_inst_r[20],IF_inst_r[30:21],1'b0};
            alu_ctrl    = 4'd0;
        end

        // (case 8) M: Mul
        7'b0000001: begin
            Reg_write = 1; 
            mul       = 1;      
        end

    endcase
end

// Sequential
always@(posedge clk) begin
    if ((!RST_n) | ((hazard|ID_jump_r) & (~stall))) begin
        ID_rs1_r <= 32'd0;
        ID_rs2_r <= 32'd0;
        ID_rs1_addr_r <= 5'd0; 
        ID_rs2_addr_r <= 5'd0; 
        ID_rd_r <= 5'd0;
        ID_imm_r <= 32'd0;
        ID_mem_to_reg_r <= 1'b0;
        ID_mem_wen_D_r <= 1'b0;
        ID_Reg_write_r <= 1'b0;
        ID_ALU_src_r <= 1'b0;
        ID_alu_ctrl_r <= 4'd7;
        ID_mul_r <= 1'b0; 
        ID_jump_r <= 1'b0;
        ID_pc_plus_four_r <= 32'd0; 
    end 

    else begin
        ID_rs1_r <= ID_rs1_w; 
        ID_rs2_r <= ID_rs2_w; 
        ID_rs1_addr_r <= ID_rs1_addr_w; 
        ID_rs2_addr_r <= ID_rs2_addr_w; 
        ID_rd_r <= ID_rd_w;
        ID_imm_r <= ID_imm_w; 
        ID_mem_to_reg_r <= ID_mem_to_reg_w; 
        ID_mem_wen_D_r <= ID_mem_wen_D_w; 
        ID_Reg_write_r <= ID_Reg_write_w;
        ID_ALU_src_r <= ID_ALU_src_w; 
        ID_alu_ctrl_r <= ID_alu_ctrl_w; 
        ID_mul_r <= ID_mul_w;
        ID_jump_r <= ID_jump_w;
        ID_pc_plus_four_r <= ID_pc_plus_four_w;
    end
end

////////////////////////// EX Stage //////////////////////////

ALU alu_u(
    .alu_ctrl(ID_alu_ctrl_r),
    .data1(EX_op1),
    .data2(EX_op2),
    .alu_calc(alu_result)
);

BoothMul mul_u(
    .clk(clk),
    .rst_n(RST_n),
    .stall(stall),
    .a(EX_op1),
    .b(EX_op2),
    .m(Booth_mul)
);

// Forwarding Part !!!
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
                 (forwardA==2'b01) ? WB_out_w : 
                 (forwardA==2'b10) ? MEM_alu_out_w : 32'd0;

assign rs2_val = (forwardB==2'b00) ? ID_rs2_r :
                 (forwardB==2'b01) ? WB_out_w : 
                 (forwardB==2'b10) ? MEM_alu_out_w : 32'd0;

// Get correct ALU operands
assign EX_op1 = rs1_val; 
assign EX_op2 = (ID_ALU_src_r) ? ID_imm_r : rs2_val; 

always@(*) begin
    EX_rd_w = ID_rd_r; 
    EX_mem_to_reg_w = ID_mem_to_reg_r; 
    EX_mem_wen_D_w = ID_mem_wen_D_r; 
    EX_Reg_write_w = ID_Reg_write_r;
    EX_mul_w = ID_mul_r;
    EX_out_w = (ID_jump_r)? ID_pc_plus_four_r : alu_result; // jump address (PC+4) or other ALU result
    EX_rs2_w = rs2_val; // Forward rs2 value, need to use it for SW

    if(stall) begin
        EX_rd_w = EX_rd_r;
        EX_mem_to_reg_w = EX_mem_to_reg_r;
        EX_mem_wen_D_w = EX_mem_wen_D_r;
        EX_Reg_write_w = EX_Reg_write_r;
        EX_mul_w = EX_mul_r;
        EX_out_w = EX_out_r;
        EX_rs2_w = EX_rs2_r; 
    end
end

always@(posedge clk) begin
    if (!RST_n) begin
        EX_rd_r <= 5'd0;
        EX_mem_to_reg_r <= 1'b0;
        EX_mem_wen_D_r <= 1'b0;
        EX_Reg_write_r <= 1'b0;
        EX_mul_r <= 1'b0;
        EX_out_r <= 32'd0;
        EX_rs2_r <= 32'd0; 
    end 
    
    else begin
        EX_rd_r <= EX_rd_w; 
        EX_mem_to_reg_r <= EX_mem_to_reg_w; 
        EX_mem_wen_D_r <= EX_mem_wen_D_w; 
        EX_Reg_write_r <= EX_Reg_write_w; 
        EX_mul_r <= EX_mul_w;
        EX_out_r <= EX_out_w; 
        EX_rs2_r <= EX_rs2_w; 
    end
end

////////////////////////// MEM Stage //////////////////////////

assign DCACHE_ren = ~EX_mem_wen_D_r; 
assign DCACHE_wen = EX_mem_wen_D_r; 
assign DCACHE_addr = EX_out_r[31:2]; 
assign DCACHE_wdata = {MEM_wdata[7:0],MEM_wdata[15:8],MEM_wdata[23:16],MEM_wdata[31:24]}; 

always@(*) begin
    MEM_alu_out_w = EX_out_r;
    MEM_rdata_w = {DCACHE_rdata[7:0],DCACHE_rdata[15:8],DCACHE_rdata[23:16],DCACHE_rdata[31:24]}; 
    MEM_rd_w = EX_rd_r; 
    MEM_mem_to_reg_w = EX_mem_to_reg_r; 
    MEM_Reg_write_w = EX_Reg_write_r; 
    MEM_mul_w = EX_mul_r;

    if(stall) begin
        MEM_alu_out_w = MEM_alu_out_r;
        MEM_rdata_w = MEM_rdata_r;
        MEM_rd_w = MEM_rd_r;
        MEM_mem_to_reg_w = MEM_mem_to_reg_r;
        MEM_Reg_write_w = MEM_Reg_write_r; 
        MEM_mul_w = MEM_mul_r;
    end
end

always@(posedge clk) begin
    if (!RST_n) begin
        MEM_rdata_r <= 32'd0; 
        MEM_alu_out_r <= 32'd0;
        MEM_rd_r <= 5'd0;
        MEM_mem_to_reg_r <= 1'b0; 
        MEM_Reg_write_r <= 1'b0; 
        MEM_mul_r <= 1'b0;
    end 
    
    else begin
        MEM_rdata_r <= MEM_rdata_w; 
        MEM_alu_out_r <= MEM_alu_out_w;
        MEM_rd_r <= MEM_rd_w; 
        MEM_mem_to_reg_r <= MEM_mem_to_reg_w; 
        MEM_Reg_write_r <= MEM_Reg_write_w; 
        MEM_mul_r <= MEM_mul_w;
    end
end

////////////////////////// WB Stage //////////////////////////
integer i;
always@(posedge clk) begin
    if (!RST_n) begin
        // Reset register file to zero
        for (i = 0; i < 32; i = i + 1) begin
            RF_r[i] <= 32'd0;
        end
    end 
    else if (MEM_Reg_write_r && MEM_rd_r != 5'd0) begin
        RF_r[MEM_rd_r] <= WB_out_w; 
    end
end

endmodule