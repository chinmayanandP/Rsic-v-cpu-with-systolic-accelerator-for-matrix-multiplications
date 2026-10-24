`timescale 1ns/1ps

module pc_plus4 (
    input  logic [31:0] pc,
    output logic [31:0] pc_next_sequential
);

    assign pc_next_sequential = pc + 32'd4;

endmodule