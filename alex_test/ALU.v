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