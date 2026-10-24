`timescale 1ns/1ps

module mem_wb_pipeline_register (
    input logic clk,
    input logic reset,
    input logic enable,
    input logic flush,

    // Pipeline state inputs
    input logic valid_in,
    input logic fault_in,
    input logic illegal_in,

    // Data inputs
    input logic [31:0] pc_plus4_in,
    input logic [31:0] alu_result_in,
    input logic [31:0] memory_data_in,

    input logic [4:0] rd_in,

    // Write-back control inputs
    input logic       register_write_in,
    input logic [1:0] result_source_in,

    input logic system_instruction_in,
    input logic fence_instruction_in,

    // Pipeline state outputs
    output logic valid_out,
    output logic fault_out,
    output logic illegal_out,

    // Data outputs
    output logic [31:0] pc_plus4_out,
    output logic [31:0] alu_result_out,
    output logic [31:0] memory_data_out,

    output logic [4:0] rd_out,

    // Write-back control outputs
    output logic       register_write_out,
    output logic [1:0] result_source_out,

    output logic system_instruction_out,
    output logic fence_instruction_out
);

    /*
     * Pipeline-register priority:
     *
     * reset → flush → enable → hold
     */
    always_ff @(posedge clk) begin
        if (reset) begin
            valid_out              <= 1'b0;
            fault_out              <= 1'b0;
            illegal_out            <= 1'b0;

            pc_plus4_out           <= 32'h00000004;
            alu_result_out         <= 32'h00000000;
            memory_data_out        <= 32'h00000000;

            rd_out                 <= 5'd0;

            register_write_out     <= 1'b0;
            result_source_out      <= 2'b11;

            system_instruction_out <= 1'b0;
            fence_instruction_out  <= 1'b0;
        end

        else if (flush) begin
            valid_out              <= 1'b0;
            fault_out              <= 1'b0;
            illegal_out            <= 1'b0;

            pc_plus4_out           <= 32'h00000004;
            alu_result_out         <= 32'h00000000;
            memory_data_out        <= 32'h00000000;

            rd_out                 <= 5'd0;

            register_write_out     <= 1'b0;
            result_source_out      <= 2'b11;

            system_instruction_out <= 1'b0;
            fence_instruction_out  <= 1'b0;
        end

        else if (enable) begin
            valid_out              <= valid_in;
            fault_out              <= fault_in;
            illegal_out            <= illegal_in;

            pc_plus4_out           <= pc_plus4_in;
            alu_result_out         <= alu_result_in;
            memory_data_out        <= memory_data_in;

            rd_out                 <= rd_in;

            register_write_out     <= register_write_in;
            result_source_out      <= result_source_in;

            system_instruction_out <= system_instruction_in;
            fence_instruction_out  <= fence_instruction_in;
        end
    end

endmodule