`timescale 1ns/1ps

module tb_operand_muxes;

    logic [31:0] rs1_value;
    logic [31:0] rs2_value;
    logic [31:0] pc_value;
    logic [31:0] immediate_value;

    logic select_pc_for_operand_a;
    logic select_immediate_for_operand_b;

    logic [31:0] operand_a;
    logic [31:0] operand_b;

    integer checks;
    integer errors;

    operand_muxes dut (
        .rs1_value                     (rs1_value),
        .rs2_value                     (rs2_value),
        .pc_value                      (pc_value),
        .immediate_value               (immediate_value),

        .select_pc_for_operand_a       (
            select_pc_for_operand_a
        ),

        .select_immediate_for_operand_b(
            select_immediate_for_operand_b
        ),

        .operand_a                     (operand_a),
        .operand_b                     (operand_b)
    );

    task automatic check_operands(
        input string       test_name,
        input logic        test_select_a,
        input logic        test_select_b,
        input logic [31:0] expected_a,
        input logic [31:0] expected_b
    );
        begin
            select_pc_for_operand_a        = test_select_a;
            select_immediate_for_operand_b = test_select_b;

            #1;

            if ((operand_a !== expected_a) ||
                (operand_b !== expected_b)) begin

                errors = errors + 1;

                $display("");
                $display("FAIL: %s", test_name);

                $display(
                    "Expected operand_a=%h operand_b=%h",
                    expected_a,
                    expected_b
                );

                $display(
                    "Received operand_a=%h operand_b=%h",
                    operand_a,
                    operand_b
                );
            end
            else begin
                checks = checks + 1;

                $display(
                    "PASS: %s A=%h B=%h",
                    test_name,
                    operand_a,
                    operand_b
                );
            end
        end
    endtask

    initial begin
        checks = 0;
        errors = 0;

        rs1_value       = 32'h11111111;
        rs2_value       = 32'h22222222;
        pc_value        = 32'h00000100;
        immediate_value = 32'hFFFFFFFC;

        /*
         * Test 1:
         * R-type instruction such as ADD.
         */
        check_operands(
            "Register and register operands",
            1'b0,
            1'b0,
            32'h11111111,
            32'h22222222
        );

        /*
         * Test 2:
         * I-type instruction such as ADDI.
         */
        check_operands(
            "Register and immediate operands",
            1'b0,
            1'b1,
            32'h11111111,
            32'hFFFFFFFC
        );

        /*
         * Test 3:
         * AUIPC uses PC plus immediate.
         */
        check_operands(
            "PC and immediate operands",
            1'b1,
            1'b1,
            32'h00000100,
            32'hFFFFFFFC
        );

        /*
         * Test 4:
         * This combination verifies independent MUX control.
         */
        check_operands(
            "PC and register operands",
            1'b1,
            1'b0,
            32'h00000100,
            32'h22222222
        );

        /*
         * Test 5:
         * Change every data input and verify register selection.
         */
        rs1_value       = 32'hA5A55A5A;
        rs2_value       = 32'h12345678;
        pc_value        = 32'h00002000;
        immediate_value = 32'h0000000C;

        check_operands(
            "Updated register operands",
            1'b0,
            1'b0,
            32'hA5A55A5A,
            32'h12345678
        );

        /*
         * Test 6:
         * Load/store address calculation.
         */
        check_operands(
            "Load-store address operands",
            1'b0,
            1'b1,
            32'hA5A55A5A,
            32'h0000000C
        );

        /*
         * Test 7:
         * AUIPC with updated values.
         */
        check_operands(
            "Updated PC plus immediate",
            1'b1,
            1'b1,
            32'h00002000,
            32'h0000000C
        );

        /*
         * Test 8:
         * Zero-valued inputs.
         */
        rs1_value       = 32'h00000000;
        rs2_value       = 32'h00000000;
        pc_value        = 32'h00000000;
        immediate_value = 32'h00000000;

        check_operands(
            "Zero operands",
            1'b0,
            1'b1,
            32'h00000000,
            32'h00000000
        );

        $display("");

        if (errors == 0) begin
            $display(
                "ALL %0d OPERAND MUX CHECKS PASSED",
                checks
            );
        end
        else begin
            $display(
                "OPERAND MUX TEST FAILED: %0d error(s)",
                errors
            );

            $fatal(1);
        end

        $finish;
    end

endmodule