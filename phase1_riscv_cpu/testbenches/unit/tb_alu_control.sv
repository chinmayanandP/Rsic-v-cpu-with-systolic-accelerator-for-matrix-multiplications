`timescale 1ns/1ps

module tb_alu_control;

    localparam logic [2:0] CLASS_ADD       = 3'b000;
    localparam logic [2:0] CLASS_BRANCH    = 3'b001;
    localparam logic [2:0] CLASS_REGISTER  = 3'b010;
    localparam logic [2:0] CLASS_IMMEDIATE = 3'b011;
    localparam logic [2:0] CLASS_LUI       = 3'b100;
    localparam logic [2:0] CLASS_NONE      = 3'b111;

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

    logic [2:0] alu_operation_class;
    logic [2:0] funct3;
    logic [6:0] funct7;

    logic [3:0] alu_control_code;
    logic       alu_control_valid;
    logic       illegal_alu_control;

    integer checks;
    integer errors;

    alu_control dut (
        .alu_operation_class (alu_operation_class),
        .funct3              (funct3),
        .funct7              (funct7),
        .alu_control_code    (alu_control_code),
        .alu_control_valid   (alu_control_valid),
        .illegal_alu_control (illegal_alu_control)
    );

    task automatic check_control(
        input string      test_name,
        input logic [2:0] test_class,
        input logic [2:0] test_funct3,
        input logic [6:0] test_funct7,
        input logic [3:0] expected_code,
        input logic       expected_valid,
        input logic       expected_illegal
    );
        begin
            alu_operation_class = test_class;
            funct3              = test_funct3;
            funct7              = test_funct7;

            #1;

            if ((alu_control_code    !== expected_code)    ||
                (alu_control_valid   !== expected_valid)   ||
                (illegal_alu_control !== expected_illegal)) begin

                errors = errors + 1;

                $display("");
                $display("FAIL: %s", test_name);

                $display(
                    "Expected code=%h valid=%b illegal=%b",
                    expected_code,
                    expected_valid,
                    expected_illegal
                );

                $display(
                    "Received code=%h valid=%b illegal=%b",
                    alu_control_code,
                    alu_control_valid,
                    illegal_alu_control
                );
            end
            else begin
                checks = checks + 1;

                $display(
                    "PASS: %s code=%h",
                    test_name,
                    alu_control_code
                );
            end
        end
    endtask

    initial begin
        checks = 0;
        errors = 0;

        check_control(
            "Address addition",
            CLASS_ADD, 3'b000, 7'b0000000,
            ALU_ADD, 1'b1, 1'b0
        );

        check_control(
            "Branch subtraction",
            CLASS_BRANCH, 3'b000, 7'b0000000,
            ALU_SUB, 1'b1, 1'b0
        );

        check_control(
            "R-type ADD",
            CLASS_REGISTER, 3'b000, 7'b0000000,
            ALU_ADD, 1'b1, 1'b0
        );

        check_control(
            "R-type SUB",
            CLASS_REGISTER, 3'b000, 7'b0100000,
            ALU_SUB, 1'b1, 1'b0
        );

        check_control(
            "R-type SLL",
            CLASS_REGISTER, 3'b001, 7'b0000000,
            ALU_SLL, 1'b1, 1'b0
        );

        check_control(
            "R-type SLT",
            CLASS_REGISTER, 3'b010, 7'b0000000,
            ALU_SLT, 1'b1, 1'b0
        );

        check_control(
            "R-type SLTU",
            CLASS_REGISTER, 3'b011, 7'b0000000,
            ALU_SLTU, 1'b1, 1'b0
        );

        check_control(
            "R-type XOR",
            CLASS_REGISTER, 3'b100, 7'b0000000,
            ALU_XOR, 1'b1, 1'b0
        );

        check_control(
            "R-type SRL",
            CLASS_REGISTER, 3'b101, 7'b0000000,
            ALU_SRL, 1'b1, 1'b0
        );

        check_control(
            "R-type SRA",
            CLASS_REGISTER, 3'b101, 7'b0100000,
            ALU_SRA, 1'b1, 1'b0
        );

        check_control(
            "R-type OR",
            CLASS_REGISTER, 3'b110, 7'b0000000,
            ALU_OR, 1'b1, 1'b0
        );

        check_control(
            "R-type AND",
            CLASS_REGISTER, 3'b111, 7'b0000000,
            ALU_AND, 1'b1, 1'b0
        );

        check_control(
            "I-type ADDI",
            CLASS_IMMEDIATE, 3'b000, 7'b0000000,
            ALU_ADD, 1'b1, 1'b0
        );

        check_control(
            "I-type SLTI",
            CLASS_IMMEDIATE, 3'b010, 7'b0000000,
            ALU_SLT, 1'b1, 1'b0
        );

        check_control(
            "I-type SLTIU",
            CLASS_IMMEDIATE, 3'b011, 7'b0000000,
            ALU_SLTU, 1'b1, 1'b0
        );

        check_control(
            "I-type XORI",
            CLASS_IMMEDIATE, 3'b100, 7'b0000000,
            ALU_XOR, 1'b1, 1'b0
        );

        check_control(
            "I-type SRLI",
            CLASS_IMMEDIATE, 3'b101, 7'b0000000,
            ALU_SRL, 1'b1, 1'b0
        );

        check_control(
            "I-type SRAI",
            CLASS_IMMEDIATE, 3'b101, 7'b0100000,
            ALU_SRA, 1'b1, 1'b0
        );

        check_control(
            "I-type ORI",
            CLASS_IMMEDIATE, 3'b110, 7'b0000000,
            ALU_OR, 1'b1, 1'b0
        );

        check_control(
            "I-type ANDI",
            CLASS_IMMEDIATE, 3'b111, 7'b0000000,
            ALU_AND, 1'b1, 1'b0
        );

        check_control(
            "LUI COPY-B",
            CLASS_LUI, 3'b000, 7'b0000000,
            ALU_COPY_B, 1'b1, 1'b0
        );

        check_control(
            "No ALU operation",
            CLASS_NONE, 3'b000, 7'b0000000,
            ALU_ADD, 1'b0, 1'b0
        );

        check_control(
            "Reject RV32M encoding",
            CLASS_REGISTER, 3'b000, 7'b0000001,
            ALU_ADD, 1'b0, 1'b1
        );

        check_control(
            "Reject invalid class",
            3'b101, 3'b000, 7'b0000000,
            ALU_ADD, 1'b0, 1'b1
        );

        $display("");

        if (errors == 0) begin
            $display(
                "ALL %0d ALU CONTROL CHECKS PASSED",
                checks
            );
        end
        else begin
            $display(
                "ALU CONTROL TEST FAILED: %0d error(s)",
                errors
            );

            $fatal(1);
        end

        $finish;
    end

endmodule