`timescale 1ns/1ps

module riscv_cpu #(
    parameter integer INSTRUCTION_WORDS = 64,
    parameter logic [31:0] RESET_PC = 32'h00000000,
    parameter logic [31:0] INSTRUCTION_BASE = 32'h00000000,
    parameter INSTRUCTION_INIT_FILE = "cpu_program.hex"
)(
    input logic clk,
    input logic reset,
    input logic external_halt,

    // External data-bus request channel
    output logic        data_bus_request_valid,
    input  logic        data_bus_request_ready,
    output logic        data_bus_write_enable,
    output logic [31:0] data_bus_address,
    output logic [31:0] data_bus_write_data,
    output logic [3:0]  data_bus_byte_enable,

    // External data-bus response channel
    input logic        data_bus_response_valid,
    input logic [31:0] data_bus_read_data,
    input logic        data_bus_access_fault,

    // CPU status outputs
    output logic        halted_out,
    output logic        pipeline_stalled_out,
    output logic        pipeline_flushed_out,
    output logic        instruction_retired_out,
    output logic        exception_valid_out,
    output logic        system_event_valid_out,
    output logic        fence_completed_out,

    output logic        register_write_enable_out,
    output logic [4:0]  register_write_address_out,
    output logic [31:0] register_write_data_out,

    output logic [31:0] fetch_pc_out,
    output logic        memory_busy_out,
    output logic        load_use_hazard_out,
    output logic        redirect_valid_out,
    output logic [31:0] redirect_target_out
);

    localparam logic [1:0] RESULT_ALU    = 2'b00;
    localparam logic [1:0] RESULT_MEMORY = 2'b01;
    localparam logic [1:0] RESULT_PC4    = 2'b10;

    logic pipeline_halt_request;
    logic accepted_redirect;

    logic pc_enable;
    logic if_id_enable;
    logic id_ex_enable;
    logic ex_mem_enable;
    logic mem_wb_enable;

    logic if_id_flush;
    logic id_ex_flush;
    logic ex_mem_flush;
    logic mem_wb_flush;

    logic [31:0] if_id_pc;
    logic [31:0] if_id_pc_plus4;
    logic [31:0] if_id_instruction;
    logic        if_id_valid;
    logic        if_id_fault;

    logic        id_valid_for_hazard;
    logic        id_uses_rs1_for_hazard;
    logic        id_uses_rs2_for_hazard;
    logic [4:0]  id_rs1_for_hazard;
    logic [4:0]  id_rs2_for_hazard;

    logic        ex_valid;
    logic        ex_fault;
    logic        ex_illegal;
    logic [31:0] ex_pc;
    logic [31:0] ex_pc_plus4;
    logic [31:0] ex_immediate;
    logic [31:0] ex_rs1_data;
    logic [31:0] ex_rs2_data;
    logic [4:0]  ex_rs1;
    logic [4:0]  ex_rs2;
    logic [4:0]  ex_rd;
    logic [6:0]  ex_opcode;
    logic [2:0]  ex_funct3;
    logic [6:0]  ex_funct7;
    logic        ex_register_write;
    logic        ex_memory_read;
    logic        ex_memory_write;
    logic        ex_branch;
    logic        ex_jump;
    logic        ex_jump_register;
    logic        ex_alu_source_a_pc;
    logic        ex_alu_source_b_immediate;
    logic        ex_uses_rs1;
    logic        ex_uses_rs2;
    logic [2:0]  ex_alu_operation_class;
    logic [1:0]  ex_result_source;
    logic        ex_system_instruction;
    logic        ex_fence_instruction;

    logic [31:0] forwarded_rs1_value;
    logic [31:0] forwarded_rs2_value;
    logic [1:0]  forward_select_rs1;
    logic [1:0]  forward_select_rs2;
    logic        forwarding_blocked_rs1;
    logic        forwarding_blocked_rs2;

    logic        branch_taken;
    logic        execute_redirect_valid;
    logic [31:0] execute_redirect_target;
    logic        target_misaligned;

    logic        ex_mem_valid;
    logic        ex_mem_fault;
    logic        ex_mem_illegal;
    logic [31:0] ex_mem_pc_plus4;
    logic [31:0] ex_mem_alu_result;
    logic [31:0] ex_mem_store_data;
    logic [4:0]  ex_mem_rd;
    logic [2:0]  ex_mem_funct3;
    logic        ex_mem_register_write;
    logic        ex_mem_memory_read;
    logic        ex_mem_memory_write;
    logic [1:0]  ex_mem_result_source;
    logic        ex_mem_system_instruction;
    logic        ex_mem_fence_instruction;
    logic [31:0] ex_mem_forward_value;
    logic        ex_mem_forward_value_valid;

    logic        mem_wb_valid;
    logic        mem_wb_fault;
    logic        mem_wb_illegal;
    logic [31:0] mem_wb_pc_plus4;
    logic [31:0] mem_wb_alu_result;
    logic [31:0] mem_wb_memory_data;
    logic [4:0]  mem_wb_rd;
    logic        mem_wb_register_write;
    logic [1:0]  mem_wb_result_source;
    logic        mem_wb_system_instruction;
    logic        mem_wb_fence_instruction;

    logic [31:0] write_back_value;
    logic        write_back_value_valid;

    assign pipeline_halt_request =
        external_halt |
        exception_valid_out |
        system_event_valid_out;

    assign halted_out = pipeline_halt_request;

    assign accepted_redirect =
        execute_redirect_valid &&
        !memory_busy_out &&
        !pipeline_halt_request;

    assign redirect_valid_out  = accepted_redirect;
    assign redirect_target_out = execute_redirect_target;

    always_comb begin
        if (ex_mem_result_source == RESULT_PC4)
            ex_mem_forward_value = ex_mem_pc_plus4;
        else
            ex_mem_forward_value = ex_mem_alu_result;
    end

    assign ex_mem_forward_value_valid =
        ex_mem_valid &&
        ex_mem_register_write &&
        !ex_mem_fault &&
        !ex_mem_illegal &&
        !ex_mem_memory_read &&
        (
            (ex_mem_result_source == RESULT_ALU) ||
            (ex_mem_result_source == RESULT_PC4)
        );

    instruction_fetch_stage #(
        .WORDS     (INSTRUCTION_WORDS),
        .RESET_PC  (RESET_PC),
        .BASE_ADDR (INSTRUCTION_BASE),
        .INIT_FILE (INSTRUCTION_INIT_FILE)
    ) u_fetch_stage (
        .clk               (clk),
        .reset             (reset),
        .stall             (!pc_enable),
        .redirect_valid    (accepted_redirect),
        .redirect_pc       (execute_redirect_target),
        .fetch_pc          (fetch_pc_out),
        .if_id_pc          (if_id_pc),
        .if_id_pc_plus4    (if_id_pc_plus4),
        .if_id_instruction (if_id_instruction),
        .if_id_valid       (if_id_valid),
        .if_id_fault       (if_id_fault)
    );

    instruction_decode_stage u_decode_stage (
        .clk                     (clk),
        .reset                   (reset),
        .pipeline_enable         (id_ex_enable),
        .pipeline_flush          (id_ex_flush),
        .if_id_pc                (if_id_pc),
        .if_id_pc_plus4          (if_id_pc_plus4),
        .if_id_instruction       (if_id_instruction),
        .if_id_valid             (if_id_valid),
        .if_id_fault             (if_id_fault),
        .wb_write_enable         (register_write_enable_out),
        .wb_write_address        (register_write_address_out),
        .wb_write_data           (register_write_data_out),
        .id_valid_for_hazard     (id_valid_for_hazard),
        .id_uses_rs1_for_hazard  (id_uses_rs1_for_hazard),
        .id_uses_rs2_for_hazard  (id_uses_rs2_for_hazard),
        .id_rs1_for_hazard       (id_rs1_for_hazard),
        .id_rs2_for_hazard       (id_rs2_for_hazard),
        .ex_valid                (ex_valid),
        .ex_fault                (ex_fault),
        .ex_illegal              (ex_illegal),
        .ex_pc                   (ex_pc),
        .ex_pc_plus4             (ex_pc_plus4),
        .ex_immediate            (ex_immediate),
        .ex_rs1_data             (ex_rs1_data),
        .ex_rs2_data             (ex_rs2_data),
        .ex_rs1                  (ex_rs1),
        .ex_rs2                  (ex_rs2),
        .ex_rd                   (ex_rd),
        .ex_opcode               (ex_opcode),
        .ex_funct3               (ex_funct3),
        .ex_funct7               (ex_funct7),
        .ex_register_write       (ex_register_write),
        .ex_memory_read          (ex_memory_read),
        .ex_memory_write         (ex_memory_write),
        .ex_branch               (ex_branch),
        .ex_jump                 (ex_jump),
        .ex_jump_register        (ex_jump_register),
        .ex_alu_source_a_pc      (ex_alu_source_a_pc),
        .ex_alu_source_b_immediate(
            ex_alu_source_b_immediate
        ),
        .ex_uses_rs1             (ex_uses_rs1),
        .ex_uses_rs2             (ex_uses_rs2),
        .ex_alu_operation_class  (ex_alu_operation_class),
        .ex_result_source        (ex_result_source),
        .ex_system_instruction   (ex_system_instruction),
        .ex_fence_instruction    (ex_fence_instruction)
    );

    instruction_execute_stage u_execute_stage (
        .clk                       (clk),
        .reset                     (reset),
        .enable                    (ex_mem_enable),
        .flush                     (ex_mem_flush),
        .valid_in                  (ex_valid),
        .fault_in                  (ex_fault),
        .illegal_in                (ex_illegal),
        .pc_in                     (ex_pc),
        .pc_plus4_in               (ex_pc_plus4),
        .rs1_value_in              (forwarded_rs1_value),
        .rs2_value_in              (forwarded_rs2_value),
        .immediate_in              (ex_immediate),
        .rd_in                     (ex_rd),
        .funct3_in                 (ex_funct3),
        .funct7_in                 (ex_funct7),
        .alu_operation_class_in    (ex_alu_operation_class),
        .alu_source_a_pc_in        (ex_alu_source_a_pc),
        .alu_source_b_immediate_in (
            ex_alu_source_b_immediate
        ),
        .branch_in                 (ex_branch),
        .jump_in                   (ex_jump),
        .jump_register_in          (ex_jump_register),
        .register_write_in         (ex_register_write),
        .memory_read_in            (ex_memory_read),
        .memory_write_in           (ex_memory_write),
        .result_source_in          (ex_result_source),
        .system_instruction_in     (ex_system_instruction),
        .fence_instruction_in      (ex_fence_instruction),
        .branch_taken_out          (branch_taken),
        .redirect_valid_out        (execute_redirect_valid),
        .redirect_target_out       (execute_redirect_target),
        .target_misaligned_out     (target_misaligned),
        .valid_out                 (ex_mem_valid),
        .fault_out                 (ex_mem_fault),
        .illegal_out               (ex_mem_illegal),
        .pc_plus4_out              (ex_mem_pc_plus4),
        .alu_result_out            (ex_mem_alu_result),
        .store_data_out            (ex_mem_store_data),
        .rd_out                    (ex_mem_rd),
        .funct3_out                (ex_mem_funct3),
        .register_write_out        (ex_mem_register_write),
        .memory_read_out           (ex_mem_memory_read),
        .memory_write_out          (ex_mem_memory_write),
        .result_source_out         (ex_mem_result_source),
        .system_instruction_out    (ex_mem_system_instruction),
        .fence_instruction_out     (ex_mem_fence_instruction)
    );

    memory_stage u_memory_stage (
        .clk                    (clk),
        .reset                  (reset),
        .enable                 (mem_wb_enable),
        .flush                  (mem_wb_flush),

        .valid_in               (ex_mem_valid),
        .fault_in               (ex_mem_fault),
        .illegal_in             (ex_mem_illegal),
        .pc_plus4_in            (ex_mem_pc_plus4),
        .alu_result_in          (ex_mem_alu_result),
        .store_data_in          (ex_mem_store_data),
        .rd_in                  (ex_mem_rd),
        .funct3_in              (ex_mem_funct3),
        .register_write_in      (ex_mem_register_write),
        .memory_read_in         (ex_mem_memory_read),
        .memory_write_in        (ex_mem_memory_write),
        .result_source_in       (ex_mem_result_source),
        .system_instruction_in  (ex_mem_system_instruction),
        .fence_instruction_in   (ex_mem_fence_instruction),

        .memory_busy_out        (memory_busy_out),

        .bus_request_valid      (data_bus_request_valid),
        .bus_request_ready      (data_bus_request_ready),
        .bus_write_enable       (data_bus_write_enable),
        .bus_address            (data_bus_address),
        .bus_write_data         (data_bus_write_data),
        .bus_byte_enable        (data_bus_byte_enable),

        .bus_response_valid     (data_bus_response_valid),
        .bus_read_data          (data_bus_read_data),
        .bus_access_fault       (data_bus_access_fault),

        .valid_out              (mem_wb_valid),
        .fault_out              (mem_wb_fault),
        .illegal_out            (mem_wb_illegal),
        .pc_plus4_out           (mem_wb_pc_plus4),
        .alu_result_out         (mem_wb_alu_result),
        .memory_data_out        (mem_wb_memory_data),
        .rd_out                 (mem_wb_rd),
        .register_write_out     (mem_wb_register_write),
        .result_source_out      (mem_wb_result_source),
        .system_instruction_out (mem_wb_system_instruction),
        .fence_instruction_out  (mem_wb_fence_instruction)
    );

    write_back_stage u_write_back_stage (
        .valid_in                        (mem_wb_valid),
        .fault_in                        (mem_wb_fault),
        .illegal_in                      (mem_wb_illegal),
        .pc_plus4_in                     (mem_wb_pc_plus4),
        .alu_result_in                   (mem_wb_alu_result),
        .memory_data_in                  (mem_wb_memory_data),
        .rd_in                           (mem_wb_rd),
        .register_write_in               (mem_wb_register_write),
        .result_source_in                (mem_wb_result_source),
        .system_instruction_in           (
            mem_wb_system_instruction
        ),
        .fence_instruction_in            (
            mem_wb_fence_instruction
        ),
        .register_file_write_enable_out  (
            register_write_enable_out
        ),
        .register_file_write_address_out (
            register_write_address_out
        ),
        .register_file_write_data_out    (
            register_write_data_out
        ),
        .write_back_value_out            (write_back_value),
        .write_back_value_valid_out      (
            write_back_value_valid
        ),
        .instruction_retired_out         (
            instruction_retired_out
        ),
        .exception_valid_out             (exception_valid_out),
        .system_event_valid_out          (system_event_valid_out),
        .fence_completed_out             (fence_completed_out)
    );

    pipeline_control u_pipeline_control (
        .pipeline_halt                (pipeline_halt_request),
        .memory_busy                  (memory_busy_out),
        .redirect_valid               (execute_redirect_valid),

        .id_valid                     (id_valid_for_hazard),
        .id_uses_rs1                  (id_uses_rs1_for_hazard),
        .id_uses_rs2                  (id_uses_rs2_for_hazard),
        .id_rs1                       (id_rs1_for_hazard),
        .id_rs2                       (id_rs2_for_hazard),

        .ex_valid                     (ex_valid),
        .ex_fault                     (ex_fault),
        .ex_illegal                   (ex_illegal),
        .ex_memory_read               (ex_memory_read),
        .ex_register_write            (ex_register_write),
        .ex_destination_register      (ex_rd),

        .ex_uses_rs1                  (ex_uses_rs1),
        .ex_uses_rs2                  (ex_uses_rs2),
        .ex_rs1                       (ex_rs1),
        .ex_rs2                       (ex_rs2),
        .ex_rs1_value                 (ex_rs1_data),
        .ex_rs2_value                 (ex_rs2_data),

        .ex_mem_valid                 (ex_mem_valid),
        .ex_mem_register_write        (ex_mem_register_write),
        .ex_mem_destination_register  (ex_mem_rd),
        .ex_mem_forward_value         (ex_mem_forward_value),
        .ex_mem_value_valid           (
            ex_mem_forward_value_valid
        ),

        .mem_wb_valid                 (mem_wb_valid),
        .mem_wb_register_write        (mem_wb_register_write),
        .mem_wb_destination_register  (mem_wb_rd),
        .mem_wb_forward_value         (write_back_value),
        .mem_wb_value_valid           (write_back_value_valid),

        .forwarded_rs1_value          (forwarded_rs1_value),
        .forwarded_rs2_value          (forwarded_rs2_value),
        .forward_select_rs1           (forward_select_rs1),
        .forward_select_rs2           (forward_select_rs2),
        .forwarding_blocked_rs1       (forwarding_blocked_rs1),
        .forwarding_blocked_rs2       (forwarding_blocked_rs2),

        .load_use_hazard_out          (load_use_hazard_out),

        .pc_enable                    (pc_enable),
        .if_id_enable                 (if_id_enable),
        .id_ex_enable                 (id_ex_enable),
        .ex_mem_enable                (ex_mem_enable),
        .mem_wb_enable                (mem_wb_enable),

        .if_id_flush                  (if_id_flush),
        .id_ex_flush                  (id_ex_flush),
        .ex_mem_flush                 (ex_mem_flush),
        .mem_wb_flush                 (mem_wb_flush),

        .pipeline_stalled             (pipeline_stalled_out),
        .pipeline_flushed             (pipeline_flushed_out)
    );

endmodule