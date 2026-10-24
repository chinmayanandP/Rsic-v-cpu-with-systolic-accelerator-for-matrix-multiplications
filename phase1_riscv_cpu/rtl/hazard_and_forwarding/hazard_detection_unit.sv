`timescale 1ns/1ps

module hazard_detection_unit (
    /*
     * Instruction currently in the Decode stage.
     */
    input logic       id_valid,
    input logic       id_uses_rs1,
    input logic       id_uses_rs2,
    input logic [4:0] id_rs1,
    input logic [4:0] id_rs2,

    /*
     * Instruction currently in the Execute stage.
     */
    input logic       ex_valid,
    input logic       ex_fault,
    input logic       ex_illegal,

    input logic       ex_memory_read,
    input logic       ex_register_write,
    input logic [4:0] ex_destination_register,

    /*
     * Indicates that the Decode-stage instruction must wait
     * because it needs the result of an Execute-stage load.
     */
    output logic load_use_hazard
);

    logic rs1_dependency;
    logic rs2_dependency;

    always_comb begin
        rs1_dependency = 1'b0;
        rs2_dependency = 1'b0;
        load_use_hazard = 1'b0;

        /*
         * Register x0 never creates a dependency because it is
         * permanently zero.
         */
        if (id_valid &&
            ex_valid &&
            !ex_fault &&
            !ex_illegal &&
            ex_memory_read &&
            ex_register_write &&
            ex_destination_register != 5'd0) begin

            if (id_uses_rs1 &&
                id_rs1 == ex_destination_register) begin

                rs1_dependency = 1'b1;
            end

            if (id_uses_rs2 &&
                id_rs2 == ex_destination_register) begin

                rs2_dependency = 1'b1;
            end

            load_use_hazard =
                rs1_dependency || rs2_dependency;
        end
    end

endmodule