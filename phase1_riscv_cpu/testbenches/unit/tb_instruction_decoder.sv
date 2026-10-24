`timescale 1ns/1ps

module tb_instruction_decoder;

    logic [31:0] instruction;
    logic        instruction_valid;
    logic        instruction_fault;

    logic [6:0] opcode;
    logic [4:0] rd;
    logic [2:0] funct3;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [6:0] funct7;

    logic decode_valid;
    logic decode_fault;

    integer checks;
    integer errors;

    instruction_decoder dut (
        .instruction       (instruction),
        .instruction_valid (instruction_valid),
        .instruction_fault (instruction_fault),

        .opcode            (opcode),
        .rd                (rd),
        .funct3            (funct3),
        .rs1               (rs1),
        .rs2               (rs2),
        .funct7            (funct7),

        .decode_valid       (decode_valid),
        .decode_fault       (decode_fault)
    );

    task automatic check_fields(
        input string       test_name,
        input logic [31:0] test_instruction,
        input logic [6:0]  expected_opcode,
        input logic [4:0]  expected_rd,
        input logic [2:0]  expected_funct3,
        input logic [4:0]  expected_rs1,
        input logic [4:0]  expected_rs2,
        input logic [6:0]  expected_funct7
    );
        begin
            instruction       = test_instruction;
            instruction_valid = 1'b1;
            instruction_fault = 1'b0;

            #1;

            if ((opcode       !== expected_opcode) ||
                (rd           !== expected_rd)     ||
                (funct3       !== expected_funct3) ||
                (rs1          !== expected_rs1)    ||
                (rs2          !== expected_rs2)    ||
                (funct7       !== expected_funct7) ||
                (decode_valid !== 1'b1)            ||
                (decode_fault !== 1'b0)) begin

                errors = errors + 1;

                $display("");
                $display("FAIL: %s", test_name);

                $display(
                    "Expected opcode=%h rd=%0d funct3=%h rs1=%0d rs2=%0d funct7=%h",
                    expected_opcode,
                    expected_rd,
                    expected_funct3,
                    expected_rs1,
                    expected_rs2,
                    expected_funct7
                );

                $display(
                    "Received opcode=%h rd=%0d funct3=%h rs1=%0d rs2=%0d funct7=%h",
                    opcode,
                    rd,
                    funct3,
                    rs1,
                    rs2,
                    funct7
                );
            end
            else begin
                checks = checks + 1;
                $display("PASS: %s", test_name);
            end
        end
    endtask

    initial begin
        checks            = 0;
        errors            = 0;
        instruction       = 32'h00000013;
        instruction_valid = 1'b0;
        instruction_fault = 1'b0;

        #1;

        /*
         * Check 1: invalid pipeline entry.
         */
        if ((decode_valid !== 1'b0) ||
            (decode_fault !== 1'b0)) begin

            errors = errors + 1;
            $display("FAIL: Invalid pipeline entry handling");
        end
        else begin
            checks = checks + 1;
            $display("PASS: Invalid pipeline entry handling");
        end

        /*
         * Check 2:
         * ADDI x1,x0,5
         */
        check_fields(
            "Decode ADDI x1,x0,5",
            32'h00500093,
            7'b0010011,
            5'd1,
            3'b000,
            5'd0,
            5'd5,
            7'b0000000
        );

        /*
         * Check 3:
         * ADD x3,x1,x2
         */
        check_fields(
            "Decode ADD x3,x1,x2",
            32'h002081B3,
            7'b0110011,
            5'd3,
            3'b000,
            5'd1,
            5'd2,
            7'b0000000
        );

        /*
         * Check 4:
         * SUB x3,x1,x2
         */
        check_fields(
            "Decode SUB x3,x1,x2",
            32'h402081B3,
            7'b0110011,
            5'd3,
            3'b000,
            5'd1,
            5'd2,
            7'b0100000
        );

        /*
         * Check 5:
         * LW x4,0(x2)
         */
        check_fields(
            "Decode LW x4,0(x2)",
            32'h00012203,
            7'b0000011,
            5'd4,
            3'b010,
            5'd2,
            5'd0,
            7'b0000000
        );

        /*
         * Check 6:
         * SW x3,0(x2)
         */
        check_fields(
            "Decode SW x3,0(x2)",
            32'h00312023,
            7'b0100011,
            5'd0,
            3'b010,
            5'd2,
            5'd3,
            7'b0000000
        );

        /*
         * Check 7:
         * BEQ x1,x2,8
         */
        check_fields(
            "Decode BEQ x1,x2,8",
            32'h00208463,
            7'b1100011,
            5'd8,
            3'b000,
            5'd1,
            5'd2,
            7'b0000000
        );

        /*
         * Check 8:
         * JAL x1,8
         */
        check_fields(
            "Decode JAL x1,8",
            32'h008000EF,
            7'b1101111,
            5'd1,
            3'b000,
            5'd0,
            5'd8,
            7'b0000000
        );

        /*
         * Check 9:
         * JALR x1,0(x2)
         */
        check_fields(
            "Decode JALR x1,0(x2)",
            32'h000100E7,
            7'b1100111,
            5'd1,
            3'b000,
            5'd2,
            5'd0,
            7'b0000000
        );

        /*
         * Check 10:
         * LUI x5,0x12345
         */
        check_fields(
            "Decode LUI x5,0x12345",
            32'h123452B7,
            7'b0110111,
            5'd5,
            3'b101,
            5'd8,
            5'd3,
            7'b0001001
        );

        /*
         * Check 11:
         * Valid instruction accompanied by an instruction fault.
         */
        instruction       = 32'h00000013;
        instruction_valid = 1'b1;
        instruction_fault = 1'b1;

        #1;

        if ((decode_valid !== 1'b0) ||
            (decode_fault !== 1'b1)) begin

            errors = errors + 1;
            $display("FAIL: Instruction-fault propagation");
        end
        else begin
            checks = checks + 1;
            $display("PASS: Instruction-fault propagation");
        end

        $display("");

        if (errors == 0) begin
            $display(
                "ALL %0d INSTRUCTION DECODER CHECKS PASSED",
                checks
            );
        end
        else begin
            $display(
                "INSTRUCTION DECODER TEST FAILED: %0d error(s)",
                errors
            );

            $fatal(1);
        end

        $finish;
    end

endmodule