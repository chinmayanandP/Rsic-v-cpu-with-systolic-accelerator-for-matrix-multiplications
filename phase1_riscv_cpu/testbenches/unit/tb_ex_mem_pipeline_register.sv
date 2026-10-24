`timescale 1ns/1ps

module tb_ex_mem_pipeline_register;

    logic clk;
    logic reset;
    logic enable;
    logic flush;

    logic valid_in;
    logic fault_in;
    logic illegal_in;

    logic [31:0] pc_plus4_in;
    logic [31:0] alu_result_in;
    logic [31:0] store_data_in;

    logic [4:0] rd_in;
    logic [2:0] funct3_in;

    logic register_write_in;
    logic memory_read_in;
    logic memory_write_in;
    logic [1:0] result_source_in;

    logic system_instruction_in;
    logic fence_instruction_in;

    logic valid_out;
    logic fault_out;
    logic illegal_out;

    logic [31:0] pc_plus4_out;
    logic [31:0] alu_result_out;
    logic [31:0] store_data_out;

    logic [4:0] rd_out;
    logic [2:0] funct3_out;

    logic register_write_out;
    logic memory_read_out;
    logic memory_write_out;
    logic [1:0] result_source_out;

    logic system_instruction_out;
    logic fence_instruction_out;

    integer checks;
    integer errors;

    ex_mem_pipeline_register dut (.*);

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic check_bubble(
        input string test_name
    );
        begin
            if ((valid_out          !== 1'b0) ||
                (register_write_out !== 1'b0) ||
                (memory_read_out    !== 1'b0) ||
                (memory_write_out   !== 1'b0)) begin

                errors = errors + 1;
                $display("FAIL: %s", test_name);
            end
            else begin
                checks = checks + 1;
                $display("PASS: %s", test_name);
            end
        end
    endtask

    task automatic check_load_payload(
        input string test_name
    );
        begin
            if ((valid_out          !== 1'b1)          ||
                (fault_out          !== 1'b0)          ||
                (illegal_out        !== 1'b0)          ||
                (pc_plus4_out       !== 32'h00000104) ||
                (alu_result_out     !== 32'h0000200C) ||
                (store_data_out     !== 32'hA5A55A5A) ||
                (rd_out             !== 5'd4)          ||
                (funct3_out         !== 3'b010)        ||
                (register_write_out !== 1'b1)          ||
                (memory_read_out    !== 1'b1)          ||
                (memory_write_out   !== 1'b0)          ||
                (result_source_out  !== 2'b01)) begin

                errors = errors + 1;
                $display("FAIL: %s", test_name);
            end
            else begin
                checks = checks + 1;
                $display("PASS: %s", test_name);
            end
        end
    endtask

    initial begin
        checks = 0;
        errors = 0;

        reset  = 1'b1;
        enable = 1'b0;
        flush  = 1'b0;

        valid_in   = 1'b0;
        fault_in   = 1'b0;
        illegal_in = 1'b0;

        pc_plus4_in   = 32'h00000004;
        alu_result_in = 32'h00000000;
        store_data_in = 32'h00000000;

        rd_in     = 5'd0;
        funct3_in = 3'd0;

        register_write_in = 1'b0;
        memory_read_in    = 1'b0;
        memory_write_in   = 1'b0;
        result_source_in  = 2'b11;

        system_instruction_in = 1'b0;
        fence_instruction_in  = 1'b0;

        /*
         * Test 1: synchronous reset.
         */
        @(posedge clk);
        #1;

        check_bubble("Reset creates EX/MEM bubble");

        /*
         * Test 2: capture a load payload.
         */
        reset  = 1'b0;
        enable = 1'b1;
        flush  = 1'b0;

        valid_in   = 1'b1;
        fault_in   = 1'b0;
        illegal_in = 1'b0;

        pc_plus4_in   = 32'h00000104;
        alu_result_in = 32'h0000200C;
        store_data_in = 32'hA5A55A5A;

        rd_in     = 5'd4;
        funct3_in = 3'b010;

        register_write_in = 1'b1;
        memory_read_in    = 1'b1;
        memory_write_in   = 1'b0;
        result_source_in  = 2'b01;

        @(posedge clk);
        #1;

        check_load_payload("Capture load payload");

        /*
         * Test 3: hold during stall.
         */
        enable = 1'b0;

        pc_plus4_in       = 32'hFFFFFFFF;
        alu_result_in     = 32'hFFFFFFFF;
        store_data_in     = 32'hFFFFFFFF;
        memory_read_in    = 1'b0;
        memory_write_in   = 1'b1;
        register_write_in = 1'b0;

        @(posedge clk);
        #1;

        check_load_payload("Stall holds EX/MEM payload");

        /*
         * Test 4: flush overrides enable.
         */
        enable = 1'b1;
        flush  = 1'b1;

        @(posedge clk);
        #1;

        check_bubble("Flush inserts EX/MEM bubble");

        /*
         * Test 5: capture a store payload.
         */
        flush      = 1'b0;
        valid_in   = 1'b1;
        fault_in   = 1'b0;
        illegal_in = 1'b0;

        pc_plus4_in   = 32'h00000204;
        alu_result_in = 32'h00003008;
        store_data_in = 32'h12345678;

        rd_in     = 5'd0;
        funct3_in = 3'b010;

        register_write_in = 1'b0;
        memory_read_in    = 1'b0;
        memory_write_in   = 1'b1;
        result_source_in  = 2'b11;

        @(posedge clk);
        #1;

        if ((valid_out          !== 1'b1)          ||
            (alu_result_out     !== 32'h00003008) ||
            (store_data_out     !== 32'h12345678) ||
            (memory_read_out    !== 1'b0)          ||
            (memory_write_out   !== 1'b1)          ||
            (register_write_out !== 1'b0)) begin

            errors = errors + 1;
            $display("FAIL: Capture store payload");
        end
        else begin
            checks = checks + 1;
            $display("PASS: Capture store payload");
        end

        /*
         * Test 6: fault and illegal status propagation.
         */
        fault_in   = 1'b1;
        illegal_in = 1'b1;

        register_write_in = 1'b0;
        memory_read_in    = 1'b0;
        memory_write_in   = 1'b0;

        @(posedge clk);
        #1;

        if ((valid_out   !== 1'b1) ||
            (fault_out   !== 1'b1) ||
            (illegal_out !== 1'b1)) begin

            errors = errors + 1;
            $display("FAIL: Fault and illegal propagation");
        end
        else begin
            checks = checks + 1;
            $display("PASS: Fault and illegal propagation");
        end

        /*
         * Test 7: reset has highest priority.
         */
        reset  = 1'b1;
        flush  = 1'b1;
        enable = 1'b1;

        @(posedge clk);
        #1;

        check_bubble("Reset has highest priority");

        $display("");

        if (errors == 0) begin
            $display(
                "ALL %0d EX/MEM PIPELINE REGISTER CHECKS PASSED",
                checks
            );
        end
        else begin
            $display(
                "EX/MEM PIPELINE REGISTER TEST FAILED: %0d error(s)",
                errors
            );

            $fatal(1);
        end

        $finish;
    end

endmodule