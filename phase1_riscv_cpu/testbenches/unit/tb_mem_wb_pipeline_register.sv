`timescale 1ns/1ps

module tb_mem_wb_pipeline_register;

    localparam logic [1:0] RESULT_ALU    = 2'b00;
    localparam logic [1:0] RESULT_MEMORY = 2'b01;
    localparam logic [1:0] RESULT_PC4    = 2'b10;
    localparam logic [1:0] RESULT_NONE   = 2'b11;

    logic clk;
    logic reset;
    logic enable;
    logic flush;

    logic valid_in;
    logic fault_in;
    logic illegal_in;

    logic [31:0] pc_plus4_in;
    logic [31:0] alu_result_in;
    logic [31:0] memory_data_in;

    logic [4:0] rd_in;

    logic       register_write_in;
    logic [1:0] result_source_in;

    logic system_instruction_in;
    logic fence_instruction_in;

    logic valid_out;
    logic fault_out;
    logic illegal_out;

    logic [31:0] pc_plus4_out;
    logic [31:0] alu_result_out;
    logic [31:0] memory_data_out;

    logic [4:0] rd_out;

    logic       register_write_out;
    logic [1:0] result_source_out;

    logic system_instruction_out;
    logic fence_instruction_out;

    integer errors;

    mem_wb_pipeline_register dut (
        .clk                    (clk),
        .reset                  (reset),
        .enable                 (enable),
        .flush                  (flush),

        .valid_in               (valid_in),
        .fault_in               (fault_in),
        .illegal_in             (illegal_in),

        .pc_plus4_in            (pc_plus4_in),
        .alu_result_in          (alu_result_in),
        .memory_data_in         (memory_data_in),

        .rd_in                  (rd_in),

        .register_write_in      (register_write_in),
        .result_source_in       (result_source_in),

        .system_instruction_in  (system_instruction_in),
        .fence_instruction_in   (fence_instruction_in),

        .valid_out              (valid_out),
        .fault_out              (fault_out),
        .illegal_out            (illegal_out),

        .pc_plus4_out           (pc_plus4_out),
        .alu_result_out         (alu_result_out),
        .memory_data_out        (memory_data_out),

        .rd_out                 (rd_out),

        .register_write_out     (register_write_out),
        .result_source_out      (result_source_out),

        .system_instruction_out (system_instruction_out),
        .fence_instruction_out  (fence_instruction_out)
    );

    initial begin
        clk = 1'b0;
    end

    always #5 clk = ~clk;

    task automatic defaults;
        begin
            reset                 = 1'b0;
            enable                = 1'b1;
            flush                 = 1'b0;

            valid_in              = 1'b0;
            fault_in              = 1'b0;
            illegal_in            = 1'b0;

            pc_plus4_in           = 32'h00000004;
            alu_result_in         = 32'h00000000;
            memory_data_in        = 32'h00000000;

            rd_in                 = 5'd0;

            register_write_in     = 1'b0;
            result_source_in      = RESULT_NONE;

            system_instruction_in = 1'b0;
            fence_instruction_in  = 1'b0;
        end
    endtask

    task automatic capture;
        begin
            @(posedge clk);
            #1;
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

    initial begin
        errors = 0;
        defaults();

        /*
         * Test 1: synchronous reset.
         */
        reset = 1'b1;
        capture();

        if (!valid_out &&
            !fault_out &&
            !illegal_out &&
            pc_plus4_out == 32'h00000004 &&
            alu_result_out == 32'h00000000 &&
            memory_data_out == 32'h00000000 &&
            rd_out == 5'd0 &&
            !register_write_out &&
            result_source_out == RESULT_NONE) begin

            pass("Reset creates MEM/WB bubble");
        end
        else begin
            fail("Reset creates MEM/WB bubble");
        end

        /*
         * Test 2: capture an ALU result.
         */
        defaults();

        valid_in          = 1'b1;
        pc_plus4_in       = 32'h00000104;
        alu_result_in     = 32'h12345678;
        memory_data_in    = 32'hAAAAAAAA;
        rd_in             = 5'd8;
        register_write_in = 1'b1;
        result_source_in  = RESULT_ALU;

        capture();

        if (valid_out &&
            !fault_out &&
            !illegal_out &&
            pc_plus4_out == 32'h00000104 &&
            alu_result_out == 32'h12345678 &&
            memory_data_out == 32'hAAAAAAAA &&
            rd_out == 5'd8 &&
            register_write_out &&
            result_source_out == RESULT_ALU) begin

            pass("Capture ALU write-back payload");
        end
        else begin
            fail("Capture ALU write-back payload");
        end

        /*
         * Test 3: capture a load result.
         */
        defaults();

        valid_in          = 1'b1;
        pc_plus4_in       = 32'h00000204;
        alu_result_in     = 32'h00001020;
        memory_data_in    = 32'hDEADBEEF;
        rd_in             = 5'd12;
        register_write_in = 1'b1;
        result_source_in  = RESULT_MEMORY;

        capture();

        if (valid_out &&
            memory_data_out == 32'hDEADBEEF &&
            alu_result_out == 32'h00001020 &&
            rd_out == 5'd12 &&
            register_write_out &&
            result_source_out == RESULT_MEMORY) begin

            pass("Capture memory write-back payload");
        end
        else begin
            fail("Capture memory write-back payload");
        end

        /*
         * Test 4: capture JAL/JALR PC+4 result.
         */
        defaults();

        valid_in          = 1'b1;
        pc_plus4_in       = 32'h00000304;
        alu_result_in     = 32'h00000000;
        memory_data_in    = 32'h00000000;
        rd_in             = 5'd1;
        register_write_in = 1'b1;
        result_source_in  = RESULT_PC4;

        capture();

        if (valid_out &&
            pc_plus4_out == 32'h00000304 &&
            rd_out == 5'd1 &&
            register_write_out &&
            result_source_out == RESULT_PC4) begin

            pass("Capture PC+4 write-back payload");
        end
        else begin
            fail("Capture PC+4 write-back payload");
        end

        /*
         * Test 5: pipeline stall must hold previous values.
         */
        defaults();

        enable            = 1'b0;
        valid_in          = 1'b1;
        pc_plus4_in       = 32'h11111111;
        alu_result_in     = 32'h22222222;
        memory_data_in    = 32'h33333333;
        rd_in             = 5'd20;
        register_write_in = 1'b0;
        result_source_in  = RESULT_ALU;

        capture();

        if (valid_out &&
            pc_plus4_out == 32'h00000304 &&
            rd_out == 5'd1 &&
            register_write_out &&
            result_source_out == RESULT_PC4) begin

            pass("Stall holds MEM/WB payload");
        end
        else begin
            fail("Stall holds MEM/WB payload");
        end

        /*
         * Test 6: flush inserts a bubble.
         */
        defaults();

        flush             = 1'b1;
        valid_in          = 1'b1;
        register_write_in = 1'b1;

        capture();

        if (!valid_out &&
            !fault_out &&
            !illegal_out &&
            !register_write_out &&
            result_source_out == RESULT_NONE &&
            rd_out == 5'd0) begin

            pass("Flush inserts MEM/WB bubble");
        end
        else begin
            fail("Flush inserts MEM/WB bubble");
        end

        /*
         * Test 7: propagate fault and illegal state.
         */
        defaults();

        valid_in          = 1'b1;
        fault_in          = 1'b1;
        illegal_in        = 1'b1;

        pc_plus4_in       = 32'h00000404;
        alu_result_in     = 32'h00004000;
        memory_data_in    = 32'h5555AAAA;

        rd_in             = 5'd10;

        /*
         * Side effects must already have been suppressed by
         * the integrated Memory stage.
         */
        register_write_in = 1'b0;
        result_source_in  = RESULT_NONE;

        capture();

        if (valid_out &&
            fault_out &&
            illegal_out &&
            !register_write_out &&
            result_source_out == RESULT_NONE) begin

            pass("Fault and illegal propagation");
        end
        else begin
            fail("Fault and illegal propagation");
        end

        /*
         * Test 8: capture SYSTEM instruction status.
         */
        defaults();

        valid_in              = 1'b1;
        system_instruction_in = 1'b1;
        result_source_in      = RESULT_NONE;

        capture();

        if (valid_out &&
            system_instruction_out &&
            !fence_instruction_out &&
            !register_write_out) begin

            pass("Capture SYSTEM instruction");
        end
        else begin
            fail("Capture SYSTEM instruction");
        end

        /*
         * Test 9: capture FENCE instruction status.
         */
        defaults();

        valid_in             = 1'b1;
        fence_instruction_in = 1'b1;
        result_source_in     = RESULT_NONE;

        capture();

        if (valid_out &&
            fence_instruction_out &&
            !system_instruction_out &&
            !register_write_out) begin

            pass("Capture FENCE instruction");
        end
        else begin
            fail("Capture FENCE instruction");
        end

        /*
         * Test 10: reset has priority over flush and enable.
         */
        defaults();

        reset             = 1'b1;
        flush             = 1'b1;
        enable            = 1'b1;

        valid_in          = 1'b1;
        fault_in          = 1'b1;
        illegal_in        = 1'b1;
        register_write_in = 1'b1;

        capture();

        if (!valid_out &&
            !fault_out &&
            !illegal_out &&
            !register_write_out &&
            result_source_out == RESULT_NONE) begin

            pass("Reset has highest priority");
        end
        else begin
            fail("Reset has highest priority");
        end

        /*
         * Final result.
         */
        if (errors == 0) begin
            $display(
                "\nALL 10 MEM/WB PIPELINE REGISTER CHECKS PASSED"
            );
        end
        else begin
            $display(
                "\nMEM/WB PIPELINE REGISTER TEST FAILED: %0d error(s)",
                errors
            );
        end

        $finish;
    end

endmodule