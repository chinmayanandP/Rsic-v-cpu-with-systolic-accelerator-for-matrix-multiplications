`timescale 1ns/1ps

module tb_write_back_mux;

    localparam logic [1:0] RESULT_ALU    = 2'b00;
    localparam logic [1:0] RESULT_MEMORY = 2'b01;
    localparam logic [1:0] RESULT_PC4    = 2'b10;
    localparam logic [1:0] RESULT_NONE   = 2'b11;

    logic [31:0] alu_result;
    logic [31:0] memory_data;
    logic [31:0] pc_plus4;

    logic [1:0] result_source;

    logic [31:0] write_back_data;
    logic        write_back_data_valid;

    integer errors;

    write_back_mux dut (
        .alu_result           (alu_result),
        .memory_data          (memory_data),
        .pc_plus4             (pc_plus4),

        .result_source        (result_source),

        .write_back_data      (write_back_data),
        .write_back_data_valid(write_back_data_valid)
    );

    task automatic defaults;
        begin
            alu_result    = 32'h12345678;
            memory_data   = 32'hDEADBEEF;
            pc_plus4      = 32'h00000104;
            result_source = RESULT_NONE;
        end
    endtask

    task automatic pass(input string test_name);
        begin
            $display(
                "PASS: %s data=%08h valid=%0b",
                test_name,
                write_back_data,
                write_back_data_valid
            );
        end
    endtask

    task automatic fail(input string test_name);
        begin
            errors = errors + 1;

            $display(
                "FAIL: %s data=%08h valid=%0b",
                test_name,
                write_back_data,
                write_back_data_valid
            );
        end
    endtask

    initial begin
        errors = 0;
        defaults();

        /*
         * Test 1: ALU result selection.
         */
        result_source = RESULT_ALU;
        #1;

        if (write_back_data == 32'h12345678 &&
            write_back_data_valid) begin

            pass("Select ALU result");
        end
        else begin
            fail("Select ALU result");
        end

        /*
         * Test 2: memory-data selection.
         */
        result_source = RESULT_MEMORY;
        #1;

        if (write_back_data == 32'hDEADBEEF &&
            write_back_data_valid) begin

            pass("Select memory data");
        end
        else begin
            fail("Select memory data");
        end

        /*
         * Test 3: PC+4 selection.
         */
        result_source = RESULT_PC4;
        #1;

        if (write_back_data == 32'h00000104 &&
            write_back_data_valid) begin

            pass("Select PC+4");
        end
        else begin
            fail("Select PC+4");
        end

        /*
         * Test 4: no write-back result.
         */
        result_source = RESULT_NONE;
        #1;

        if (write_back_data == 32'h00000000 &&
            !write_back_data_valid) begin

            pass("No write-back result");
        end
        else begin
            fail("No write-back result");
        end

        /*
         * Test 5: verify that the selected source follows changes.
         */
        result_source = RESULT_MEMORY;
        memory_data   = 32'hA5A55A5A;
        #1;

        if (write_back_data == 32'hA5A55A5A &&
            write_back_data_valid) begin

            pass("Selected input updates correctly");
        end
        else begin
            fail("Selected input updates correctly");
        end

        /*
         * Test 6: unselected input changes must not affect output.
         */
        alu_result = 32'hFFFFFFFF;
        pc_plus4   = 32'hAAAAAAAA;
        #1;

        if (write_back_data == 32'hA5A55A5A &&
            write_back_data_valid) begin

            pass("Unselected inputs do not affect output");
        end
        else begin
            fail("Unselected inputs do not affect output");
        end

        if (errors == 0) begin
            $display(
                "\nALL 6 WRITE-BACK MUX CHECKS PASSED"
            );
        end
        else begin
            $display(
                "\nWRITE-BACK MUX TEST FAILED: %0d error(s)",
                errors
            );
        end

        $finish;
    end

endmodule