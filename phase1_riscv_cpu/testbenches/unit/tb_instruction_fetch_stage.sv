`timescale 1ns/1ps

module tb_instruction_fetch_stage;

    logic clk;
    logic reset;
    logic stall;

    logic        redirect_valid;
    logic [31:0] redirect_pc;

    logic [31:0] fetch_pc;

    logic [31:0] if_id_pc;
    logic [31:0] if_id_pc_plus4;
    logic [31:0] if_id_instruction;
    logic        if_id_valid;
    logic        if_id_fault;

    integer checks;
    integer errors;
    integer timeout_count;

    instruction_fetch_stage #(
        .WORDS     (16),
        .RESET_PC  (32'h00000000),
        .BASE_ADDR (32'h00000000),
        .INIT_FILE ("program16.hex")
    ) dut (
        .clk               (clk),
        .reset             (reset),
        .stall             (stall),
        .redirect_valid    (redirect_valid),
        .redirect_pc       (redirect_pc),

        .fetch_pc          (fetch_pc),

        .if_id_pc          (if_id_pc),
        .if_id_pc_plus4    (if_id_pc_plus4),
        .if_id_instruction (if_id_instruction),
        .if_id_valid       (if_id_valid),
        .if_id_fault       (if_id_fault)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic wait_for_valid;
        begin
            timeout_count = 0;

            while ((if_id_valid !== 1'b1) &&
                   (timeout_count < 20)) begin
                @(posedge clk);
                #1;

                timeout_count = timeout_count + 1;
            end

            if (if_id_valid !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL: Timeout waiting for valid instruction");
            end
        end
    endtask

    task automatic check_fetch(
        input string       test_name,
        input logic [31:0] expected_pc,
        input logic [31:0] expected_instruction,
        input logic        expected_fault
    );
        begin
            if ((if_id_pc          !== expected_pc)          ||
                (if_id_pc_plus4    !== expected_pc + 32'd4)  ||
                (if_id_instruction !== expected_instruction) ||
                (if_id_valid       !== 1'b1)                 ||
                (if_id_fault       !== expected_fault)) begin

                errors = errors + 1;

                $display("");
                $display("FAIL: %s", test_name);

                $display(
                    "Expected pc=%h pc+4=%h instruction=%h valid=1 fault=%b",
                    expected_pc,
                    expected_pc + 32'd4,
                    expected_instruction,
                    expected_fault
                );

                $display(
                    "Received pc=%h pc+4=%h instruction=%h valid=%b fault=%b",
                    if_id_pc,
                    if_id_pc_plus4,
                    if_id_instruction,
                    if_id_valid,
                    if_id_fault
                );
            end
            else begin
                checks = checks + 1;

                $display(
                    "PASS: %s pc=%h instruction=%h fault=%b",
                    test_name,
                    if_id_pc,
                    if_id_instruction,
                    if_id_fault
                );
            end
        end
    endtask

    task automatic check_invalid(
        input string test_name
    );
        begin
            if (if_id_valid !== 1'b0) begin
                errors = errors + 1;

                $display(
                    "FAIL: %s expected valid=0 received valid=%b",
                    test_name,
                    if_id_valid
                );
            end
            else begin
                checks = checks + 1;
                $display("PASS: %s", test_name);
            end
        end
    endtask

    initial begin
        checks         = 0;
        errors         = 0;
        timeout_count  = 0;

        reset          = 1'b1;
        stall          = 1'b0;
        redirect_valid = 1'b0;
        redirect_pc    = 32'h00000000;

        /*
         * Test 1: synchronous reset.
         */
        repeat (2) begin
            @(posedge clk);
            #1;
        end

        if ((fetch_pc !== 32'h00000000) ||
            (if_id_valid !== 1'b0)) begin

            errors = errors + 1;

            $display(
                "FAIL: Reset fetch_pc=%h if_id_valid=%b",
                fetch_pc,
                if_id_valid
            );
        end
        else begin
            checks = checks + 1;
            $display("PASS: Integrated IF-stage reset");
        end

        @(negedge clk);
        reset = 1'b0;

        /*
         * Test 2: fetch address 0x00.
         */
        wait_for_valid();

        check_fetch(
            "Fetch ADDI x1,x0,5",
            32'h00000000,
            32'h00500093,
            1'b0
        );

        /*
         * Test 3: fetch address 0x04.
         */
        @(posedge clk);
        #1;

        check_fetch(
            "Fetch ADDI x2,x0,7",
            32'h00000004,
            32'h00700113,
            1'b0
        );

        /*
         * Test 4: apply a stall while the next instruction
         * is pending.
         */
        @(negedge clk);
        stall = 1'b1;

        @(posedge clk);
        #1;

        if ((if_id_pc          !== 32'h00000004) ||
            (if_id_instruction !== 32'h00700113) ||
            (if_id_valid       !== 1'b1)) begin

            errors = errors + 1;
            $display("FAIL: Stall did not hold IF/ID values");
        end
        else begin
            checks = checks + 1;
            $display("PASS: Stall holds IF/ID values");
        end

        /*
         * Test 5: extended stall.
         */
        @(posedge clk);
        #1;

        if ((if_id_pc          !== 32'h00000004) ||
            (if_id_instruction !== 32'h00700113) ||
            (if_id_valid       !== 1'b1)) begin

            errors = errors + 1;
            $display("FAIL: Extended stall changed IF/ID values");
        end
        else begin
            checks = checks + 1;
            $display("PASS: Extended stall holds IF/ID values");
        end

        /*
         * Release the stall.
         */
        @(negedge clk);
        stall = 1'b0;

        /*
         * Test 6:
         * The buffered PC=0x08 response must now enter IF/ID.
         */
        @(posedge clk);
        #1;

        check_fetch(
            "Resume buffered ADD x3,x1,x2",
            32'h00000008,
            32'h002081B3,
            1'b0
        );

        /*
         * Redirect to address 0x20.
         */
        @(negedge clk);
        redirect_pc    = 32'h00000020;
        redirect_valid = 1'b1;

        /*
         * Test 7: redirect flush.
         */
        @(posedge clk);
        #1;

        check_invalid(
            "Redirect flushes old instruction"
        );

        @(negedge clk);
        redirect_valid = 1'b0;

        /*
         * Test 8: redirected instruction.
         */
        wait_for_valid();

        check_fetch(
            "Fetch redirected instruction",
            32'h00000020,
            32'h00800213,
            1'b0
        );

        /*
         * Redirect outside the instruction-memory range.
         */
        @(negedge clk);
        redirect_pc    = 32'h00000040;
        redirect_valid = 1'b1;

        /*
         * Test 9: invalid-address redirect flush.
         */
        @(posedge clk);
        #1;

        check_invalid(
            "Invalid-address redirect flushes IF/ID"
        );

        @(negedge clk);
        redirect_valid = 1'b0;

        /*
         * Test 10: out-of-range memory fault.
         */
        wait_for_valid();

        check_fetch(
            "Detect out-of-range instruction address",
            32'h00000040,
            32'h00000013,
            1'b1
        );

        $display("");

        if (errors == 0) begin
            $display(
                "ALL %0d INTEGRATED IF-STAGE CHECKS PASSED",
                checks
            );
        end
        else begin
            $display(
                "INTEGRATED IF-STAGE TEST FAILED: %0d error(s)",
                errors
            );

            $fatal(1);
        end

        $finish;
    end

endmodule