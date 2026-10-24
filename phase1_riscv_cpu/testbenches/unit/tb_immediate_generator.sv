`timescale 1ns/1ps

module tb_immediate_generator;

    localparam logic [2:0] IMM_I    = 3'b000;
    localparam logic [2:0] IMM_S    = 3'b001;
    localparam logic [2:0] IMM_B    = 3'b010;
    localparam logic [2:0] IMM_U    = 3'b011;
    localparam logic [2:0] IMM_J    = 3'b100;
    localparam logic [2:0] IMM_NONE = 3'b111;

    logic [31:0] instruction;
    logic [2:0]  immediate_type;

    logic [31:0] immediate;
    logic        immediate_valid;

    integer checks;
    integer errors;

    immediate_generator dut (
        .instruction     (instruction),
        .immediate_type  (immediate_type),
        .immediate       (immediate),
        .immediate_valid (immediate_valid)
    );

    task automatic check_immediate(
        input string       test_name,
        input logic [31:0] test_instruction,
        input logic [2:0]  test_type,
        input logic [31:0] expected_immediate,
        input logic        expected_valid
    );
        begin
            instruction    = test_instruction;
            immediate_type = test_type;

            #1;

            if ((immediate       !== expected_immediate) ||
                (immediate_valid !== expected_valid)) begin

                errors = errors + 1;

                $display("");
                $display("FAIL: %s", test_name);

                $display(
                    "Expected immediate=%h valid=%b",
                    expected_immediate,
                    expected_valid
                );

                $display(
                    "Received immediate=%h valid=%b",
                    immediate,
                    immediate_valid
                );
            end
            else begin
                checks = checks + 1;

                $display(
                    "PASS: %s immediate=%h",
                    test_name,
                    immediate
                );
            end
        end
    endtask

    initial begin
        checks         = 0;
        errors         = 0;
        instruction    = 32'h00000013;
        immediate_type = IMM_NONE;

        /*
         * Test 1:
         * ADDI x1,x0,5
         * I-type immediate = +5.
         */
        check_immediate(
            "I-type positive immediate",
            32'h00500093,
            IMM_I,
            32'h00000005,
            1'b1
        );

        /*
         * Test 2:
         * ADDI x1,x0,-1
         * Sign extension must produce FFFFFFFF.
         */
        check_immediate(
            "I-type negative immediate",
            32'hFFF00093,
            IMM_I,
            32'hFFFFFFFF,
            1'b1
        );

        /*
         * Test 3:
         * LW x4,12(x2)
         */
        check_immediate(
            "Load offset positive 12",
            32'h00C12203,
            IMM_I,
            32'h0000000C,
            1'b1
        );

        /*
         * Test 4:
         * SW x3,16(x2)
         */
        check_immediate(
            "S-type positive immediate",
            32'h00312823,
            IMM_S,
            32'h00000010,
            1'b1
        );

        /*
         * Test 5:
         * SW x3,-4(x2)
         */
        check_immediate(
            "S-type negative immediate",
            32'hFE312E23,
            IMM_S,
            32'hFFFFFFFC,
            1'b1
        );

        /*
         * Test 6:
         * BEQ x1,x2,+8
         */
        check_immediate(
            "B-type forward branch",
            32'h00208463,
            IMM_B,
            32'h00000008,
            1'b1
        );

        /*
         * Test 7:
         * BEQ x1,x2,-4
         */
        check_immediate(
            "B-type backward branch",
            32'hFE208EE3,
            IMM_B,
            32'hFFFFFFFC,
            1'b1
        );

        /*
         * Test 8:
         * LUI x5,0x12345
         */
        check_immediate(
            "U-type LUI immediate",
            32'h123452B7,
            IMM_U,
            32'h12345000,
            1'b1
        );

        /*
         * Test 9:
         * AUIPC using upper immediate FFFFF.
         */
        check_immediate(
            "U-type upper negative pattern",
            32'hFFFFF317,
            IMM_U,
            32'hFFFFF000,
            1'b1
        );

        /*
         * Test 10:
         * JAL x1,+8
         */
        check_immediate(
            "J-type forward jump",
            32'h008000EF,
            IMM_J,
            32'h00000008,
            1'b1
        );

        /*
         * Test 11:
         * JAL x1,-4
         */
        check_immediate(
            "J-type backward jump",
            32'hFFDFF0EF,
            IMM_J,
            32'hFFFFFFFC,
            1'b1
        );

        /*
         * Test 12:
         * R-type instructions do not have an immediate.
         */
        check_immediate(
            "No immediate for R-type",
            32'h002081B3,
            IMM_NONE,
            32'h00000000,
            1'b0
        );

        /*
         * Test 13:
         * Undefined immediate-type encoding.
         */
        check_immediate(
            "Invalid immediate-type selection",
            32'hFFFFFFFF,
            3'b101,
            32'h00000000,
            1'b0
        );

        $display("");

        if (errors == 0) begin
            $display(
                "ALL %0d IMMEDIATE GENERATOR CHECKS PASSED",
                checks
            );
        end
        else begin
            $display(
                "IMMEDIATE GENERATOR TEST FAILED: %0d error(s)",
                errors
            );

            $fatal(1);
        end

        $finish;
    end

endmodule