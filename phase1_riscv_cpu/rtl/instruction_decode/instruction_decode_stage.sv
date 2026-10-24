`timescale 1ns/1ps

module instruction_decode_stage (
    input logic clk,
    input logic reset,

    input logic pipeline_enable,
    input logic pipeline_flush,

    // Inputs from IF/ID
    input logic [31:0] if_id_pc,
    input logic [31:0] if_id_pc_plus4,
    input logic [31:0] if_id_instruction,
    input logic        if_id_valid,
    input logic        if_id_fault,

    // Write-back interface
    input logic        wb_write_enable,
    input logic [4:0]  wb_write_address,
    input logic [31:0] wb_write_data,

    // Current Decode-stage information for hazard detection
    output logic        id_valid_for_hazard,
    output logic        id_uses_rs1_for_hazard,
    output logic        id_uses_rs2_for_hazard,
    output logic [4:0]  id_rs1_for_hazard,
    output logic [4:0]  id_rs2_for_hazard,

    // Outputs to Execute stage
    output logic        ex_valid,
    output logic        ex_fault,
    output logic        ex_illegal,

    output logic [31:0] ex_pc,
    output logic [31:0] ex_pc_plus4,
    output logic [31:0] ex_immediate,
    output logic [31:0] ex_rs1_data,
    output logic [31:0] ex_rs2_data,

    output logic [4:0] ex_rs1,
    output logic [4:0] ex_rs2,
    output logic [4:0] ex_rd,

    output logic [6:0] ex_opcode,
    output logic [2:0] ex_funct3,
    output logic [6:0] ex_funct7,

    output logic ex_register_write,
    output logic ex_memory_read,
    output logic ex_memory_write,

    output logic ex_branch,
    output logic ex_jump,
    output logic ex_jump_register,

    output logic ex_alu_source_a_pc,
    output logic ex_alu_source_b_immediate,

    output logic ex_uses_rs1,
    output logic ex_uses_rs2,

    output logic [2:0] ex_alu_operation_class,
    output logic [1:0] ex_result_source,

    output logic ex_system_instruction,
    output logic ex_fence_instruction
);

    // =========================================================
    // Decoded instruction fields
    // =========================================================

    logic [6:0] opcode;
    logic [4:0] rd;
    logic [2:0] funct3;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [6:0] funct7;

    logic decode_valid;
    logic decode_fault;

    // =========================================================
    // Register-file data
    // =========================================================

    logic [31:0] rs1_data;
    logic [31:0] rs2_data;

    // =========================================================
    // Control-unit signals
    // =========================================================

    logic control_valid;
    logic illegal_instruction;
    logic instruction_fault_control;

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

    // =========================================================
    // Immediate-generator signals
    // =========================================================

    logic [31:0] generated_immediate;
    logic immediate_valid;

    /*
     * These signals describe the instruction currently located in
     * IF/ID. The hazard detector uses them before ID/EX is updated.
     */
    assign id_valid_for_hazard =
        if_id_valid &&
        !if_id_fault &&
        control_valid &&
        !illegal_instruction;

    assign id_uses_rs1_for_hazard = uses_rs1;
    assign id_uses_rs2_for_hazard = uses_rs2;
    assign id_rs1_for_hazard      = rs1;
    assign id_rs2_for_hazard      = rs2;

    // =========================================================
    // Instruction decoder
    // =========================================================

    instruction_decoder decoder_inst (
        .instruction       (if_id_instruction),
        .instruction_valid (if_id_valid),
        .instruction_fault (if_id_fault),

        .opcode            (opcode),
        .rd                (rd),
        .funct3            (funct3),
        .rs1               (rs1),
        .rs2               (rs2),
        .funct7            (funct7),

        .decode_valid       (decode_valid),
        .decode_fault       (decode_fault)
    );

    // =========================================================
    // Register file
    // =========================================================

    register_file register_file_inst (
        .clk            (clk),
        .reset          (reset),

        .read_address_1 (rs1),
        .read_address_2 (rs2),

        .read_data_1    (rs1_data),
        .read_data_2    (rs2_data),

        .write_enable   (wb_write_enable),
        .write_address  (wb_write_address),
        .write_data     (wb_write_data)
    );

    // =========================================================
    // Main control unit
    // =========================================================

    control_unit control_unit_inst (
        .instruction_valid      (if_id_valid),
        .instruction_fault      (if_id_fault),

        .opcode                 (opcode),
        .funct3                 (funct3),
        .funct7                 (funct7),
        .rs1                    (rs1),
        .rd                     (rd),

        .system_immediate       (
            if_id_instruction[31:20]
        ),

        .control_valid          (control_valid),
        .illegal_instruction    (illegal_instruction),
        .instruction_fault_out  (
            instruction_fault_control
        ),

        .register_write         (register_write),
        .memory_read            (memory_read),
        .memory_write           (memory_write),

        .branch                 (branch),
        .jump                   (jump),
        .jump_register          (jump_register),

        .alu_source_a_pc        (alu_source_a_pc),
        .alu_source_b_immediate (
            alu_source_b_immediate
        ),

        .uses_rs1               (uses_rs1),
        .uses_rs2               (uses_rs2),

        .immediate_type         (immediate_type),
        .alu_operation_class    (alu_operation_class),
        .result_source          (result_source),

        .system_instruction     (system_instruction),
        .fence_instruction      (fence_instruction)
    );

    // =========================================================
    // Immediate generator
    // =========================================================

    immediate_generator immediate_generator_inst (
        .instruction     (if_id_instruction),
        .immediate_type  (immediate_type),

        .immediate       (generated_immediate),
        .immediate_valid (immediate_valid)
    );

    // =========================================================
    // ID/EX pipeline register
    // =========================================================

    id_ex_pipeline_register id_ex_register_inst (
        .clk                       (clk),
        .reset                     (reset),
        .enable                    (pipeline_enable),
        .flush                     (pipeline_flush),

        .valid_in                  (if_id_valid),
        .fault_in                  (
            instruction_fault_control
        ),
        .illegal_in                (illegal_instruction),

        .pc_in                     (if_id_pc),
        .pc_plus4_in               (if_id_pc_plus4),
        .immediate_in              (generated_immediate),

        .rs1_data_in               (rs1_data),
        .rs2_data_in               (rs2_data),

        .rs1_in                    (rs1),
        .rs2_in                    (rs2),
        .rd_in                     (rd),

        .opcode_in                 (opcode),
        .funct3_in                 (funct3),
        .funct7_in                 (funct7),

        .register_write_in         (register_write),
        .memory_read_in            (memory_read),
        .memory_write_in           (memory_write),

        .branch_in                 (branch),
        .jump_in                   (jump),
        .jump_register_in          (jump_register),

        .alu_source_a_pc_in        (alu_source_a_pc),
        .alu_source_b_immediate_in (
            alu_source_b_immediate
        ),

        .uses_rs1_in               (uses_rs1),
        .uses_rs2_in               (uses_rs2),

        .alu_operation_class_in    (
            alu_operation_class
        ),
        .result_source_in          (result_source),

        .system_instruction_in     (
            system_instruction
        ),
        .fence_instruction_in      (
            fence_instruction
        ),

        .valid_out                 (ex_valid),
        .fault_out                 (ex_fault),
        .illegal_out               (ex_illegal),

        .pc_out                    (ex_pc),
        .pc_plus4_out              (ex_pc_plus4),
        .immediate_out             (ex_immediate),

        .rs1_data_out              (ex_rs1_data),
        .rs2_data_out              (ex_rs2_data),

        .rs1_out                   (ex_rs1),
        .rs2_out                   (ex_rs2),
        .rd_out                    (ex_rd),

        .opcode_out                (ex_opcode),
        .funct3_out                (ex_funct3),
        .funct7_out                (ex_funct7),

        .register_write_out        (ex_register_write),
        .memory_read_out           (ex_memory_read),
        .memory_write_out          (ex_memory_write),

        .branch_out                (ex_branch),
        .jump_out                  (ex_jump),
        .jump_register_out         (ex_jump_register),

        .alu_source_a_pc_out       (
            ex_alu_source_a_pc
        ),
        .alu_source_b_immediate_out(
            ex_alu_source_b_immediate
        ),

        .uses_rs1_out              (ex_uses_rs1),
        .uses_rs2_out              (ex_uses_rs2),

        .alu_operation_class_out   (
            ex_alu_operation_class
        ),
        .result_source_out         (
            ex_result_source
        ),

        .system_instruction_out    (
            ex_system_instruction
        ),
        .fence_instruction_out     (
            ex_fence_instruction
        )
    );

endmodule