// this is a test bench feeds initial instruction and data
// the processor output is not verified

`timescale 1 ns/10 ps

`define CYCLE 3.5 // You can modify your clock frequency
`define MAX_CYCLES 10000000 // Max cycle count to stop the simulaiton. You can modify it

`define SDFFILE   "./Netlist/CHIP_syn.sdf"	// Modify your SDF file name

// INFO: Files for different conditions are listed here. Please modify the path if needed.
`ifdef noHazard
	`define IMEM_INIT "../Baseline/I_mem_noHazard"
	`include "../Baseline/TestBed_noHazard.v"
	`define DMEM_INIT "../Baseline/D_mem"
`endif
`ifdef hasHazard
	`define IMEM_INIT "../Baseline/I_mem_hasHazard"
	`include "../Baseline/TestBed_hasHazard.v"
	`define DMEM_INIT "../Baseline/D_mem"
`endif
`ifdef BrPred
	`define IMEM_INIT "../Extension/BrPred/a10b20c30/I_mem_BrPred"
	`include "../Extension/BrPred/a10b20c30/TestBed_BrPred.v"
	`define DMEM_INIT "../Baseline/D_mem"
`endif
`ifdef compression
	`define IMEM_INIT "../Extension/Compression/DEADxF625/I_mem_compression"
	`include "../Extension/Compression/DEADxF625/TestBed_compression.v"
	`define DMEM_INIT "../Baseline/D_mem"
`endif
`ifdef compression_uncompressed
	`define IMEM_INIT "../Extension/Compression/DEADxF625/I_mem_decompression"
	`include "../Extension/Compression/DEADxF625/TestBed_compression.v"
	`define DMEM_INIT "../Baseline/D_mem"
`endif
`ifdef Mul
	`define IMEM_INIT "../Extension/Mul/I_mem"
	`define END_PC 88
	`define QSort_TestBed
	`define DMEM_INIT "../Extension/Mul/D_mem"
	`define GOLDEN "../Extension/Mul/D_gold"
	`include "../Q_Sort/data_gen/TestBed_QSort.v"
`endif
`ifdef QSort
	`define IMEM_INIT "../Q_Sort/data_gen/I_mem_compression"
	`define END_PC 320
	`define QSort
	`define QSort_TestBed
	`define DMEM_INIT "../Q_Sort/data_gen/D_mem"
	`define GOLDEN "../Q_Sort/data_gen/D_gold"
	`include "../Q_Sort/data_gen/TestBed_QSort.v"
`endif
`ifdef QSort_uncompressed
	`define IMEM_INIT "../Q_Sort/data_gen/I_mem"
	`define END_PC 400
	`define QSort
	`define QSort_TestBed
	`define DMEM_INIT "../Q_Sort/data_gen/D_mem"
	`define GOLDEN "../Q_Sort/data_gen/D_gold"
	`include "../Q_Sort/data_gen/TestBed_QSort.v"
`endif
`ifdef Conv
	`define IMEM_INIT "../Conv/I_mem_compression"
	`define END_PC 424
	`define QSort_TestBed
	`define DMEM_INIT "../Conv/D_mem"
	`define GOLDEN "../Conv/D_gold"
	`include "../Q_Sort/data_gen/TestBed_QSort.v"
`endif
`ifdef Conv_uncompressed
	`define IMEM_INIT "../Conv/I_mem"
	`define END_PC 616
	`define QSort_TestBed
	`define DMEM_INIT "../Conv/D_mem"
	`define GOLDEN "../Conv/D_gold"
	`include "../Q_Sort/data_gen/TestBed_QSort.v"
