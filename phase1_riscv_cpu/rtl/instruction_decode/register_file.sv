`timescale 1ns/1ps

module register_file (
    input  logic        clk,
    input  logic        reset,

    // Two asynchronous read ports
    input  logic [4:0]  read_address_1,
    input  logic [4:0]  read_address_2,
    output logic [31:0] read_data_1,
    output logic [31:0] read_data_2,

    // One synchronous write port
    input  logic        write_enable,
    input  logic [4:0]  write_address,
    input  logic [31:0] write_data
);

    logic [31:0] registers [0:31];

    integer index;

    /*
     * Synchronous write and synchronous reset.
     *
     * Register x0 is never written.
     */
    always_ff @(posedge clk) begin
        if (reset) begin
            for (index = 0; index < 32; index = index + 1) begin
                registers[index] <= 32'h00000000;
            end
        end
        else begin
            if (write_enable &&
                (write_address != 5'd0)) begin

                registers[write_address] <= write_data;
            end

            /*
             * Protect x0 even if an unwanted write is attempted.
             */
            registers[0] <= 32'h00000000;
        end
    end

    /*
     * Read port 1.
     *
     * The write-bypass condition allows an instruction in the
     * Decode stage to see a value being written during the same
     * cycle by the Write-Back stage.
     */
    always_comb begin
        if (read_address_1 == 5'd0) begin
            read_data_1 = 32'h00000000;
        end
        else if (write_enable &&
                 (write_address != 5'd0) &&
                 (write_address == read_address_1)) begin

            read_data_1 = write_data;
        end
        else begin
            read_data_1 = registers[read_address_1];
        end
    end

    /*
     * Read port 2.
     */
    always_comb begin
        if (read_address_2 == 5'd0) begin
            read_data_2 = 32'h00000000;
        end
        else if (write_enable &&
                 (write_address != 5'd0) &&
                 (write_address == read_address_2)) begin

            read_data_2 = write_data;
        end
        else begin
            read_data_2 = registers[read_address_2];
        end
    end

endmodule