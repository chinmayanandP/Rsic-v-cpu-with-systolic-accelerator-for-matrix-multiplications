`timescale 1ns/1ps

module tb_write_back_stage;

    localparam logic [1:0] RESULT_ALU    = 2'b00;
    localparam logic [1:0] RESULT_MEMORY = 2'b01;
    localparam logic [1:0] RESULT_PC4    = 2'b10;
    localparam logic [1:0] RESULT_NONE   = 2'b11;

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

    logic        register_file_write_enable_out;
    logic [4:0]  register_file_write_address_out;
    logic [31:0] register_file_write_data_out;

    logic [31:0] write_back_value_out;
    logic        write_back_value_valid_out;

    logic instruction_retired_out;
    logic exception_valid_out;
    logic system_event_valid_out;
    logic fence_completed_out;

    integer errors;

    write_back_stage dut (
        .valid_in                       (valid_in),
        .fault_in                       (fault_in),
        .illegal_in                     (illegal_in),

        .pc_plus4_in                    (pc_plus4_in),
        .alu_result_in                  (alu_result_in),
        .memory_data_in                 (memory_data_in),

        .rd_in                          (rd_in),

        .register_write_in              (register_write_in),
        .result_source_in               (result_source_in),

        .system_instruction_in          (
            system_instruction_in
        ),
        .fence_instruction_in           (
            fence_instruction_in
        ),

        .register_file_write_enable_out (
            register_file_write_enable_out
        ),
        .register_file_write_address_out(
            register_file_write_address_out
        ),
        .register_file_write_data_out   (
            register_file_write_data_out
        ),

        .write_back_value_out           (
            write_back_value_out
        ),
        .write_back_value_valid_out     (
            write_back_value_valid_out
        ),

        .instruction_retired_out        (
            instruction_retired_out
        ),
        .exception_valid_out            (
            exception_valid_out
        ),
        .system_event_valid_out         (
            system_event_valid_out
        ),
        .fence_completed_out            (
            fence_completed_out
        )
    );

    task automatic defaults;
        begin
            valid_in             = 1'b1;
            fault_in             = 1'b0;
            illegal_in           = 1'b0;

            pc_plus4_in          = 32'h00000104;
            alu_result_in        = 32'h12345678;
            memory_data_in       = 32'hDEADBEEF;

            rd_in                = 5'd5;

            register_write_in    = 1'b1;
            result_source_in     = RESULT_ALU;

            system_instruction_in= 1'b0;
            fence_instruction_in = 1'b0;
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

        /*
         * Test 1: ALU result write-back.
         */
        defaults();
        result_source_in = RESULT_ALU;
        #1;

        if (register_file_write_enable_out &&
            register_file_write_address_out == 5'd5 &&
            register_file_write_data_out == 32'h12345678 &&
            write_back_value_out == 32'h12345678 &&
            write_back_value_valid_out &&
            instruction_retired_out &&
            !exception_valid_out) begin

            pass("Integrated ALU write-back");
        end
        else begin
            fail("Integrated ALU write-back");
        end

        /*
         * Test 2: load result write-back.
         */
        defaults();

        rd_in            = 5'd8;
        result_source_in = RESULT_MEMORY;
        #1;

        if (register_file_write_enable_out &&
            register_file_write_address_out == 5'd8 &&
            register_file_write_data_out == 32'hDEADBEEF &&
            write_back_value_out == 32'hDEADBEEF &&
            write_back_value_valid_out) begin

            pass("Integrated memory write-back");
        end
        else begin
            fail("Integrated memory write-back");
        end

        /*
         * Test 3: JAL/JALR PC+4 write-back.
         */
        defaults();

        rd_in            = 5'd1;
        result_source_in = RESULT_PC4;
        #1;

        if (register_file_write_enable_out &&
            register_file_write_address_out == 5'd1 &&
            register_file_write_data_out == 32'h00000104 &&
            write_back_value_out == 32'h00000104) begin

            pass("Integrated PC+4 write-back");
        end
        else begin
            fail("Integrated PC+4 write-back");
        end

        /*
         * Test 4: store/branch with no write-back value.
         */
        defaults();

        register_write_in = 1'b0;
        result_source_in  = RESULT_NONE;
        rd_in             = 5'd0;
        #1;

        if (!register_file_write_enable_out &&
            !write_back_value_valid_out &&
            instruction_retired_out) begin

            pass("Instruction with no register result");
        end
        else begin
            fail("Instruction with no register result");
        end

        /*
         * Test 5: write to x0.
         */
        defaults();

        rd_in = 5'd0;
        #1;

        if (!register_file_write_enable_out &&
            !write_back_value_valid_out &&
            instruction_retired_out) begin

            pass("Integrated x0 protection");
        end
        else begin
            fail("Integrated x0 protection");
        end

        /*
         * Test 6: invalid pipeline entry.
         */
        defaults();

        valid_in = 1'b0;
        #1;

        if (!register_file_write_enable_out &&
            !write_back_value_valid_out &&
            !instruction_retired_out &&
            !exception_valid_out) begin

            pass("Integrated invalid-entry handling");
        end
        else begin
            fail("Integrated invalid-entry handling");
        end

        /*
         * Test 7: faulted instruction.
         */
        defaults();

        fault_in = 1'b1;
        #1;

        if (!register_file_write_enable_out &&
            !write_back_value_valid_out &&
            exception_valid_out &&
            !instruction_retired_out) begin

            pass("Integrated fault handling");
        end
        else begin
            fail("Integrated fault handling");
        end

        /*
         * Test 8: illegal instruction.
         */
        defaults();

        illegal_in = 1'b1;
        #1;

        if (!register_file_write_enable_out &&
            exception_valid_out &&
            !instruction_retired_out) begin

            pass("Integrated illegal-instruction handling");
        end
        else begin
            fail("Integrated illegal-instruction handling");
        end

        /*
         * Test 9: SYSTEM event.
         */
        defaults();

        register_write_in     = 1'b0;
        result_source_in      = RESULT_NONE;
        rd_in                 = 5'd0;
        system_instruction_in = 1'b1;
        #1;

        if (!register_file_write_enable_out &&
            system_event_valid_out &&
            !instruction_retired_out &&
            !exception_valid_out) begin

            pass("Integrated SYSTEM event");
        end
        else begin
            fail("Integrated SYSTEM event");
        end

        /*
         * Test 10: FENCE completion.
         */
        defaults();

        register_write_in    = 1'b0;
        result_source_in     = RESULT_NONE;
        rd_in                = 5'd0;
        fence_instruction_in = 1'b1;
        #1;

        if (!register_file_write_enable_out &&
            instruction_retired_out &&
            fence_completed_out &&
            !system_event_valid_out &&
            !exception_valid_out) begin

            pass("Integrated FENCE completion");
        end
        else begin
            fail("Integrated FENCE completion");
        end

        /*
         * Test 11: fault priority over register write.
         */
        defaults();

        fault_in        = 1'b1;
        result_source_in= RESULT_MEMORY;
        rd_in           = 5'd9;
        #1;

        if (!register_file_write_enable_out &&
            !write_back_value_valid_out &&
            exception_valid_out) begin

            pass("Fault priority over write-back");
        end
        else begin
            fail("Fault priority over write-back");
        end

        /*
         * Test 12: selected value updates immediately.
         */
        defaults();

        result_source_in = RESULT_ALU;
        alu_result_in    = 32'hCAFEBABE;
        rd_in            = 5'd31;
        #1;

        if (register_file_write_enable_out &&
            register_file_write_address_out == 5'd31 &&
            register_file_write_data_out == 32'hCAFEBABE &&
            write_back_value_out == 32'hCAFEBABE) begin

            pass("Integrated write-back value update");
        end
        else begin
            fail("Integrated write-back value update");
        end

        if (errors == 0) begin
            $display(
                "\nALL 12 INTEGRATED WRITE-BACK STAGE CHECKS PASSED"
            );
        end
        else begin
            $display(
                "\nINTEGRATED WRITE-BACK STAGE TEST FAILED: %0d error(s)",
                errors
            );
        end

        $finish;
    end

endmodule