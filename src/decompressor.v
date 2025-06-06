module decompressor (
    input  wire [15:0] instr16,
    output reg  [31:0] instr32
);
    wire [2:0] funct3;
    wire [1:0] op;

    assign funct3 = instr16[15:13];
    assign op = instr16[1:0];

    always @(*) begin
        case (op)
            2'b00: begin
                case (funct3)
                    3'b010: // LW
                    3'b110: // SW
                endcase
            end
            2'b01: begin
                case (funct3)
                    3'b000: // ADDI, NOP
                    3'b001: // JAL
                    3'b100: // ANDI, SRLI, SRAI
                    3'b101: // J
                    3'b110: // BEQZ
                    3'b111: // BNEZ
                endcase
            end
            2'b10: begin
                case (funct3)
                    3'b000: // SLLI
                    3'b100: // JR, JALR, MV, ADD
                endcase
            end
        endcase
    end

endmodule
