`timescale 1ns/1ps

module alu_control (
    input  logic [2:0] alu_operation_class,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,

    output logic [3:0] alu_control_code,
    output logic       alu_control_valid,
    output logic       illegal_alu_control
);

    /*
     * ALU-operation classes from control_unit.sv.
     */
    localparam logic [2:0] ALU_CLASS_ADD       = 3'b000;
    localparam logic [2:0] ALU_CLASS_BRANCH    = 3'b001;
    localparam logic [2:0] ALU_CLASS_REGISTER  = 3'b010;
    localparam logic [2:0] ALU_CLASS_IMMEDIATE = 3'b011;
    localparam logic [2:0] ALU_CLASS_LUI       = 3'b100;
    localparam logic [2:0] ALU_CLASS_NONE      = 3'b111;

    /*
     * Operation encodings used by alu.sv.
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

    always_comb begin
        alu_control_code   = ALU_ADD;
        alu_control_valid  = 1'b0;
        illegal_alu_control= 1'b0;

        case (alu_operation_class)

            /*
             * Address calculations and AUIPC use addition.
             */
            ALU_CLASS_ADD: begin
                alu_control_code  = ALU_ADD;
                alu_control_valid = 1'b1;
            end

            /*
             * Branch comparison uses subtraction while the ALU's
             * comparison outputs provide signed/unsigned results.
             */
            ALU_CLASS_BRANCH: begin
                alu_control_code  = ALU_SUB;
                alu_control_valid = 1'b1;
            end

            /*
             * R-type register-register instructions.
             */
            ALU_CLASS_REGISTER: begin
                case (funct3)

                    3'b000: begin
                        if (funct7 == 7'b0000000) begin
                            alu_control_code  = ALU_ADD;
                            alu_control_valid = 1'b1;
                        end
                        else if (funct7 == 7'b0100000) begin
                            alu_control_code  = ALU_SUB;
                            alu_control_valid = 1'b1;
                        end
                        else begin
                            illegal_alu_control = 1'b1;
                        end
                    end

                    3'b001: begin
                        if (funct7 == 7'b0000000) begin
                            alu_control_code  = ALU_SLL;
                            alu_control_valid = 1'b1;
                        end
                        else begin
                            illegal_alu_control = 1'b1;
                        end
                    end

                    3'b010: begin
                        if (funct7 == 7'b0000000) begin
                            alu_control_code  = ALU_SLT;
                            alu_control_valid = 1'b1;
                        end
                        else begin
                            illegal_alu_control = 1'b1;
                        end
                    end

                    3'b011: begin
                        if (funct7 == 7'b0000000) begin
                            alu_control_code  = ALU_SLTU;
                            alu_control_valid = 1'b1;
                        end
                        else begin
                            illegal_alu_control = 1'b1;
                        end
                    end

                    3'b100: begin
                        if (funct7 == 7'b0000000) begin
                            alu_control_code  = ALU_XOR;
                            alu_control_valid = 1'b1;
                        end
                        else begin
                            illegal_alu_control = 1'b1;
                        end
                    end

                    3'b101: begin
                        if (funct7 == 7'b0000000) begin
                            alu_control_code  = ALU_SRL;
                            alu_control_valid = 1'b1;
                        end
                        else if (funct7 == 7'b0100000) begin
                            alu_control_code  = ALU_SRA;
                            alu_control_valid = 1'b1;
                        end
                        else begin
                            illegal_alu_control = 1'b1;
                        end
                    end

                    3'b110: begin
                        if (funct7 == 7'b0000000) begin
                            alu_control_code  = ALU_OR;
                            alu_control_valid = 1'b1;
                        end
                        else begin
                            illegal_alu_control = 1'b1;
                        end
                    end

                    3'b111: begin
                        if (funct7 == 7'b0000000) begin
                            alu_control_code  = ALU_AND;
                            alu_control_valid = 1'b1;
                        end
                        else begin
                            illegal_alu_control = 1'b1;
                        end
                    end

                    default: begin
                        illegal_alu_control = 1'b1;
                    end

                endcase
            end

            /*
             * I-type arithmetic instructions.
             */
            ALU_CLASS_IMMEDIATE: begin
                case (funct3)

                    3'b000: begin
                        alu_control_code  = ALU_ADD;
                        alu_control_valid = 1'b1;
                    end

                    3'b010: begin
                        alu_control_code  = ALU_SLT;
                        alu_control_valid = 1'b1;
                    end

                    3'b011: begin
                        alu_control_code  = ALU_SLTU;
                        alu_control_valid = 1'b1;
                    end

                    3'b100: begin
                        alu_control_code  = ALU_XOR;
                        alu_control_valid = 1'b1;
                    end

                    3'b110: begin
                        alu_control_code  = ALU_OR;
                        alu_control_valid = 1'b1;
                    end

                    3'b111: begin
                        alu_control_code  = ALU_AND;
                        alu_control_valid = 1'b1;
                    end

                    3'b001: begin
                        if (funct7 == 7'b0000000) begin
                            alu_control_code  = ALU_SLL;
                            alu_control_valid = 1'b1;
                        end
                        else begin
                            illegal_alu_control = 1'b1;
                        end
                    end

                    3'b101: begin
                        if (funct7 == 7'b0000000) begin
                            alu_control_code  = ALU_SRL;
                            alu_control_valid = 1'b1;
                        end
                        else if (funct7 == 7'b0100000) begin
                            alu_control_code  = ALU_SRA;
                            alu_control_valid = 1'b1;
                        end
                        else begin
                            illegal_alu_control = 1'b1;
                        end
                    end

                    default: begin
                        illegal_alu_control = 1'b1;
                    end

                endcase
            end

            /*
             * LUI copies its immediate operand.
             */
            ALU_CLASS_LUI: begin
                alu_control_code  = ALU_COPY_B;
                alu_control_valid = 1'b1;
            end

            ALU_CLASS_NONE: begin
                alu_control_code    = ALU_ADD;
                alu_control_valid   = 1'b0;
                illegal_alu_control = 1'b0;
            end

            default: begin
                alu_control_code    = ALU_ADD;
                alu_control_valid   = 1'b0;
                illegal_alu_control = 1'b1;
            end

        endcase
    end

endmodule