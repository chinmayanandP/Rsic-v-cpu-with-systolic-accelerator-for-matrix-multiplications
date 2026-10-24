`timescale 1ns/1ps

module instruction_decoder (
    input  logic [31:0] instruction,
    input  logic        instruction_valid,
    input  logic        instruction_fault,

    output logic [6:0]  opcode,
    output logic [4:0]  rd,
    output logic [2:0]  funct3,
    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [6:0]  funct7,

    output logic        decode_valid,
    output logic        decode_fault
);

    /*
     * Standard RV32I instruction-field locations:
     *
     * [6:0]   opcode
     * [11:7]  destination register
     * [14:12] funct3
     * [19:15] source register 1
     * [24:20] source register 2
     * [31:25] funct7
     */

    always_comb begin
        opcode = instruction[6:0];
        rd     = instruction[11:7];
        funct3 = instruction[14:12];
        rs1    = instruction[19:15];
        rs2    = instruction[24:20];
        funct7 = instruction[31:25];

        decode_valid = instruction_valid &&
                       !instruction_fault;

        decode_fault = instruction_valid &&
                       instruction_fault;
    end

endmodule