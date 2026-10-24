`timescale 1ns/1ps

module data_memory #(
    parameter integer WORDS = 1024,
    parameter logic [31:0] BASE_ADDRESS = 32'h00000000,
    parameter string INIT_FILE = ""
)(
    input  logic        clk,
    input  logic        reset,

    input  logic        request,
    input  logic        write_enable,

    input  logic [31:0] address,
    input  logic [31:0] write_data,
    input  logic [3:0]  byte_enable,

    output logic        response_valid,
    output logic [31:0] read_data,
    output logic        access_fault
);

    localparam integer ADDRESS_WIDTH =
        (WORDS <= 1) ? 1 : $clog2(WORDS);

    logic [31:0] memory [0:WORDS-1];

    logic        address_valid;
    logic [31:0] address_offset;
    logic [31:0] word_number;
    logic [ADDRESS_WIDTH-1:0] memory_index;

    integer index;

    /*
     * Optional FPGA memory initialization.
     *
     * The memory is initialized to zero when no initialization
     * file is supplied.
     */
    initial begin
        for (index = 0; index < WORDS; index = index + 1) begin
            memory[index] = 32'h00000000;
        end

        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, memory);
        end
    end

    /*
     * Convert the byte address into a memory-word index.
     */
    always_comb begin
        address_offset = address - BASE_ADDRESS;
        word_number    = address_offset >> 2;

        memory_index =
            word_number[ADDRESS_WIDTH-1:0];

        address_valid =
            (address >= BASE_ADDRESS) &&
            (word_number < WORDS);
    end

    /*
     * Synchronous FPGA-memory interface.
     *
     * A request presented before a rising clock edge produces
     * response_valid, read_data and access_fault after that edge.
     */
    always_ff @(posedge clk) begin
        if (reset) begin
            response_valid <= 1'b0;
            read_data      <= 32'h00000000;
            access_fault   <= 1'b0;
        end
        else begin
            response_valid <= request;
            access_fault   <= 1'b0;

            if (request) begin
                if (address_valid) begin
                    /*
                     * The complete aligned word is returned.
                     * Load formatting will be performed by the
                     * load/store control module.
                     */
                    read_data <= memory[memory_index];

                    if (write_enable) begin
                        if (byte_enable[0]) begin
                            memory[memory_index][7:0] <=
                                write_data[7:0];
                        end

                        if (byte_enable[1]) begin
                            memory[memory_index][15:8] <=
                                write_data[15:8];
                        end

                        if (byte_enable[2]) begin
                            memory[memory_index][23:16] <=
                                write_data[23:16];
                        end

                        if (byte_enable[3]) begin
                            memory[memory_index][31:24] <=
                                write_data[31:24];
                        end
                    end
                end
                else begin
                    read_data    <= 32'h00000000;
                    access_fault <= 1'b1;
                end
            end
            else begin
                response_valid <= 1'b0;
            end
        end
    end

endmodule