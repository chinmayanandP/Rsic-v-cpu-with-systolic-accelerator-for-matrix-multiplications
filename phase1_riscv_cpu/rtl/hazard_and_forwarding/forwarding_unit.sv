`timescale 1ns/1ps

module forwarding_unit (
    /*
     * Source registers and values belonging to the instruction
     * currently in the Execute stage.
     */
    input logic       ex_uses_rs1,
    input logic       ex_uses_rs2,

    input logic [4:0] ex_rs1,
    input logic [4:0] ex_rs2,

    input logic [31:0] ex_rs1_value,
    input logic [31:0] ex_rs2_value,

    /*
     * Possible forwarding source from EX/MEM.
     *
     * ex_mem_value_valid must be zero for a load because its data
     * has not returned from memory yet.
     */
    input logic        ex_mem_valid,
    input logic        ex_mem_register_write,
    input logic [4:0]  ex_mem_destination_register,
    input logic [31:0] ex_mem_forward_value,
    input logic        ex_mem_value_valid,

    /*
     * Possible forwarding source from MEM/WB.
     */
    input logic        mem_wb_valid,
    input logic        mem_wb_register_write,
    input logic [4:0]  mem_wb_destination_register,
    input logic [31:0] mem_wb_forward_value,
    input logic        mem_wb_value_valid,

    /*
     * Final operand values supplied to the Execute stage.
     */
    output logic [31:0] forwarded_rs1_value,
    output logic [31:0] forwarded_rs2_value,

    /*
     * Selection encodings:
     *
     * 00 = original register-file value
     * 01 = EX/MEM forwarding
     * 10 = MEM/WB forwarding
     */
    output logic [1:0] forward_select_rs1,
    output logic [1:0] forward_select_rs2,

    /*
     * Asserted if EX/MEM contains a newer matching destination,
     * but its value is not available yet.
     */
    output logic forwarding_blocked_rs1,
    output logic forwarding_blocked_rs2
);

    localparam logic [1:0] FORWARD_ORIGINAL = 2'b00;
    localparam logic [1:0] FORWARD_EX_MEM   = 2'b01;
    localparam logic [1:0] FORWARD_MEM_WB   = 2'b10;

    logic ex_mem_matches_rs1;
    logic ex_mem_matches_rs2;

    logic mem_wb_matches_rs1;
    logic mem_wb_matches_rs2;

    /*
     * Dependency comparisons.
     */
    always_comb begin
        ex_mem_matches_rs1 =
            ex_uses_rs1 &&
            ex_rs1 != 5'd0 &&
            ex_mem_valid &&
            ex_mem_register_write &&
            ex_mem_destination_register != 5'd0 &&
            ex_mem_destination_register == ex_rs1;

        ex_mem_matches_rs2 =
            ex_uses_rs2 &&
            ex_rs2 != 5'd0 &&
            ex_mem_valid &&
            ex_mem_register_write &&
            ex_mem_destination_register != 5'd0 &&
            ex_mem_destination_register == ex_rs2;

        mem_wb_matches_rs1 =
            ex_uses_rs1 &&
            ex_rs1 != 5'd0 &&
            mem_wb_valid &&
            mem_wb_register_write &&
            mem_wb_destination_register != 5'd0 &&
            mem_wb_destination_register == ex_rs1;

        mem_wb_matches_rs2 =
            ex_uses_rs2 &&
            ex_rs2 != 5'd0 &&
            mem_wb_valid &&
            mem_wb_register_write &&
            mem_wb_destination_register != 5'd0 &&
            mem_wb_destination_register == ex_rs2;
    end

    /*
     * Forward rs1.
     *
     * EX/MEM has priority because it contains the newer result.
     */
    always_comb begin
        forwarded_rs1_value  = ex_rs1_value;
        forward_select_rs1   = FORWARD_ORIGINAL;
        forwarding_blocked_rs1 = 1'b0;

        if (ex_mem_matches_rs1) begin
            if (ex_mem_value_valid) begin
                forwarded_rs1_value =
                    ex_mem_forward_value;

                forward_select_rs1 =
                    FORWARD_EX_MEM;
            end
            else begin
                /*
                 * Do not forward an older MEM/WB value when a newer
                 * matching EX/MEM result is still unavailable.
                 */
                forwarding_blocked_rs1 = 1'b1;
            end
        end
        else if (mem_wb_matches_rs1 &&
                 mem_wb_value_valid) begin

            forwarded_rs1_value =
                mem_wb_forward_value;

            forward_select_rs1 =
                FORWARD_MEM_WB;
        end
    end

    /*
     * Forward rs2.
     *
     * rs2 forwarding is also used for store data and branch
     * comparisons, not only the ALU's second operand.
     */
    always_comb begin
        forwarded_rs2_value  = ex_rs2_value;
        forward_select_rs2   = FORWARD_ORIGINAL;
        forwarding_blocked_rs2 = 1'b0;

        if (ex_mem_matches_rs2) begin
            if (ex_mem_value_valid) begin
                forwarded_rs2_value =
                    ex_mem_forward_value;

                forward_select_rs2 =
                    FORWARD_EX_MEM;
            end
            else begin
                forwarding_blocked_rs2 = 1'b1;
            end
        end
        else if (mem_wb_matches_rs2 &&
                 mem_wb_value_valid) begin

            forwarded_rs2_value =
                mem_wb_forward_value;

            forward_select_rs2 =
                FORWARD_MEM_WB;
        end
    end

endmodule