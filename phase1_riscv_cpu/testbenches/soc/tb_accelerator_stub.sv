`timescale 1ns/1ps

module tb_accelerator_stub;

    logic clk;
    logic reset;

    logic        request;
    logic        write_enable;
    logic [31:0] address;
    logic [31:0] write_data;
    logic [3:0]  byte_enable;

    logic        response_valid;
    logic [31:0] read_data;
    logic        access_fault;

    integer errors;

    accelerator_stub dut (
        .clk            (clk),
        .reset          (reset),
        .request        (request),
        .write_enable   (write_enable),
        .address        (address),
        .write_data     (write_data),
        .byte_enable    (byte_enable),
        .response_valid (response_valid),
        .read_data      (read_data),
        .access_fault   (access_fault)
    );

    always #5 clk = ~clk;

    task automatic set_idle;
        begin
            request      = 1'b0;
            write_enable = 1'b0;
            address      = 32'h4000_0000;
            write_data   = 32'h0000_0000;
            byte_enable  = 4'b0000;
        end
    endtask

    task automatic pass(input string test_name);
        begin
            $display("PASS: %s", test_name);
        end
    endtask

    task automatic fail(input string test_name);
        begin
            errors = errors + 1;
            $display("FAIL: %s", test_name);
        end
    endtask

    task automatic issue_request(
        input logic        test_write_enable,
        input logic [31:0] test_address,
        input logic [31:0] test_write_data,
        input logic [3:0]  test_byte_enable
    );
        begin
            @(negedge clk);

            request      = 1'b1;
            write_enable = test_write_enable;
            address      = test_address;
            write_data   = test_write_data;
            byte_enable  = test_byte_enable;

            @(posedge clk);
            #1;

            request = 1'b0;
        end
    endtask

    initial begin
        clk    = 1'b0;
        reset  = 1'b1;
        errors = 0;
        set_idle();

        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        if (!response_valid &&
            !access_fault &&
            read_data == 32'h0000_0000) begin
            pass("Synchronous interface reset");
        end
        else begin
            fail("Synchronous interface reset");
        end

        // A placeholder read completes after one rising edge and returns 0.
        issue_request(
            1'b0,
            32'h4000_0000,
            32'h0000_0000,
            4'b0000
        );

        if (response_valid &&
            !access_fault &&
            read_data == 32'h0000_0000) begin
            pass("Accelerator placeholder read");
        end
        else begin
            fail("Accelerator placeholder read");
        end

        // A placeholder write is accepted but intentionally has no effect.
        issue_request(
            1'b1,
            32'h4000_1000,
            32'h1234_5678,
            4'b1111
        );

        if (response_valid &&
            !access_fault &&
            read_data == 32'h0000_0000) begin
            pass("Accelerator placeholder write accepted");
        end
        else begin
            fail("Accelerator placeholder write accepted");
        end

        // Verify byte-enable values do not change placeholder behaviour.
        issue_request(
            1'b1,
            32'h4000_2002,
            32'hABCD_ABCD,
            4'b1100
        );

        if (response_valid &&
            !access_fault &&
            read_data == 32'h0000_0000) begin
            pass("Accelerator placeholder partial write accepted");
        end
        else begin
            fail("Accelerator placeholder partial write accepted");
        end

        // An idle cycle must not generate a response.
        @(negedge clk);
        set_idle();

        @(posedge clk);
        #1;

        if (!response_valid && !access_fault)
            pass("Idle cycle produces no response");
        else
            fail("Idle cycle produces no response");

        // Back-to-back requests must each receive a response.
        @(negedge clk);
        request      = 1'b1;
        write_enable = 1'b0;
        address      = 32'h4000_0004;
        write_data   = 32'h0000_0000;
        byte_enable  = 4'b0000;

        @(posedge clk);
        #1;

        if (response_valid &&
            !access_fault &&
            read_data == 32'h0000_0000) begin
            pass("First back-to-back placeholder request");
        end
        else begin
            fail("First back-to-back placeholder request");
        end

        @(negedge clk);
        address = 32'h4000_3000;

        @(posedge clk);
        #1;

        if (response_valid &&
            !access_fault &&
            read_data == 32'h0000_0000) begin
            pass("Second back-to-back placeholder request");
        end
        else begin
            fail("Second back-to-back placeholder request");
        end

        @(negedge clk);
        set_idle();

        $display("");

        if (errors == 0)
            $display("ALL ACCELERATOR PLACEHOLDER CHECKS PASSED");
        else
            $display(
                "ACCELERATOR PLACEHOLDER TEST FAILED: %0d error(s)",
                errors
            );

        $finish;
    end

endmodule
