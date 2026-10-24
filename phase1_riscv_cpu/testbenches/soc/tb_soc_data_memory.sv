`timescale 1ns/1ps

module tb_soc_data_memory;

    localparam integer WORDS = 4096;
    localparam logic [31:0] BASE_ADDRESS = 32'h0000_0000;

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

    data_memory #(
        .WORDS        (WORDS),
        .BASE_ADDRESS (BASE_ADDRESS),
        .INIT_FILE    ("")
    ) dut (
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
            address      = BASE_ADDRESS;
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

    task automatic perform_write(
        input logic [31:0] test_address,
        input logic [31:0] test_data,
        input logic [3:0]  test_byte_enable
    );
        begin
            @(negedge clk);

            request      = 1'b1;
            write_enable = 1'b1;
            address      = test_address;
            write_data   = test_data;
            byte_enable  = test_byte_enable;

            @(posedge clk);
            #1;

            @(negedge clk);
            set_idle();
        end
    endtask

    task automatic perform_read(
        input logic [31:0] test_address
    );
        begin
            @(negedge clk);

            request      = 1'b1;
            write_enable = 1'b0;
            address      = test_address;
            write_data   = 32'h0000_0000;
            byte_enable  = 4'b0000;

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

        // Keep reset active through two rising edges, then release it
        // on a falling edge to avoid a testbench/RTL timing race.
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

        // Confirm that the initialized first word is zero.
        perform_read(32'h0000_0000);

        if (response_valid &&
            !access_fault &&
            read_data == 32'h0000_0000) begin
            pass("Initial memory value is zero");
        end
        else begin
            fail("Initial memory value is zero");
        end

        // Complete 32-bit word write and read at the first location.
        perform_write(
            32'h0000_0000,
            32'h1122_3344,
            4'b1111
        );

        if (response_valid && !access_fault)
            pass("Full-word write accepted");
        else
            fail("Full-word write accepted");

        perform_read(32'h0000_0000);

        if (response_valid &&
            !access_fault &&
            read_data == 32'h1122_3344) begin
            pass("Full-word read returned stored value");
        end
        else begin
            fail("Full-word read returned stored value");
        end

        // Change byte lane 1. The word becomes 0x1122AA44.
        perform_write(
            32'h0000_0001,
            32'hAAAA_AAAA,
            4'b0010
        );

        perform_read(32'h0000_0000);

        if (!access_fault && read_data == 32'h1122_AA44)
            pass("Byte-enable write updated only byte lane 1");
        else
            fail("Byte-enable write updated only byte lane 1");

        // Change the upper halfword. The word becomes 0xBBBBAA44.
        perform_write(
            32'h0000_0002,
            32'hBBBB_BBBB,
            4'b1100
        );

        perform_read(32'h0000_0000);

        if (!access_fault && read_data == 32'hBBBB_AA44)
            pass("Halfword byte enables updated upper two lanes");
        else
            fail("Halfword byte enables updated upper two lanes");

        // The final 32-bit word begins at byte address 16,380.
        perform_write(
            32'h0000_3FFC,
            32'hCAFE_BABE,
            4'b1111
        );

        perform_read(32'h0000_3FFC);

        if (response_valid &&
            !access_fault &&
            read_data == 32'hCAFE_BABE) begin
            pass("Final word of 16 KiB memory");
        end
        else begin
            fail("Final word of 16 KiB memory");
        end

        // Address 16,384 is the first byte outside the memory.
        perform_read(32'h0000_4000);

        if (response_valid &&
            access_fault &&
            read_data == 32'h0000_0000) begin
            pass("Address above 16 KiB memory reports access fault");
        end
        else begin
            fail("Address above 16 KiB memory reports access fault");
        end

        // No request must produce no response on the following edge.
        @(negedge clk);
        set_idle();

        @(posedge clk);
        #1;

        if (!response_valid && !access_fault)
            pass("Idle cycle produces no response");
        else
            fail("Idle cycle produces no response");

        // Back-to-back reads prove one request can be accepted each cycle.
        @(negedge clk);
        request      = 1'b1;
        write_enable = 1'b0;
        address      = 32'h0000_0000;
        write_data   = 32'h0000_0000;
        byte_enable  = 4'b0000;

        @(posedge clk);
        #1;

        if (response_valid &&
            !access_fault &&
            read_data == 32'hBBBB_AA44) begin
            pass("First back-to-back read");
        end
        else begin
            fail("First back-to-back read");
        end

        @(negedge clk);
        address = 32'h0000_3FFC;

        @(posedge clk);
        #1;

        if (response_valid &&
            !access_fault &&
            read_data == 32'hCAFE_BABE) begin
            pass("Second back-to-back read");
        end
        else begin
            fail("Second back-to-back read");
        end

        @(negedge clk);
        set_idle();

        $display("");

        if (errors == 0)
            $display("ALL SOC DATA MEMORY CHECKS PASSED");
        else
            $display("SOC DATA MEMORY TEST FAILED: %0d error(s)", errors);

        $finish;
    end

endmodule
