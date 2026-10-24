`timescale 1ns/1ps

module tb_load_store_control;

    logic memory_access_valid;
    logic memory_read;
    logic memory_write;

    logic [2:0]  funct3;
    logic [31:0] address;
    logic [31:0] store_data;
    logic [31:0] memory_read_data;

    logic memory_request;
    logic memory_write_enable;

    logic [31:0] memory_address;
    logic [31:0] memory_write_data;
    logic [3:0]  memory_byte_enable;

    logic [31:0] load_data;

    logic access_misaligned;
    logic illegal_memory_operation;

    integer errors;

    load_store_control dut (
        .memory_access_valid     (memory_access_valid),

        .memory_read             (memory_read),
        .memory_write            (memory_write),

        .funct3                  (funct3),
        .address                 (address),

        .store_data              (store_data),
        .memory_read_data        (memory_read_data),

        .memory_request          (memory_request),
        .memory_write_enable     (memory_write_enable),

        .memory_address          (memory_address),
        .memory_write_data       (memory_write_data),
        .memory_byte_enable      (memory_byte_enable),

        .load_data               (load_data),

        .access_misaligned       (access_misaligned),
        .illegal_memory_operation(
            illegal_memory_operation
        )
    );

    task automatic defaults;
        begin
            memory_access_valid = 1'b1;
            memory_read         = 1'b0;
            memory_write        = 1'b0;

            funct3              = 3'b000;
            address             = 32'h00001000;
            store_data          = 32'h12345678;
            memory_read_data    = 32'h80FF7F01;
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

    task automatic wait_comb;
        begin
            #1;
        end
    endtask

    initial begin
        errors = 0;

        /*
         * Test 1: invalid pipeline entry.
         */
        defaults();

        memory_access_valid = 1'b0;
        memory_read         = 1'b1;

        wait_comb();

        if (!memory_request &&
            !memory_write_enable &&
            !access_misaligned &&
            !illegal_memory_operation) begin

            pass("Invalid pipeline entry");
        end
        else begin
            fail("Invalid pipeline entry");
        end

        /*
         * Test 2: no memory operation.
         */
        defaults();
        wait_comb();

        if (!memory_request &&
            !memory_write_enable &&
            load_data == 32'h00000000) begin

            pass("Non-memory instruction");
        end
        else begin
            fail("Non-memory instruction");
        end

        /*
         * memory_read_data = 0x80FF7F01
         *
         * Address offset 0 -> 0x01
         * Address offset 1 -> 0x7F
         * Address offset 2 -> 0xFF
         * Address offset 3 -> 0x80
         */

        /*
         * Test 3: LB positive byte.
         */
        defaults();

        memory_read = 1'b1;
        funct3      = 3'b000;
        address     = 32'h00001001;

        wait_comb();

        if (memory_request &&
            load_data == 32'h0000007F &&
            !access_misaligned &&
            !illegal_memory_operation) begin

            pass("LB positive byte");
        end
        else begin
            fail("LB positive byte");
        end

        /*
         * Test 4: LB negative byte with sign extension.
         */
        defaults();

        memory_read = 1'b1;
        funct3      = 3'b000;
        address     = 32'h00001003;

        wait_comb();

        if (memory_request &&
            load_data == 32'hFFFFFF80) begin

            pass("LB negative sign extension");
        end
        else begin
            fail("LB negative sign extension");
        end

        /*
         * Test 5: LBU does not sign-extend.
         */
        defaults();

        memory_read = 1'b1;
        funct3      = 3'b100;
        address     = 32'h00001003;

        wait_comb();

        if (memory_request &&
            load_data == 32'h00000080) begin

            pass("LBU zero extension");
        end
        else begin
            fail("LBU zero extension");
        end

        /*
         * Test 6: LH lower halfword.
         */
        defaults();

        memory_read = 1'b1;
        funct3      = 3'b001;
        address     = 32'h00001000;

        wait_comb();

        if (memory_request &&
            load_data == 32'h00007F01 &&
            !access_misaligned) begin

            pass("LH lower halfword");
        end
        else begin
            fail("LH lower halfword");
        end

        /*
         * Test 7: LH upper negative halfword.
         */
        defaults();

        memory_read = 1'b1;
        funct3      = 3'b001;
        address     = 32'h00001002;

        wait_comb();

        if (memory_request &&
            load_data == 32'hFFFF80FF &&
            !access_misaligned) begin

            pass("LH upper sign extension");
        end
        else begin
            fail("LH upper sign extension");
        end

        /*
         * Test 8: LHU upper halfword.
         */
        defaults();

        memory_read = 1'b1;
        funct3      = 3'b101;
        address     = 32'h00001002;

        wait_comb();

        if (memory_request &&
            load_data == 32'h000080FF) begin

            pass("LHU zero extension");
        end
        else begin
            fail("LHU zero extension");
        end

        /*
         * Test 9: LW.
         */
        defaults();

        memory_read = 1'b1;
        funct3      = 3'b010;
        address     = 32'h00001000;

        wait_comb();

        if (memory_request &&
            load_data == 32'h80FF7F01 &&
            !access_misaligned) begin

            pass("LW complete word");
        end
        else begin
            fail("LW complete word");
        end

        /*
         * Test 10: misaligned LH.
         */
        defaults();

        memory_read = 1'b1;
        funct3      = 3'b001;
        address     = 32'h00001001;

        wait_comb();

        if (!memory_request &&
            access_misaligned) begin

            pass("Misaligned LH detection");
        end
        else begin
            fail("Misaligned LH detection");
        end

        /*
         * Test 11: misaligned LW.
         */
        defaults();

        memory_read = 1'b1;
        funct3      = 3'b010;
        address     = 32'h00001002;

        wait_comb();

        if (!memory_request &&
            access_misaligned) begin

            pass("Misaligned LW detection");
        end
        else begin
            fail("Misaligned LW detection");
        end

        /*
         * Test 12: SB lane zero.
         */
        defaults();

        memory_write = 1'b1;
        funct3       = 3'b000;
        address      = 32'h00001000;
        store_data   = 32'h123456A5;

        wait_comb();

        if (memory_request &&
            memory_write_enable &&
            memory_byte_enable == 4'b0001 &&
            memory_write_data == 32'hA5A5A5A5) begin

            pass("SB byte lane zero");
        end
        else begin
            fail("SB byte lane zero");
        end

        /*
         * Test 13: SB lane three.
         */
        defaults();

        memory_write = 1'b1;
        funct3       = 3'b000;
        address      = 32'h00001003;
        store_data   = 32'h0000005A;

        wait_comb();

        if (memory_request &&
            memory_write_enable &&
            memory_byte_enable == 4'b1000 &&
            memory_write_data == 32'h5A5A5A5A) begin

            pass("SB byte lane three");
        end
        else begin
            fail("SB byte lane three");
        end

        /*
         * Test 14: SH lower halfword.
         */
        defaults();

        memory_write = 1'b1;
        funct3       = 3'b001;
        address      = 32'h00001000;
        store_data   = 32'h1234BEEF;

        wait_comb();

        if (memory_request &&
            memory_write_enable &&
            memory_byte_enable == 4'b0011 &&
            memory_write_data == 32'hBEEFBEEF) begin

            pass("SH lower halfword");
        end
        else begin
            fail("SH lower halfword");
        end

        /*
         * Test 15: SH upper halfword.
         */
        defaults();

        memory_write = 1'b1;
        funct3       = 3'b001;
        address      = 32'h00001002;
        store_data   = 32'h1234CAFE;

        wait_comb();

        if (memory_request &&
            memory_write_enable &&
            memory_byte_enable == 4'b1100 &&
            memory_write_data == 32'hCAFECAFE) begin

            pass("SH upper halfword");
        end
        else begin
            fail("SH upper halfword");
        end

        /*
         * Test 16: misaligned SH.
         */
        defaults();

        memory_write = 1'b1;
        funct3       = 3'b001;
        address      = 32'h00001001;

        wait_comb();

        if (!memory_request &&
            !memory_write_enable &&
            access_misaligned) begin

            pass("Misaligned SH detection");
        end
        else begin
            fail("Misaligned SH detection");
        end

        /*
         * Test 17: SW.
         */
        defaults();

        memory_write = 1'b1;
        funct3       = 3'b010;
        address      = 32'h00001000;
        store_data   = 32'hDEADBEEF;

        wait_comb();

        if (memory_request &&
            memory_write_enable &&
            memory_byte_enable == 4'b1111 &&
            memory_write_data == 32'hDEADBEEF) begin

            pass("SW complete word");
        end
        else begin
            fail("SW complete word");
        end

        /*
         * Test 18: misaligned SW.
         */
        defaults();

        memory_write = 1'b1;
        funct3       = 3'b010;
        address      = 32'h00001002;

        wait_comb();

        if (!memory_request &&
            !memory_write_enable &&
            access_misaligned) begin

            pass("Misaligned SW detection");
        end
        else begin
            fail("Misaligned SW detection");
        end

        /*
         * Test 19: illegal load funct3.
         */
        defaults();

        memory_read = 1'b1;
        funct3      = 3'b011;

        wait_comb();

        if (!memory_request &&
            illegal_memory_operation) begin

            pass("Illegal load funct3");
        end
        else begin
            fail("Illegal load funct3");
        end

        /*
         * Test 20: illegal store funct3.
         */
        defaults();

        memory_write = 1'b1;
        funct3       = 3'b111;

        wait_comb();

        if (!memory_request &&
            !memory_write_enable &&
            illegal_memory_operation) begin

            pass("Illegal store funct3");
        end
        else begin
            fail("Illegal store funct3");
        end

        /*
         * Test 21: simultaneous read and write.
         */
        defaults();

        memory_read  = 1'b1;
        memory_write = 1'b1;
        funct3       = 3'b010;

        wait_comb();

        if (!memory_request &&
            !memory_write_enable &&
            illegal_memory_operation) begin

            pass("Illegal simultaneous read and write");
        end
        else begin
            fail("Illegal simultaneous read and write");
        end

        /*
         * Test 22: address passthrough.
         */
        defaults();

        memory_read = 1'b1;
        funct3      = 3'b000;
        address     = 32'h12345673;

        wait_comb();

        if (memory_address == 32'h12345673) begin
            pass("Memory address passthrough");
        end
        else begin
            fail("Memory address passthrough");
        end

        /*
         * Final result.
         */
        if (errors == 0) begin
            $display(
                "\nALL 22 LOAD-STORE CONTROL CHECKS PASSED"
            );
        end
        else begin
            $display(
                "\nLOAD-STORE CONTROL TEST FAILED: %0d error(s)",
                errors
            );
        end

        $finish;
    end

endmodule