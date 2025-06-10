module cache(
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
    mem_ready,
    stall_count,
    exec_count
);

//==== input/output definition ============================
    input        clk;
    // processor interface
    input         proc_reset;
    input         proc_read, proc_write;
    input  [29:0] proc_addr;
    input  [31:0] proc_wdata;
    output        proc_stall;
    output [31:0] proc_rdata;
    // memory interface
    input [127:0] mem_rdata;
    input         mem_ready;
    output reg         mem_read, mem_write;
    output reg [ 27:0] mem_addr;
    output reg [127:0] mem_wdata;
    output reg [ 31:0] stall_count;
    output reg [ 31:0] exec_count;

//==== Protect Don't Modified!!! ===============
    reg RST;
    
    always@(posedge clk) begin
        RST <= proc_reset;
    end

    reg [127:0] mem_rdata_proc_w, mem_rdata_proc_r;
    reg mem_ready_w, mem_ready_r;
    
    always@(*) begin
        mem_rdata_proc_w = mem_rdata;
        mem_ready_w = mem_ready;
    end

    always@(posedge clk)begin
        mem_ready_r <= mem_ready_w;
        mem_rdata_proc_r <= mem_rdata_proc_w;
    end
//=============================================


//==== wire/reg definition ================================
localparam S_LOOKUP = 2'd0;
localparam S_WB     = 2'd1;
localparam S_REFILL = 2'd2;

reg [1:0] state_r, state_w;

// Single cache array: { valid(1), dirty(1), tag(26), data(128) }
// [155] = valid, [154] = dirty, [153:128] = tag, [127:0] = data
reg [155:0] cache_r0 [0:3], cache_r1 [0:3];
reg [155:0] cache_w0 [0:3], cache_w1 [0:3];
reg [ 31:0] lru_r, lru_w;

wire [25:0] req_tag;
wire [ 1:0] req_set;
wire [ 1:0] req_offset;

assign req_tag    = proc_addr[29:4];
assign req_set    = proc_addr[3:2];
assign req_offset = proc_addr[1:0];

wire valid0, dirty0, hit0, valid1, dirty1, hit1, hit;
wire [ 25:0] tag0, tag1;
wire [127:0] data0, data1;
wire [ 31:0] rdata0, rdata1;

assign valid0 = cache_r0[req_set][155];
assign dirty0 = cache_r0[req_set][154];
assign tag0   = cache_r0[req_set][153:128];
assign data0  = cache_r0[req_set][127:0];

assign valid1 = cache_r1[req_set][155];
assign dirty1 = cache_r1[req_set][154];
assign tag1   = cache_r1[req_set][153:128];
assign data1  = cache_r1[req_set][127:0];

assign hit0       = valid0 && (tag0 == req_tag);
assign hit1       = valid1 && (tag1 == req_tag);
assign hit        = hit0 || hit1;
assign proc_stall = ~hit;

assign rdata0 = (req_offset == 2'd0) ? data0[31:0] :
                (req_offset == 2'd1) ? data0[63:32] :
                (req_offset == 2'd2) ? data0[95:64] : data0[127:96];
assign rdata1 = (req_offset == 2'd0) ? data1[31:0] :
                (req_offset == 2'd1) ? data1[63:32] :
                (req_offset == 2'd2) ? data1[95:64] : data1[127:96];
assign proc_rdata = hit0 ? rdata0 : rdata1;

wire         victim_way;
wire         victim_dirty;
wire [ 25:0] victim_tag;
wire [127:0] victim_data;

assign victim_way   = lru_r[req_set];
assign victim_dirty = victim_way ? dirty1 : dirty0;
assign victim_tag   = victim_way ? tag1   : tag0;
assign victim_data  = victim_way ? data1  : data0;

integer i;

//==== combinational circuit ==============================
always @(*) begin
    state_w = state_r;
    case (state_r)
        S_LOOKUP: begin
            if (~(proc_read || proc_write)) state_w = S_LOOKUP;
            else if (hit) state_w = S_LOOKUP;
            else if (victim_dirty) state_w = S_WB;
            else state_w = S_REFILL;
        end
        S_WB: begin
            if (mem_ready_r) state_w = S_REFILL;
        end
        S_REFILL: begin
            if (mem_ready_r) state_w = S_LOOKUP;
        end
    endcase
end

always @(*) begin
    for (i = 0; i < 4; i = i + 1) begin
        cache_w0[i] = cache_r0[i];
        cache_w1[i] = cache_r1[i];
        lru_w[i]    = lru_r[i];
    end

    mem_read  = 1'b0;
    mem_write = 1'b0;
    mem_addr  = proc_addr[29:2];
    mem_wdata = victim_data;

    case (state_r)
        S_WB: begin
            if (~mem_ready_r) mem_write = 1;
            mem_addr = {victim_tag, req_set};
        end
        S_REFILL: begin
            if (~mem_ready_r) mem_read = 1;
            else begin
                if (victim_way == 0) cache_w0[req_set] = {1'b1, 1'b0, req_tag, mem_rdata_proc_r};
                else cache_w1[req_set] = {1'b1, 1'b0, req_tag, mem_rdata_proc_r};
                lru_w[req_set] = ~victim_way;
            end
        end
    endcase

    if (hit0) begin
        lru_w[req_set] = 1;
    end else if (hit1) begin
        lru_w[req_set] = 0;
    end

    if (proc_write) begin
        if (hit0) begin
            case (req_offset)
                2'd0: cache_w0[req_set] = {1'b1, 1'b1, req_tag, cache_r0[req_set][127:32], proc_wdata};
                2'd1: cache_w0[req_set] = {1'b1, 1'b1, req_tag, cache_r0[req_set][127:64], proc_wdata, cache_r0[req_set][31:0]};
                2'd2: cache_w0[req_set] = {1'b1, 1'b1, req_tag, cache_r0[req_set][127:96], proc_wdata, cache_r0[req_set][63:0]};
                2'd3: cache_w0[req_set] = {1'b1, 1'b1, req_tag, proc_wdata, cache_r0[req_set][95:0]};
            endcase
        end else if (hit1) begin
            case (req_offset)
                2'd0: cache_w1[req_set] = {1'b1, 1'b1, req_tag, cache_r1[req_set][127:32], proc_wdata};
                2'd1: cache_w1[req_set] = {1'b1, 1'b1, req_tag, cache_r1[req_set][127:64], proc_wdata, cache_r1[req_set][31:0]};
                2'd2: cache_w1[req_set] = {1'b1, 1'b1, req_tag, cache_r1[req_set][127:96], proc_wdata, cache_r1[req_set][63:0]};
                2'd3: cache_w1[req_set] = {1'b1, 1'b1, req_tag, proc_wdata, cache_r1[req_set][95:0]};
            endcase
        end
    end
end

//==== sequential circuit =================================
always @(posedge clk) begin
    if (RST) begin
        state_r <= S_LOOKUP;
        stall_count  <= 32'd0;
        exec_count   <= 32'd0;
        for (i = 0; i < 4; i = i + 1) begin
            cache_r0[i] <= 0;
            cache_r1[i] <= 0;
            lru_r[i]    <= 0;
        end
    end else begin
        state_r <= state_w;
        if (proc_stall)
            stall_count <= stall_count + 1;
        else
            exec_count <= exec_count + 1;
        for (i = 0; i < 4; i = i + 1) begin
            cache_r0[i] <= cache_w0[i];
            cache_r1[i] <= cache_w1[i];
            lru_r[i]   <= lru_w[i];
        end
    end
end

endmodule