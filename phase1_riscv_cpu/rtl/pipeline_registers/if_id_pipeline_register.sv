`timescale 1ns/1ps

module if_id_pipeline_register (
    input  logic        clk,
    input  logic        reset,
    input  logic        enable,
    input  logic        flush,

    input  logic [31:0] pc_in,
    input  logic [31:0] pc_plus4_in,
    input  logic [31:0] instruction_in,
    input  logic        valid_in,
    input  logic        fault_in,

    output logic [31:0] pc_out,
    output logic [31:0] pc_plus4_out,
    output logic [31:0] instruction_out,
    output logic        valid_out,
    output logic        fault_out
);

    localparam logic [31:0] NOP = 32'h00000013;

    always_ff @(posedge clk) begin
        if (reset) begin
            pc_out          <= 32'h00000000;
            pc_plus4_out    <= 32'h00000004;
            instruction_out <= NOP;
            valid_out       <= 1'b0;
            fault_out       <= 1'b0;
        end
        else if (flush) begin
            pc_out          <= 32'h00000000;
            pc_plus4_out    <= 32'h00000004;
            instruction_out <= NOP;
            valid_out       <= 1'b0;
            fault_out       <= 1'b0;
        end
        else if (enable) begin
            pc_out          <= pc_in;
            pc_plus4_out    <= pc_plus4_in;
            instruction_out <= instruction_in;
            valid_out       <= valid_in;
            fault_out       <= fault_in;
        end
    end

endmodule