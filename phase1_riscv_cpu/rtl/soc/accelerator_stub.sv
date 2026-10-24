`timescale 1ns/1ps

module accelerator_stub (
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

    /*
     * Temporary accelerator placeholder.
     *
     * The address decoder guarantees that request is asserted only for
     * a reserved accelerator address. The placeholder accepts every
     * forwarded request after one rising clock edge, returns zero for
     * reads, and ignores writes. The real systolic-accelerator top module
     * will later replace this module without changing the system-bus
     * interface.
     */
    always_ff @(posedge clk) begin
        if (reset) begin
            response_valid <= 1'b0;
            read_data      <= 32'h0000_0000;
            access_fault   <= 1'b0;
        end
        else begin
            response_valid <= request;
            access_fault   <= 1'b0;

            if (request) begin
                // Reads return zero and writes are intentionally ignored.
                read_data <= 32'h0000_0000;
            end
            else begin
                response_valid <= 1'b0;
            end
        end
    end

endmodule
