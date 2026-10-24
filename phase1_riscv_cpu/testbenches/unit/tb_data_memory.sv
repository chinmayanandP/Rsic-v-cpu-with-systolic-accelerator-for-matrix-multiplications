`timescale 1ns/1ps

module tb_data_memory;

    localparam integer WORDS = 16;
    localparam logic [31:0] BASE_ADDRESS = 32'h00001000;

    logic clk;
    logic reset;

    logic request;
    logic write_enable;

    logic [31:0] address;
    logic [31:0] write_data;
    logic [3:0]  byte_enable;

    logic response_valid;
    logic [31:0] read_data;
    logic access_fault;

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

    initial begin
        clk = 1'b0;
    end

    always #5 clk = ~clk;

    task automatic set_idle;
        begin
            request      = 1'b0;
            write_enable = 1'b0;
            address      = BASE_ADDRESS;
            write_data   = 32'h00000000;
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

    task automatic write_word(
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

            request      = 1'b0;
            write_enable = 1'b0;
            byte_enable  = 4'b0000;
        end
    endtask

    task automatic read_word(
        input logic [31:0] test_address
    );
        begin
            @(negedge clk);

            request      = 1'b1;
            write_enable = 1'b0;
            address      = test_address;
            write_data   = 32'h00000000;
            byte_enable  = 4'b0000;

            @(posedge clk);
            #1;

            request = 1'b0;
        end
    endtask

    initial begin
        errors = 0;

        reset = 1'b1;
        set_idle();

        /*
         * Test 1: synchronous reset.
         */
        @(posedge clk);
        #1;

        if (!response_valid &&
            !access_fault &&
            read_data == 32'h00000000) begin

            pass("Synchronous reset");
        end
        else begin
            fail("Synchronous reset");
        end

        reset = 1'b0;

        /*
         * Test 2: complete 32-bit word write.
         */
        write_word(
            32'h00001000,
            32'h11223344,
            4'b1111
        );

        if (response_valid &&
            !access_fault) begin

            pass("Full-word write accepted");
        end
        else begin
            fail("Full-word write accepted");
        end

        /*
         * Test 3: read the stored word.
         */
        read_word(32'h00001000);

        if (response_valid &&
            !access_fault &&
            read_data == 32'h11223344) begin

            pass("Full-word read");
        end
        else begin
            fail("Full-word read");
        end

        /*
         * Test 4: modify byte lane 1.
         *
         * Original: 11 22 33 44
         * Updated : 11 22 AA 44
         */
        write_word(
            32'h00001001,
            32'h0000AA00,
            4'b0010
        );

        read_word(32'h00001000);

        if (read_data == 32'h1122AA44 &&
            !access_fault) begin

            pass("Byte-lane write");
        end
        else begin
            fail("Byte-lane write");
        end

        /*
         * Test 5: modify the upper halfword.
         *
         * Previous: 11 22 AA 44
         * Updated : BB BB AA 44
         */
        write_word(
            32'h00001002,
            32'hBBBB0000,
            4'b1100
        );

        read_word(32'h00001000);

        if (read_data == 32'hBBBBAA44 &&
            !access_fault) begin

            pass("Halfword byte-enable write");
        end
        else begin
            fail("Halfword byte-enable write");
        end

        /*
         * Test 6: first memory location.
         */
        write_word(
            BASE_ADDRESS,
            32'hA5A55A5A,
            4'b1111
        );

        read_word(BASE_ADDRESS);

        if (read_data == 32'hA5A55A5A &&
            !access_fault) begin

            pass("First memory location");
        end
        else begin
            fail("First memory location");
        end

        /*
         * Test 7: final memory location.
         *
         * Sixteen words occupy byte addresses:
         * 0x1000 to 0x103F.
         */
        write_word(
            32'h0000103C,
            32'hCAFEBABE,
            4'b1111
        );

        read_word(32'h0000103C);

        if (read_data == 32'hCAFEBABE &&
            !access_fault) begin

            pass("Final memory word");
        end
        else begin
            fail("Final memory word");
        end

        /*
         * Test 8: address below the configured memory.
         */
        read_word(32'h00000FFC);

        if (response_valid &&
            access_fault &&
            read_data == 32'h00000000) begin

            pass("Address below memory detected");
        end
        else begin
            fail("Address below memory detected");
        end

        /*
         * Test 9: address above the configured memory.
         */
        read_word(32'h00001040);

        if (response_valid &&
            access_fault &&
            read_data == 32'h00000000) begin

            pass("Address above memory detected");
        end
        else begin
            fail("Address above memory detected");
        end

        /*
         * Test 10: no request means no response.
         */
        @(negedge clk);
        set_idle();

        @(posedge clk);
        #1;

        if (!response_valid &&
            !access_fault) begin

            pass("Idle cycle produces no response");
        end
        else begin
            fail("Idle cycle produces no response");
        end

        /*
         * Test 11: back-to-back requests.
         */
        @(negedge clk);

        request      = 1'b1;
        write_enable = 1'b0;
        address      = 32'h00001000;
        byte_enable  = 4'b0000;

        @(posedge clk);
        #1;

        if (!response_valid ||
            access_fault ||
            read_data != 32'hA5A55A5A) begin

            fail("First back-to-back read");
        end
        else begin
            pass("First back-to-back read");
        end

        @(negedge clk);
        address = 32'h0000103C;

        @(posedge clk);
        #1;

        if (!response_valid ||
            access_fault ||
            read_data != 32'hCAFEBABE) begin

            fail("Second back-to-back read");
        end
        else begin
            pass("Second back-to-back read");
        end

        @(negedge clk);
        set_idle();

        /*
         * Final result.
         */
        if (errors == 0) begin
            $display(
                "\nALL 11 DATA MEMORY CHECKS PASSED"
            );
        end
        else begin
            $display(
                "\nDATA MEMORY TEST FAILED: %0d error(s)",
                errors
            );
        end

        $finish;
    end

endmodule