module decompressor (
    input  wire [15:0] c
    output reg  [31:0] r
);
    wire [2:0] funct3;
    wire [1:0] op;

    assign funct3 = instr16[15:13];
    assign op     = instr16[1:0];

    // For C0
    wire [ 4:0] C0rs1;
    wire [ 4:0] C0rs2rd;
    wire [11:0] C0imm;

    assign C0rs1   = {2'b00, c[9:7]};
    assign C0rs2rd = {2'b00, c[4:2]};
    assign C0imm   = {3'b000, c[5], c[12:10], c[6], 2'b00};

    // For C1-ADDI, NOP, SLLI
    wire [ 4:0] C1Ars1;
    wire [11:0] C1Aimm;
    assign C1Ars1 = c[11:7];
    assign C1Aimm = {c[12], c[6:2]};

    // For C1-JAL, J
    wire [13:0] C1Jimm;
    assign C1Jimm = {c[12], c[8], c[10:9], c[6], c[7], c[2], c[11], c[5:3]}

    // For C1-SRLI, SRAI, ANDI, BEQZ, BNEZ
    wire [ 4:0] C1Srs1;
    wire [11:0] C1Simm;
    assign C1Srs1 = {2'b00, c[9:7]};
    assign C1Simm = {8{c[12]}, c[6:2]};

    // For C1-BEQZ, BNEZ
    wire [11:0] C1Bimm;
    assign C1Bimm = {c[12], c[6:5], c[2], c[11:10], c[4:3]};

    // For C2-
    wire [4:0] C2rs1rd;
    wire [4:0] C2rs2;
    assign C2rs1rd = c[11:7];
    assign C2rs2   = c[6:2];

    always @(*) begin
        case (op)
            2'b00: begin
                case (funct3)
                    3'b010: begin // LW
                        r = {C0imm, C0rs1, 5'b010, C0rs2rd, 7'b0000011};
                    end
                    3'b110: begin // SW
                        r = {C0imm[11:5], C0rs2rd, C0rs1, 3'b010, C0imm[4:0], 7'b0100011};
                    end
                endcase
            end
            2'b01: begin
                case (funct3)
                    3'b000: // ADDI, NOP
                        r = {C1Aimm, C1Ars1, 3'b111, C1Ars1, 7'b0010011};
                    3'b001: // JAL
                        r = {C1Jimm[20], C1Jimm[10:1], C1Jimm[11], C1Jimm[19:12], 5'd1, 7'b1101111};
                    3'b100: // ANDI, SRLI, SRAI
                        case (c[10:11])
                            2'b00: begin // SRLI
                                r = {7'b0000000, C1Simm[4:0], C1Srs1, 3'b101, C1Srs1, 7'b0010011}
                            end
                            2'b01: begin // SRAI
                                r = {7'b0100000, C1Simm[4:0], C1Srs1, 3'b101, C1Srs1, 7'b0010011}
                            end
                            2'b10: begin // ANDI
                                r = {C1Simm, C1Srs1, 3'b111, C1Srs1, 7'b0010011}
                            end
                        endcase
                    3'b101: begin // J
                        r = {C1Jimm[20], C1Jimm[10:1], C1Jimm[11], C1Jimm[19:12], 5'd0, 7'b1101111};
                    end
                    3'b110: begin // BEQZ
                        r = {C1Bimm[12], C1Bimm[10:5], 5'd0, C1Srs1, 3'b000, C1Bimm[4:1], C1Bimm[11], 7'b1100011}
                    end
                    3'b111: begin // BNEZ
                        r = {C1Bimm[12], C1Bimm[10:5], 5'd0, C1Srs1, 3'b001, C1Bimm[4:1], C1Bimm[11], 7'b1100011}
                    end
                endcase
            end
            2'b10: begin
                case (funct3)
                    3'b000: // SLLI
                        r = {7'b0100000, C1Aimm[4:0], C1Ars1, 3'b001, C1Ars1, 7'b0010011}
                    3'b100: // JR, JALR, MV, ADD
                        if (c[12] == 1'b0) begin
                            if (C2rs2 == 5'd0) begin // JR
                                r = {11'd0, C2rs1rd, 3'b000, 5'd0, 7'b1100111}
                            end else begin // MV
                                r = {7'b0000000, C2rs2, 5'd0, 3'b000, C2rs1rd, 7'b0110011}
                            end
                        end else begin
                            if (C2rs2 == 5'd0) begin // JALR
                                r = {11'd0, C2rs1rd, 3'b000, 5'd1, 7'b1100111}
                            end else begin // ADD
                                r = {7'b0000000, C2rs2, C2rs1rd, 3'b000, C2rs1rd, 7'b0110011}
                            end
                        end
                endcase
            end
        endcase
    end

endmodule
