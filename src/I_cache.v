module I_cache(
    clk,
    proc_reset,
    proc_read,
    proc_write,
    proc_addr,
    proc_rdata,
    proc_wdata,
    proc_stall,
    mem_read,
    mem_write,
    mem_addr,
    mem_rdata,
    mem_wdata,
    mem_ready
);
    
//==== input/output definition ============================
    input          clk;
    // processor interface
    input          proc_reset;
    input          proc_read, proc_write;
    input   [29:0] proc_addr;
    input   [31:0] proc_wdata;
    output    proc_stall;
    output reg [31:0] proc_rdata;
    // memory interface
    input  [127:0] mem_rdata;
    input          mem_ready;
    output reg    mem_read, mem_write;
    output reg [27:0] mem_addr;
    output reg [127:0] mem_wdata;

    localparam COMP = 0, ALLC = 1, WB = 2;
    integer i;

    // protect
    reg RST;
    
    always@(posedge clk) begin
        RSR <= proc_reset;
    end

    reg [127:0] mem_rdata_proc_w, mem_rdata_proc_r;
    reg cnt_w,cnt_r;
    
    always@(*) begin
        mem_rdata_proc_w = mem_rdata;
        cnt_w = mem_ready;
    end

    always@(posedge clk)begin
        cnt_r <= cnt_w;
        mem_rdata_proc_r <= mem_rdata_proc_w;
    end


//==== wire/reg definition ================================
    //reg [154:0] cache0, cache1, cache2, cache3, cache4, cache5, cache6, cache7; //8 blocks each with 4 words
    reg [154:0] cache [0:7]; //8 blocks each with 4 words
    //reg [154:0] cache0_w, cache1_w, cache2_w, cache3_w, cache4_w, cache5_w, cache6_w, cache7_w;
    reg [154:0] cache_w [0:7];
    reg [1:0] state_r, state_w;
    reg hit;
    reg dirty;
    wire [1:0] index;
    wire [2:0] block_num;
    wire [24:0] tag;

//==== combinational circuit ==============================
    assign index = proc_addr[1:0];
    assign block_num = proc_addr[4:2];
    assign tag = proc_addr[29:5];
    assign proc_stall = (~hit);
//FSM
always@(*) begin
    case(state_r) // synopsys parallel_case full_case
    COMP: begin
        if(~proc_write & ~proc_read) state_w = COMP;
        else if(hit) state_w = COMP;
        else if(dirty) state_w = WB;
        else state_w = ALLC;
    end
    ALLC: begin
        if(cnt_r) state_w = COMP;
        else state_w = ALLC;
    end
    WB: begin
        if(cnt_r) state_w = ALLC;
        else state_w = WB;
    end
    endcase
end

//functions
function [31:0] cur_data;
    input [154:0] cur_block;
    input [1:0] cur_index;
    begin
        cur_data = (cur_index == 2'd0)? cur_block[31:0]:
                   (cur_index == 2'd1)? cur_block[63:32]:
                   (cur_index == 2'd2)? cur_block[95:64]:
                    cur_block[127:96];
    end
endfunction

function hit_check;
    input [154:0] cur_block;
    input [24:0] cur_tag;
    begin
        hit_check = (cur_block[154] & (cur_tag == cur_block[152:128]));
    end
endfunction

//control output logic
always@(*) begin
    mem_read = 0;
    mem_write = 0;
    //proc_stall = (~hit)? 1'b1:1'b0;
    case(state_r)
    ALLC:begin
        if(~cnt_r) mem_read = 1;
    end
    WB:begin
        //miss and dirty, need update memory's value
        if(~cnt_r) mem_write = 1;
    end
    endcase
end

//data output logic
always@(*) begin
    for(i = 0; i < 8; i = i + 1)
        cache_w[i] = cache[i];
    mem_addr = proc_addr[29:2];
    proc_rdata = cur_data(cache[block_num], index);
    mem_wdata = cache[block_num][127:0];
    hit = hit_check(cache[block_num], tag);
    dirty = cache[block_num][153];
    if(state_r == WB) mem_addr = {cache[block_num][152:128], block_num};
    if(state_r == ALLC && cnt_r) cache_w[block_num] = {1'b1, 1'b0, tag, mem_rdata_proc_r};
    if(proc_write && hit)begin
        case(index)
        2'd0:begin
                //if(state_r == ALLC && mem_ready)
                //cache_w[block_num] = {1'b1, 1'b1, tag, mem_rdata[127:32], proc_wdata};
                //else if(hit) 
                cache_w[block_num] = {1'b1, 1'b1, tag, cache[block_num][127:32], proc_wdata};
        end
        2'd1:begin
                //if(state_r == ALLC && mem_ready)
                //cache_w[block_num] = {1'b1, 1'b1, tag, mem_rdata[127:64], proc_wdata, mem_rdata[31:0]};
                //else if(hit) 
                cache_w[block_num] = {1'b1, 1'b1, tag, cache[block_num][127:64], proc_wdata, cache[block_num][31:0]};
        end
        2'd2:begin
                //if(state_r == ALLC && mem_ready)
                //cache_w[block_num] = {1'b1, 1'b1, tag, mem_rdata[127:96], proc_wdata, mem_rdata[63:0]};
                //else if(hit) 
                cache_w[block_num] = {1'b1, 1'b1, tag, cache[block_num][127:96], proc_wdata, cache[block_num][63:0]};
        end
        2'd3:begin
                //if(state_r == ALLC && mem_ready)
                //cache_w[block_num] = {1'b1, 1'b1, tag, proc_wdata, mem_rdata[95:0]};
                //else if(hit) 
                cache_w[block_num] = {1'b1, 1'b1, tag, proc_wdata, cache[block_num][95:0]};
        end
        endcase
    end
end

//==== sequential circuit =================================
always@( posedge clk ) begin
    if( RST ) begin
        state_r <= COMP;
        for(i = 0; i < 8; i = i + 1)begin
            cache[i] <= 0;
        end
    end
    else begin
        state_r <= state_w;
        for(i = 0; i < 8; i = i + 1)begin
            cache[i] <= cache_w[i];
        end
    end
end

endmodule
