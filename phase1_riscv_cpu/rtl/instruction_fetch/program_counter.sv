`timescale 1ns/1ps

module program_counter #(
    parameter logic [31:0] RESET_PC = 32'h00000000
)(
    input  logic clk,
    input  logic reset,
    input  logic pc_enable,
    input  logic [31:0] next_pc,

    output logic [31:0] pc
);

    always_ff @(posedge clk) begin
        if (reset)
            pc <= RESET_PC;
        else if (pc_enable)
            pc <= next_pc;
        // Otherwise, retain the current PC.
    end

endmodule