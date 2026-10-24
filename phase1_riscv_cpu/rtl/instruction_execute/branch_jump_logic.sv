`timescale 1ns/1ps

module branch_jump_logic (
    input logic        execute_valid,

    input logic        branch,
    input logic        jump,
    input logic        jump_register,

    input logic [2:0]  funct3,

    input logic [31:0] pc,
    input logic [31:0] rs1_value,
    input logic [31:0] rs2_value,
    input logic [31:0] immediate,

    output logic        branch_taken,
    output logic        redirect_valid,
    output logic [31:0] redirect_target,

    output logic        target_misaligned,
    output logic        illegal_branch_function,
    output logic        illegal_control_combination
);

    logic branch_condition;
    logic branch_function_valid;

    logic control_combination_valid;

    logic [31:0] branch_target;
    logic [31:0] jal_target;
    logic [31:0] jalr_target;

    always_comb begin
        branch_condition      = 1'b0;
        branch_function_valid = 1'b1;

        case (funct3)

            // BEQ
            3'b000:
                branch_condition = (rs1_value == rs2_value);

            // BNE
            3'b001:
                branch_condition = (rs1_value != rs2_value);

            // BLT
            3'b100:
                branch_condition =
                    ($signed(rs1_value) < $signed(rs2_value));

            // BGE
            3'b101:
                branch_condition =
                    ($signed(rs1_value) >= $signed(rs2_value));

            // BLTU
            3'b110:
                branch_condition = (rs1_value < rs2_value);

            // BGEU
            3'b111:
                branch_condition = (rs1_value >= rs2_value);

            default: begin
                branch_condition      = 1'b0;
                branch_function_valid = 1'b0;
            end

        endcase
    end

    assign branch_target = pc + immediate;
    assign jal_target    = pc + immediate;

    /*
     * RV32I JALR clears bit zero of the calculated target.
     */
    assign jalr_target =
        (rs1_value + immediate) & 32'hFFFFFFFE;

    /*
     * Only one of branch, JAL, or JALR may be active.
     */
    always_comb begin
        case ({branch, jump, jump_register})
            3'b000,
            3'b100,
            3'b010,
            3'b011:
                control_combination_valid = 1'b1;

            default:
                control_combination_valid = 1'b0;
        endcase
    end

    always_comb begin
        branch_taken               = 1'b0;
        redirect_valid             = 1'b0;
        redirect_target            = 32'h00000000;
        target_misaligned          = 1'b0;
        illegal_branch_function    = 1'b0;
        illegal_control_combination= 1'b0;

        if (execute_valid) begin
            if (!control_combination_valid) begin
                illegal_control_combination = 1'b1;
            end
            else if (jump_register) begin
                redirect_target   = jalr_target;
                target_misaligned = (jalr_target[1:0] != 2'b00);

                if (!target_misaligned)
                    redirect_valid = 1'b1;
            end
            else if (jump) begin
                redirect_target   = jal_target;
                target_misaligned = (jal_target[1:0] != 2'b00);

                if (!target_misaligned)
                    redirect_valid = 1'b1;
            end
            else if (branch) begin
                if (!branch_function_valid) begin
                    illegal_branch_function = 1'b1;
                end
                else begin
                    branch_taken = branch_condition;

                    if (branch_condition) begin
                        redirect_target   = branch_target;
                        target_misaligned =
                            (branch_target[1:0] != 2'b00);

                        if (!target_misaligned)
                            redirect_valid = 1'b1;
                    end
                end
            end
        end
    end

endmodule