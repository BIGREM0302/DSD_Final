`timescale 1 ns/10 ps
`define TestPort    30'hFF
`define BeginSymbol 32'h00000168
`define EndSymbol   32'hFFFFFD5D
`define CheckNum    7'd33

module	TestBed(
	clk,
	rst,
	addr,
	data,
	wen,
	error_num,
	duration,
	PC,
	finish
);
	input			clk, rst;
	input	[29:0]	addr;
	input	[31:0]	data;
	input			wen;
	input	[31:0]  PC;

	output	[7:0]	error_num;
	output	[15:0]	duration;
	output			finish;
	reg		[7:0]	error_num;
	reg		[15:0]	duration;
	reg				finish;
	
	reg		[31:0]	answer;

	reg		[1:0]	curstate;
	reg		[1:0]	nxtstate;
	reg		[6:0]	curaddr;
	reg		[6:0]	nxtaddr;
	reg		[7:0]	nxt_error_num;
	reg		[15:0]	nxtduration;
	
	reg				state,state_next;

	wire    [31:0]  data_modify;
		
	parameter	state_idle 	= 2'b00;
	parameter	state_check = 2'b01;
	parameter	state_report= 2'b10;	

	assign data_modify = {data[7:0],data[15:8],data[23:16],data[31:24]}; // convert little-endian format to readable format
		
	always@( posedge clk or negedge rst )						// State-DFF
	begin
		if( ~rst )
		begin
			curstate <= state_idle;
			curaddr  <= 0;
			duration <= 0;
			error_num <= 8'd255;
			
			state <= 0;
		end
		else
		begin
			curstate <= nxtstate;
			curaddr  <= nxtaddr;
			duration <= nxtduration;
			error_num <= nxt_error_num;
			
			state <= state_next;
		end
	end
			
	always@(*)	// FSM for test
	begin
		finish = 1'b0;
		case( curstate )
		state_idle: 	begin
							nxtaddr = 0;
							nxtduration = 0;
							nxt_error_num = 255;	
							if( addr==`TestPort && data_modify==`BeginSymbol && wen )
							begin
								nxt_error_num = 0;
								nxtstate = state_check;
							end	 	
							else nxtstate = state_idle;
						end
		state_check:	begin
							nxtduration = duration + 1;
							nxtaddr = curaddr;						
							nxt_error_num = error_num;	
							if( addr==`TestPort && wen && state==0 )
							begin
								nxtaddr = curaddr + 1;
								if( data_modify != answer )
									nxt_error_num = error_num + 8'd1;
							end
							nxtstate = curstate;
							if( curaddr==`CheckNum )	
								nxtstate = state_report;
						end
		state_report:	begin
							finish = 1'b1;
							nxtaddr = curaddr;
							nxtstate = curstate;		
							nxtduration = duration;
							nxt_error_num = error_num;	
						end				
		endcase	
	end

	always@( negedge clk )						
	begin
		if(curstate == state_report) begin
			$display("--------------------------- Simulation FINISH !!---------------------------");
			if (error_num) begin 
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
	
	always@(*)begin//sub-FSM (avoid the Dcache stall condition)
		case(state)
			1'b0:begin
				if(wen)
					state_next=1;
				else
					state_next=state;				
			end
			1'b1:begin
				if(!wen)
					state_next=0;
				else
					state_next=state;	
			end
		endcase
	end
	
	
	always@(*)	// ROM for correct result
	begin
		answer = 0;
		case( curaddr )
		7'd0   : answer = 32'd0     ;
		7'd1   : answer = 32'd1     ;
		7'd2   : answer = 32'd1     ;
		7'd3   : answer = 32'd2     ;
		7'd4   : answer = 32'd3     ;
		7'd5   : answer = 32'd5     ;
		7'd6   : answer = 32'd8     ;
		7'd7   : answer = 32'd13    ;
		7'd8   : answer = 32'd21    ;
		7'd9   : answer = 32'd34    ;
		7'd10  : answer = 32'd55    ;
		7'd11  : answer = 32'd89    ;
		7'd12  : answer = 32'd144   ;
		7'd13  : answer = 32'd233   ;
		7'd14  : answer = 32'd377   ;
		7'd15  : answer = 32'd610   ;
		7'd16  : answer = 32'd610   ;
		7'd17  : answer = 32'd377   ;
		7'd18  : answer = 32'd233   ;
		7'd19  : answer = 32'd144   ;
		7'd20  : answer = 32'd89    ;
		7'd21  : answer = 32'd55    ;
		7'd22  : answer = 32'd34    ;
		7'd23  : answer = 32'd21    ;
		7'd24  : answer = 32'd13    ;
		7'd25  : answer = 32'd8     ;
		7'd26  : answer = 32'd5     ;
		7'd27  : answer = 32'd3     ;
		7'd28  : answer = 32'd2     ;
		7'd29  : answer = 32'd1     ;
		7'd30  : answer = 32'd1     ;
		7'd31  : answer = 32'd0     ;
		7'd32  : answer = `EndSymbol;
		endcase
	end
endmodule