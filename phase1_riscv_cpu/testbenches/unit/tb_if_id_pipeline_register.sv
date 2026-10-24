`timescale 1ns/1ps

module tb_if_id_pipeline_register;

    logic clk;
    logic reset;
    logic enable;
    logic flush;

    logic [31:0] pc_in;
    logic [31:0] pc_plus4_in;
    logic [31:0] instruction_in;
    logic        valid_in;
    logic        fault_in;

    logic [31:0] pc_out;
    logic [31:0] pc_plus4_out;
    logic [31:0] instruction_out;
    logic        valid_out;
    logic        fault_out;

    integer checks;

    if_id_pipeline_register dut (
        .clk             (clk),
        .reset           (reset),
        .enable          (enable),
        .flush           (flush),

        .pc_in           (pc_in),
        .pc_plus4_in     (pc_plus4_in),
        .instruction_in  (instruction_in),
        .valid_in        (valid_in),
        .fault_in        (fault_in),

        .pc_out          (pc_out),
        .pc_plus4_out    (pc_plus4_out),
        .instruction_out (instruction_out),
        .valid_out       (valid_out),
        .fault_out       (fault_out)
    );

    // 10 ns clock period
    initial begin
        clk = 1'b0;

        forever begin
            #5 clk = ~clk;
        end
    end

    task automatic wait_for_rising_edge;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic check_outputs(
        input string       test_name,
        input logic [31:0] expected_pc,
        input logic [31:0] expected_pc_plus4,
        input logic [31:0] expected_instruction,
        input logic        expected_valid,
        input logic        expected_fault
    );
        begin
            if ((pc_out          !== expected_pc)          ||
                (pc_plus4_out    !== expected_pc_plus4)    ||
                (instruction_out !== expected_instruction) ||
                (valid_out       !== expected_valid)       ||
                (fault_out       !== expected_fault)) begin

                $display("");
                $display("FAIL: %s", test_name);

                $display(
                    "Expected pc=%h pc_plus4=%h instruction=%h valid=%b fault=%b",
                    expected_pc,
                    expected_pc_plus4,
                    expected_instruction,
                    expected_valid,
                    expected_fault
                );

                $display(
                    "Received pc=%h pc_plus4=%h instruction=%h valid=%b fault=%b",
                    pc_out,
                    pc_plus4_out,
                    instruction_out,
                    valid_out,
                    fault_out
                );

                $fatal(1);
            end

            checks = checks + 1;
            $display("PASS: %s", test_name);
        end
    endtask

    initial begin
        checks = 0;

        reset          = 1'b1;
        enable         = 1'b0;
        flush          = 1'b0;
        pc_in          = 32'h00000000;
        pc_plus4_in    = 32'h00000004;
        instruction_in = 32'h00000000;
        valid_in       = 1'b0;
        fault_in       = 1'b0;

        // Test 1: synchronous reset
        wait_for_rising_edge();

        check_outputs(
            "Synchronous reset",
            32'h00000000,
            32'h00000004,
            32'h00000013,
            1'b0,
            1'b0
        );

        // Test 2: capture a valid instruction
        reset          = 1'b0;
        enable         = 1'b1;
        flush          = 1'b0;
        pc_in          = 32'h00000000;
        pc_plus4_in    = 32'h00000004;
        instruction_in = 32'h00500093;
        valid_in       = 1'b1;
        fault_in       = 1'b0;

        wait_for_rising_edge();

        check_outputs(
            "Capture ADDI instruction",
            32'h00000000,
            32'h00000004,
            32'h00500093,
            1'b1,
            1'b0
        );

        // Test 3: enable=0 must hold previous values
        enable         = 1'b0;
        pc_in          = 32'h00000020;
        pc_plus4_in    = 32'h00000024;
        instruction_in = 32'h00700113;
        valid_in       = 1'b1;
        fault_in       = 1'b0;

        wait_for_rising_edge();

        check_outputs(
            "Stall holds previous instruction",
            32'h00000000,
            32'h00000004,
            32'h00500093,
            1'b1,
            1'b0
        );

        // Test 4: flush must insert a bubble
        enable         = 1'b1;
        flush          = 1'b1;
        pc_in          = 32'h00000020;
        pc_plus4_in    = 32'h00000024;
        instruction_in = 32'h00700113;
        valid_in       = 1'b1;
        fault_in       = 1'b0;

        wait_for_rising_edge();

        check_outputs(
            "Flush inserts bubble",
            32'h00000000,
            32'h00000004,
            32'h00000013,
            1'b0,
            1'b0
        );

        // Test 5: capture an instruction-memory fault
        flush          = 1'b0;
        enable         = 1'b1;
        pc_in          = 32'h00000040;
        pc_plus4_in    = 32'h00000044;
        instruction_in = 32'h00000013;
        valid_in       = 1'b1;
        fault_in       = 1'b1;

        wait_for_rising_edge();

        check_outputs(
            "Capture instruction fault",
            32'h00000040,
            32'h00000044,
            32'h00000013,
            1'b1,
            1'b1
        );

        // Test 6: reset has priority over flush and enable
        reset          = 1'b1;
        flush          = 1'b1;
        enable         = 1'b1;
        pc_in          = 32'hFFFFFFFF;
        pc_plus4_in    = 32'h00000003;
        instruction_in = 32'hFFFFFFFF;
        valid_in       = 1'b1;
        fault_in       = 1'b1;

        wait_for_rising_edge();

        check_outputs(
            "Reset has highest priority",
            32'h00000000,
            32'h00000004,
            32'h00000013,
            1'b0,
            1'b0
        );

        // Test 7: capture an invalid pipeline entry
        reset          = 1'b0;
        flush          = 1'b0;
        enable         = 1'b1;
        pc_in          = 32'h00000080;
        pc_plus4_in    = 32'h00000084;
        instruction_in = 32'h0000006F;
        valid_in       = 1'b0;
        fault_in       = 1'b0;

        wait_for_rising_edge();

        check_outputs(
            "Capture invalid pipeline entry",
            32'h00000080,
            32'h00000084,
            32'h0000006F,
            1'b0,
            1'b0
        );

        $display("");
        $display(
            "ALL %0d IF/ID PIPELINE REGISTER CHECKS PASSED",
            checks
        );

        $finish;
    end

endmodule