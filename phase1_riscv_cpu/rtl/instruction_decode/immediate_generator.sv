`timescale 1ns/1ps

module immediate_generator (
    input  logic [31:0] instruction,
    input  logic [2:0]  immediate_type,

    output logic [31:0] immediate,
    output logic        immediate_valid
);

    /*
     * These encodings must be used consistently by the future
     * Control Unit.
     */
    localparam logic [2:0] IMM_I    = 3'b000;
    localparam logic [2:0] IMM_S    = 3'b001;
    localparam logic [2:0] IMM_B    = 3'b010;
    localparam logic [2:0] IMM_U    = 3'b011;
    localparam logic [2:0] IMM_J    = 3'b100;
    localparam logic [2:0] IMM_NONE = 3'b111;

    always_comb begin
        immediate       = 32'h00000000;
        immediate_valid = 1'b1;

        case (immediate_type)

            /*
             * I-type:
             * immediate = instruction[31:20]
             */
            IMM_I: begin
                immediate = {
                    {20{instruction[31]}},
                    instruction[31:20]
                };
            end

            /*
             * S-type:
             * immediate = instruction[31:25] and [11:7]
             */
            IMM_S: begin
                immediate = {
                    {20{instruction[31]}},
                    instruction[31:25],
                    instruction[11:7]
                };
            end

            /*
             * B-type:
             *
             * immediate[12]   = instruction[31]
             * immediate[11]   = instruction[7]
             * immediate[10:5] = instruction[30:25]
             * immediate[4:1]  = instruction[11:8]
             * immediate[0]    = 0
             */
            IMM_B: begin
                immediate = {
                    {19{instruction[31]}},
                    instruction[31],
                    instruction[7],
                    instruction[30:25],
                    instruction[11:8],
                    1'b0
                };
            end

            /*
             * U-type:
             * Upper 20 bits followed by 12 zeros.
             */
            IMM_U: begin
                immediate = {
                    instruction[31:12],
                    12'b000000000000
                };
            end

            /*
             * J-type:
             *
             * immediate[20]    = instruction[31]
             * immediate[19:12] = instruction[19:12]
             * immediate[11]    = instruction[20]
             * immediate[10:1]  = instruction[30:21]
             * immediate[0]     = 0
             */
            IMM_J: begin
                immediate = {
                    {11{instruction[31]}},
                    instruction[31],
                    instruction[19:12],
                    instruction[20],
                    instruction[30:21],
                    1'b0
                };
            end

            IMM_NONE: begin
                immediate       = 32'h00000000;
                immediate_valid = 1'b0;
            end

            default: begin
                immediate       = 32'h00000000;
                immediate_valid = 1'b0;
            end

        endcase
    end

endmodule