`timescale 1ns/1ps

module tb_pc_plus4;

    logic [31:0] pc;
    wire [31:0] pc_next_sequential;

    integer checks = 0;

    pc_plus4 dut (
        .pc(pc),
        .pc_next_sequential(pc_next_sequential)
    );

    task automatic check_add(
        input logic [31:0] address,
        input logic [31:0] expected
    );
        pc = address;
        #10;

        if (pc_next_sequential !== expected)
            $fatal(
                1,
                "pc=%h got=%h expected=%h",
                pc,
                pc_next_sequential,
                expected
            );

        checks = checks + 1;

        $display(
            "PASS pc=%08h pc_next_sequential=%08h",
            pc,
            pc_next_sequential
        );
    endtask

    initial begin

        // Normal sequential addresses.
        check_add(32'h00000000, 32'h00000004);
        check_add(32'h00000004, 32'h00000008);
        check_add(32'h00000008, 32'h0000000c);
        check_add(32'h0000000c, 32'h00000010);

        // Carry across address boundaries.
        check_add(32'h000000fc, 32'h00000100);
        check_add(32'h0000fffc, 32'h00010000);
        check_add(32'h7ffffffc, 32'h80000000);

        // Upper address range.
        check_add(32'h80000000, 32'h80000004);
        check_add(32'hfffffff8, 32'hfffffffc);

        // 32-bit arithmetic wraparound.
        check_add(32'hfffffffc, 32'h00000000);

        $display(
            "ALL %0d PC + 4 CHECKS PASSED",
            checks
        );

        $finish;
    end

endmodule