`timescale 1 ns/10 ps

module	TestBed(
	clk,
	rst,
	addr,
	data,
	wen,
	duration,
	PC,
	error_num,
	finish
);
	input			clk, rst;
	input	[29:0]	addr;
	input	[31:0]	data;
	input			wen;
	input	[31:0]  PC;
	
	output	[8:0]	error_num;
	output	[15:0]	duration;
	output			finish;


	reg		[1:0]	state_w, state_r;
	parameter		S_IDLE = 0, S_CHECK = 1, S_REPORT= 2, S_END=3;

	reg		[9:0]	counter_r, counter_w;
	reg		[8:0]	error_num_r, error_num_w;
	reg				finish_r, finish_w;

	reg		[31:0]	golden_ans [0:255];
	reg		[31:0]  pseudo_mem [0:255];
	wire signed	[31:0]	golden_dec, pseudo_dec;


	initial	begin
		$readmemh (`DMEM_INIT, pseudo_mem ); // initialize data in DMEM
		$readmemh (`GOLDEN,    golden_ans );
	end

	// output logic
	assign finish = finish_r;
	assign error_num = error_num_r;


	// state machine
	always@(posedge clk) begin
		if( (state_r==S_IDLE) && (wen) ) begin
			pseudo_mem[addr] = data;
		end
	end

	always@(*) begin
		state_w = state_r;
		case( state_r )
			S_IDLE: begin
				if(PC>=`END_PC)
					state_w = S_CHECK;
			end
			S_CHECK: begin
				if(counter_r==255)
				state_w = S_REPORT;
			end
			S_REPORT: begin	
				state_w = S_END;
			end				
		endcase	
	end


	assign pseudo_dec = {pseudo_mem[counter_r][7:0],pseudo_mem[counter_r][15:8],pseudo_mem[counter_r][23:16],pseudo_mem[counter_r][31:24]};
	assign golden_dec = {golden_ans[counter_r][7:0],golden_ans[counter_r][15:8],golden_ans[counter_r][23:16],golden_ans[counter_r][31:24]};

	always@(*) begin
		counter_w = counter_r;
		error_num_w = error_num_r;
		finish_w = finish_r;
		case( state_r )
			S_CHECK: begin
				counter_w = counter_r+1;
				if(pseudo_mem[counter_r] !== golden_ans[counter_r])
					error_num_w = error_num_r + 1;
			end
			S_REPORT: begin
				finish_w = 1;
			end				
		endcase	
	end

	always@(error_num_r) begin
		if(state_r == S_CHECK)
			$display(" error in mem %d (0x%h)  expect:%d (%h),          get:%d (%h)", counter_r[7:0], counter_r<<2, golden_dec, golden_ans[counter_r], pseudo_dec, pseudo_mem[counter_r]);
	end

	always@( negedge clk ) begin
		if(state_r == S_REPORT) begin
			$display("--------------------------- Simulation FINISH !!---------------------------");
			if (|error_num_r) begin 
				$display("============================================================================");
				$display("\n (T_T) FAIL!! The simulation result is FAIL!!! there were %d errors at all.\n", error_num);
				$display("============================================================================");
			end
			 else begin 
				$display("============================================================================");
				$display("\n \\(^o^)/ CONGRATULATIONS!!  The simulation result is PASS!!!\n");
				$display("============================================================================");
			end
		end
	end



	always@( posedge clk or negedge rst ) begin
		if( ~rst ) begin
			state_r 	<= S_IDLE;
			counter_r	<= 0;
			error_num_r	<= 0;
			finish_r	<= 0;
		end
		else begin
			state_r 	<= state_w;
			counter_r	<= counter_w;
			error_num_r	<= error_num_w;
			finish_r	<= finish_w;
		end
	end

endmodule