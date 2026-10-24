`timescale 1ns/1ps

module write_back_stage (
    // Inputs from MEM/WB pipeline register
    input logic        valid_in,
    input logic        fault_in,
    input logic        illegal_in,

    input logic [31:0] pc_plus4_in,
    input logic [31:0] alu_result_in,
    input logic [31:0] memory_data_in,

    input logic [4:0] rd_in,

    input logic       register_write_in,
    input logic [1:0] result_source_in,

    input logic system_instruction_in,
    input logic fence_instruction_in,

    // Register-file write interface
    output logic        register_file_write_enable_out,
    output logic [4:0]  register_file_write_address_out,
    output logic [31:0] register_file_write_data_out,

    /*
     * These outputs will also be used by the forwarding unit.
     */
    output logic [31:0] write_back_value_out,
    output logic        write_back_value_valid_out,

    // Processor status
    output logic instruction_retired_out,
    output logic exception_valid_out,
    output logic system_event_valid_out,
    output logic fence_completed_out
);

    logic [31:0] selected_write_back_data;
    logic        selected_write_back_data_valid;

    /*
     * Select ALU, memory or PC+4 result.
     */
    write_back_mux u_write_back_mux (
        .alu_result            (alu_result_in),
        .memory_data           (memory_data_in),
        .pc_plus4              (pc_plus4_in),

        .result_source         (result_source_in),

        .write_back_data       (
            selected_write_back_data
        ),
        .write_back_data_valid (
            selected_write_back_data_valid
        )
    );

    /*
     * Decide whether the selected value may update the
     * architectural register file.
     */
    register_write_back_logic u_register_write_back_logic (
        .pipeline_valid              (valid_in),
        .pipeline_fault              (fault_in),
        .pipeline_illegal            (illegal_in),

        .register_write_control      (register_write_in),
        .write_back_data_valid       (
            selected_write_back_data_valid
        ),
        .destination_register        (rd_in),
        .selected_write_back_data    (
            selected_write_back_data
        ),

        .system_instruction          (
            system_instruction_in
        ),
        .fence_instruction           (
            fence_instruction_in
        ),

        .register_file_write_enable  (
            register_file_write_enable_out
        ),
        .register_file_write_address (
            register_file_write_address_out
        ),
        .register_file_write_data    (
            register_file_write_data_out
        ),

        .instruction_retired         (
            instruction_retired_out
        ),
        .exception_valid             (
            exception_valid_out
        ),
        .system_event_valid          (
            system_event_valid_out
        ),
        .fence_completed             (
            fence_completed_out
        )
    );

    /*
     * Forwarding logic later uses the selected result.
     * The valid signal follows the actual register-file write.
     */
    assign write_back_value_out =
        selected_write_back_data;

    assign write_back_value_valid_out =
        register_file_write_enable_out;

endmodule