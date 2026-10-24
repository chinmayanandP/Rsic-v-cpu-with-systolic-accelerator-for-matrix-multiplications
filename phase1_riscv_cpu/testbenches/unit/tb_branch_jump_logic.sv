`timescale 1ns/1ps

module tb_branch_jump_logic;

    logic execute_valid;
    logic branch;
    logic jump;
    logic jump_register;

    logic [2:0] funct3;

    logic [31:0] pc;
    logic [31:0] rs1_value;
    logic [31:0] rs2_value;
    logic [31:0] immediate;

    logic branch_taken;
    logic redirect_valid;
    logic [31:0] redirect_target;

    logic target_misaligned;
    logic illegal_branch_function;
    logic illegal_control_combination;

    integer checks;
    integer errors;

    branch_jump_logic dut (
        .execute_valid               (execute_valid),
        .branch                      (branch),
        .jump                        (jump),
        .jump_register               (jump_register),
        .funct3                      (funct3),

        .pc                          (pc),
        .rs1_value                   (rs1_value),
        .rs2_value                   (rs2_value),
        .immediate                   (immediate),

        .branch_taken                (branch_taken),
        .redirect_valid              (redirect_valid),
        .redirect_target             (redirect_target),

        .target_misaligned           (target_misaligned),
        .illegal_branch_function     (
            illegal_branch_function
        ),

        .illegal_control_combination (
            illegal_control_combination
        )
    );

    /*
     * This task waits for the combinational logic to settle and
     * then reads the DUT outputs directly.
     */
    task automatic check_outputs(
        input string       test_name,
        input logic        expected_branch_taken,
        input logic        expected_redirect_valid,
        input logic [31:0] expected_redirect_target,
        input logic        expected_misaligned,
        input logic        expected_illegal_branch,
        input logic        expected_illegal_combination
    );
        begin
            #1;

            if ((branch_taken                !==
                 expected_branch_taken)              ||

                (redirect_valid              !==
                 expected_redirect_valid)            ||

                (redirect_target             !==
                 expected_redirect_target)           ||

                (target_misaligned           !==
                 expected_misaligned)                ||

                (illegal_branch_function     !==
                 expected_illegal_branch)            ||

                (illegal_control_combination !==
                 expected_illegal_combination)) begin

                errors = errors + 1;

                $display("");
                $display("FAIL: %s", test_name);

                $display(
                    "Expected taken=%b redirect=%b target=%h misaligned=%b illegal_branch=%b illegal_control=%b",
                    expected_branch_taken,
                    expected_redirect_valid,
                    expected_redirect_target,
                    expected_misaligned,
                    expected_illegal_branch,
                    expected_illegal_combination
                );

                $display(
                    "Received taken=%b redirect=%b target=%h misaligned=%b illegal_branch=%b illegal_control=%b",
                    branch_taken,
                    redirect_valid,
                    redirect_target,
                    target_misaligned,
                    illegal_branch_function,
                    illegal_control_combination
                );
            end
            else begin
                checks = checks + 1;

                $display(
                    "PASS: %s target=%h",
                    test_name,
                    redirect_target
                );
            end
        end
    endtask

    task automatic set_branch_inputs(
        input logic [2:0]  test_funct3,
        input logic [31:0] test_rs1,
        input logic [31:0] test_rs2,
        input logic [31:0] test_immediate
    );
        begin
            execute_valid = 1'b1;
            branch        = 1'b1;
            jump          = 1'b0;
            jump_register = 1'b0;

            funct3        = test_funct3;
            rs1_value     = test_rs1;
            rs2_value     = test_rs2;
            immediate     = test_immediate;
        end
    endtask

    initial begin
        checks = 0;
        errors = 0;

        execute_valid = 1'b0;
        branch        = 1'b0;
        jump          = 1'b0;
        jump_register = 1'b0;

        funct3    = 3'b000;
        pc        = 32'h00000100;
        rs1_value = 32'h00000000;
        rs2_value = 32'h00000000;
        immediate = 32'h00000000;

        /*
         * Test 1: invalid pipeline entry.
         */
        check_outputs(
            "Invalid entry causes no redirect",
            1'b0,
            1'b0,
            32'h00000000,
            1'b0,
            1'b0,
            1'b0
        );

        /*
         * Test 2: BEQ taken.
         */
        set_branch_inputs(
            3'b000,
            32'd5,
            32'd5,
            32'd8
        );

        check_outputs(
            "BEQ taken",
            1'b1,
            1'b1,
            32'h00000108,
            1'b0,
            1'b0,
            1'b0
        );

        /*
         * Test 3: BEQ not taken.
         */
        set_branch_inputs(
            3'b000,
            32'd5,
            32'd7,
            32'd8
        );

        check_outputs(
            "BEQ not taken",
            1'b0,
            1'b0,
            32'h00000000,
            1'b0,
            1'b0,
            1'b0
        );

        /*
         * Test 4: BNE taken.
         */
        set_branch_inputs(
            3'b001,
            32'd5,
            32'd7,
            32'd8
        );

        check_outputs(
            "BNE taken",
            1'b1,
            1'b1,
            32'h00000108,
            1'b0,
            1'b0,
            1'b0
        );

        /*
         * Test 5: BLT signed.
         * -1 is less than +1.
         */
        set_branch_inputs(
            3'b100,
            32'hFFFFFFFF,
            32'h00000001,
            32'd8
        );

        check_outputs(
            "BLT signed negative comparison",
            1'b1,
            1'b1,
            32'h00000108,
            1'b0,
            1'b0,
            1'b0
        );

        /*
         * Test 6: BGE signed.
         * +5 is greater than -2.
         */
        set_branch_inputs(
            3'b101,
            32'h00000005,
            32'hFFFFFFFE,
            32'd8
        );

        check_outputs(
            "BGE signed comparison",
            1'b1,
            1'b1,
            32'h00000108,
            1'b0,
            1'b0,
            1'b0
        );

        /*
         * Test 7: BLTU not taken.
         * Unsigned FFFFFFFF is greater than 1.
         */
        set_branch_inputs(
            3'b110,
            32'hFFFFFFFF,
            32'h00000001,
            32'd8
        );

        check_outputs(
            "BLTU unsigned comparison",
            1'b0,
            1'b0,
            32'h00000000,
            1'b0,
            1'b0,
            1'b0
        );

        /*
         * Test 8: BGEU taken.
         */
        set_branch_inputs(
            3'b111,
            32'hFFFFFFFF,
            32'h00000001,
            32'd8
        );

        check_outputs(
            "BGEU unsigned comparison",
            1'b1,
            1'b1,
            32'h00000108,
            1'b0,
            1'b0,
            1'b0
        );

        /*
         * Test 9: taken branch with misaligned target.
         */
        set_branch_inputs(
            3'b000,
            32'd10,
            32'd10,
            32'd2
        );

        check_outputs(
            "Misaligned taken branch",
            1'b1,
            1'b0,
            32'h00000102,
            1'b1,
            1'b0,
            1'b0
        );

        /*
         * Test 10: JAL target = PC + immediate.
         */
        execute_valid = 1'b1;
        branch        = 1'b0;
        jump          = 1'b1;
        jump_register = 1'b0;

        pc        = 32'h00000200;
        immediate = 32'h00000010;

        check_outputs(
            "JAL target calculation",
            1'b0,
            1'b1,
            32'h00000210,
            1'b0,
            1'b0,
            1'b0
        );

        /*
         * Test 11:
         * JALR target: 0x200 + 5 = 0x205.
         * Bit zero is cleared, producing 0x204.
         */
        execute_valid = 1'b1;
        branch        = 1'b0;
        jump          = 1'b1;
        jump_register = 1'b1;

        rs1_value = 32'h00000200;
        immediate = 32'h00000005;

        check_outputs(
            "JALR clears target bit zero",
            1'b0,
            1'b1,
            32'h00000204,
            1'b0,
            1'b0,
            1'b0
        );

        /*
         * Test 12:
         * 0x200 + 3 = 0x203.
         * Clearing bit zero gives 0x202, which is not
         * four-byte aligned.
         */
        rs1_value = 32'h00000200;
        immediate = 32'h00000003;

        check_outputs(
            "JALR misaligned target",
            1'b0,
            1'b0,
            32'h00000202,
            1'b1,
            1'b0,
            1'b0
        );

        /*
         * Test 13: illegal branch funct3.
         */
        set_branch_inputs(
            3'b010,
            32'd1,
            32'd1,
            32'd8
        );

        check_outputs(
            "Illegal branch function detection",
            1'b0,
            1'b0,
            32'h00000000,
            1'b0,
            1'b1,
            1'b0
        );

        /*
         * Test 14:
         * Branch and JAL cannot be active together.
         */
        execute_valid = 1'b1;
        branch        = 1'b1;
        jump          = 1'b1;
        jump_register = 1'b0;

        check_outputs(
            "Illegal control combination detection",
            1'b0,
            1'b0,
            32'h00000000,
            1'b0,
            1'b0,
            1'b1
        );

        $display("");

        if (errors == 0) begin
            $display(
                "ALL %0d BRANCH-JUMP CHECKS PASSED",
                checks
            );
        end
        else begin
            $display(
                "BRANCH-JUMP TEST FAILED: %0d error(s)",
                errors
            );

            $fatal(1);
        end

        $finish;
    end

endmodule