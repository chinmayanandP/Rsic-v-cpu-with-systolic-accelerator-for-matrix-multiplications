`timescale 1ns/1ps

module id_ex_pipeline_register (
    input logic clk,
    input logic reset,
    input logic enable,
    input logic flush,

    // Pipeline status
    input logic valid_in,
    input logic fault_in,
    input logic illegal_in,

    // Instruction information
    input logic [31:0] pc_in,
    input logic [31:0] pc_plus4_in,
    input logic [31:0] immediate_in,
    input logic [31:0] rs1_data_in,
    input logic [31:0] rs2_data_in,

    input logic [4:0] rs1_in,
    input logic [4:0] rs2_in,
    input logic [4:0] rd_in,

    input logic [6:0] opcode_in,
    input logic [2:0] funct3_in,
    input logic [6:0] funct7_in,

    // Control signals
    input logic register_write_in,
    input logic memory_read_in,
    input logic memory_write_in,

    input logic branch_in,
    input logic jump_in,
    input logic jump_register_in,

    input logic alu_source_a_pc_in,
    input logic alu_source_b_immediate_in,

    input logic uses_rs1_in,
    input logic uses_rs2_in,

    input logic [2:0] alu_operation_class_in,
    input logic [1:0] result_source_in,

    input logic system_instruction_in,
    input logic fence_instruction_in,

    // Pipeline status outputs
    output logic valid_out,
    output logic fault_out,
    output logic illegal_out,

    // Instruction information outputs
    output logic [31:0] pc_out,
    output logic [31:0] pc_plus4_out,
    output logic [31:0] immediate_out,
    output logic [31:0] rs1_data_out,
    output logic [31:0] rs2_data_out,

    output logic [4:0] rs1_out,
    output logic [4:0] rs2_out,
    output logic [4:0] rd_out,

    output logic [6:0] opcode_out,
    output logic [2:0] funct3_out,
    output logic [6:0] funct7_out,

    // Control outputs
    output logic register_write_out,
    output logic memory_read_out,
    output logic memory_write_out,

    output logic branch_out,
    output logic jump_out,
    output logic jump_register_out,

    output logic alu_source_a_pc_out,
    output logic alu_source_b_immediate_out,

    output logic uses_rs1_out,
    output logic uses_rs2_out,

    output logic [2:0] alu_operation_class_out,
    output logic [1:0] result_source_out,

    output logic system_instruction_out,
    output logic fence_instruction_out
);

    /*
     * Priority:
     *
     * reset → flush → enable → hold
     */
    always_ff @(posedge clk) begin
        if (reset) begin
            valid_out                  <= 1'b0;
            fault_out                  <= 1'b0;
            illegal_out                <= 1'b0;

            pc_out                     <= 32'h00000000;
            pc_plus4_out               <= 32'h00000004;
            immediate_out              <= 32'h00000000;
            rs1_data_out               <= 32'h00000000;
            rs2_data_out               <= 32'h00000000;

            rs1_out                    <= 5'd0;
            rs2_out                    <= 5'd0;
            rd_out                     <= 5'd0;

            opcode_out                 <= 7'd0;
            funct3_out                 <= 3'd0;
            funct7_out                 <= 7'd0;

            register_write_out         <= 1'b0;
            memory_read_out            <= 1'b0;
            memory_write_out           <= 1'b0;

            branch_out                 <= 1'b0;
            jump_out                   <= 1'b0;
            jump_register_out          <= 1'b0;

            alu_source_a_pc_out        <= 1'b0;
            alu_source_b_immediate_out <= 1'b0;

            uses_rs1_out               <= 1'b0;
            uses_rs2_out               <= 1'b0;

            alu_operation_class_out    <= 3'b111;
            result_source_out          <= 2'b11;

            system_instruction_out     <= 1'b0;
            fence_instruction_out      <= 1'b0;
        end
        else if (flush) begin
            /*
             * Insert a pipeline bubble.
             */
            valid_out                  <= 1'b0;
            fault_out                  <= 1'b0;
            illegal_out                <= 1'b0;

            pc_out                     <= 32'h00000000;
            pc_plus4_out               <= 32'h00000004;
            immediate_out              <= 32'h00000000;
            rs1_data_out               <= 32'h00000000;
            rs2_data_out               <= 32'h00000000;

            rs1_out                    <= 5'd0;
            rs2_out                    <= 5'd0;
            rd_out                     <= 5'd0;

            opcode_out                 <= 7'd0;
            funct3_out                 <= 3'd0;
            funct7_out                 <= 7'd0;

            register_write_out         <= 1'b0;
            memory_read_out            <= 1'b0;
            memory_write_out           <= 1'b0;

            branch_out                 <= 1'b0;
            jump_out                   <= 1'b0;
            jump_register_out          <= 1'b0;

            alu_source_a_pc_out        <= 1'b0;
            alu_source_b_immediate_out <= 1'b0;

            uses_rs1_out               <= 1'b0;
            uses_rs2_out               <= 1'b0;

            alu_operation_class_out    <= 3'b111;
            result_source_out          <= 2'b11;

            system_instruction_out     <= 1'b0;
            fence_instruction_out      <= 1'b0;
        end
        else if (enable) begin
            valid_out                  <= valid_in;
            fault_out                  <= fault_in;
            illegal_out                <= illegal_in;

            pc_out                     <= pc_in;
            pc_plus4_out               <= pc_plus4_in;
            immediate_out              <= immediate_in;
            rs1_data_out               <= rs1_data_in;
            rs2_data_out               <= rs2_data_in;

            rs1_out                    <= rs1_in;
            rs2_out                    <= rs2_in;
            rd_out                     <= rd_in;

            opcode_out                 <= opcode_in;
            funct3_out                 <= funct3_in;
            funct7_out                 <= funct7_in;

            register_write_out         <= register_write_in;
            memory_read_out            <= memory_read_in;
            memory_write_out           <= memory_write_in;

            branch_out                 <= branch_in;
            jump_out                   <= jump_in;
            jump_register_out          <= jump_register_in;

            alu_source_a_pc_out        <= alu_source_a_pc_in;
            alu_source_b_immediate_out <=
                alu_source_b_immediate_in;

            uses_rs1_out               <= uses_rs1_in;
            uses_rs2_out               <= uses_rs2_in;

            alu_operation_class_out    <=
                alu_operation_class_in;

            result_source_out          <= result_source_in;

            system_instruction_out     <= system_instruction_in;
            fence_instruction_out      <= fence_instruction_in;
        end
    end

endmodule