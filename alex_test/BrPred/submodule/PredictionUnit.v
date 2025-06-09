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