module D_cache(
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
localparam S_IDLE = 2'b00;
localparam S_READ = 2'b01;
localparam S_WRITE = 2'b10;


//==== input/output definition ============================
    input          clk;
    // processor interface
    input          proc_reset;
    input          proc_read, proc_write;
    input   [29:0] proc_addr;
    input   [31:0] proc_wdata;
    output  reg       proc_stall;
    output  reg [31:0] proc_rdata;
    // memory interface
    input  [127:0] mem_rdata;
    input          mem_ready;
    output        mem_read, mem_write;
    output  [27:0] mem_addr;
    output [127:0] mem_wdata;
//==== wire/reg definition ================================
    wire hit1, hit2;
    wire [1:0] idx;
    wire [1:0] offset;
    reg [127:0] block_data_r [0:7], block_data_w [0:7];
    reg [25:0] tag_r [0:7], tag_w [0:7];
    reg [7:0] dirty_r, dirty_w;
    reg [7:0] valid_r, valid_w;
    reg [1:0] state_r, state_w;
    reg mem_read_r, mem_read_w;
    reg mem_write_r, mem_write_w;
    reg [31:0] proc_rdata;
    reg [27:0] mem_addr_r, mem_addr_w;
    reg [127:0] mem_wdata_r, mem_wdata_w;
    reg [3:0] recent_used_r, recent_used_w;
    reg [3:0] change_idx_r, change_idx_w;
    wire [3:0] check_idx;
    reg mem_ready_r;
    reg proc_reset_r;
    reg [127:0] mem_rdata_r;
//==== combinational circuit ==============================
assign idx = proc_addr[3:2];
assign offset = proc_addr[1:0];
assign hit1 = (valid_r[{idx, 1'b0}] && (tag_r[{idx, 1'b0}] == proc_addr[29:4]));
assign hit2 = (valid_r[{idx, 1'b1}] && (tag_r[{idx, 1'b1}] == proc_addr[29:4]));
assign check_idx = $unsigned((~recent_used_r[idx])) + idx*2;
assign mem_read = mem_read_r;
assign mem_write = mem_write_r;
assign mem_addr = mem_addr_r;
assign mem_wdata = mem_wdata_r;
integer i;
always @(*) begin
    state_w = state_r;
    for (i = 0; i < 8; i = i + 1) begin
        tag_w[i] = tag_r[i];
        dirty_w[i] = dirty_r[i];
        valid_w[i] = valid_r[i];
        block_data_w[i] = block_data_r[i];
    end
    proc_stall = 1'b0;
    mem_read_w = mem_read_r;
    mem_write_w = mem_write_r;
    mem_addr_w = mem_addr_r;
    mem_wdata_w = mem_wdata_r;
    recent_used_w = recent_used_r;
    change_idx_w = change_idx_r;
    proc_rdata = 32'b0;
    case (state_r)
        S_IDLE: begin
            proc_stall = 1'b0;
            if(proc_read | proc_write) begin
                case({hit1, hit2}) //synopsys parallel_case full_case
                    2'b10: begin // hit1
                        if (proc_read) begin
                            proc_rdata = block_data_r[{idx, 1'b0}][32*offset +: 32];
                            recent_used_w[idx] = 1'b0;
                        end
                        if (proc_write) begin
                            block_data_w[{idx, 1'b0}][32*offset +: 32] = proc_wdata;
                            dirty_w[{idx, 1'b0}] = 1'b1;
                            valid_w[{idx, 1'b0}] = 1'b1;
                            recent_used_w[idx] = 1'b0;
                        end
                    end
                    2'b01: begin // hit2
                        if (proc_read) begin
                            proc_rdata = block_data_r[{idx, 1'b1}][32*offset +: 32];
                            recent_used_w[idx] = 1'b1;
                        end
                        if (proc_write) begin
                            block_data_w[{idx, 1'b1}][32*offset +: 32] = proc_wdata;
                            dirty_w[{idx, 1'b1}] = 1'b1;
                            valid_w[{idx, 1'b1}] = 1'b1;
                            recent_used_w[idx] = 1'b1;
                        end
                    end
                    default: begin
                        if (dirty_r[check_idx])begin
                            state_w = S_WRITE;
                            proc_stall = 1'b1;
                            mem_write_w = 1'b1;
                            mem_read_w = 1'b0;
                            change_idx_w = check_idx;
                            mem_addr_w = {tag_r[check_idx], idx};
                            mem_wdata_w = block_data_r[check_idx];
                            if (check_idx[0]) begin
                                recent_used_w[idx] = 1'b1;
                            end
                            else begin
                                recent_used_w[idx] = 1'b0;
                            end
                        end
                        else begin
                            state_w = S_READ;
                            change_idx_w = check_idx;
                            proc_stall = 1'b1;
                            mem_read_w = 1'b1;
                            mem_write_w = 1'b0;
                            mem_addr_w = proc_addr[29:2];
                            if (check_idx[0]) begin
                                recent_used_w[idx] = 1'b1;
                            end
                            else begin
                                recent_used_w[idx] = 1'b0;
                            end
                        end
                    end
            endcase
        end
        end

        S_READ: begin
            proc_stall = 1'b1;
            case ({mem_ready_r, proc_read, proc_write}) //synopsys parallel_case full_case
                3'b110: begin // mem_ready, proc_read
                    state_w = S_IDLE;
                    block_data_w[change_idx_r] = mem_rdata_r;
                    proc_rdata = mem_rdata_r[32*offset +: 32];
                    valid_w[change_idx_r] = 1'b1;
                    dirty_w[change_idx_r] = 1'b0;
                    tag_w[change_idx_r] = proc_addr[29:4];
                    proc_stall = 1'b0;
                    mem_read_w = 1'b0;
                    mem_write_w = 1'b0;
                end
                3'b101: begin // mem_ready, proc_write
                    state_w = S_IDLE;
                    block_data_w[change_idx_r] = mem_rdata_r;
                    block_data_w[change_idx_r][32*offset +: 32] = proc_wdata;
                    dirty_w[change_idx_r] = 1'b1;
                    valid_w[change_idx_r] = 1'b1;
                    tag_w[change_idx_r] = proc_addr[29:4];
                    proc_stall = 1'b0;
                    mem_read_w = 1'b0;
                    mem_write_w = 1'b0;
                end
                default: begin // not ready
                    state_w = S_READ;
                end
            endcase
        end

        S_WRITE: begin
            proc_stall = 1'b1;
            if (mem_ready_r) begin
                    state_w = S_READ;
                    mem_read_w = 1'b1;
                    mem_write_w = 1'b0;
                    proc_stall = 1'b1;
                    mem_addr_w = proc_addr[29:2];
                
            end else begin
                state_w = S_WRITE;
            end
        end
    endcase
end
//==== sequential circuit =================================
always@( posedge clk ) begin
    proc_reset_r <= proc_reset;
    if( proc_reset_r ) begin
        for (i = 0; i < 8; i = i + 1) begin
            tag_r[i] <= 25'b0;
            block_data_r[i] <= 128'b0;
        end
        state_r <= S_IDLE;
        dirty_r <= 8'b0;
        valid_r <= 8'b0;
        mem_wdata_r <= 128'b0;
        recent_used_r <= 4'b0;
        change_idx_r <= 4'b0;
        
        mem_rdata_r <= 128'b0;

    end
    else begin
        for (i = 0; i < 8; i = i + 1) begin
            tag_r[i] <= tag_w[i];
            block_data_r[i] <= block_data_w[i];
        end
        dirty_r <= dirty_w;
        valid_r <= valid_w;
        state_r <= state_w;
        mem_ready_r <= mem_ready;
        mem_rdata_r <= mem_rdata;
        
        
        mem_wdata_r <= mem_wdata_w;
        recent_used_r <= recent_used_w;
        change_idx_r <= change_idx_w;
    end
end
always@(posedge clk) begin
        case(state_r)
                S_READ: begin
                    mem_read_r <= (mem_ready)? 0 : mem_read_w; // Read from memory if not ready
                    mem_write_r <= (mem_ready)? 0 : mem_write_w; // Write to memory if not ready
                    mem_addr_r <=  mem_addr_w; // 28 bits for memory address
                end
                S_WRITE: begin
                    // Data is already updated in the combinational logic
                    mem_read_r <= (mem_ready)? 1 : mem_read_w; // Read from memory if not ready
                    mem_write_r <= (mem_ready)? 0 : mem_write_w; // Write to memory if not ready
                    mem_addr_r <= (mem_ready)? proc_addr[29:2]:mem_addr_w; // 28 bits for memory address
                    
                end
                default: begin
                    mem_read_r <= mem_read_w; // Default to the previous state
                    mem_write_r <= mem_write_w; // Default to the previous state
                    mem_addr_r <= mem_addr_w; // Reset memory address
                end
                
        endcase
    
end

endmodule
