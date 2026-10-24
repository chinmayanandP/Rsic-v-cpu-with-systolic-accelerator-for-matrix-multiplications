`timescale 1ns/1ps

module tb_hazard_detection_unit;

    logic       id_valid;
    logic       id_uses_rs1;
    logic       id_uses_rs2;
    logic [4:0] id_rs1;
    logic [4:0] id_rs2;

    logic       ex_valid;
    logic       ex_fault;
    logic       ex_illegal;

    logic       ex_memory_read;
    logic       ex_register_write;
    logic [4:0] ex_destination_register;

    logic load_use_hazard;

    integer errors;

    hazard_detection_unit dut (
        .id_valid               (id_valid),
        .id_uses_rs1            (id_uses_rs1),
        .id_uses_rs2            (id_uses_rs2),
        .id_rs1                 (id_rs1),
        .id_rs2                 (id_rs2),

        .ex_valid               (ex_valid),
        .ex_fault               (ex_fault),
        .ex_illegal             (ex_illegal),

        .ex_memory_read         (ex_memory_read),
        .ex_register_write      (ex_register_write),
        .ex_destination_register(
            ex_destination_register
        ),

        .load_use_hazard        (load_use_hazard)
    );

    task automatic defaults;
        begin
            id_valid               = 1'b1;
            id_uses_rs1            = 1'b1;
            id_uses_rs2            = 1'b1;
            id_rs1                 = 5'd1;
            id_rs2                 = 5'd2;

            ex_valid               = 1'b1;
            ex_fault               = 1'b0;
            ex_illegal             = 1'b0;

            ex_memory_read         = 1'b1;
            ex_register_write      = 1'b1;
            ex_destination_register= 5'd3;
        end
    endtask

    task automatic pass(input string test_name);
        begin
            $display(
                "PASS: %s hazard=%0b",
                test_name,
                load_use_hazard
            );
        end
    endtask

    task automatic fail(input string test_name);
        begin
            errors = errors + 1;

            $display(
                "FAIL: %s hazard=%0b",
                test_name,
                load_use_hazard
            );
        end
    endtask

    initial begin
        errors = 0;

        /*
         * Test 1: no dependency.
         */
        defaults();
        #1;

        if (!load_use_hazard)
            pass("No register dependency");
        else
            fail("No register dependency");

        /*
         * Test 2: rs1 depends on an Execute-stage load.
         */
        defaults();

        id_rs1 = 5'd3;
        #1;

        if (load_use_hazard)
            pass("Load-use hazard through rs1");
        else
            fail("Load-use hazard through rs1");

        /*
         * Test 3: rs2 depends on an Execute-stage load.
         */
        defaults();

        id_rs2 = 5'd3;
        #1;

        if (load_use_hazard)
            pass("Load-use hazard through rs2");
        else
            fail("Load-use hazard through rs2");

        /*
         * Test 4: both source registers depend on the load.
         */
        defaults();

        id_rs1 = 5'd3;
        id_rs2 = 5'd3;
        #1;

        if (load_use_hazard)
            pass("Load-use hazard through both sources");
        else
            fail("Load-use hazard through both sources");

        /*
         * Test 5: rs1 field matches, but instruction does not use rs1.
         */
        defaults();

        id_rs1      = 5'd3;
        id_uses_rs1 = 1'b0;
        #1;

        if (!load_use_hazard)
            pass("Unused rs1 causes no hazard");
        else
            fail("Unused rs1 causes no hazard");

        /*
         * Test 6: rs2 field matches, but instruction does not use rs2.
         */
        defaults();

        id_rs2      = 5'd3;
        id_uses_rs2 = 1'b0;
        #1;

        if (!load_use_hazard)
            pass("Unused rs2 causes no hazard");
        else
            fail("Unused rs2 causes no hazard");

        /*
         * Test 7: invalid Decode-stage instruction.
         */
        defaults();

        id_valid = 1'b0;
        id_rs1   = 5'd3;
        #1;

        if (!load_use_hazard)
            pass("Invalid Decode entry causes no hazard");
        else
            fail("Invalid Decode entry causes no hazard");

        /*
         * Test 8: invalid Execute-stage instruction.
         */
        defaults();

        ex_valid = 1'b0;
        id_rs1   = 5'd3;
        #1;

        if (!load_use_hazard)
            pass("Invalid Execute entry causes no hazard");
        else
            fail("Invalid Execute entry causes no hazard");

        /*
         * Test 9: Execute-stage instruction is not a load.
         *
         * An ordinary ALU dependency will be solved by forwarding,
         * so it must not stall the pipeline.
         */
        defaults();

        ex_memory_read = 1'b0;
        id_rs1         = 5'd3;
        #1;

        if (!load_use_hazard)
            pass("ALU dependency uses forwarding");
        else
            fail("ALU dependency uses forwarding");

        /*
         * Test 10: load does not write a destination register.
         */
        defaults();

        ex_register_write = 1'b0;
        id_rs1            = 5'd3;
        #1;

        if (!load_use_hazard)
            pass("Disabled Execute write causes no hazard");
        else
            fail("Disabled Execute write causes no hazard");

        /*
         * Test 11: destination x0 never creates a hazard.
         */
        defaults();

        ex_destination_register = 5'd0;
        id_rs1                  = 5'd0;
        id_rs2                  = 5'd0;
        #1;

        if (!load_use_hazard)
            pass("Destination x0 causes no hazard");
        else
            fail("Destination x0 causes no hazard");

        /*
         * Test 12: faulted Execute instruction.
         */
        defaults();

        ex_fault = 1'b1;
        id_rs1   = 5'd3;
        #1;

        if (!load_use_hazard)
            pass("Faulted Execute entry causes no hazard");
        else
            fail("Faulted Execute entry causes no hazard");

        /*
         * Test 13: illegal Execute instruction.
         */
        defaults();

        ex_illegal = 1'b1;
        id_rs2     = 5'd3;
        #1;

        if (!load_use_hazard)
            pass("Illegal Execute entry causes no hazard");
        else
            fail("Illegal Execute entry causes no hazard");

        /*
         * Test 14: two different sources, only rs2 matches.
         */
        defaults();

        id_rs1 = 5'd10;
        id_rs2 = 5'd3;
        #1;

        if (load_use_hazard)
            pass("Only rs2 dependency detected");
        else
            fail("Only rs2 dependency detected");

        /*
         * Test 15: destination changes and dependency disappears.
         */
        defaults();

        id_rs1                  = 5'd3;
        ex_destination_register = 5'd4;
        #1;

        if (!load_use_hazard)
            pass("Different destination causes no hazard");
        else
            fail("Different destination causes no hazard");

        if (errors == 0) begin
            $display(
                "\nALL 15 HAZARD DETECTION CHECKS PASSED"
            );
        end
        else begin
            $display(
                "\nHAZARD DETECTION TEST FAILED: %0d error(s)",
                errors
            );
        end

        $finish;
    end

endmodule