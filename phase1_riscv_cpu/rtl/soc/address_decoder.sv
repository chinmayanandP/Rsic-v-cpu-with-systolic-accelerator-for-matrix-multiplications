`timescale 1ns/1ps

module address_decoder (
    input  logic        request_valid,
    input  logic [31:0] address,

    output logic        data_memory_select,
    output logic        accelerator_select,
    output logic        unmapped_address
);

    // Normal data-memory range:
    // decimal 0 through 16,383 (16 KiB total).
    localparam logic [31:0] DATA_MEMORY_START = 32'h0000_0000;
    localparam logic [31:0] DATA_MEMORY_END   = 32'h0000_3FFF;

    // Reserved accelerator ranges. The real accelerator is added later.
    localparam logic [31:0] ACCEL_CONTROL_START = 32'h4000_0000;
    localparam logic [31:0] ACCEL_CONTROL_END   = 32'h4000_00FF;

    localparam logic [31:0] ACCEL_A_START = 32'h4000_1000;
    localparam logic [31:0] ACCEL_A_END   = 32'h4000_10FF;

    localparam logic [31:0] ACCEL_B_START = 32'h4000_2000;
    localparam logic [31:0] ACCEL_B_END   = 32'h4000_20FF;

    localparam logic [31:0] ACCEL_C_START = 32'h4000_3000;
    localparam logic [31:0] ACCEL_C_END   = 32'h4000_30FF;

    logic address_is_data_memory;
    logic address_is_accelerator;

    always_comb begin
        address_is_data_memory =
            (address >= DATA_MEMORY_START) &&
            (address <= DATA_MEMORY_END);

        address_is_accelerator =
            ((address >= ACCEL_CONTROL_START) &&
             (address <= ACCEL_CONTROL_END)) ||
            ((address >= ACCEL_A_START) &&
             (address <= ACCEL_A_END)) ||
            ((address >= ACCEL_B_START) &&
             (address <= ACCEL_B_END)) ||
            ((address >= ACCEL_C_START) &&
             (address <= ACCEL_C_END));

        data_memory_select = request_valid && address_is_data_memory;
        accelerator_select = request_valid && address_is_accelerator;

        unmapped_address = request_valid &&
                           !address_is_data_memory &&
                           !address_is_accelerator;
    end

endmodule
