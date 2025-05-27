// Your SingleCycle RISC-V code

module ALU(alu_ctrl,
           data1,
           data2,
           alu_calc,
           zero
);
    input         [3:0]  alu_ctrl;
    input  signed [31:0] data1;
    input  signed [31:0] data2;
    output        [31:0] alu_calc;
    output         zero;

    wire          [31:0] temp;
    assign zero = ~(|(alu_calc));

    assign temp =     (alu_ctrl == 4'b0001)? data1 | data2:
                      (alu_ctrl == 4'b0010)? data1 + data2:
                      (alu_ctrl == 4'b0110)? data1 - data2: 
                      (alu_ctrl == 4'b1000)? data1 - data2: data1 & data2;

    assign alu_calc = (alu_ctrl == 4'b1000)? {31'd0,temp[31]}:temp;

endmodule

module core(clk,
            rst_n,
            // for mem_D
            mem_wen_D,
            mem_addr_D,
            mem_wdata_D,
            mem_rdata_D,
            // for mem_I
            mem_addr_I,
            mem_rdata_I
    );

// i/p port and o/p port //

    input         clk, rst_n ;
    // for mem_D
    output reg        mem_wen_D  ;  // mem_wen_D is high, core writes data to D-mem; else, core reads data from D-mem
    output     [31:0] mem_addr_D ;  // the specific address to fetch/store data 
    output     [31:0] mem_wdata_D;  // data writing to D-mem 
    input      [31:0] mem_rdata_D;  // data reading from D-mem
    // for mem_I
    output [31:0] mem_addr_I ;  // the fetching address of next instruction
    input  [31:0] mem_rdata_I;  // instruction reading from I-mem

// variable declaration //

    reg    [31:0] RF_r [0:31]; 
    reg    [31:0] PC_r;
    wire   [31:0] PC_w;
    wire   [31:0] rs1;          // default data1 :)
    wire   [31:0] rs2;
    wire   [31:0] data2;        // choose by ALU_src
    reg    [31:0] immediate;
    wire   [31:0] alu_calc;
    wire          zero;
    wire   [31:0] branch_jal_addr;
    wire   [31:0] jalr_addr;
    wire   [31:0] write_back;

    reg          jal;
    reg          jalr;
    reg          branch;
    reg          ALU_src;
    reg          Reg_write;
    reg          mem_to_reg;
    reg   [3:0]  alu_ctrl;
    wire  [3:0]  alu_ctrl_w;
    assign alu_ctrl_w = alu_ctrl;

    wire  [31:0] inst;
    assign inst = {mem_rdata_I[7:0],mem_rdata_I[15:8],mem_rdata_I[23:16],mem_rdata_I[31:24]};

// submodule //
    ALU alu1(.alu_ctrl(alu_ctrl_w),
             .data1(rs1),
             .data2(data2),
             .alu_calc(alu_calc),
             .zero(zero));

// assign var & output //

    assign rs1 = RF_r[inst[19:15]];
    assign rs2 = RF_r[inst[24:20]];
    assign data2 = (ALU_src)? immediate : rs2;
    assign branch_jal_addr = PC_r + immediate;
    assign jalr_addr = immediate + rs1; 
    assign mem_addr_D  = alu_calc;
    assign mem_wdata_D = {rs2[7:0],rs2[15:8],rs2[23:16],rs2[31:24]};
    assign mem_addr_I = PC_r;         
    assign PC_w = ((branch&zero)|jal)?branch_jal_addr:
                  (jalr)? jalr_addr: PC_r+4;     
    assign write_back = (jal|jalr)? PC_r+4:
                        (mem_to_reg)? {mem_rdata_D[7:0],mem_rdata_D[15:8],mem_rdata_D[23:16],mem_rdata_D[31:24]}: alu_calc;    

// alway comb ckt for imm_gen & alu_ctrl & other ctrl signal //

    always@(*) begin      

        jal         = 0;
        jalr        = 0;
        branch      = 0;
        ALU_src     = 0;
        Reg_write   = 0;
        mem_to_reg  = 0;
        mem_wen_D   = 0;
        immediate   = 0;
        alu_ctrl    = 4'b0010;

        case(inst[6:0])  // R: add,sub,and,or,slt  I:lw,jalr  S:sw  B:beq  J:jal
            // R: add,sub,and,or,slt
            7'b0110011: begin
                Reg_write  = 1;
                alu_ctrl[3]= inst[14] ^ inst[13];
                alu_ctrl[2]= inst[30];
                alu_ctrl[1]= ~(|inst[14:12]);
                alu_ctrl[0]= inst[14]&inst[13]&(~inst[12]);
            end

            // I:lw
            7'b0000011: begin
                ALU_src    = 1;
                mem_to_reg = 1;
                Reg_write  = 1;
                immediate  = {{21{inst[31]}},inst[30:25],inst[24:21],inst[20]};
            end       

            // I:jalr
            7'b1100111: begin
                jalr      = 1;
                Reg_write = 1;
                immediate = {{21{inst[31]}},inst[30:25],inst[24:21],inst[20]};
            end  

            // S:sw
            7'b0100011: begin
                ALU_src   = 1;
                mem_wen_D = 1;
                immediate = {{21{inst[31]}},inst[30:25],inst[11:8],inst[7]};
            end

            // B:beq
            7'b1100011: begin
                branch    = 1;
                immediate = {{20{inst[31]}},inst[7],inst[30:25],inst[11:8],1'b0};
                alu_ctrl  = 4'b0110;
            end

            // J:jal
            7'b1101111: begin
                jal       = 1;
                Reg_write = 1;
                immediate = {{12{inst[31]}},inst[19:12],inst[20],inst[30:21],1'b0};
            end

        endcase
    end

// always ff ckt //
    integer j;
    always@(posedge clk) begin

        if(!rst_n) begin
            for(j = 0; j < 32; j = j + 1) begin
                RF_r[j] <= 32'd0;
            end
            PC_r <= 32'd0;
        end

        else begin
            if (Reg_write) begin
                case (inst[11:7])
                    5'd0  : RF_r[0]   <= 32'd0;
                    5'd1  : RF_r[1]   <= write_back;
                    5'd2  : RF_r[2]   <= write_back;
                    5'd3  : RF_r[3]   <= write_back;
                    5'd4  : RF_r[4]   <= write_back;
                    5'd5  : RF_r[5]   <= write_back;
                    5'd6  : RF_r[6]   <= write_back;
                    5'd7  : RF_r[7]   <= write_back;
                    5'd8  : RF_r[8]   <= write_back;
                    5'd9  : RF_r[9]   <= write_back;
                    5'd10 : RF_r[10]  <= write_back;
                    5'd11 : RF_r[11]  <= write_back;
                    5'd12 : RF_r[12]  <= write_back;
                    5'd13 : RF_r[13]  <= write_back;
                    5'd14 : RF_r[14]  <= write_back;
                    5'd15 : RF_r[15]  <= write_back;
                    5'd16 : RF_r[16]  <= write_back;
                    5'd17 : RF_r[17]  <= write_back;
                    5'd18 : RF_r[18]  <= write_back;
                    5'd19 : RF_r[19]  <= write_back;
                    5'd20 : RF_r[20]  <= write_back;
                    5'd21 : RF_r[21]  <= write_back;
                    5'd22 : RF_r[22]  <= write_back;
                    5'd23 : RF_r[23]  <= write_back;
                    5'd24 : RF_r[24]  <= write_back;
                    5'd25 : RF_r[25]  <= write_back;
                    5'd26 : RF_r[26]  <= write_back;
                    5'd27 : RF_r[27]  <= write_back;
                    5'd28 : RF_r[28]  <= write_back;
                    5'd29 : RF_r[29]  <= write_back;
                    5'd30 : RF_r[30]  <= write_back;
                    5'd31 : RF_r[31]  <= write_back;
                endcase
            end
            PC_r <= PC_w;
        end

    end
endmodule