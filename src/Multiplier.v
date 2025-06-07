module BoothMul (
    a,
    b,
    m
);

input [31:0] a, b; //a be multiplicand, b be multiplier
output [63:0] m; // m = a * b (unsigned)

reg [33:0] PProd [0:15];
reg [63:0] shifted [0:15];

reg [63:0] temp1 [0:11];
reg [63:0] temp2 [0:7];
reg [63:0] temp3 [0:5];
reg [63:0] temp4 [0:3];
reg [63:0] temp5 [0:2];
reg [63:0] temp6 [0:1];

wire [34:0] upper_sum = temp6[0][63:30] + temp6[1][63:30];
assign m = {upper_sum[33:0], temp6[0][29:0]};

// Booth Encoding
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
        shifted[i] = {{29{PProd[i][33]}, PProd[i]}} << (2*i);
    end

    // stage 1
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
                {temp1[2*j][i+1], temp1[2*j][i]} = HA_compress(shifted[3*j][i], shifted[3*j+1][i]);
            end
            else if (i == 63) begin
                temp1[(2*j+1)][i] = FA_compress(shifted[3*j][i], shifted[3*j+1][i], shifted[3*j+2][i])[0];
            end
            else begin
                {temp1[(2*j+1)][i+1], temp1[(2*j+1)][i]} = FA_compress(shifted[3*j][i], shifted[3*j+1][i], shifted[3*j+2][i]);
            end
        end
    end
    temp1[10] = shifted[15];

    // stage 2
    for (i = 0; i < 8; i = i + 1)begin
        //initialize
        temp2[i] = 64'd0;
    end
    // for 0, 1
    j = 0;
    for(i = 0; i < 64; i = i + 1) begin
        if( i < 4 )begin
            temp2[2*j][i] = temp1[3*j][i];
        end
        else if(i >= 4 && i < 6) begin
            {temp2[2*j][i+1], temp2[2*j][i]} = HA_compress(temp1[3*j][i], temp1[3*j+1][i]);
        end
        else if (i == 63) begin
            temp2[(2*j+1)][i] = FA_compress(temp1[3*j][i], temp1[3*j+1][i], temp1[3*j+2][i])[0];
        end
        else begin
            {temp2[(2*j+1)][i+1], temp2[(2*j+1)][i]} = FA_compress(temp1[3*j][i], temp1[3*j+1][i], temp1[3*j+2][i]);
        end
    end
    j = 1;
    // for 2, 3
    for(i = 10; i < 64; i = i + 1) begin
        if( i < 12 )begin
            temp2[2*j][i] = temp1[3*j][i];
        end
        else if(i >= 12 && i < 16) begin
            {temp2[2*j][i+1], temp2[2*j][i]} = HA_compress(temp1[3*j][i], temp1[3*j+1][i]);
        end
        else if (i == 63) begin
            temp2[(2*j+1)][i] = FA_compress(temp1[3*j][i], temp1[3*j+1][i], temp1[3*j+2][i])[0];
        end
        else begin
            {temp2[(2*j+1)][i+1], temp2[(2*j+1)][i]} = FA_compress(temp1[3*j][i], temp1[3*j+1][i], temp1[3*j+2][i]);
        end
    end
    j = 2;
    // for 4, 5
    for(i = 18; i < 64; i = i + 1) begin
        if( i < 22 )begin
            temp2[2*j][i] = temp1[3*j][i];
        end
        else if(i >= 22 && i < 24) begin
            {temp2[2*j][i+1], temp2[2*j][i]} = HA_compress(temp1[3*j][i], temp1[3*j+1][i]);
        end
        else if (i == 63) begin
            temp2[(2*j+1)][i] = FA_compress(temp1[3*j][i], temp1[3*j+1][i], temp1[3*j+2][i])[0];
        end
        else begin
            {temp2[(2*j+1)][i+1], temp2[(2*j+1)][i]} = FA_compress(temp1[3*j][i], temp1[3*j+1][i], temp1[3*j+2][i]);
        end
    end

    // for 6, 7
    temp2[6] = temp1[9];
    temp2[7] = temp1[10];

    // stage 3
    for (i = 0; i < 6; i = i + 1)begin
        //initialize
        temp3[i] = 64'd0;
    end
    // for 0, 1
    j = 0;
    for(i = 0; i < 64; i = i + 1) begin
        if( i < 6 )begin
            temp3[2*j][i] = temp2[3*j][i];
        end
        else if(i >= 6 && i < 10) begin
            {temp3[2*j][i+1], temp3[2*j][i]} = HA_compress(temp2[3*j][i], temp2[3*j+1][i]);
        end
        else if (i == 63) begin
            temp3[(2*j+1)][i] = FA_compress(temp2[3*j][i], temp2[3*j+1][i], temp2[3*j+2][i])[0];
        end
        else begin
            {temp3[(2*j+1)][i+1], temp3[(2*j+1)][i]} = FA_compress(temp2[3*j][i], temp2[3*j+1][i], temp2[3*j+2][i]);
        end
    end
    // for 2, 3
    j = 1;
    for(i = 16; i < 64; i = i + 1) begin
        if( i < 18 )begin
            temp3[2*j][i] = temp2[3*j][i];
        end
        else if(i >= 18 && i < 24) begin
            {temp3[2*j][i+1], temp3[2*j][i]} = HA_compress(temp2[3*j][i], temp2[3*j+1][i]);
        end
        else if (i == 63) begin
            temp3[(2*j+1)][i] = FA_compress(temp2[3*j][i], temp2[3*j+1][i], temp2[3*j+2][i])[0];
        end
        else begin
            {temp3[(2*j+1)][i+1], temp3[(2*j+1)][i]} = FA_compress(temp2[3*j][i], temp2[3*j+1][i], temp2[3*j+2][i]);
        end
    end
    // for 4, 5
    temp3[4] = temp2[6];
    temp4[5] = temp2[7];

    // stage 4
    for (i = 0; i < 4; i = i + 1)begin
        //initialize
        temp4[i] = 64'd0;
    end
    // for 0, 1
    j = 0;
    for(i = 0; i < 64; i = i + 1) begin
        if( i < 10 )begin
            temp4[2*j][i] = temp3[3*j][i];
        end
        else if(i >= 10 && i < 16) begin
            {temp4[2*j][i+1], temp4[2*j][i]} = HA_compress(temp3[3*j][i], temp3[3*j+1][i]);
        end
        else if (i == 63) begin
            temp4[(2*j+1)][i] = FA_compress(temp3[3*j][i], temp3[3*j+1][i], temp3[3*j+2][i])[0];
        end
        else begin
            {temp4[(2*j+1)][i+1], temp4[(2*j+1)][i]} = FA_compress(temp3[3*j][i], temp3[3*j+1][i], temp3[3*j+2][i]);
        end
    end
    // for 2, 3
    j = 1;
    for(i = 24; i < 64; i = i + 1) begin
        if( i < 28 )begin
            temp4[2*j][i] = temp3[3*j][i];
        end
        else if(i >= 28 && i < 30) begin
            {temp4[2*j][i+1], temp4[2*j][i]} = HA_compress(temp3[3*j][i], temp3[3*j+1][i]);
        end
        else if (i == 63) begin
            temp4[(2*j+1)][i] = FA_compress(temp3[3*j][i], temp3[3*j+1][i], temp3[3*j+2][i])[0];
        end
        else begin
            {temp4[(2*j+1)][i+1], temp4[(2*j+1)][i]} = FA_compress(temp3[3*j][i], temp3[3*j+1][i], temp3[3*j+2][i]);
        end
    end

    // stage 5
    for (i = 0; i < 3; i = i + 1)begin
        //initialize
        temp5[i] = 64'd0;
    end
    // for 0, 1
    j = 0;
    for(i = 0; i < 64; i = i + 1) begin
        if( i < 16 )begin
            temp5[2*j][i] = temp4[3*j][i];
        end
        else if(i >= 16 && i < 24) begin
            {temp5[2*j][i+1], temp5[2*j][i]} = HA_compress(temp4[3*j][i], temp4[3*j+1][i]);
        end
        else if (i == 63) begin
            temp5[(2*j+1)][i] = FA_compress(temp4[3*j][i], temp4[3*j+1][i], temp4[3*j+2][i])[0];
        end
        else begin
            {temp5[(2*j+1)][i+1], temp5[(2*j+1)][i]} = FA_compress(temp4[3*j][i], temp4[3*j+1][i], temp4[3*j+2][i]);
        end
    end
    // for 2
    temp5[2] = temp4[3];

    // stage 6
    for (i = 0; i < 2; i = i + 1)begin
        //initialize
        temp6[i] = 64'd0;
    end
    j = 0;
    for(i = 0; i < 64; i = i + 1) begin
        if( i < 24 )begin
            temp6[2*j][i] = temp5[3*j][i];
        end
        else if(i >= 24 && i < 30) begin
            {temp6[2*j][i+1], temp6[2*j][i]} = HA_compress(temp5[3*j][i], temp5[3*j+1][i]);
        end
        else if (i == 63) begin
            temp6[(2*j+1)][i] = FA_compress(temp5[3*j][i], temp5[3*j+1][i], temp5[3*j+2][i])[0];
        end
        else begin
            {temp6[(2*j+1)][i+1], temp6[(2*j+1)][i]} = FA_compress(temp5[3*j][i], temp5[3*j+1][i], temp5[3*j+2][i]);
        end
    end
end

endmodule