module PredictionUnit (
    output BrPre,          // 1: predict taken, 0: predict not-taken
    input  clk,
    input  rst_n,
    input  stall,          // pipeline stall
    input  PreWrong,       // 1: mis-prediction on this branch
    input  B               // 1: the inst. in IF is a branch inst.
);

    // 2-bit saturating counter：00,01,10,11
    // 00 : Strongly Not-Taken
    // 01 : Weakly Not-Taken
    // 10 : Weakly Taken
    // 11 : Strongly Taken
    
    reg [1:0] counter;

    assign BrPre = counter[1];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 2'b01;
        end
        else if (!stall && B) begin
            if (BrPre) begin
                if (PreWrong) begin
                    if (counter != 2'b00)
                        counter <= counter - 1'b1;
                end
                else begin
                    if (counter != 2'b11)
                        counter <= counter + 1'b1;
                end
            end
            else begin
                if (PreWrong) begin
                    if (counter != 2'b11)
                        counter <= counter + 1'b1;
                end
                else begin
                    if (counter != 2'b00)
                        counter <= counter - 1'b1;
                end
            end
        end
    end

endmodule