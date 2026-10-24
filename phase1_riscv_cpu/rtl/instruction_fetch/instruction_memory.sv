`timescale 1ns/1ps

module instruction_memory #(
    parameter integer WORDS = 256,
    parameter logic [31:0] BASE_ADDR = 32'h00000000,
    parameter INIT_FILE = "program.hex"
)(
    input  logic clk,
    input  logic reset,

    input  logic read_enable,
    input  logic [31:0] address,

    output logic [31:0] instruction,
    output logic instruction_valid,
    output logic instruction_fault
);

    localparam integer INDEX_WIDTH =
        (WORDS <= 1) ? 1 : $clog2(WORDS);

    logic [31:0] rom [0:WORDS-1];

    logic [32:0] offset;
    logic address_in_range;

    integer i;

    /*
     * Convert the complete CPU byte address into an offset
     * from the start of instruction memory.
     */
    always_comb begin
        offset = {1'b0, address} -
                 {1'b0, BASE_ADDR};

        address_in_range =
            !offset[32] &&
            ((offset >> 2) < 33'(WORDS));
    end

    /*
     * Fill unused locations with a RISC-V NOP.
     *
     * 00000013 = addi x0, x0, 0
     *
     * The required program words are then loaded from
     * the hexadecimal initialization file.
     */
    initial begin
        for (i = 0; i < WORDS; i = i + 1)
            rom[i] = 32'h00000013;

        $readmemh(INIT_FILE, rom);
    end

    /*
     * Synchronous instruction read.
     *
     * Fault:
     *   0 = valid instruction address
     *   1 = unaligned or outside instruction memory
     */
    always_ff @(posedge clk) begin
        if (reset) begin
            instruction       <= 32'h00000013;
            instruction_valid <= 1'b0;
            instruction_fault <= 1'b0;

        end else begin
            instruction_valid <= read_enable;
            instruction_fault <= 1'b0;

            if (read_enable) begin
                if (
                    address[1:0] != 2'b00 ||
                    !address_in_range
                ) begin
                    instruction       <= 32'h00000013;
                    instruction_fault <= 1'b1;

                end else begin
                    instruction <=
                        rom[offset[INDEX_WIDTH+1:2]];
                end
            end
        end
    end

endmodule