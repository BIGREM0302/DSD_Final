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
    output reg        proc_stall;
    output reg [31:0] proc_rdata;
    // memory interface
    input  [127:0] mem_rdata;
    input          mem_ready;
    output         mem_read, mem_write;
    output [27:0]  mem_addr;
    output [127:0] mem_wdata;
    
//==== wire/reg definition ================================

    reg [127:0]block_w[0:15],block_r[0:15];
    reg [24:0]tag_r[0:15],tag_w[0:15];
    reg valid_r[0:15],valid_w[0:15];
    reg new_w[0:15],new_r[0:15];
    reg mem_read_w,mem_read_r;

    reg [27:0] mem_addr_r;
    reg state_w,state_r;
    reg [127:0] mem_rdata_r;
    reg mem_ready_r;
    reg proc_reset_r;
    integer i;

    assign mem_write = 0;
    assign mem_wdata = 0;
    assign mem_read = mem_read_r;
    assign mem_addr = mem_addr_r;

//==== combinational circuit ==============================
wire hit_1;
assign hit_1 = (valid_r[{proc_addr[4:2],1'b0}]) && (tag_r[{proc_addr[4:2],1'b0}] == proc_addr[29:5]);

wire hit_2;
assign hit_2 = (valid_r[{proc_addr[4:2],1'b1}]) && (tag_r[{proc_addr[4:2],1'b1}] == proc_addr[29:5]);

wire [1:0]LRU_pair;
assign LRU_pair = {new_r[{proc_addr[4:2],1'b1}], new_r[{proc_addr[4:2],1'b0}]};

always@(*) begin
    proc_rdata = 0;
    proc_stall = 0;
    mem_read_w = mem_read_r;
    state_w = state_r;
    
    for(i=0;i<16;i=i+1) begin
        block_w[i] = block_r[i];
        tag_w[i] = tag_r[i];
        valid_w[i] = valid_r[i];
        new_w[i] = new_r[i];
    end
    case(state_r) //synopsys parallel_case full_case
        1'b0: begin // idle state
            proc_stall = 0;
            if(proc_read) begin
                case ({hit_1, hit_2}) //synopsys parallel_case full_case
                    2'b10 : begin
                        proc_rdata = block_r[{proc_addr[4:2],1'b0}][({proc_addr[1:0],5'b0})+:32];
                        new_w[{proc_addr[4:2],1'b0}] = 1;
                        new_w[{proc_addr[4:2],1'b1}] = 0;
                        if(LRU_pair == 2'b11)begin
                            new_w[{proc_addr[4:2],1'b1}] = 1;
                            new_w[{proc_addr[4:2],1'b0}] = 1;
                        end
                    end
                    2'b01 : begin
                        proc_rdata = block_r[{proc_addr[4:2],1'b1}][({proc_addr[1:0],5'b0})+:32];
                        new_w[{proc_addr[4:2],1'b1}] = 1;
                        new_w[{proc_addr[4:2],1'b0}] = 0;
                    end
                    default : begin
                        mem_read_w = 1;
                        state_w = 1; // go to read state
                        proc_stall = 1;
                    end
                endcase
                    
                end
            end
        
        1'b1: begin // read state
            proc_stall = 1;
            if(mem_ready_r) begin
                state_w = 0; // go back to idle state
                case(LRU_pair) //synopsys parallel_case full_case
                 2'b00: begin // both blocks are not valid
                    block_w[{proc_addr[4:2],1'b0}] = mem_rdata_r;
                    tag_w[{proc_addr[4:2],1'b0}] = proc_addr[29:5];
                    valid_w[{proc_addr[4:2],1'b0}] = 1;
                    new_w[{proc_addr[4:2],1'b0}] = 1;
                    new_w[{proc_addr[4:2],1'b1}] = 1;
                    proc_rdata = mem_rdata_r[({proc_addr[1:0],5'b0})+:32];
                    proc_stall = 0;
                    mem_read_w = 0;
                 end
                 2'b11:begin
                    block_w[{proc_addr[4:2],1'b1}] = mem_rdata_r;
                    tag_w[{proc_addr[4:2],1'b1}] = proc_addr[29:5];
                    valid_w[{proc_addr[4:2],1'b1}] = 1;
                    new_w[{proc_addr[4:2],1'b0}] = 0;
                    new_w[{proc_addr[4:2],1'b1}] = 1;
                    proc_rdata = mem_rdata_r[({proc_addr[1:0],5'b0})+:32];
                    proc_stall = 0;
                    mem_read_w = 0;
                 end
                 2'b01:begin // block 0 is LRU
                    block_w[{proc_addr[4:2],1'b1}] = mem_rdata_r;
                    tag_w[{proc_addr[4:2],1'b1}] = proc_addr[29:5];
                    valid_w[{proc_addr[4:2],1'b1}] = 1;
                    new_w[{proc_addr[4:2],1'b1}] = 1;
                    new_w[{proc_addr[4:2],1'b0}] = 0;
                    proc_rdata = mem_rdata_r[({proc_addr[1:0],5'b0})+:32];
                    proc_stall = 0;
                    mem_read_w = 0;
                 end
                 2'b10:begin // block 1 is LRU
                    block_w[{proc_addr[4:2],1'b0}] = mem_rdata_r;
                    tag_w[{proc_addr[4:2],1'b0}] = proc_addr[29:5];
                    valid_w[{proc_addr[4:2],1'b0}] = 1;
                    new_w[{proc_addr[4:2],1'b0}] = 1;
                    new_w[{proc_addr[4:2],1'b1}] = 0;
                    proc_rdata = mem_rdata_r[({proc_addr[1:0],5'b0})+:32];
                    proc_stall = 0;
                    mem_read_w = 0;
                 end
                endcase
            end
        end
    endcase
    
end
    

//==== sequential circuit =================================
always@( posedge clk ) begin
    proc_reset_r <= proc_reset;
    if(proc_reset_r) begin
        for(i=0;i<16;i=i+1) begin
            block_r[i] <= 0;
            tag_r[i] <= 0;
            valid_r[i] <= 0;
            new_r[i] <= 0;
        end
        state_r <= 0;
        mem_read_r <= 0;
        mem_rdata_r <= 0;
        mem_ready_r <= 0;
        mem_addr_r <= 0;
        
    end 
    else if(mem_ready)begin
        mem_read_r <= 0;
        for(i=0;i<16;i=i+1) begin
            block_r[i] <= block_w[i];
            tag_r[i] <= tag_w[i];
            valid_r[i] <= valid_w[i];
            new_r[i] <= new_w[i];
        end
        mem_rdata_r <= mem_rdata;
        mem_ready_r <= mem_ready;
        state_r <= state_w;
        mem_addr_r <= proc_addr[29:2]; // 28 bits for memory address
    
    end
    else begin
        for(i=0;i<16;i=i+1) begin
            block_r[i] <= block_w[i];
            tag_r[i] <= tag_w[i];
            valid_r[i] <= valid_w[i];
            new_r[i] <= new_w[i];
        end
        state_r <= state_w;
        mem_read_r <= mem_read_w;
        mem_rdata_r <= mem_rdata;
        mem_ready_r <= mem_ready;
        mem_addr_r <= proc_addr[29:2];
    end
end

endmodule
