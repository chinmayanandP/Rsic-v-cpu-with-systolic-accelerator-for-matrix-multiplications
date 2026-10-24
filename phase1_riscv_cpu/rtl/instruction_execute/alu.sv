`timescale 1ns/1ps

module alu (
    input  logic [31:0] operand_a,
    input  logic [31:0] operand_b,
    input  logic [3:0]  alu_control,

    output logic [31:0] result,

    output logic zero,
    output logic equal,
    output logic less_than_signed,
    output logic less_than_unsigned,

    output logic illegal_operation
);

    /*
     * Frozen ALU operation encodings.
     *
     * The future ALU Control module must generate these values.
     */
    localparam logic [3:0] ALU_ADD    = 4'b0000;
    localparam logic [3:0] ALU_SUB    = 4'b0001;
    localparam logic [3:0] ALU_SLL    = 4'b0010;
    localparam logic [3:0] ALU_SLT    = 4'b0011;
    localparam logic [3:0] ALU_SLTU   = 4'b0100;
    localparam logic [3:0] ALU_XOR    = 4'b0101;
    localparam logic [3:0] ALU_SRL    = 4'b0110;
    localparam logic [3:0] ALU_SRA    = 4'b0111;
    localparam logic [3:0] ALU_OR     = 4'b1000;
    localparam logic [3:0] ALU_AND    = 4'b1001;
    localparam logic [3:0] ALU_COPY_B = 4'b1010;

    /*
     * Comparison outputs are continuously available.
     */
    always_comb begin
        equal = (operand_a == operand_b);

        less_than_signed =
            ($signed(operand_a) < $signed(operand_b));

        less_than_unsigned =
            (operand_a < operand_b);
    end

    /*
     * Main ALU operation.
     */
    always_comb begin
        result            = 32'h00000000;
        illegal_operation = 1'b0;

        case (alu_control)

            ALU_ADD: begin
                result = operand_a + operand_b;
            end

            ALU_SUB: begin
                result = operand_a - operand_b;
            end

            ALU_SLL: begin
                /*
                 * RV32I uses only the lower five bits of the
                 * shift amount.
                 */
                result = operand_a << operand_b[4:0];
            end

            ALU_SLT: begin
                result = {
                    31'b0,
                    ($signed(operand_a) < $signed(operand_b))
                };
            end

            ALU_SLTU: begin
                result = {
                    31'b0,
                    (operand_a < operand_b)
                };
            end

            ALU_XOR: begin
                result = operand_a ^ operand_b;
            end

            ALU_SRL: begin
                result = operand_a >> operand_b[4:0];
            end

            ALU_SRA: begin
                result =
                    $signed(operand_a) >>> operand_b[4:0];
            end

            ALU_OR: begin
                result = operand_a | operand_b;
            end

            ALU_AND: begin
                result = operand_a & operand_b;
            end

            ALU_COPY_B: begin
                /*
                 * Used by LUI.
                 */
                result = operand_b;
            end

            default: begin
                result            = 32'h00000000;
                illegal_operation = 1'b1;
            end

        endcase
    end

    assign zero = (result == 32'h00000000);

endmodule