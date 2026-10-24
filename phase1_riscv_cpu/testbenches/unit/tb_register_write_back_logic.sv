`timescale 1ns/1ps

module tb_register_write_back_logic;

    logic pipeline_valid;
    logic pipeline_fault;
    logic pipeline_illegal;

    logic        register_write_control;
    logic        write_back_data_valid;
    logic [4:0]  destination_register;
    logic [31:0] selected_write_back_data;

    logic system_instruction;
    logic fence_instruction;

    logic        register_file_write_enable;
    logic [4:0]  register_file_write_address;
    logic [31:0] register_file_write_data;

    logic instruction_retired;
    logic exception_valid;
    logic system_event_valid;
    logic fence_completed;

    integer errors;

    register_write_back_logic dut (
        .pipeline_valid             (pipeline_valid),
        .pipeline_fault             (pipeline_fault),
        .pipeline_illegal           (pipeline_illegal),

        .register_write_control     (register_write_control),
        .write_back_data_valid      (write_back_data_valid),
        .destination_register       (destination_register),
        .selected_write_back_data   (
            selected_write_back_data
        ),

        .system_instruction         (system_instruction),
        .fence_instruction          (fence_instruction),

        .register_file_write_enable (
            register_file_write_enable
        ),
        .register_file_write_address(
            register_file_write_address
        ),
        .register_file_write_data   (
            register_file_write_data
        ),

        .instruction_retired        (instruction_retired),
        .exception_valid            (exception_valid),
        .system_event_valid         (system_event_valid),
        .fence_completed            (fence_completed)
    );

    task automatic defaults;
        begin
            pipeline_valid          = 1'b1;
            pipeline_fault          = 1'b0;
            pipeline_illegal        = 1'b0;

            register_write_control  = 1'b1;
            write_back_data_valid   = 1'b1;
            destination_register    = 5'd5;
            selected_write_back_data= 32'h12345678;

            system_instruction      = 1'b0;
            fence_instruction       = 1'b0;
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
         * Test 1: normal register write.
         */
        defaults();
        #1;

        if (register_file_write_enable &&
            register_file_write_address == 5'd5 &&
            register_file_write_data == 32'h12345678 &&
            instruction_retired &&
            !exception_valid &&
            !system_event_valid) begin

            pass("Normal register write-back");
        end
        else begin
            fail("Normal register write-back");
        end

        /*
         * Test 2: write to x0 is suppressed.
         */
        defaults();

        destination_register = 5'd0;
        #1;

        if (!register_file_write_enable &&
            instruction_retired &&
            !exception_valid) begin

            pass("Write to x0 suppressed");
        end
        else begin
            fail("Write to x0 suppressed");
        end

        /*
         * Test 3: invalid pipeline entry.
         */
        defaults();

        pipeline_valid = 1'b0;
        #1;

        if (!register_file_write_enable &&
            !instruction_retired &&
            !exception_valid &&
            !system_event_valid &&
            !fence_completed) begin

            pass("Invalid pipeline entry");
        end
        else begin
            fail("Invalid pipeline entry");
        end

        /*
         * Test 4: pipeline fault.
         */
        defaults();

        pipeline_fault = 1'b1;
        #1;

        if (!register_file_write_enable &&
            !instruction_retired &&
            exception_valid &&
            !system_event_valid) begin

            pass("Fault suppresses write-back");
        end
        else begin
            fail("Fault suppresses write-back");
        end

        /*
         * Test 5: illegal instruction.
         */
        defaults();

        pipeline_illegal = 1'b1;
        #1;

        if (!register_file_write_enable &&
            !instruction_retired &&
            exception_valid) begin

            pass("Illegal instruction suppresses write-back");
        end
        else begin
            fail("Illegal instruction suppresses write-back");
        end

        /*
         * Test 6: register-write control disabled.
         */
        defaults();

        register_write_control = 1'b0;
        #1;

        if (!register_file_write_enable &&
            instruction_retired &&
            !exception_valid) begin

            pass("Disabled register-write control");
        end
        else begin
            fail("Disabled register-write control");
        end

        /*
         * Test 7: selected result is not valid.
         */
        defaults();

        write_back_data_valid = 1'b0;
        #1;

        if (!register_file_write_enable &&
            instruction_retired) begin

            pass("Invalid write-back data suppresses write");
        end
        else begin
            fail("Invalid write-back data suppresses write");
        end

        /*
         * Test 8: SYSTEM instruction.
         */
        defaults();

        system_instruction     = 1'b1;
        register_write_control = 1'b0;
        write_back_data_valid  = 1'b0;
        destination_register   = 5'd0;
        #1;

        if (!register_file_write_enable &&
            !instruction_retired &&
            !exception_valid &&
            system_event_valid &&
            !fence_completed) begin

            pass("SYSTEM instruction event");
        end
        else begin
            fail("SYSTEM instruction event");
        end

        /*
         * Test 9: FENCE instruction.
         */
        defaults();

        fence_instruction      = 1'b1;
        register_write_control = 1'b0;
        write_back_data_valid  = 1'b0;
        destination_register   = 5'd0;
        #1;

        if (!register_file_write_enable &&
            instruction_retired &&
            !exception_valid &&
            !system_event_valid &&
            fence_completed) begin

            pass("FENCE instruction completion");
        end
        else begin
            fail("FENCE instruction completion");
        end

        /*
         * Test 10: a fault has priority over SYSTEM.
         */
        defaults();

        pipeline_fault          = 1'b1;
        system_instruction      = 1'b1;
        register_write_control  = 1'b0;
        write_back_data_valid   = 1'b0;
        destination_register    = 5'd0;
        #1;

        if (!register_file_write_enable &&
            exception_valid &&
            !system_event_valid &&
            !instruction_retired) begin

            pass("Fault priority over SYSTEM event");
        end
        else begin
            fail("Fault priority over SYSTEM event");
        end

        /*
         * Test 11: illegal state has priority over FENCE.
         */
        defaults();

        pipeline_illegal        = 1'b1;
        fence_instruction       = 1'b1;
        register_write_control  = 1'b0;
        write_back_data_valid   = 1'b0;
        destination_register    = 5'd0;
        #1;

        if (!register_file_write_enable &&
            exception_valid &&
            !fence_completed &&
            !instruction_retired) begin

            pass("Illegal-state priority over FENCE");
        end
        else begin
            fail("Illegal-state priority over FENCE");
        end

        /*
         * Test 12: data and destination passthrough.
         */
        defaults();

        destination_register     = 5'd31;
        selected_write_back_data = 32'hCAFEBABE;
        #1;

        if (register_file_write_enable &&
            register_file_write_address == 5'd31 &&
            register_file_write_data == 32'hCAFEBABE) begin

            pass("Write-back address and data passthrough");
        end
        else begin
            fail("Write-back address and data passthrough");
        end

        if (errors == 0) begin
            $display(
                "\nALL 12 REGISTER WRITE-BACK LOGIC CHECKS PASSED"
            );
        end
        else begin
            $display(
                "\nREGISTER WRITE-BACK LOGIC TEST FAILED: %0d error(s)",
                errors
            );
        end

        $finish;
    end

endmodule