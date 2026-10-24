`timescale 1ns/1ps

module tb_control_unit;

    localparam logic [2:0] IMM_I    = 3'b000;
    localparam logic [2:0] IMM_S    = 3'b001;
    localparam logic [2:0] IMM_B    = 3'b010;
    localparam logic [2:0] IMM_U    = 3'b011;
    localparam logic [2:0] IMM_J    = 3'b100;
    localparam logic [2:0] IMM_NONE = 3'b111;

    localparam logic [2:0] ALU_ADD       = 3'b000;
    localparam logic [2:0] ALU_BRANCH    = 3'b001;
    localparam logic [2:0] ALU_REGISTER  = 3'b010;
    localparam logic [2:0] ALU_IMMEDIATE = 3'b011;
    localparam logic [2:0] ALU_LUI       = 3'b100;

    localparam logic [1:0] RESULT_ALU    = 2'b00;
    localparam logic [1:0] RESULT_MEMORY = 2'b01;
    localparam logic [1:0] RESULT_PC4    = 2'b10;

    logic [31:0] instruction;
    logic        instruction_valid;
    logic        instruction_fault;

    logic [6:0]  opcode;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic [4:0]  rs1;
    logic [4:0]  rd;
    logic [11:0] system_immediate;

    logic control_valid;
    logic illegal_instruction;
    logic instruction_fault_out;

    logic register_write;
    logic memory_read;
    logic memory_write;
    logic branch;
    logic jump;
    logic jump_register;
    logic alu_source_a_pc;
    logic alu_source_b_immediate;
    logic uses_rs1;
    logic uses_rs2;
    logic [2:0] immediate_type;
    logic [2:0] alu_operation_class;
    logic [1:0] result_source;
    logic system_instruction;
    logic fence_instruction;

    integer checks;
    integer errors;

    assign opcode           = instruction[6:0];
    assign rd               = instruction[11:7];
    assign funct3           = instruction[14:12];
    assign rs1              = instruction[19:15];
    assign funct7           = instruction[31:25];
    assign system_immediate = instruction[31:20];

    control_unit dut (
        .instruction_valid       (instruction_valid),
        .instruction_fault       (instruction_fault),
        .opcode                  (opcode),
        .funct3                  (funct3),
        .funct7                  (funct7),
        .rs1                     (rs1),
        .rd                      (rd),
        .system_immediate        (system_immediate),

        .control_valid           (control_valid),
        .illegal_instruction     (illegal_instruction),
        .instruction_fault_out   (instruction_fault_out),

        .register_write          (register_write),
        .memory_read             (memory_read),
        .memory_write            (memory_write),
        .branch                  (branch),
        .jump                    (jump),
        .jump_register           (jump_register),

        .alu_source_a_pc         (alu_source_a_pc),
        .alu_source_b_immediate  (alu_source_b_immediate),
        .uses_rs1                (uses_rs1),
        .uses_rs2                (uses_rs2),

        .immediate_type          (immediate_type),
        .alu_operation_class     (alu_operation_class),
        .result_source           (result_source),

        .system_instruction      (system_instruction),
        .fence_instruction       (fence_instruction)
    );

    task automatic apply_instruction(
        input logic [31:0] test_instruction,
        input logic        test_valid,
        input logic        test_fault
    );
        begin
            instruction       = test_instruction;
            instruction_valid = test_valid;
            instruction_fault = test_fault;
            #1;
        end
    endtask

    task automatic check_condition(
        input string test_name,
        input logic  condition
    );
        begin
            if (condition !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL: %s", test_name);
            end
            else begin
                checks = checks + 1;
                $display("PASS: %s", test_name);
            end
        end
    endtask

    initial begin
        checks = 0;
        errors = 0;

        /*
         * Test 1: invalid pipeline entry.
         */
        apply_instruction(32'h00000013, 1'b0, 1'b0);

        check_condition(
            "Invalid pipeline entry has no controls",
            !control_valid &&
            !illegal_instruction &&
            !register_write &&
            !memory_read &&
            !memory_write
        );

        /*
         * Test 2: ADD x3,x1,x2.
         */
        apply_instruction(32'h002081B3, 1'b1, 1'b0);

        check_condition(
            "ADD control signals",
            control_valid &&
            !illegal_instruction &&
            register_write &&
            uses_rs1 &&
            uses_rs2 &&
            (alu_operation_class == ALU_REGISTER) &&
            (result_source == RESULT_ALU)
        );

        /*
         * Test 3: SUB x3,x1,x2.
         */
        apply_instruction(32'h402081B3, 1'b1, 1'b0);

        check_condition(
            "SUB control signals",
            control_valid &&
            register_write &&
            uses_rs1 &&
            uses_rs2 &&
            (alu_operation_class == ALU_REGISTER)
        );

        /*
         * Test 4: ADDI x1,x0,5.
         */
        apply_instruction(32'h00500093, 1'b1, 1'b0);

        check_condition(
            "ADDI control signals",
            control_valid &&
            register_write &&
            uses_rs1 &&
            !uses_rs2 &&
            alu_source_b_immediate &&
            (immediate_type == IMM_I) &&
            (alu_operation_class == ALU_IMMEDIATE)
        );

        /*
         * Test 5: LW x4,0(x2).
         */
        apply_instruction(32'h00012203, 1'b1, 1'b0);

        check_condition(
            "LW control signals",
            control_valid &&
            register_write &&
            memory_read &&
            !memory_write &&
            uses_rs1 &&
            (immediate_type == IMM_I) &&
            (result_source == RESULT_MEMORY)
        );

        /*
         * Test 6: SW x3,0(x2).
         */
        apply_instruction(32'h00312023, 1'b1, 1'b0);

        check_condition(
            "SW control signals",
            control_valid &&
            !register_write &&
            !memory_read &&
            memory_write &&
            uses_rs1 &&
            uses_rs2 &&
            (immediate_type == IMM_S)
        );

        /*
         * Test 7: BEQ x1,x2,+8.
         */
        apply_instruction(32'h00208463, 1'b1, 1'b0);

        check_condition(
            "BEQ control signals",
            control_valid &&
            branch &&
            uses_rs1 &&
            uses_rs2 &&
            !register_write &&
            (immediate_type == IMM_B) &&
            (alu_operation_class == ALU_BRANCH)
        );

        /*
         * Test 8: LUI x5,0x12345.
         */
        apply_instruction(32'h123452B7, 1'b1, 1'b0);

        check_condition(
            "LUI control signals",
            control_valid &&
            register_write &&
            !uses_rs1 &&
            !uses_rs2 &&
            (immediate_type == IMM_U) &&
            (alu_operation_class == ALU_LUI)
        );

        /*
         * Test 9: AUIPC x6,0x12345.
         */
        apply_instruction(32'h12345317, 1'b1, 1'b0);

        check_condition(
            "AUIPC control signals",
            control_valid &&
            register_write &&
            alu_source_a_pc &&
            alu_source_b_immediate &&
            (immediate_type == IMM_U) &&
            (alu_operation_class == ALU_ADD)
        );

        /*
         * Test 10: JAL x1,+8.
         */
        apply_instruction(32'h008000EF, 1'b1, 1'b0);

        check_condition(
            "JAL control signals",
            control_valid &&
            jump &&
            !jump_register &&
            register_write &&
            (immediate_type == IMM_J) &&
            (result_source == RESULT_PC4)
        );

        /*
         * Test 11: JALR x1,0(x2).
         */
        apply_instruction(32'h000100E7, 1'b1, 1'b0);

        check_condition(
            "JALR control signals",
            control_valid &&
            jump &&
            jump_register &&
            register_write &&
            uses_rs1 &&
            (immediate_type == IMM_I) &&
            (result_source == RESULT_PC4)
        );

        /*
         * Test 12: ECALL.
         */
        apply_instruction(32'h00000073, 1'b1, 1'b0);

        check_condition(
            "ECALL is recognized",
            control_valid &&
            system_instruction &&
            !illegal_instruction &&
            !register_write
        );

        /*
         * Test 13: EBREAK.
         */
        apply_instruction(32'h00100073, 1'b1, 1'b0);

        check_condition(
            "EBREAK is recognized",
            control_valid &&
            system_instruction &&
            !illegal_instruction
        );

        /*
         * Test 14: FENCE.
         */
        apply_instruction(32'h0000000F, 1'b1, 1'b0);

        check_condition(
            "FENCE is recognized",
            control_valid &&
            fence_instruction &&
            !illegal_instruction
        );

        /*
         * Test 15: invalid opcode.
         */
        apply_instruction(32'hFFFFFFFF, 1'b1, 1'b0);

        check_condition(
            "Invalid opcode is rejected",
            !control_valid &&
            illegal_instruction &&
            !register_write &&
            !memory_write
        );

        /*
         * Test 16: invalid load funct3=111.
         */
        apply_instruction(32'h00017083, 1'b1, 1'b0);

        check_condition(
            "Invalid load encoding is rejected",
            !control_valid &&
            illegal_instruction &&
            !register_write &&
            !memory_read
        );

        /*
         * Test 17:
         * Illegal RV32M MUL encoding for an RV32I-only processor.
         */
        apply_instruction(32'h022081B3, 1'b1, 1'b0);

        check_condition(
            "RV32M instruction is rejected",
            !control_valid &&
            illegal_instruction &&
            !register_write
        );

        /*
         * Test 18: instruction-memory fault.
         */
        apply_instruction(32'h00000013, 1'b1, 1'b1);

        check_condition(
            "Instruction fault disables controls",
            !control_valid &&
            instruction_fault_out &&
            !illegal_instruction &&
            !register_write &&
            !memory_write
        );

        $display("");

        if (errors == 0) begin
            $display(
                "ALL %0d CONTROL UNIT CHECKS PASSED",
                checks
            );
        end
        else begin
            $display(
                "CONTROL UNIT TEST FAILED: %0d error(s)",
                errors
            );

            $fatal(1);
        end

        $finish;
    end

endmodule