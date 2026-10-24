`timescale 1ns/1ps

module instruction_execute_stage (
    input  logic        clk,
    input  logic        reset,
    input  logic        enable,
    input  logic        flush,

    // Inputs from ID/EX pipeline register
    input  logic        valid_in,
    input  logic        fault_in,
    input  logic        illegal_in,

    input  logic [31:0] pc_in,
    input  logic [31:0] pc_plus4_in,
    input  logic [31:0] rs1_value_in,
    input  logic [31:0] rs2_value_in,
    input  logic [31:0] immediate_in,

    input  logic [4:0]  rd_in,
    input  logic [2:0]  funct3_in,
    input  logic [6:0]  funct7_in,

    // Execute control signals
    input  logic [2:0]  alu_operation_class_in,
    input  logic        alu_source_a_pc_in,
    input  logic        alu_source_b_immediate_in,

    input  logic        branch_in,
    input  logic        jump_in,
    input  logic        jump_register_in,

    // Controls passed toward MEM and WB
    input  logic        register_write_in,
    input  logic        memory_read_in,
    input  logic        memory_write_in,
    input  logic [1:0]  result_source_in,

    input  logic        system_instruction_in,
    input  logic        fence_instruction_in,

    // Redirect outputs to instruction fetch stage
    output logic        branch_taken_out,
    output logic        redirect_valid_out,
    output logic [31:0] redirect_target_out,
    output logic        target_misaligned_out,

    // EX/MEM pipeline outputs
    output logic        valid_out,
    output logic        fault_out,
    output logic        illegal_out,

    output logic [31:0] pc_plus4_out,
    output logic [31:0] alu_result_out,
    output logic [31:0] store_data_out,

    output logic [4:0]  rd_out,
    output logic [2:0]  funct3_out,

    output logic        register_write_out,
    output logic        memory_read_out,
    output logic        memory_write_out,
    output logic [1:0]  result_source_out,

    output logic        system_instruction_out,
    output logic        fence_instruction_out
);

    localparam logic [2:0] ALU_CLASS_NONE = 3'b111;

    logic [31:0] operand_a;
    logic [31:0] operand_b;

    logic [3:0] alu_control_code;
    logic       alu_control_valid;
    logic       illegal_alu_control;

    logic [31:0] alu_result;
    logic        alu_zero;
    logic        alu_equal;
    logic        alu_less_than_signed;
    logic        alu_less_than_unsigned;
    logic        illegal_alu_operation;

    logic        branch_taken;
    logic        redirect_valid;
    logic [31:0] redirect_target;
    logic        target_misaligned;

    logic        illegal_branch_function;
    logic        illegal_control_combination;

    logic        execute_active;
    logic        execute_fault;
    logic        execute_illegal;

    logic        safe_register_write;
    logic        safe_memory_read;
    logic        safe_memory_write;
    logic        safe_system_instruction;
    logic        safe_fence_instruction;

    /*
     * An instruction may perform execution only when it is valid
     * and has not already received a fault or illegal indication.
     */
    assign execute_active =
        valid_in && !fault_in && !illegal_in;

    /*
     * Operand selection:
     *
     * Operand A = rs1 or PC
     * Operand B = rs2 or immediate
     */
    operand_muxes u_operand_muxes (
        .rs1_value                      (rs1_value_in),
        .rs2_value                      (rs2_value_in),
        .pc_value                       (pc_in),
        .immediate_value                (immediate_in),

        .select_pc_for_operand_a        (alu_source_a_pc_in),
        .select_immediate_for_operand_b (
            alu_source_b_immediate_in
        ),

        .operand_a                      (operand_a),
        .operand_b                      (operand_b)
    );

    /*
     * Convert the ALU operation class, funct3 and funct7 into
     * the exact ALU operation.
     */
    alu_control u_alu_control (
        .alu_operation_class (alu_operation_class_in),
        .funct3              (funct3_in),
        .funct7              (funct7_in),

        .alu_control_code    (alu_control_code),
        .alu_control_valid   (alu_control_valid),
        .illegal_alu_control (illegal_alu_control)
    );

    /*
     * Main arithmetic and logical operation.
     */
    alu u_alu (
        .operand_a           (operand_a),
        .operand_b           (operand_b),
        .alu_control         (alu_control_code),

        .result              (alu_result),
        .zero                (alu_zero),
        .equal               (alu_equal),
        .less_than_signed    (alu_less_than_signed),
        .less_than_unsigned  (alu_less_than_unsigned),

        .illegal_operation   (illegal_alu_operation)
    );

    /*
     * Branch and jump processing.
     */
    branch_jump_logic u_branch_jump_logic (
        .execute_valid               (execute_active),

        .branch                      (branch_in),
        .jump                        (jump_in),
        .jump_register               (jump_register_in),

        .funct3                      (funct3_in),

        .pc                          (pc_in),
        .rs1_value                   (rs1_value_in),
        .rs2_value                   (rs2_value_in),
        .immediate                   (immediate_in),

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
     * Combine all possible illegal-instruction conditions.
     *
     * ALU_CLASS_NONE is legal for instructions that do not need
     * an ALU result, such as JAL, FENCE and SYSTEM instructions.
     */
    always_comb begin
        execute_illegal = illegal_in;

        if (execute_active) begin
            execute_illegal =
                illegal_in                  |
                illegal_alu_control         |
                illegal_branch_function     |
                illegal_control_combination;

            if (alu_control_valid &&
                illegal_alu_operation) begin
                execute_illegal = 1'b1;
            end

            if ((alu_operation_class_in != ALU_CLASS_NONE) &&
                !alu_control_valid) begin
                execute_illegal = 1'b1;
            end
        end
    end

    /*
     * With RV32I and no compressed instructions, an instruction
     * target must be aligned to four bytes.
     */
    assign execute_fault =
        fault_in |
        (execute_active && target_misaligned);

    /*
     * Faulted, illegal or invalid instructions must not modify
     * registers or memory.
     */
    always_comb begin
        safe_register_write     = register_write_in;
        safe_memory_read        = memory_read_in;
        safe_memory_write       = memory_write_in;
        safe_system_instruction = system_instruction_in;
        safe_fence_instruction  = fence_instruction_in;

        if (!valid_in ||
            execute_fault ||
            execute_illegal) begin

            safe_register_write     = 1'b0;
            safe_memory_read        = 1'b0;
            safe_memory_write       = 1'b0;
            safe_system_instruction = 1'b0;
            safe_fence_instruction  = 1'b0;
        end
    end

    assign branch_taken_out      = branch_taken;
    assign redirect_valid_out    = redirect_valid;
    assign redirect_target_out   = redirect_target;
    assign target_misaligned_out = target_misaligned;

    /*
     * Register the execute results for the Memory stage.
     */
    ex_mem_pipeline_register u_ex_mem_pipeline_register (
        .clk                    (clk),
        .reset                  (reset),
        .enable                 (enable),
        .flush                  (flush),

        .valid_in               (valid_in),
        .fault_in               (execute_fault),
        .illegal_in             (execute_illegal),

        .pc_plus4_in            (pc_plus4_in),
        .alu_result_in          (alu_result),

        /*
         * Store data must use rs2 directly.
         * For a store, operand B contains the immediate offset.
         */
        .store_data_in          (rs2_value_in),

        .rd_in                  (rd_in),
        .funct3_in              (funct3_in),

        .register_write_in      (safe_register_write),
        .memory_read_in         (safe_memory_read),
        .memory_write_in        (safe_memory_write),
        .result_source_in       (result_source_in),

        .system_instruction_in  (safe_system_instruction),
        .fence_instruction_in   (safe_fence_instruction),

        .valid_out              (valid_out),
        .fault_out              (fault_out),
        .illegal_out            (illegal_out),

        .pc_plus4_out           (pc_plus4_out),
        .alu_result_out         (alu_result_out),
        .store_data_out         (store_data_out),

        .rd_out                 (rd_out),
        .funct3_out             (funct3_out),

        .register_write_out     (register_write_out),
        .memory_read_out        (memory_read_out),
        .memory_write_out       (memory_write_out),
        .result_source_out      (result_source_out),

        .system_instruction_out (system_instruction_out),
        .fence_instruction_out  (fence_instruction_out)
    );

endmodule