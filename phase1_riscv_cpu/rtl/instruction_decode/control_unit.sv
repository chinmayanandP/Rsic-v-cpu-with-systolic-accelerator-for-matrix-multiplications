`timescale 1ns/1ps

module control_unit (
    input  logic        instruction_valid,
    input  logic        instruction_fault,

    input  logic [6:0]  opcode,
    input  logic [2:0]  funct3,
    input  logic [6:0]  funct7,
    input  logic [4:0]  rs1,
    input  logic [4:0]  rd,
    input  logic [11:0] system_immediate,

    output logic        control_valid,
    output logic        illegal_instruction,
    output logic        instruction_fault_out,

    output logic        register_write,
    output logic        memory_read,
    output logic        memory_write,

    output logic        branch,
    output logic        jump,
    output logic        jump_register,

    output logic        alu_source_a_pc,
    output logic        alu_source_b_immediate,

    output logic        uses_rs1,
    output logic        uses_rs2,

    output logic [2:0]  immediate_type,
    output logic [2:0]  alu_operation_class,
    output logic [1:0]  result_source,

    output logic        system_instruction,
    output logic        fence_instruction
);

    /*
     * Immediate-type encodings.
     * These match immediate_generator.sv.
     */
    localparam logic [2:0] IMM_I    = 3'b000;
    localparam logic [2:0] IMM_S    = 3'b001;
    localparam logic [2:0] IMM_B    = 3'b010;
    localparam logic [2:0] IMM_U    = 3'b011;
    localparam logic [2:0] IMM_J    = 3'b100;
    localparam logic [2:0] IMM_NONE = 3'b111;

    /*
     * ALU-operation classes.
     *
     * The future ALU Control module will combine this class
     * with funct3 and funct7 to select the exact ALU function.
     */
    localparam logic [2:0] ALU_CLASS_ADD      = 3'b000;
    localparam logic [2:0] ALU_CLASS_BRANCH   = 3'b001;
    localparam logic [2:0] ALU_CLASS_REGISTER = 3'b010;
    localparam logic [2:0] ALU_CLASS_IMMEDIATE= 3'b011;
    localparam logic [2:0] ALU_CLASS_LUI      = 3'b100;
    localparam logic [2:0] ALU_CLASS_NONE     = 3'b111;

    /*
     * Write-back result sources.
     */
    localparam logic [1:0] RESULT_ALU    = 2'b00;
    localparam logic [1:0] RESULT_MEMORY = 2'b01;
    localparam logic [1:0] RESULT_PC4    = 2'b10;
    localparam logic [1:0] RESULT_NONE   = 2'b11;

    /*
     * RV32I opcodes.
     */
    localparam logic [6:0] OPCODE_LOAD   = 7'b0000011;
    localparam logic [6:0] OPCODE_FENCE  = 7'b0001111;
    localparam logic [6:0] OPCODE_OP_IMM = 7'b0010011;
    localparam logic [6:0] OPCODE_AUIPC  = 7'b0010111;
    localparam logic [6:0] OPCODE_STORE  = 7'b0100011;
    localparam logic [6:0] OPCODE_OP     = 7'b0110011;
    localparam logic [6:0] OPCODE_LUI    = 7'b0110111;
    localparam logic [6:0] OPCODE_BRANCH = 7'b1100011;
    localparam logic [6:0] OPCODE_JALR   = 7'b1100111;
    localparam logic [6:0] OPCODE_JAL    = 7'b1101111;
    localparam logic [6:0] OPCODE_SYSTEM = 7'b1110011;

    always_comb begin
        control_valid        = 1'b0;
        illegal_instruction  = 1'b0;
        instruction_fault_out= instruction_valid &&
                               instruction_fault;

        register_write       = 1'b0;
        memory_read          = 1'b0;
        memory_write         = 1'b0;

        branch               = 1'b0;
        jump                 = 1'b0;
        jump_register        = 1'b0;

        alu_source_a_pc      = 1'b0;
        alu_source_b_immediate = 1'b0;

        uses_rs1             = 1'b0;
        uses_rs2             = 1'b0;

        immediate_type       = IMM_NONE;
        alu_operation_class  = ALU_CLASS_NONE;
        result_source        = RESULT_NONE;

        system_instruction   = 1'b0;
        fence_instruction    = 1'b0;

        if (instruction_valid && !instruction_fault) begin
            /*
             * Assume illegal until a legal instruction encoding
             * is recognized.
             */
            illegal_instruction = 1'b1;

            case (opcode)

                /*
                 * Register-register arithmetic:
                 * ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND.
                 */
                OPCODE_OP: begin
                    uses_rs1            = 1'b1;
                    uses_rs2            = 1'b1;
                    register_write      = 1'b1;
                    alu_operation_class = ALU_CLASS_REGISTER;
                    result_source       = RESULT_ALU;

                    case (funct3)
                        3'b000: begin
                            if ((funct7 == 7'b0000000) ||
                                (funct7 == 7'b0100000))
                                illegal_instruction = 1'b0;
                        end

                        3'b101: begin
                            if ((funct7 == 7'b0000000) ||
                                (funct7 == 7'b0100000))
                                illegal_instruction = 1'b0;
                        end

                        3'b001,
                        3'b010,
                        3'b011,
                        3'b100,
                        3'b110,
                        3'b111: begin
                            if (funct7 == 7'b0000000)
                                illegal_instruction = 1'b0;
                        end

                        default:
                            illegal_instruction = 1'b1;
                    endcase
                end

                /*
                 * Immediate arithmetic:
                 * ADDI, SLTI, SLTIU, XORI, ORI, ANDI,
                 * SLLI, SRLI and SRAI.
                 */
                OPCODE_OP_IMM: begin
                    uses_rs1              = 1'b1;
                    register_write        = 1'b1;
                    alu_source_b_immediate= 1'b1;
                    immediate_type        = IMM_I;
                    alu_operation_class   = ALU_CLASS_IMMEDIATE;
                    result_source         = RESULT_ALU;

                    case (funct3)
                        3'b001: begin
                            if (funct7 == 7'b0000000)
                                illegal_instruction = 1'b0;
                        end

                        3'b101: begin
                            if ((funct7 == 7'b0000000) ||
                                (funct7 == 7'b0100000))
                                illegal_instruction = 1'b0;
                        end

                        3'b000,
                        3'b010,
                        3'b011,
                        3'b100,
                        3'b110,
                        3'b111:
                            illegal_instruction = 1'b0;

                        default:
                            illegal_instruction = 1'b1;
                    endcase
                end

                /*
                 * Loads:
                 * LB, LH, LW, LBU and LHU.
                 */
                OPCODE_LOAD: begin
                    uses_rs1              = 1'b1;
                    register_write        = 1'b1;
                    memory_read           = 1'b1;
                    alu_source_b_immediate= 1'b1;
                    immediate_type        = IMM_I;
                    alu_operation_class   = ALU_CLASS_ADD;
                    result_source         = RESULT_MEMORY;

                    case (funct3)
                        3'b000,
                        3'b001,
                        3'b010,
                        3'b100,
                        3'b101:
                            illegal_instruction = 1'b0;

                        default:
                            illegal_instruction = 1'b1;
                    endcase
                end

                /*
                 * Stores:
                 * SB, SH and SW.
                 */
                OPCODE_STORE: begin
                    uses_rs1              = 1'b1;
                    uses_rs2              = 1'b1;
                    memory_write          = 1'b1;
                    alu_source_b_immediate= 1'b1;
                    immediate_type        = IMM_S;
                    alu_operation_class   = ALU_CLASS_ADD;
                    result_source         = RESULT_NONE;

                    case (funct3)
                        3'b000,
                        3'b001,
                        3'b010:
                            illegal_instruction = 1'b0;

                        default:
                            illegal_instruction = 1'b1;
                    endcase
                end

                /*
                 * Conditional branches:
                 * BEQ, BNE, BLT, BGE, BLTU and BGEU.
                 */
                OPCODE_BRANCH: begin
                    uses_rs1            = 1'b1;
                    uses_rs2            = 1'b1;
                    branch              = 1'b1;
                    immediate_type      = IMM_B;
                    alu_operation_class = ALU_CLASS_BRANCH;

                    case (funct3)
                        3'b000,
                        3'b001,
                        3'b100,
                        3'b101,
                        3'b110,
                        3'b111:
                            illegal_instruction = 1'b0;

                        default:
                            illegal_instruction = 1'b1;
                    endcase
                end

                /*
                 * LUI: write the upper immediate to rd.
                 */
                OPCODE_LUI: begin
                    register_write         = 1'b1;
                    alu_source_b_immediate = 1'b1;
                    immediate_type         = IMM_U;
                    alu_operation_class    = ALU_CLASS_LUI;
                    result_source          = RESULT_ALU;
                    illegal_instruction    = 1'b0;
                end

                /*
                 * AUIPC: rd = PC + upper immediate.
                 */
                OPCODE_AUIPC: begin
                    register_write         = 1'b1;
                    alu_source_a_pc        = 1'b1;
                    alu_source_b_immediate = 1'b1;
                    immediate_type         = IMM_U;
                    alu_operation_class    = ALU_CLASS_ADD;
                    result_source          = RESULT_ALU;
                    illegal_instruction    = 1'b0;
                end

                /*
                 * JAL: rd = PC+4 and target = PC+immediate.
                 */
                OPCODE_JAL: begin
                    register_write       = 1'b1;
                    jump                 = 1'b1;
                    immediate_type       = IMM_J;
                    result_source        = RESULT_PC4;
                    illegal_instruction  = 1'b0;
                end

                /*
                 * JALR: rd = PC+4 and target = rs1+immediate.
                 */
                OPCODE_JALR: begin
                    uses_rs1              = 1'b1;
                    register_write        = 1'b1;
                    jump                  = 1'b1;
                    jump_register         = 1'b1;
                    alu_source_b_immediate= 1'b1;
                    immediate_type        = IMM_I;
                    alu_operation_class   = ALU_CLASS_ADD;
                    result_source         = RESULT_PC4;

                    if (funct3 == 3'b000)
                        illegal_instruction = 1'b0;
                end

                /*
                 * FENCE is treated as a legal ordering instruction.
                 * It currently has no register or memory side effect.
                 */
                OPCODE_FENCE: begin
                    fence_instruction = 1'b1;

                    if ((funct3 == 3'b000) &&
                        (rs1 == 5'd0) &&
                        (rd  == 5'd0))
                        illegal_instruction = 1'b0;
                end

                /*
                 * Base RV32I ECALL and EBREAK.
                 */
                OPCODE_SYSTEM: begin
                    system_instruction = 1'b1;

                    if ((funct3 == 3'b000) &&
                        (rs1 == 5'd0) &&
                        (rd  == 5'd0) &&
                        ((system_immediate == 12'h000) ||
                         (system_immediate == 12'h001)))
                        illegal_instruction = 1'b0;
                end

                default: begin
                    illegal_instruction = 1'b1;
                end

            endcase

            /*
             * Illegal instructions must never modify architectural
             * state.
             */
            if (illegal_instruction) begin
                register_write         = 1'b0;
                memory_read            = 1'b0;
                memory_write           = 1'b0;
                branch                 = 1'b0;
                jump                   = 1'b0;
                jump_register          = 1'b0;
                system_instruction     = 1'b0;
                fence_instruction      = 1'b0;
                control_valid          = 1'b0;
            end
            else begin
                control_valid = 1'b1;
            end
        end
    end

endmodule