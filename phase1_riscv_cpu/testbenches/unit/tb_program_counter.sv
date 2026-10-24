`timescale 1ns/1ps

module tb_program_counter;

    logic clk = 0;
    always #5 clk = ~clk;

    logic reset = 1;
    logic pc_enable = 0;
    logic [31:0] next_pc = 0;

    wire [31:0] pc;
    wire [31:0] pc_alt;

    integer checks = 0;

    // Main instance: reset address = 0.
    program_counter dut (
        .clk(clk),
        .reset(reset),
        .pc_enable(pc_enable),
        .next_pc(next_pc),
        .pc(pc)
    );

    // Additional instance verifies the reset-address parameter.
    program_counter #(
        .RESET_PC(32'h00000100)
    ) dut_alt (
        .clk(clk),
        .reset(reset),
        .pc_enable(pc_enable),
        .next_pc(next_pc),
        .pc(pc_alt)
    );

    task automatic check_pc(
        input logic [31:0] expected,
        input logic [31:0] expected_alt,
        input string label_text
    );
        if (pc !== expected || pc_alt !== expected_alt)
            $fatal(
                1,
                "%s: pc=%h pc_alt=%h expected=%h/%h",
                label_text,
                pc,
                pc_alt,
                expected,
                expected_alt
            );

        checks = checks + 1;

        $display(
            "PASS %s: pc=%08h pc_alt=%08h",
            label_text,
            pc,
            pc_alt
        );
    endtask

    task automatic step(
        input logic rst,
        input logic enable,
        input logic [31:0] address,
        input logic [31:0] expected,
        input logic [31:0] expected_alt,
        input string label_text
    );
        // Drive inputs away from the active clock edge.
        @(negedge clk);
        reset = rst;
        pc_enable = enable;
        next_pc = address;

        // Check after the register update.
        @(posedge clk);
        #1;
        check_pc(expected, expected_alt, label_text);
    endtask

    initial begin

        @(posedge clk);
        #1;
        check_pc(0, 32'h100, "Initial reset");

        step(
            0, 1, 32'h4, 32'h4, 32'h4,
            "Load address 4"
        );

        step(
            0, 1, 32'h8, 32'h8, 32'h8,
            "Load address 8"
        );

        step(
            0, 0, 32'hc, 32'h8, 32'h8,
            "Hold during stall"
        );

        step(
            0, 0, 32'h80, 32'h8, 32'h8,
            "Hold despite changed input"
        );

        step(
            0, 1, 32'h40, 32'h40, 32'h40,
            "Load selected jump address"
        );

        // Input changes must not immediately change the PC.
        @(negedge clk);
        next_pc = 32'h80;

        #1;
        check_pc(
            32'h40, 32'h40,
            "No update between rising edges"
        );

        // Synchronous reset must wait for a rising edge.
        reset = 1;

        #1;
        check_pc(
            32'h40, 32'h40,
            "Reset is synchronous"
        );

        @(posedge clk);
        #1;
        check_pc(
            0, 32'h100,
            "Reset overrides enable"
        );

        step(
            1, 0, 32'h88, 0, 32'h100,
            "Reset works with enable low"
        );

        step(
            0, 0, 32'h88, 0, 32'h100,
            "Hold after reset release"
        );

        step(
            0, 1,
            32'hfffffffc,
            32'hfffffffc,
            32'hfffffffc,
            "Full-width address"
        );

        $display("ALL %0d PC CHECKS PASSED", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end

endmodule