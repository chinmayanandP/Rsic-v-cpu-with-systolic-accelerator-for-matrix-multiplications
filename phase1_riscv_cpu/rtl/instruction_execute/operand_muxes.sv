`timescale 1ns/1ps

module operand_muxes (
    input logic [31:0] rs1_value,
    input logic [31:0] rs2_value,
    input logic [31:0] pc_value,
    input logic [31:0] immediate_value,

    input logic select_pc_for_operand_a,
    input logic select_immediate_for_operand_b,

    output logic [31:0] operand_a,
    output logic [31:0] operand_b
);

    /*
     * Operand A:
     * 0 → rs1 register value
     * 1 → current PC
     */
    always_comb begin
        if (select_pc_for_operand_a)
            operand_a = pc_value;
        else
            operand_a = rs1_value;
    end

    /*
     * Operand B:
     * 0 → rs2 register value
     * 1 → generated immediate
     */
    always_comb begin
        if (select_immediate_for_operand_b)
            operand_b = immediate_value;
        else
            operand_b = rs2_value;
    end

endmodule