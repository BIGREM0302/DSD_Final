module decompressor (
    input  wire [15:0] instr16,
    output reg  [31:0] instr32
);

    //--------------------------------------------------------------------------
    // RVC 檢測：若 instr16[1:0] == 2'b11，則不是壓縮指令（範例裡直接回傳 NOP）
    // 否則就要依 funct3（instr16[15:13]）與不同格式解碼
    //--------------------------------------------------------------------------
    wire [1:0]   c_opcode     = instr16[1:0];       // 壓縮指令的低 2 bits
    wire [2:0]   c_funct3     = instr16[15:13];     // 壓縮指令的 funct3
    // 為了方便，先把幾個常用的欄位拆出來：
    wire [4:0]   c_rd_rs1     = {2'b01, instr16[4:2]};    // “rd’/“rs1’”: 取 c 指令中 bits[4:2]，再加上常數 01（只支援 x8~x15 這組暫存器），組成 5-bit
    wire [4:0]   c_rs2_rs2p   = {2'b01, instr16[9:7]};    // “rs2’/“rs2p”: 同樣取 bits[9:7]，再加上 01
    wire [4:0]   c_rs1_rd     = {2'b01, instr16[9:7]};    // 某些格式下此欄位代表 rs1 或 rd，同樣只對應 x8~x15
    // 以下拆各種 immediate 用的欄位，以統一方式在 case 裡做 sign-extend
    wire         c_imm_sgn    = instr16[12];            // 用在某些立即數指令當作 sign bit
    wire [5:0]   c_imm_bits   = { instr16[12], instr16[6:2] };  
    // 但不同指令格式的位元排列不同，會在 case 裡另行拼接

    always @* begin
        // 如果低兩位是 11，表示不是壓縮指令；這裡直接回傳 NOP (ADDI x0,x0,0)
        if (c_opcode == 2'b11) begin
            instr32 = 32'h0000_0013;  // ADDI x0, x0, 0 → NOP
        end
        else begin
            // 一般情況：以 funct3 來區分各種 compressed 類別
            case (c_funct3)
                //--------------------------------------------------------
                // 1) C.ADDI (funct3 == 3'b000，opcode=01)
                //    格式：| 12 | 6 | 5:2 | 1:0 |
                //         | imm[5] | imm[4:0] | 01 |
                //    rd = bits[11:7] (實際位於 instr16[11:7] = instr16[12] + instr16[6:2] → 合併成 6bit)
                //    rd (x8~x15) → 實作時直接把 c_imm_bits 做 sign-extend 12 bit
                //    展開成： ADDI rd, rd, imm[5:0]
                //--------------------------------------------------------
                3'b000: begin 
                    // 濾掉所有 zero immediate（C.NOP），即如果 rd == 0 && imm == 0，則是 C.NOP
                    if ({c_imm_bits} == 6'b0 && c_rd_rs1 == 5'b00000) begin
                        instr32 = 32'h0000_0013;  // ADDI x0, x0, 0 → NOP
                    end else begin
                        // 16bit 中的 immed = { instr16[12], instr16[6:2] }
                        // sign extend 到 12 bits：{ {6{imm[5]}}, imm[5:0] }
                        wire [11:0] imm12 = { {6{c_imm_bits[5]}}, c_imm_bits };
                        // opcode (7) = 0010011, funct3=000
                        instr32 = { imm12, c_rd_rs1, 3'b000, c_rd_rs1, 7'b0010011 };
                    end
                end

                //--------------------------------------------------------
                // 2) C.SLLI (funct3 == 3'b001，opcode=01)  —— 只限 rd=rs1=x8~x15
                //    格式：|12|6:2|1:0|  (bit12=0 才視為 SLLI)
                //    shamt = bits[6:2] (5-bit)
                //    展開成： SLLI rd, rd, shamt
                //--------------------------------------------------------
                3'b001: begin
                    // C.SLLI 只有當 instr16[12] == 0 而且 rd != x0 才有效
                    if (instr16[12] == 1'b0 && c_rd_rs1 != 5'b00000) begin
                        wire [4:0] shamt = instr16[6:2];
                        // opcode=0010011, funct3=001
                        instr32 = { 7'b0000000, shamt, c_rd_rs1, 3'b001, c_rd_rs1, 7'b0010011 };
                    end else begin
                        instr32 = 32'h0000_0013;  // 當成 NOP
                    end
                end

                //--------------------------------------------------------
                // 3) C.SRLI / C.SRAI (funct3 == 3'b101，opcode=01)
                //    if instr16[12]==0 → C.SRLI  (logical)
                //    if instr16[12]==1 → C.SRAI  (arithmetic)
                //    只限 rd=rs1=x8~x15, bit11 must be 0 for C.SRLI/C.SRAI
                //    shamt = bits[6:2] (5-bit)
                //    展開：
                //      C.SRLI → SRLI rd, rd, shamt    (opcode=0010011, funct3=101)
                //      C.SRAI → SRAI rd, rd, shamt    (opcode=0010011, funct3=101, funct7=0100000)
                //--------------------------------------------------------
                3'b101: begin
                    if (c_rd_rs1 != 5'b00000) begin
                        wire [4:0] shamt = instr16[6:2];
                        if (instr16[12] == 1'b0) begin
                            // C.SRLI
                            wire [6:0] funct7 = 7'b0000000;
                            instr32 = { funct7, shamt, c_rd_rs1, 3'b101, c_rd_rs1, 7'b0010011 };
                        end else begin
                            // C.SRAI (funct7=0100000)
                            wire [6:0] funct7 = 7'b0100000;
                            instr32 = { funct7, shamt, c_rd_rs1, 3'b101, c_rd_rs1, 7'b0010011 };
                        end
                    end else begin
                        instr32 = 32'h0000_0013;  // 當成 NOP
                    end
                end

                //--------------------------------------------------------
                // 4) C.ANDI (funct3 == 3'b011，opcode=01)
                //    格式：|12|6:2|1:0|  (bit12 = sign, bits[6:2]=imm[4:0])
                //    rd=rs1=x8~x15
                //    展開成： ANDI rd, rd, imm
                //--------------------------------------------------------
                3'b011: begin
                    if (c_rd_rs1 != 5'b00000) begin
                        // 立即數 = { instr16[12], instr16[6:2] } → 6 bits，再 sign extend 到12
                        wire [5:0] imm6  = { instr16[12], instr16[6:2] };
                        wire [11:0] imm12 = { {6{imm6[5]}}, imm6 };
                        instr32 = { imm12, c_rd_rs1, 3'b111, c_rd_rs1, 7'b0010011 };
                    end else begin
                        instr32 = 32'h0000_0013;  // 當成 NOP
                    end
                end

                //--------------------------------------------------------
                // 5) C.LW (funct3 == 3'b010，opcode=00，只支援 UIMM 模式)
                //    格式：| 5 | 3 | 2 | 6 | 5:4 | 1:0 |
                //         | uimm[5] | uimm[4:3] | rs1’ | uimm[2] | rd’ | 00 |
                //    uimm = { instr16[5], instr16[12:10], instr16[6] } << 2
                //    rs1’ = bits[9:7] (→ c_rs1_rd, x8~x15)
                //    rd’  = bits[4:2] (→ c_rd_rs1, x8~x15)
                //    展開成： LW rd, uimm(rs1)
                //    32-bit lw 格式： imm[11:0] | rs1[4:0] | funct3=010 | rd[4:0] | opcode=0000011
                //--------------------------------------------------------
                3'b010: begin
                    // uimm[5] = instr16[5]
                    // uimm[4:3] = instr16[12:11]
                    // uimm[2] = instr16[6]
                    wire [5:0] uimm6 = { instr16[5], instr16[12:11], instr16[6], 1'b0 };  
                    // 最後 << 2，因此實際 imm12 = { 6'b000000, uimm6[5:0] }
                    wire [11:0] imm12 = { 6'b000000, uimm6 };
                    instr32 = { imm12, c_rs1_rd, 3'b010, c_rd_rs1, 7'b0000011 };
                end

                //--------------------------------------------------------
                // 6) C.SW (funct3 == 3'b110，opcode=00)
                //    格式：| 5 | 3 | 2 | 6 | 5:4 | 1:0 |
                //         | uimm[5] | uimm[4:3] | rs1’ | uimm[2] | rs2’ | 00 |
                //    uimm = { instr16[5], instr16[12:10], instr16[6] } << 2
                //    rs1’ = bits[9:7]  (→ c_rs1_rd)
                //    rs2’ = bits[4:2]  (→ c_rs2_rs2p)
                //    展開成： SW rs2, uimm(rs1)
                //    32-bit sw 格式： imm[11:5] | rs2[4:0] | rs1[4:0] | funct3=010 | imm[4:0] | opcode=0100011
                //--------------------------------------------------------
                3'b110: begin
                    wire [5:0] uimm6 = { instr16[5], instr16[12:11], instr16[6], 1'b0 };  
                    wire [11:0] imm12 = { 6'b000000, uimm6 };
                    // sw 需要把 imm12 分成 imm[11:5] 和 imm[4:0]
                    instr32 = { imm12[11:5], c_rs2_rs2p, c_rs1_rd, 3'b010, imm12[4:0], 7'b0100011 };
                end

                //--------------------------------------------------------
                // 7) C.ADD (funct3 == 3'b100, bits[12]=0), C.MV (funct3 == 3'b100, bits[12]=1)
                //    7-bit funct3=100, opcode=10（10 表示 10|1 = 101，實際上 16bit 中 op=10）
                //    如果 bits[12]==0 → C.ADD，rs2’ → 寫成 ADD rd, rd, rs2
                //    如果 bits[12]==1 → C.MV (rd／rs1 都是 bits[11:7], rs2=bits[6:2]) → MV rd, rs2 = ADD rd, x0, rs2
                //    展開成：
                //     C.ADD → ADD rd, rd, rs2
                //        32-bit: funct7=0000000, rs2, rs1=rd, funct3=000, rd, opcode=0110011
                //     C.MV  → ADD rd, x0, rs2
                //        32-bit: funct7=0000000, rs2, rs1=x0(00000), funct3=000, rd, opcode=0110011
                //--------------------------------------------------------
                3'b100: begin
                    if (instr16[12] == 1'b0) begin
                        // C.ADD   → rd = c_rs1_rd, rs2=c_rs2_rs2p
                        instr32 = { 7'b0000000, c_rs2_rs2p, c_rs1_rd, 3'b000, c_rs1_rd, 7'b0110011 };
                    end else begin
                        // C.MV    → rd = c_rs1_rd, rs2=c_rs2_rs2p，rs1 = x0 (00000)
                        instr32 = { 7'b0000000, c_rs2_rs2p, 5'b00000, 3'b000, c_rs1_rd, 7'b0110011 };
                    end
                end

                //--------------------------------------------------------
                // 8) C.JAL (funct3 == 3'b001，opcode=01, rd= x1 (RA))
                //    格式：| imm[11] | imm[4] | imm[9:8] | imm[10] | imm[6] | imm[7] | imm[3:1] | imm[5] | 01 |
                //    立刻數組成方式較複雜 (依照 spec 排列)，組成 12 位的有符號 J-type 立即數
                //    展開成： JAL x1, imm
                //    32-bit: imm[20|10:1|11|19:12], rd=00001, opcode=1101111 (JAL)
                //--------------------------------------------------------
                3'b001: begin
                    // 如果 funct3=001 → 依規範一定是 C.JAL (只針對 RV32/64)
                    // 取出各 bit：
                    wire      j_11   = instr16[12];
                    wire      j_4    = instr16[11];
                    wire [1:0]j_9_8  = instr16[10:9];
                    wire      j_10   = instr16[8];
                    wire      j_6    = instr16[7];
                    wire      j_7    = instr16[6];
                    wire [2:0]j_3_1  = instr16[5:3];
                    wire      j_5    = instr16[2];
                    // 12-bit 立即數 (注意第 11 位是最高位)
                    wire [11:0] imm12 = { j_11, j_10, j_9_8, j_8/*placeholder*/, j_7, j_6, j_5, j_4, j_3_1 };
                    // 但要依 J-type 排列成 20 位： 
                    //   imm[20] = imm12[11]
                    //   imm[10:1]= imm12[10:1]
                    //   imm[11] = imm12[0]
                    //   imm[19:12]= 0 (因為 c 指令只有 12 位)
                    wire [19:0] imm20 = { imm12[11],      // imm[11] → imm20[19]
                                          imm12[10:1],    // imm[10:1] → imm20[10:1]
                                          1'b0,           // imm[0]=0 (always 2-byte aligned)
                                          8'b0            // imm[19:12]=0 (補齊)
                                        };
                    // 但上面排列有誤，實際應該依 J-type format 插入：
                    //  imm20[20]    = imm12[11]
                    //  imm20[10:1]  = imm12[10:1]
                    //  imm20[11]    = imm12[0]
                    //  imm20[19:12] = imm12[...??]  (C-J 只有 11 位，所以高幾位補零)
                    //  以下簡化：直接算出 20 位 signed immediate，再扔進 32-bit
                    wire signed [20:0] simm20 =
                        { {8{imm12[11]}},        // sign extend to 21 bits
                          imm12[11],             // bit20
                          imm12[10:1],           // bit10:1
                          imm12[0],              // bit11
                          1'b0                   // bit0 = 0
                        };
                    // 本來 J-type 要把 imm20 拆成 [20][10:1][11][19:12]，但上面 simm20 已經完整排列好
                    // 所以 instr32 = { imm20[20], imm20[10:1], imm20[11], imm20[19:12], rd, opcode}
                    instr32 = { simm20[20], simm20[10:1], simm20[11], simm20[19:12],
                                5'b00001,  // rd = x1
                                7'b1101111 // opcode = JAL
                              };
                end

                //--------------------------------------------------------
                // 9) C.J (funct3 == 3'b101，opcode=01)
                //    類似 C.JAL，但 rd = x0，opcode=1101111，funct3 同樣從 c 指令取
                //--------------------------------------------------------
                3'b101: begin
                    // 取法同上面 C.JAL (僅差 rd=00000, opcode=1101111)
                    wire      j_11   = instr16[12];
                    wire      j_4    = instr16[11];
                    wire [1:0]j_9_8  = instr16[10:9];
                    wire      j_10   = instr16[8];
                    wire      j_6    = instr16[7];
                    wire      j_7    = instr16[6];
                    wire [2:0]j_3_1  = instr16[5:3];
                    wire      j_5    = instr16[2];
                    wire [11:0] imm12 = { j_11, j_10, j_9_8, 1'b0, j_7, j_6, j_5, j_4, j_3_1 };
                    wire signed [20:0] simm20 =
                        { {8{imm12[11]}},
                          imm12[11],
                          imm12[10:1],
                          imm12[0],
                          1'b0
                        };
                    instr32 = { simm20[20], simm20[10:1], simm20[11], simm20[19:12],
                                5'b00000,  // rd = x0
                                7'b1101111 // opcode = JAL
                              };
                end

                //--------------------------------------------------------
                //10) C.BEQZ / C.BNEZ (funct3 == 3'b110 或 3'b111，opcode=01)
                //    C.BEQZ (funct3=110)，C.BNEZ (funct3=111)
                //    格式：| imm[8] | imm[4:3] | rs1’ | imm[7:6] | imm[2:1] | imm[5] | 01 |
                //    imm = { instr16[12], instr16[6:5], instr16[2], instr16[11:10], instr16[4:3] } << 1
                //    rs1’ = bits[9:7] (x8~x15)
                //    展開成： BEQZ rs1, offset  或 BNEZ rs1, offset
                //    32-bit: imm[12|10:5] | rs2= x0 | rs1 | funct3 | imm[4:1|11] | opcode=1100011
                //--------------------------------------------------------
                3'b110, 3'b111: begin
                    wire      b5   = instr16[6];   // imm[5]
                    wire [1:0]b3_2 = instr16[5:4]; // imm[4:3]
                    wire [1:0]b1_0 = instr16[3:2]; // imm[2:1]
                    wire [1:0]b7_6 = instr16[11:10]; // imm[7:6]
                    wire      b8   = instr16[12];  // imm[8]
                    // 先把 9-bit imm: { b8, b7_6, b5, b4_3, b2_1, 0 }
                    wire [8:0] imm9 = { b8, b7_6, b5, b3_2, b1_0, 1'b0 };
                    // sign extend 到 13 bits: { {4{imm9[8]}}, imm9 }
                    wire [12:0] simm13 = { {4{imm9[8]}}, imm9 };
                    // 32-bit BEQ/BNE 需要把 simm13 排列成 { imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode}
                    wire [6:0] imm12_10_5 = simm13[12] ? simm13[12:7] : simm13[12:7];
                    // 其實比較直接：根據立即數格式手動插
                    wire [31:0] be_instr;
                    // BEQZ → opcode=1100011, funct3=000; BNEZ → opcode=1100011, funct3=001
                    if (c_funct3 == 3'b110) begin
                        // BEQZ
                        be_instr = { simm13[12], simm13[10:5], 5'b00000 /*rs2=x0*/, c_rs1_rd, 3'b000,
                                      simm13[4:1], simm13[11], 7'b1100011 };
                    end else begin
                        // BNEZ
                        be_instr = { simm13[12], simm13[10:5], 5'b00000 /*rs2=x0*/, c_rs1_rd, 3'b001,
                                      simm13[4:1], simm13[11], 7'b1100011 };
                    end
                    instr32 = be_instr;
                end

                //--------------------------------------------------------
                //11) C.JR / C.JALR (funct3 == 3'b100，且 bits[12:2] != above “ADD/MV”模式)
                //    C.JR (bit12=0, bits[11:7]!=0)  → JALR x0, 0(rs1)   (jump register)
                //    C.JALR (bit12=1, bits[11:7]!=0) → JALR x1, 0(rs1)   (jump and link)
                //    格式：|12|11:7|6:2|1:0|
                //         | bit12 | rs1 | 00000 | 10 |
                //    展開成： JALR rd, 0(rs1) [rd=x0 或 x1]
                //    32-bit: funct7(=0000000) | imm=0 | rs1 | funct3=000 | rd | opcode=1100111
                //--------------------------------------------------------
                3'b100: begin
                    // 先排除 C.ADD/C.MV (上面已處理 instr16[12]==0 或 c_rs1_rd==0)，所以這裡是 bits[6:2]==0 才是 JR/JALR
                    if (instr16[6:2] == 5'b00000 && c_rs1_rd != 5'b00000) begin
                        if (instr16[12] == 1'b0) begin
                            // C.JR → JALR x0, 0(rs1)
                            instr32 = { 7'b0000000, 5'b00000/*imm=*/ , c_rs1_rd, 3'b000, 5'b00000/*rd=x0*/, 7'b1100111 };
                        end else begin
                            // C.JALR → JALR x1, 0(rs1)
                            instr32 = { 7'b0000000, 5'b00000/*imm=*/ , c_rs1_rd, 3'b000, 5'b00001/*rd=x1*/, 7'b1100111 };
                        end
                    end else begin
                        instr32 = 32'h0000_0013; // 視為 NOP
                    end
                end

                //--------------------------------------------------------
                // 12) 其他未實作指令，直接當成 NOP
                //--------------------------------------------------------
                default: begin
                    instr32 = 32'h0000_0013;  // NOP
                end
            endcase
        end
    end

endmodule
