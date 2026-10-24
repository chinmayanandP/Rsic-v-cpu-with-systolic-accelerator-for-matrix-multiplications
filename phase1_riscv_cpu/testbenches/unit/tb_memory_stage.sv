`timescale 1ns/1ps

module tb_memory_stage;

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
    logic [31:0] store_data_in;

    logic [4:0] rd_in;
    logic [2:0] funct3_in;

    logic       register_write_in;
    logic       memory_read_in;
    logic       memory_write_in;
    logic [1:0] result_source_in;

    logic system_instruction_in;
    logic fence_instruction_in;

    logic memory_busy_out;

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

    memory_stage #(
        .DATA_MEMORY_WORDS     (16),
        .DATA_MEMORY_BASE      (32'h00001000),
        .DATA_MEMORY_INIT_FILE ("")
    ) dut (
        .clk                    (clk),
        .reset                  (reset),
        .enable                 (enable),
        .flush                  (flush),

        .valid_in               (valid_in),
        .fault_in               (fault_in),
        .illegal_in             (illegal_in),

        .pc_plus4_in            (pc_plus4_in),
        .alu_result_in          (alu_result_in),
        .store_data_in          (store_data_in),

        .rd_in                  (rd_in),
        .funct3_in              (funct3_in),

        .register_write_in      (register_write_in),
        .memory_read_in         (memory_read_in),
        .memory_write_in        (memory_write_in),
        .result_source_in       (result_source_in),

        .system_instruction_in  (system_instruction_in),
        .fence_instruction_in   (fence_instruction_in),

        .memory_busy_out        (memory_busy_out),

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

    initial clk = 1'b0;
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
            store_data_in         = 32'h00000000;

            rd_in                 = 5'd0;
            funct3_in             = 3'b000;

            register_write_in     = 1'b0;
            memory_read_in        = 1'b0;
            memory_write_in       = 1'b0;
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

    task automatic pass(input string name);
        $display("PASS: %s", name);
    endtask

    task automatic fail(input string name);
        begin
            errors = errors + 1;
            $display("FAIL: %s", name);
        end
    endtask

    /*
     * Remove the current EX/MEM instruction after the request
     * has been accepted. In the complete CPU this happens when
     * memory_busy_out releases the upstream pipeline.
     */
    task automatic insert_input_bubble;
        begin
            @(negedge clk);
            valid_in          = 1'b0;
            memory_read_in    = 1'b0;
            memory_write_in   = 1'b0;
            register_write_in = 1'b0;
            result_source_in  = RESULT_NONE;
        end
    endtask

    initial begin
        errors = 0;
        defaults();

        /*
         * Test 1: reset.
         */
        reset = 1'b1;
        capture();
        reset = 1'b0;

        if (!valid_out &&
            !fault_out &&
            !illegal_out &&
            !register_write_out) begin
            pass("Integrated Memory-stage reset");
        end
        else begin
            fail("Integrated Memory-stage reset");
        end

        /*
         * Test 2: non-memory ALU instruction.
         */
        @(negedge clk);
        defaults();

        valid_in          = 1'b1;
        pc_plus4_in       = 32'h00000104;
        alu_result_in     = 32'h12345678;
        rd_in             = 5'd5;
        register_write_in = 1'b1;
        result_source_in  = RESULT_ALU;

        capture();

        if (valid_out &&
            alu_result_out == 32'h12345678 &&
            rd_out == 5'd5 &&
            register_write_out &&
            result_source_out == RESULT_ALU &&
            !memory_busy_out) begin
            pass("Non-memory instruction passthrough");
        end
        else begin
            fail("Non-memory instruction passthrough");
        end

        /*
         * Test 3: SW writes a complete word.
         */
        @(negedge clk);
        defaults();

        valid_in          = 1'b1;
        pc_plus4_in       = 32'h00000204;
        alu_result_in     = 32'h00001000;
        store_data_in     = 32'hDEADBEEF;
        funct3_in         = 3'b010;
        memory_write_in   = 1'b1;
        result_source_in  = RESULT_NONE;

        #1;

        if (memory_busy_out)
            pass("Store requests pipeline wait");
        else
            fail("Store requests pipeline wait");

        capture();
        insert_input_bubble();
        capture();

        if (valid_out &&
            !fault_out &&
            !illegal_out &&
            !register_write_out) begin
            pass("Integrated SW completion");
        end
        else begin
            fail("Integrated SW completion");
        end

        /*
         * Test 4: LW reads the stored word.
         */
        @(negedge clk);
        defaults();

        valid_in          = 1'b1;
        pc_plus4_in       = 32'h00000304;
        alu_result_in     = 32'h00001000;
        rd_in             = 5'd7;
        funct3_in         = 3'b010;
        register_write_in = 1'b1;
        memory_read_in    = 1'b1;
        result_source_in  = RESULT_MEMORY;

        capture();
        insert_input_bubble();
        capture();

        if (valid_out &&
            memory_data_out == 32'hDEADBEEF &&
            rd_out == 5'd7 &&
            register_write_out &&
            result_source_out == RESULT_MEMORY &&
            !fault_out &&
            !illegal_out) begin
            pass("Integrated LW operation");
        end
        else begin
            fail("Integrated LW operation");
        end

        /*
         * Test 5: SB changes only the selected byte.
         */
        @(negedge clk);
        defaults();

        valid_in        = 1'b1;
        alu_result_in   = 32'h00001001;
        store_data_in   = 32'h000000AA;
        funct3_in       = 3'b000;
        memory_write_in = 1'b1;

        capture();
        insert_input_bubble();
        capture();

        /*
         * Test 6: LBU reads the modified byte.
         */
        @(negedge clk);
        defaults();

        valid_in          = 1'b1;
        alu_result_in     = 32'h00001001;
        rd_in             = 5'd8;
        funct3_in         = 3'b100;
        register_write_in = 1'b1;
        memory_read_in    = 1'b1;
        result_source_in  = RESULT_MEMORY;

        capture();
        insert_input_bubble();
        capture();

        if (memory_data_out == 32'h000000AA &&
            register_write_out &&
            !fault_out) begin
            pass("Integrated SB and LBU operations");
        end
        else begin
            fail("Integrated SB and LBU operations");
        end

        /*
         * Test 7: signed byte load.
         */
        @(negedge clk);
        defaults();

        valid_in        = 1'b1;
        alu_result_in   = 32'h00001002;
        store_data_in   = 32'h00000080;
        funct3_in       = 3'b000;
        memory_write_in = 1'b1;

        capture();
        insert_input_bubble();
        capture();

        @(negedge clk);
        defaults();

        valid_in          = 1'b1;
        alu_result_in     = 32'h00001002;
        rd_in             = 5'd9;
        funct3_in         = 3'b000;
        register_write_in = 1'b1;
        memory_read_in    = 1'b1;
        result_source_in  = RESULT_MEMORY;

        capture();
        insert_input_bubble();
        capture();

        if (memory_data_out == 32'hFFFFFF80 &&
            register_write_out) begin
            pass("Integrated signed-byte load");
        end
        else begin
            fail("Integrated signed-byte load");
        end

        /*
         * Test 8: misaligned LW.
         */
        @(negedge clk);
        defaults();

        valid_in          = 1'b1;
        alu_result_in     = 32'h00001002;
        rd_in             = 5'd10;
        funct3_in         = 3'b010;
        register_write_in = 1'b1;
        memory_read_in    = 1'b1;
        result_source_in  = RESULT_MEMORY;

        capture();

        if (valid_out &&
            fault_out &&
            !illegal_out &&
            !register_write_out &&
            !memory_busy_out) begin
            pass("Integrated misaligned-load fault");
        end
        else begin
            fail("Integrated misaligned-load fault");
        end

        /*
         * Test 9: address outside data memory.
         */
        @(negedge clk);
        defaults();

        valid_in          = 1'b1;
        alu_result_in     = 32'h00002000;
        rd_in             = 5'd11;
        funct3_in         = 3'b010;
        register_write_in = 1'b1;
        memory_read_in    = 1'b1;
        result_source_in  = RESULT_MEMORY;

        capture();
        insert_input_bubble();
        capture();

        if (valid_out &&
            fault_out &&
            !register_write_out) begin
            pass("Integrated data-memory access fault");
        end
        else begin
            fail("Integrated data-memory access fault");
        end

        /*
         * Test 10: illegal memory funct3.
         */
        @(negedge clk);
        defaults();

        valid_in          = 1'b1;
        alu_result_in     = 32'h00001000;
        rd_in             = 5'd12;
        funct3_in         = 3'b011;
        register_write_in = 1'b1;
        memory_read_in    = 1'b1;
        result_source_in  = RESULT_MEMORY;

        capture();

        if (valid_out &&
            illegal_out &&
            !register_write_out &&
            !memory_busy_out) begin
            pass("Integrated illegal memory operation");
        end
        else begin
            fail("Integrated illegal memory operation");
        end

        /*
         * Test 11: upstream fault suppresses memory access.
         */
        @(negedge clk);
        defaults();

        valid_in          = 1'b1;
        fault_in          = 1'b1;
        alu_result_in     = 32'h00001000;
        rd_in             = 5'd13;
        funct3_in         = 3'b010;
        register_write_in = 1'b1;
        memory_read_in    = 1'b1;
        result_source_in  = RESULT_MEMORY;

        capture();

        if (valid_out &&
            fault_out &&
            !register_write_out &&
            !memory_busy_out) begin
            pass("Upstream fault suppresses memory request");
        end
        else begin
            fail("Upstream fault suppresses memory request");
        end

        /*
         * Test 12: flush creates a MEM/WB bubble.
         */
        @(negedge clk);
        defaults();

        flush             = 1'b1;
        valid_in          = 1'b1;
        register_write_in = 1'b1;

        capture();

        if (!valid_out &&
            !fault_out &&
            !illegal_out &&
            !register_write_out) begin
            pass("Integrated Memory-stage flush");
        end
        else begin
            fail("Integrated Memory-stage flush");
        end

        if (errors == 0) begin
            $display(
                "\nALL 12 INTEGRATED MEMORY-STAGE CHECKS PASSED"
            );
        end
        else begin
            $display(
                "\nINTEGRATED MEMORY-STAGE TEST FAILED: %0d error(s)",
                errors
            );
        end

        $finish;
    end

endmodule