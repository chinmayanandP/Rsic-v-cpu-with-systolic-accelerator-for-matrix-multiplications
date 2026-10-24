`timescale 1ns/1ps

module tb_alu;

    localparam logic [3:0] ALU_ADD    = 4'b0000;
    localparam logic [3:0] ALU_SUB    = 4'b0001;
    localparam logic [3:0] ALU_SLL    = 4'b0010;
    localparam logic [3:0] ALU_SLT    = 4'b0011;
    localparam logic [3:0] ALU_SLTU   = 4'b0100;
    localparam logic [3:0] ALU_XOR    = 4'b0101;
    localparam logic [3:0] ALU_SRL    = 4'b0110;
    localparam logic [3:0] ALU_SRA    = 4'b0111;
    localparam logic [3:0] ALU_OR     = 4'b1000;
    localparam logic [3:0] ALU_AND    = 4'b1001;
    localparam logic [3:0] ALU_COPY_B = 4'b1010;

    logic [31:0] operand_a;
    logic [31:0] operand_b;
    logic [3:0]  alu_control;

    logic [31:0] result;
    logic zero;
    logic equal;
    logic less_than_signed;
    logic less_than_unsigned;
    logic illegal_operation;

    integer checks;
    integer errors;

    alu dut (
        .operand_a          (operand_a),
        .operand_b          (operand_b),
        .alu_control        (alu_control),

        .result             (result),
        .zero               (zero),
        .equal              (equal),
        .less_than_signed   (less_than_signed),
        .less_than_unsigned (less_than_unsigned),
        .illegal_operation  (illegal_operation)
    );

    task automatic check_alu(
        input string       test_name,
        input logic [31:0] test_operand_a,
        input logic [31:0] test_operand_b,
        input logic [3:0]  test_control,
        input logic [31:0] expected_result,
        input logic        expected_illegal
    );
        begin
            operand_a   = test_operand_a;
            operand_b   = test_operand_b;
            alu_control = test_control;

            #1;

            if ((result            !== expected_result) ||
                (illegal_operation !== expected_illegal)) begin

                errors = errors + 1;

                $display("");
                $display("FAIL: %s", test_name);

                $display(
                    "A=%h B=%h control=%h",
                    operand_a,
                    operand_b,
                    alu_control
                );

                $display(
                    "Expected result=%h illegal=%b",
                    expected_result,
                    expected_illegal
                );

                $display(
                    "Received result=%h illegal=%b",
                    result,
                    illegal_operation
                );
            end
            else begin
                checks = checks + 1;

                $display(
                    "PASS: %s result=%h",
                    test_name,
                    result
                );
            end
        end
    endtask

    initial begin
        checks      = 0;
        errors      = 0;
        operand_a   = 32'h00000000;
        operand_b   = 32'h00000000;
        alu_control = ALU_ADD;

        /*
         * Test 1: normal addition.
         */
        check_alu(
            "ADD 5 plus 7",
            32'd5,
            32'd7,
            ALU_ADD,
            32'd12,
            1'b0
        );

        /*
         * Test 2: unsigned wraparound is valid RV32I behavior.
         */
        check_alu(
            "ADD wraparound",
            32'hFFFFFFFF,
            32'h00000001,
            ALU_ADD,
            32'h00000000,
            1'b0
        );

        /*
         * Test 3: subtraction.
         */
        check_alu(
            "SUB 12 minus 7",
            32'd12,
            32'd7,
            ALU_SUB,
            32'd5,
            1'b0
        );

        /*
         * Test 4: negative subtraction result.
         */
        check_alu(
            "SUB negative result",
            32'd5,
            32'd7,
            ALU_SUB,
            32'hFFFFFFFE,
            1'b0
        );

        /*
         * Test 5: logical left shift.
         */
        check_alu(
            "SLL by four",
            32'h00000001,
            32'd4,
            ALU_SLL,
            32'h00000010,
            1'b0
        );

        /*
         * Test 6:
         * Only operand_b[4:0] is used.
         * Shift by 32 becomes shift by zero.
         */
        check_alu(
            "SLL masks shift amount",
            32'h12345678,
            32'd32,
            ALU_SLL,
            32'h12345678,
            1'b0
        );

        /*
         * Test 7: signed comparison, -1 < 1.
         */
        check_alu(
            "SLT signed negative",
            32'hFFFFFFFF,
            32'h00000001,
            ALU_SLT,
            32'h00000001,
            1'b0
        );

        /*
         * Test 8:
         * Unsigned FFFFFFFF is greater than 1.
         */
        check_alu(
            "SLTU unsigned comparison",
            32'hFFFFFFFF,
            32'h00000001,
            ALU_SLTU,
            32'h00000000,
            1'b0
        );

        /*
         * Test 9: XOR.
         */
        check_alu(
            "XOR operation",
            32'hAA55AA55,
            32'hFFFF0000,
            ALU_XOR,
            32'h55AAAA55,
            1'b0
        );

        /*
         * Test 10: logical right shift.
         */
        check_alu(
            "SRL operation",
            32'h80000000,
            32'd4,
            ALU_SRL,
            32'h08000000,
            1'b0
        );

        /*
         * Test 11:
         * Arithmetic right shift preserves the sign.
         */
        check_alu(
            "SRA negative value",
            32'h80000000,
            32'd4,
            ALU_SRA,
            32'hF8000000,
            1'b0
        );

        /*
         * Test 12: OR.
         */
        check_alu(
            "OR operation",
            32'hAA550000,
            32'h0000FF00,
            ALU_OR,
            32'hAA55FF00,
            1'b0
        );

        /*
         * Test 13: AND.
         */
        check_alu(
            "AND operation",
            32'hAA55AA55,
            32'h0F0F0F0F,
            ALU_AND,
            32'h0A050A05,
            1'b0
        );

        /*
         * Test 14: COPY_B for LUI.
         */
        check_alu(
            "COPY B for LUI",
            32'hAAAAAAAA,
            32'h12345000,
            ALU_COPY_B,
            32'h12345000,
            1'b0
        );

        /*
         * Test 15: zero flag.
         */
        operand_a   = 32'd7;
        operand_b   = 32'd7;
        alu_control = ALU_SUB;

        #1;

        if ((result !== 32'h00000000) ||
            (zero !== 1'b1) ||
            (equal !== 1'b1)) begin

            errors = errors + 1;
            $display("FAIL: Zero and equality flags");
        end
        else begin
            checks = checks + 1;
            $display("PASS: Zero and equality flags");
        end

        /*
         * Test 16: signed and unsigned comparisons differ.
         */
        operand_a   = 32'hFFFFFFFF;
        operand_b   = 32'h00000001;
        alu_control = ALU_SUB;

        #1;

        if ((less_than_signed   !== 1'b1) ||
            (less_than_unsigned !== 1'b0) ||
            (equal              !== 1'b0)) begin

            errors = errors + 1;
            $display("FAIL: Signed and unsigned flags");
        end
        else begin
            checks = checks + 1;
            $display("PASS: Signed and unsigned flags");
        end

        /*
         * Test 17: invalid ALU operation.
         */
        check_alu(
            "Invalid ALU control",
            32'h12345678,
            32'h87654321,
            4'b1111,
            32'h00000000,
            1'b1
        );

        $display("");

        if (errors == 0) begin
            $display(
                "ALL %0d ALU CHECKS PASSED",
                checks
            );
        end
        else begin
            $display(
                "ALU TEST FAILED: %0d error(s)",
                errors
            );

            $fatal(1);
        end

        $finish;
    end

endmodule