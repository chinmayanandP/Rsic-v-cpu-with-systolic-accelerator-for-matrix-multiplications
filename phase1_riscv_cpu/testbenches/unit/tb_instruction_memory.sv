`timescale 1ns/1ps

module tb_instruction_memory;

    logic clk = 0;

    always #5 clk = ~clk;

    logic reset = 1;
    logic read_enable = 0;
    logic [31:0] address = 0;

    wire [31:0] instruction;
    wire instruction_valid;
    wire instruction_fault;

    integer checks = 0;

    /*
     * The test uses a 16-word instruction memory.
     */
    instruction_memory #(
        .WORDS(16),
        .BASE_ADDR(32'h00000000),
        .INIT_FILE("program16.hex")
    ) dut (
        .clk(clk),
        .reset(reset),
        .read_enable(read_enable),
        .address(address),
        .instruction(instruction),
        .instruction_valid(instruction_valid),
        .instruction_fault(instruction_fault)
    );

    task automatic read_and_check(
        input logic [31:0] requested_address,
        input logic [31:0] expected_instruction,
        input logic expected_fault,
        input string label_text
    );
        /*
         * Apply the address at the falling edge so it is
         * stable before the next rising edge.
         */
        @(negedge clk);

        read_enable = 1;
        address = requested_address;

        /*
         * The synchronous memory reads on this rising edge.
         */
        @(posedge clk);
        #1;

        if (
            !instruction_valid ||
            instruction_fault !== expected_fault ||
            instruction !== expected_instruction
        )
            $fatal(
                1,
                "%s: address=%h instruction=%h valid=%b fault=%b",
                label_text,
                address,
                instruction,
                instruction_valid,
                instruction_fault
            );

        checks = checks + 1;

        $display(
            "PASS %s: address=%08h instruction=%08h fault=%b",
            label_text,
            requested_address,
            instruction,
            instruction_fault
        );
    endtask

    initial begin

        /*
         * Check reset.
         */
        @(posedge clk);
        #1;

        if (instruction_valid !== 0)
            $fatal(
                1,
                "Valid must be zero during reset"
            );

        checks = checks + 1;

        /*
         * Release reset.
         */
        @(negedge clk);
        reset = 0;

        /*
         * Check real RV32I instruction words.
         */
        read_and_check(
            32'h00000000,
            32'h00500093,
            0,
            "Fetch ADDI x1,x0,5"
        );

        read_and_check(
            32'h00000004,
            32'h00700113,
            0,
            "Fetch ADDI x2,x0,7"
        );

        read_and_check(
            32'h00000008,
            32'h002081b3,
            0,
            "Fetch ADD x3,x1,x2"
        );

        read_and_check(
            32'h0000000c,
            32'h0000006f,
            0,
            "Fetch JAL x0,0"
        );

        /*
         * Check the last valid ROM word.
         */
        read_and_check(
            32'h0000003c,
            32'h00f00213,
            0,
            "Fetch last ROM word"
        );

        /*
         * Address 2 is not divisible by four.
         */
        read_and_check(
            32'h00000002,
            32'h00000013,
            1,
            "Detect unaligned address"
        );

        /*
         * A 16-word ROM occupies addresses 0x00-0x3F.
         * Address 0x40 is outside that range.
         */
        read_and_check(
            32'h00000040,
            32'h00000013,
            1,
            "Detect address above ROM"
        );

        read_and_check(
            32'hfffffffc,
            32'h00000013,
            1,
            "Detect invalid high address"
        );

        /*
         * With read_enable low, no new instruction is valid.
         */
        @(negedge clk);

        read_enable = 0;
        address = 32'h00000004;

        @(posedge clk);
        #1;

        if (instruction_valid !== 0)
            $fatal(
                1,
                "Valid must be zero when read_enable is zero"
            );

        checks = checks + 1;

        $display(
            "PASS disabled read: instruction_valid=0"
        );

        /*
         * Reset has priority over a memory request.
         */
        @(negedge clk);

        reset = 1;
        read_enable = 1;
        address = 32'h00000000;

        @(posedge clk);
        #1;

        if (
            instruction_valid !== 0 ||
            instruction_fault !== 0 ||
            instruction !== 32'h00000013
        )
            $fatal(
                1,
                "Reset did not override read request"
            );

        checks = checks + 1;

        $display("PASS reset priority");

        $display(
            "ALL %0d INSTRUCTION MEMORY CHECKS PASSED",
            checks
        );

        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end

endmodule