`endif

// INFO: The golden answer for QSort & mul is stored in D_gold. For other cases, it's written in the TestBed.



module Final_tb;

	reg clk;
	reg rst_n;
	
	wire mem_read_D;
	wire mem_write_D;
	wire [31:4] mem_addr_D;
	wire [127:0] mem_wdata_D;
	wire [127:0] mem_rdata_D;
	wire mem_ready_D;

	wire mem_read_I;
	wire mem_write_I;
	wire [31:4] mem_addr_I;
	wire [127:0] mem_wdata_I;
	wire [127:0] mem_rdata_I;
	wire mem_ready_I;
	
	wire [29:0]	DCACHE_addr;
	wire [31:0]	DCACHE_wdata;
	wire 		DCACHE_wen;
	
	wire [8:0] error_num;
	wire [15:0] duration;
	wire finish;	
	wire [31:0] PC; 

	// Note the design is connected at testbench, include:
	// 1. CHIP (RISCV + D_cache + I_chache)
	// 2. slow memory for data
	// 3. slow memory for instruction
	
	CHIP chip0 (clk,
				rst_n,
//----------for slow_memD------------	
				mem_read_D,
				mem_write_D,
				mem_addr_D,
				mem_wdata_D,
				mem_rdata_D,
				mem_ready_D,
//----------for slow_memI------------
				mem_read_I,
				mem_write_I,
				mem_addr_I,
				mem_wdata_I,
				mem_rdata_I,
				mem_ready_I,
//----------for TestBed--------------				
				DCACHE_addr,
				DCACHE_wdata,
				DCACHE_wen,
				PC
				);

	slow_memory slow_memD(
		.clk        (clk)           ,
		.mem_read   (mem_read_D)    ,
		.mem_write  (mem_write_D)   ,
		.mem_addr   (mem_addr_D)    ,
		.mem_wdata  (mem_wdata_D)   ,
		.mem_rdata  (mem_rdata_D)   ,
		.mem_ready  (mem_ready_D)
	);

	slow_memory slow_memI(
		.clk        (clk)           ,
		.mem_read   (mem_read_I)    ,
		.mem_write  (mem_write_I)   ,
		.mem_addr   (mem_addr_I)    ,
		.mem_wdata  (mem_wdata_I)   ,
		.mem_rdata  (mem_rdata_I)   ,
		.mem_ready  (mem_ready_I)
	);

	TestBed testbed(
		.clk        (clk)           ,
		.rst        (rst_n)         ,
		.addr       (DCACHE_addr)   ,
		.data       (DCACHE_wdata)  ,
		.wen        (DCACHE_wen)    ,
		.PC			(PC)			,
		.error_num  (error_num)     ,
		.duration   (duration)      ,
		.finish     (finish)
	);
	// INFO: PC for QSort TestBed, duration for others. For uniformity, all TestBeds have both ports.
	
`ifdef SDF
    initial $sdf_annotate(`SDFFILE, chip0);
`endif
	
integer i;
// Initialize the data memory
	initial begin
		$readmemh (`DMEM_INIT, slow_memD.mem ); // initialize data in DMEM
		for (i=0; i<slow_memI.MEM_NUM*4; i=i+1) begin
			slow_memI.mem[i] = 32'h13_00_00_00; // padding the IMEM with NOP instruction
		end
		$readmemh (`IMEM_INIT, slow_memI.mem ); // initialize data in IMEM
		
		$display("-----------------------------------------------------\n");
	 	$display("START!!! Simulation Start .....\n");
	 	$display("-----------------------------------------------------\n");

		// waveform dump
	    // $dumpfile("Final.vcd");
	    // $dumpvars;

		$fsdbDumpfile("Final.fsdb");
		$fsdbDumpvars(0,Final_tb,"+mda");
		$fsdbDumpvars;
	
		clk = 1;
		rst_n = 1'b1;
		#(`CYCLE*1.6) rst_n = 1'b0;
		#(`CYCLE*5.0) rst_n = 1'b1;
     
		#(`CYCLE * `MAX_CYCLES) // calculate clock cycles for all operation (you can modify it)
		$display("============================================================================");
		$display("\n           Error!!! There is something wrong with your code ...!          ");
		$display("\n                       The test result is .....FAIL                     \n");
		$display("============================================================================");

		`ifndef QSort_TestBed
			if (testbed.curstate == 2'b0)
				$display("Possible solution: The first answer may not be correct.\n");
			if (testbed.curstate == 2'b1)
				$display("Possible solution: The clock cycles may be too small. Please modify it.\n");
		`endif
	 	$finish;
	end
		
	always #(`CYCLE*0.5) clk = ~clk;
	
	always@(finish)
	    if(finish)
	       #(`CYCLE) $finish;		   
	
endmodule
