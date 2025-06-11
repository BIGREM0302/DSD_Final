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
reg [63:0] temp5_w [0:2];
reg [63:0] temp5_r [0:2];

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
            temp5[2*j][i] = temp4[3*j][i];
        end
        else if(i >= 6 && i < 19) begin
            {temp5[2*j+1][i+1], temp5[2*j][i]} = HA_compress(temp4[3*j][i], temp4[3*j+1][i]);
        end
        else if (i == 63) begin
            {overflow, temp5[(2*j)][i]} = FA_compress(temp4[3*j][i], temp4[3*j+1][i], temp4[3*j+2][i]);
        end
        else begin
            {temp5[(2*j+1)][i+1], temp5[(2*j)][i]} = FA_compress(temp4_r[3*j][i], temp4[3*j+1][i], temp4[3*j+2][i]);
        end
    end
    // for 2
    temp5[2] = temp4[3];

// ================================== stage 6 ==========================================================
    for (i = 0; i < 2; i = i + 1)begin
        //initialize
        temp6[i] = 64'd0;
    end
    j = 0;
    for(i = 0; i < 64; i = i + 1) begin
        if( i < 7 )begin
            temp6[2*j][i] = temp5_r[3*j][i];
        end
        else if(i >= 7 && i < 28) begin
            {temp6[2*j+1][i+1], temp6[2*j][i]} = HA_compress(temp5_r[3*j][i], temp5_r[3*j+1][i]);
        end
        else if (i == 63) begin
            {overflow, temp6[(2*j)][i]} = FA_compress(temp5[3*j][i], temp5_r[3*j+1][i], temp5_r[3*j+2][i]);
        end
        else begin
            {temp6[(2*j+1)][i+1], temp6[(2*j)][i]} = FA_compress(temp5_r[3*j][i], temp5_r[3*j+1][i], temp5_r[3*j+2][i]);
        end
    end
end

always@(*) begin
    if(stall) begin
        for (i = 0; i < 8; i = i + 1) begin
            temp2_w[i] = temp2_r[i];
        end
        
        for (i = 0; i < 3; i = i + 1) begin
            temp5_w[i] = temp5_r[i];
        end
    end

    else begin
        for (i = 0; i < 8; i = i + 1) begin
            temp2_w[i] = temp2[i];
        end

        for (i = 0; i < 3; i = i + 1) begin
            temp5_w[i] = temp5[i];
        end
    end
end

always@(posedge clk) begin

    if(!rst_n) begin
        for (i = 0; i < 8; i = i + 1) begin
            temp2_r[i] <= 64'd0;
        end
        for (i = 0; i < 3; i = i + 1) begin
            temp5_r[i] <= 64'd0;
        end
    end 

    else begin
        for (i = 0; i < 8; i = i + 1) begin
            temp2_r[i] <= temp2_w[i];
        end

        for (i = 0; i < 3; i = i + 1) begin
            temp5_r[i] <= temp5_w[i];
        end
    end
end

endmodule