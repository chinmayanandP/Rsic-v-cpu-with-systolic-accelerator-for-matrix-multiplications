`timescale 1ns/1ps

module register_write_back_logic (
    // MEM/WB pipeline state
    input logic pipeline_valid,
    input logic pipeline_fault,
    input logic pipeline_illegal,

    // Write-back controls and data
    input logic        register_write_control,
    input logic        write_back_data_valid,
    input logic [4:0]  destination_register,
    input logic [31:0] selected_write_back_data,

    // Special-instruction status
    input logic system_instruction,
    input logic fence_instruction,

    // Register-file write interface
    output logic        register_file_write_enable,
    output logic [4:0]  register_file_write_address,
    output logic [31:0] register_file_write_data,

    // Processor status outputs
    output logic instruction_retired,
    output logic exception_valid,
    output logic system_event_valid,
    output logic fence_completed
);

    always_comb begin
        register_file_write_enable  = 1'b0;
        register_file_write_address = destination_register;
        register_file_write_data    = selected_write_back_data;

        instruction_retired = 1'b0;
        exception_valid     = 1'b0;
        system_event_valid  = 1'b0;
        fence_completed     = 1'b0;

        if (pipeline_valid) begin
            /*
             * Faulted or illegal instructions must not update
             * architectural state.
             */
            if (pipeline_fault || pipeline_illegal) begin
                exception_valid = 1'b1;
            end

            /*
             * ECALL/EBREAK are reported as system events.
             * They do not perform normal register write-back.
             */
            else if (system_instruction) begin
                system_event_valid = 1'b1;
            end

            /*
             * All remaining legal instructions retire here.
             */
            else begin
                instruction_retired = 1'b1;

                if (fence_instruction)
                    fence_completed = 1'b1;

                /*
                 * x0 is permanently zero. Suppress writes to x0
                 * even though the register file also protects it.
                 */
                if (register_write_control &&
                    write_back_data_valid &&
                    destination_register != 5'd0) begin

                    register_file_write_enable = 1'b1;
                end
            end
        end
    end

endmodule