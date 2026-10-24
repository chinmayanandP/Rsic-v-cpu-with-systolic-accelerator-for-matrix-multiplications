module pipeline_control (
    // ---------------------------------------------------------
    // Global pipeline conditions
    // ---------------------------------------------------------
    input  logic        pipeline_halt,
    input  logic        memory_busy,
    input  logic        redirect_valid,

    // ---------------------------------------------------------
    // Decode-stage information for hazard detection
    // ---------------------------------------------------------
    input  logic        id_valid,
    input  logic        id_uses_rs1,
    input  logic        id_uses_rs2,
    input  logic [4:0]  id_rs1,
    input  logic [4:0]  id_rs2,

    // ---------------------------------------------------------
    // Execute-stage information for hazard detection
    // ---------------------------------------------------------
    input  logic        ex_valid,
    input  logic        ex_fault,
    input  logic        ex_illegal,
    input  logic        ex_memory_read,
    input  logic        ex_register_write,
    input  logic [4:0]  ex_destination_register,

    // ---------------------------------------------------------
    // Execute-stage source operands for forwarding
    // ---------------------------------------------------------
    input  logic        ex_uses_rs1,
    input  logic        ex_uses_rs2,
    input  logic [4:0]  ex_rs1,
    input  logic [4:0]  ex_rs2,
    input  logic [31:0] ex_rs1_value,
    input  logic [31:0] ex_rs2_value,

    // ---------------------------------------------------------
    // EX/MEM forwarding source
    // ---------------------------------------------------------
    input  logic        ex_mem_valid,
    input  logic        ex_mem_register_write,
    input  logic [4:0]  ex_mem_destination_register,
    input  logic [31:0] ex_mem_forward_value,
    input  logic        ex_mem_value_valid,

    // ---------------------------------------------------------
    // MEM/WB forwarding source
    // ---------------------------------------------------------
    input  logic        mem_wb_valid,
    input  logic        mem_wb_register_write,
    input  logic [4:0]  mem_wb_destination_register,
    input  logic [31:0] mem_wb_forward_value,
    input  logic        mem_wb_value_valid,

    // ---------------------------------------------------------
    // Forwarded Execute-stage operands
    // ---------------------------------------------------------
    output logic [31:0] forwarded_rs1_value,
    output logic [31:0] forwarded_rs2_value,

    // 00 = original register value
    // 01 = EX/MEM forwarding
    // 10 = MEM/WB forwarding
    output logic [1:0]  forward_select_rs1,
    output logic [1:0]  forward_select_rs2,

    output logic        forwarding_blocked_rs1,
    output logic        forwarding_blocked_rs2,

    // ---------------------------------------------------------
    // Hazard result
    // ---------------------------------------------------------
    output logic        load_use_hazard_out,

    // ---------------------------------------------------------
    // Pipeline register enables
    // ---------------------------------------------------------
    output logic        pc_enable,
    output logic        if_id_enable,
    output logic        id_ex_enable,
    output logic        ex_mem_enable,
    output logic        mem_wb_enable,

    // ---------------------------------------------------------
    // Pipeline flush controls
    // ---------------------------------------------------------
    output logic        if_id_flush,
    output logic        id_ex_flush,
    output logic        ex_mem_flush,
    output logic        mem_wb_flush,

    // ---------------------------------------------------------
    // Pipeline status
    // ---------------------------------------------------------
    output logic        pipeline_stalled,
    output logic        pipeline_flushed
);

    logic load_use_hazard_internal;

    // =========================================================
    // Load-use hazard detection
    // =========================================================
    hazard_detection_unit hazard_detection_unit_inst (
        .id_valid                (id_valid),
        .id_uses_rs1             (id_uses_rs1),
        .id_uses_rs2             (id_uses_rs2),
        .id_rs1                  (id_rs1),
        .id_rs2                  (id_rs2),

        .ex_valid                (ex_valid),
        .ex_fault                (ex_fault),
        .ex_illegal              (ex_illegal),
        .ex_memory_read          (ex_memory_read),
        .ex_register_write       (ex_register_write),
        .ex_destination_register (ex_destination_register),

        .load_use_hazard         (load_use_hazard_internal)
    );

    assign load_use_hazard_out = load_use_hazard_internal;

    // =========================================================
    // Operand forwarding
    // =========================================================
    forwarding_unit forwarding_unit_inst (
        .ex_uses_rs1                (ex_uses_rs1),
        .ex_uses_rs2                (ex_uses_rs2),
        .ex_rs1                     (ex_rs1),
        .ex_rs2                     (ex_rs2),
        .ex_rs1_value               (ex_rs1_value),
        .ex_rs2_value               (ex_rs2_value),

        .ex_mem_valid               (ex_mem_valid),
        .ex_mem_register_write      (ex_mem_register_write),
        .ex_mem_destination_register(ex_mem_destination_register),
        .ex_mem_forward_value       (ex_mem_forward_value),
        .ex_mem_value_valid         (ex_mem_value_valid),

        .mem_wb_valid               (mem_wb_valid),
        .mem_wb_register_write      (mem_wb_register_write),
        .mem_wb_destination_register(mem_wb_destination_register),
        .mem_wb_forward_value       (mem_wb_forward_value),
        .mem_wb_value_valid         (mem_wb_value_valid),

        .forwarded_rs1_value        (forwarded_rs1_value),
        .forwarded_rs2_value        (forwarded_rs2_value),
        .forward_select_rs1         (forward_select_rs1),
        .forward_select_rs2         (forward_select_rs2),
        .forwarding_blocked_rs1     (forwarding_blocked_rs1),
        .forwarding_blocked_rs2     (forwarding_blocked_rs2)
    );

    // =========================================================
    // Pipeline stall and flush generation
    // =========================================================
    stall_flush_control stall_flush_control_inst (
        .pipeline_halt   (pipeline_halt),
        .memory_busy     (memory_busy),
        .redirect_valid  (redirect_valid),
        .load_use_hazard (load_use_hazard_internal),

        .pc_enable       (pc_enable),
        .if_id_enable    (if_id_enable),
        .id_ex_enable    (id_ex_enable),
        .ex_mem_enable   (ex_mem_enable),
        .mem_wb_enable   (mem_wb_enable),

        .if_id_flush     (if_id_flush),
        .id_ex_flush     (id_ex_flush),
        .ex_mem_flush    (ex_mem_flush),
        .mem_wb_flush    (mem_wb_flush),

        .pipeline_stalled(pipeline_stalled),
        .pipeline_flushed(pipeline_flushed)
    );

endmodule