`timescale 1ns/1ps

module write_back_mux (
    input logic [31:0] alu_result,
    input logic [31:0] memory_data,
    input logic [31:0] pc_plus4,

    input logic [1:0] result_source,

    output logic [31:0] write_back_data,
    output logic        write_back_data_valid
);

    /*
     * These encodings match control_unit.sv and all pipeline
     * registers already created.
     */
    localparam logic [1:0] RESULT_ALU    = 2'b00;
    localparam logic [1:0] RESULT_MEMORY = 2'b01;
    localparam logic [1:0] RESULT_PC4    = 2'b10;
    localparam logic [1:0] RESULT_NONE   = 2'b11;

    always_comb begin
        write_back_data       = 32'h00000000;
        write_back_data_valid = 1'b0;

        case (result_source)

            /*
             * Arithmetic, logical, LUI and AUIPC instructions.
             */
            RESULT_ALU: begin
                write_back_data       = alu_result;
                write_back_data_valid = 1'b1;
            end

            /*
             * Load instructions.
             */
            RESULT_MEMORY: begin
                write_back_data       = memory_data;
                write_back_data_valid = 1'b1;
            end

            /*
             * JAL and JALR link-address result.
             */
            RESULT_PC4: begin
                write_back_data       = pc_plus4;
                write_back_data_valid = 1'b1;
            end

            /*
             * Stores, branches, FENCE, SYSTEM and pipeline bubbles
             * do not produce register write-back data.
             */
            RESULT_NONE: begin
                write_back_data       = 32'h00000000;
                write_back_data_valid = 1'b0;
            end

            default: begin
                write_back_data       = 32'h00000000;
                write_back_data_valid = 1'b0;
            end

        endcase
    end

endmodule