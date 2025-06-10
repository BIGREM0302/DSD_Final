`timescale 1ns/1ps

module boothmul_tb;

    reg  [31:0] a, b;
    wire [63:0] m;

    integer i, j;
    reg [63:0] expected;
    wire [63:0] shift[0:15];
    // Instantiate your Booth multiplier
    BoothMul uut (
        .a(a),
        .b(b),
        .m(m),
        .shift0(shift[0]),
        .shift1(shift[1]),
        .shift2(shift[2]),
        .shift3(shift[3]),
        .shift4(shift[4]),
        .shift5(shift[5]),
        .shift6(shift[6]),
        .shift7(shift[7]),
        .shift8(shift[8]),
        .shift9(shift[9]),
        .shift10(shift[10]),
        .shift11(shift[11]),
        .shift12(shift[12]),
        .shift13(shift[13]),
        .shift14(shift[14]),
        .shift15(shift[15])
    );

    task run_test;
        input [31:0] in_a;
        input [31:0] in_b;
    begin
        a = in_a;
        b = in_b;
        expected = in_a * in_b;

        #10; // 等待模組運作

        if (m !== expected) begin
            $display("❌ FAIL: a = %0d, b = %0d → expected = %h, got = %h", a, b, expected, m);
            debug;
        end
        else
            $display("✅ PASS: a = %h, b = %h → result = %h", a, b, m);
    end
    endtask

    task debug;
    begin
        for(j = 0; j < 16; j = j + 1)begin
            $display("shift %d = %h", j, shift[j]);
        end
    end
    endtask

    initial begin
        $display("=== BoothMul Unsigned Test ===");

        // Basic unsigned test cases
        run_test(32'hB04955A2, 32'hE0541ECE);         // max unsigned
        run_test(32'hADBEADDE, 32'h0138D5A0);
        run_test(32'h48209B17, 32'hE35DFF62);
        run_test(32'h01563709, 32'hF1A959DC);      // 16-bit max * 16-bit max

        // Random unsigned test
        for (i = 0; i < 10; i = i + 1) begin
            run_test($urandom % (2**31), $urandom % (2**31));
        end

        $display("=== Test Done ===");
        $finish;
    end

endmodule
