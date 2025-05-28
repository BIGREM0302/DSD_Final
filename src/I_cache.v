module I_cache(
    input           clk,
    input           proc_reset,
    // processor interface
    input           proc_read,
    input           proc_write,
    input   [29:0]  proc_addr,
    output reg [31:0] proc_rdata,
    input   [31:0]  proc_wdata,
    output reg      proc_stall,
    // memory interface
    output reg      mem_read,
    output reg      mem_write,
    output reg [27:0] mem_addr,
    output reg [127:0] mem_wdata,
    input   [127:0] mem_rdata,
    input           mem_ready
);

  localparam S_IDLE      = 2'b00;
  localparam S_WRITEBACK = 2'b01;
  localparam S_READMISS  = 2'b10;

  reg [1:0]  state_r, state_w;
  reg        victim_r, victim_w;

  reg [31:0] latched_data_r, latched_data_w;
  reg        use_latched_r,  use_latched_w;

  reg [127:0] cache_r0 [0:3], cache_w0 [0:3];
  reg [127:0] cache_r1 [0:3], cache_w1 [0:3];
  reg         valid_r0 [0:3],  valid_w0 [0:3];
  reg         valid_r1 [0:3],  valid_w1 [0:3];
  reg         dirty_r0 [0:3],  dirty_w0 [0:3];
  reg         dirty_r1 [0:3],  dirty_w1 [0:3];
  reg  [25:0] tag_r0   [0:3],  tag_w0   [0:3];
  reg  [25:0] tag_r1   [0:3],  tag_w1   [0:3];
  reg         lru_r    [0:3],  lru_w    [0:3];

  wire [1:0]  set_idx    = proc_addr[3:2];
  wire [25:0] addr_tag   = proc_addr[29:4];
  wire [27:0] block_addr = proc_addr[29:2];
  wire [1:0]  offset     = proc_addr[1:0];

  wire hit0 = valid_r0[set_idx] && (tag_r0[set_idx] == addr_tag);
  wire hit1 = valid_r1[set_idx] && (tag_r1[set_idx] == addr_tag);

  integer i, j;

  //==========================================================================
  // combinational logic
  //==========================================================================
  always @(*) begin
    state_w         = state_r;
    victim_w        = victim_r;
    latched_data_w  = latched_data_r;
    use_latched_w   = 1'b0;

    proc_stall      = 1'b0;
    proc_rdata      = 32'b0;
    mem_read        = 1'b0;
    mem_write       = 1'b0;
    mem_addr        = block_addr;
    mem_wdata       = 128'b0;

    for (j = 0; j < 4; j = j + 1) begin
      cache_w0[j] = cache_r0[j];
      cache_w1[j] = cache_r1[j];
      valid_w0[j] = valid_r0[j];
      valid_w1[j] = valid_r1[j];
      dirty_w0[j] = dirty_r0[j];
      dirty_w1[j] = dirty_r1[j];
      tag_w0[j]   = tag_r0[j];
      tag_w1[j]   = tag_r1[j];
      lru_w[j]    = lru_r[j];
    end

    case (state_r)
      S_IDLE: begin
        if (proc_read && hit0) begin
          proc_rdata        = cache_r0[set_idx][offset*32 +:32];
          lru_w[set_idx]    = 1'b1;  
        end
        else if (proc_read && hit1) begin
          proc_rdata        = cache_r1[set_idx][offset*32 +:32];
          lru_w[set_idx]    = 1'b0;  
        end

        else if (proc_write && hit0) begin
          cache_w0[set_idx][offset*32 +:32] = proc_wdata;
          dirty_w0[set_idx]    = 1'b1;
          lru_w[set_idx]       = 1'b1;
        end
        else if (proc_write && hit1) begin
          cache_w1[set_idx][offset*32 +:32] = proc_wdata;
          dirty_w1[set_idx]    = 1'b1;
          lru_w[set_idx]       = 1'b0;
        end

        else if (proc_read || proc_write) begin
          proc_stall = 1'b1;
          if (!valid_r0[set_idx])        victim_w = 1'b0;
          else if (!valid_r1[set_idx])   victim_w = 1'b1;
          else                            victim_w = lru_r[set_idx];
          if ((victim_w==0 && dirty_r0[set_idx]) ||
              (victim_w==1 && dirty_r1[set_idx])) begin
            state_w   = S_WRITEBACK;
            mem_write = 1'b1;
            if (victim_w==0) begin
              mem_wdata = cache_r0[set_idx];
              mem_addr  = { tag_r0[set_idx], set_idx };
            end else begin
              mem_wdata = cache_r1[set_idx];
              mem_addr  = { tag_r1[set_idx], set_idx };
            end
          end
          else begin
            state_w   = S_READMISS;
            mem_read  = 1'b1;
            mem_addr  = block_addr;
          end
        end
      end

      S_WRITEBACK: begin
        proc_stall = 1'b1;
        mem_write  = 1'b1;
        if (victim_r==0) begin
          mem_wdata = cache_r0[set_idx];
          mem_addr  = { tag_r0[set_idx], set_idx };
        end else begin
          mem_wdata = cache_r1[set_idx];
          mem_addr  = { tag_r1[set_idx], set_idx };
        end
        if (mem_ready) begin
          state_w  = S_READMISS;
          mem_read = 1'b1;
          mem_addr = block_addr;
        end
      end

      S_READMISS: begin
        proc_stall = 1'b1;
        mem_read   = 1'b1;
        mem_addr   = block_addr;
        if (mem_ready) begin
          if (victim_r==0) begin
            cache_w0[set_idx] = mem_rdata;
            valid_w0[set_idx] = 1'b1;
            dirty_w0[set_idx] = 1'b0;
            tag_w0[set_idx]   = addr_tag;
            if (proc_write) begin
              cache_w0[set_idx][offset*32 +:32] = proc_wdata;
              dirty_w0[set_idx] = 1'b1;
            end
            lru_w[set_idx]    = 1'b1;
          end else begin
            cache_w1[set_idx] = mem_rdata;
            valid_w1[set_idx] = 1'b1;
            dirty_w1[set_idx] = 1'b0;
            tag_w1[set_idx]   = addr_tag;
            if (proc_write) begin
              cache_w1[set_idx][offset*32 +:32] = proc_wdata;
              dirty_w1[set_idx] = 1'b1;
            end
            lru_w[set_idx]    = 1'b0;
          end
          latched_data_w = mem_rdata[offset*32 +:32];
          use_latched_w  = 1'b1;
          state_w        = S_IDLE;
        end
      end

      default: state_w = S_IDLE;
    endcase

    if (state_r==S_IDLE && use_latched_r) begin
      proc_rdata = latched_data_r;
    end
  end

  //==========================================================================
  // sequential logic
  //==========================================================================
  always @(posedge clk or posedge proc_reset) begin
    if (proc_reset) begin
      state_r        <= S_IDLE;
      victim_r       <= 1'b0;
      latched_data_r <= 32'b0;
      use_latched_r  <= 1'b0;
      for (i = 0; i < 4; i = i + 1) begin
        valid_r0[i]  <= 1'b0; valid_r1[i]  <= 1'b0;
        dirty_r0[i]  <= 1'b0; dirty_r1[i]  <= 1'b0;
        tag_r0[i]    <= 26'b0; tag_r1[i]    <= 26'b0;
        cache_r0[i]  <= 128'b0; cache_r1[i]  <= 128'b0;
        lru_r[i]     <= 1'b0;
      end
    end else begin
      state_r        <= state_w;
      victim_r       <= victim_w;
      latched_data_r <= latched_data_w;
      use_latched_r  <= use_latched_w;
      for (i = 0; i < 4; i = i + 1) begin
        cache_r0[i] <= cache_w0[i];
        cache_r1[i] <= cache_w1[i];
        valid_r0[i] <= valid_w0[i];
        valid_r1[i] <= valid_w1[i];
        dirty_r0[i] <= dirty_w0[i];
        dirty_r1[i] <= dirty_w1[i];
        tag_r0[i]   <= tag_w0[i];
        tag_r1[i]   <= tag_w1[i];
        lru_r[i]    <= lru_w[i];
      end
    end
  end

endmodule