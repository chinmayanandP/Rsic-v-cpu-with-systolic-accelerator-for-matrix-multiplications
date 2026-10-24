`timescale 1ns/1ps

module tb_register_file;

    logic clk;
    logic reset;

    logic [4:0]  read_address_1;
    logic [4:0]  read_address_2;
    logic [31:0] read_data_1;
    logic [31:0] read_data_2;

    logic        write_enable;
    logic [4:0]  write_address;
    logic [31:0] write_data;

    integer checks;
    integer errors;

    register_file dut (
        .clk            (clk),
        .reset          (reset),

        .read_address_1 (read_address_1),
        .read_address_2 (read_address_2),
        .read_data_1    (read_data_1),
        .read_data_2    (read_data_2),

        .write_enable   (write_enable),
        .write_address  (write_address),
        .write_data     (write_data)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic check_reads(
        input string       test_name,
        input logic [31:0] expected_data_1,
        input logic [31:0] expected_data_2
    );
        begin
            #1;

            if ((read_data_1 !== expected_data_1) ||
                (read_data_2 !== expected_data_2)) begin

                errors = errors + 1;

                $display("");
                $display("FAIL: %s", test_name);

                $display(
                    "Expected read1=%h read2=%h",
                    expected_data_1,
                    expected_data_2
                );

                $display(
                    "Received read1=%h read2=%h",
                    read_data_1,
                    read_data_2
                );
            end
            else begin
                checks = checks + 1;

                $display(
                    "PASS: %s read1=%h read2=%h",
                    test_name,
                    read_data_1,
                    read_data_2
                );
            end
        end
    endtask

    initial begin
        checks         = 0;
        errors         = 0;

        reset          = 1'b1;
        read_address_1 = 5'd0;
        read_address_2 = 5'd1;
        write_enable   = 1'b0;
        write_address  = 5'd0;
        write_data     = 32'h00000000;

        /*
         * Test 1:
         * Apply synchronous reset.
         */
        repeat (2) begin
            @(posedge clk);
            #1;
        end

        check_reads(
            "Reset clears registers",
            32'h00000000,
            32'h00000000
        );

        /*
         * Test 2:
         * x0 must always return zero.
         */
        reset          = 1'b0;
        read_address_1 = 5'd0;
        read_address_2 = 5'd0;

        check_reads(
            "x0 reads as zero",
            32'h00000000,
            32'h00000000
        );

        /*
         * Test 3:
         * Write 5 into x1.
         */
        write_enable  = 1'b1;
        write_address = 5'd1;
        write_data    = 32'h00000005;

        @(posedge clk);
        #1;

        write_enable   = 1'b0;
        read_address_1 = 5'd1;
        read_address_2 = 5'd0;

        check_reads(
            "Write and read x1",
            32'h00000005,
            32'h00000000
        );

        /*
         * Test 4:
         * Write 7 into x2.
         */
        write_enable  = 1'b1;
        write_address = 5'd2;
        write_data    = 32'h00000007;

        @(posedge clk);
        #1;

        write_enable   = 1'b0;
        read_address_1 = 5'd1;
        read_address_2 = 5'd2;

        check_reads(
            "Two simultaneous reads",
            32'h00000005,
            32'h00000007
        );

        /*
         * Test 5:
         * Overwrite x1.
         */
        write_enable  = 1'b1;
        write_address = 5'd1;
        write_data    = 32'h12345678;

        @(posedge clk);
        #1;

        write_enable   = 1'b0;
        read_address_1 = 5'd1;
        read_address_2 = 5'd2;

        check_reads(
            "Overwrite existing register",
            32'h12345678,
            32'h00000007
        );

        /*
         * Test 6:
         * A disabled write must not modify x2.
         */
        write_enable  = 1'b0;
        write_address = 5'd2;
        write_data    = 32'hFFFFFFFF;

        @(posedge clk);
        #1;

        read_address_1 = 5'd2;
        read_address_2 = 5'd1;

        check_reads(
            "Disabled write changes nothing",
            32'h00000007,
            32'h12345678
        );

        /*
         * Test 7:
         * Attempting to write x0 must be ignored.
         */
        write_enable  = 1'b1;
        write_address = 5'd0;
        write_data    = 32'hFFFFFFFF;

        @(posedge clk);
        #1;

        write_enable   = 1'b0;
        read_address_1 = 5'd0;
        read_address_2 = 5'd1;

        check_reads(
            "Write to x0 is ignored",
            32'h00000000,
            32'h12345678
        );

        /*
         * Test 8:
         * Same-cycle write bypass.
         *
         * The value being written to x3 must be immediately
         * visible on both read ports.
         */
        write_enable   = 1'b1;
        write_address  = 5'd3;
        write_data     = 32'hA5A55A5A;
        read_address_1 = 5'd3;
        read_address_2 = 5'd3;

        check_reads(
            "Same-cycle write bypass",
            32'hA5A55A5A,
            32'hA5A55A5A
        );

        /*
         * Complete the x3 write.
         */
        @(posedge clk);
        #1;

        write_enable = 1'b0;

        check_reads(
            "Bypassed value stored in x3",
            32'hA5A55A5A,
            32'hA5A55A5A
        );

        /*
         * Test 10:
         * Test the highest register, x31.
         */
        write_enable  = 1'b1;
        write_address = 5'd31;
        write_data    = 32'hCAFEBABE;

        @(posedge clk);
        #1;

        write_enable   = 1'b0;
        read_address_1 = 5'd31;
        read_address_2 = 5'd3;

        check_reads(
            "Write and read x31",
            32'hCAFEBABE,
            32'hA5A55A5A
        );

        /*
         * Test 11:
         * Reset must have priority over a write.
         */
        reset         = 1'b1;
        write_enable  = 1'b1;
        write_address = 5'd4;
        write_data    = 32'hDEADBEEF;

        @(posedge clk);
        #1;

        reset          = 1'b0;
        write_enable   = 1'b0;
        read_address_1 = 5'd1;
        read_address_2 = 5'd31;

        check_reads(
            "Reset has priority over write",
            32'h00000000,
            32'h00000000
        );

        /*
         * Test 12:
         * Confirm x3 was also cleared by reset.
         */
        read_address_1 = 5'd3;
        read_address_2 = 5'd0;

        check_reads(
            "Reset clears x3 and preserves x0",
            32'h00000000,
            32'h00000000
        );

        $display("");

        if (errors == 0) begin
            $display(
                "ALL %0d REGISTER FILE CHECKS PASSED",
                checks
            );
        end
        else begin
            $display(
                "REGISTER FILE TEST FAILED: %0d error(s)",
                errors
            );

            $fatal(1);
        end

        $finish;
    end

endmodule