`timescale 1ns/1ps

module tb_forwarding_unit;

    localparam logic [1:0] FORWARD_ORIGINAL = 2'b00;
    localparam logic [1:0] FORWARD_EX_MEM   = 2'b01;
    localparam logic [1:0] FORWARD_MEM_WB   = 2'b10;

    logic       ex_uses_rs1;
    logic       ex_uses_rs2;

    logic [4:0] ex_rs1;
    logic [4:0] ex_rs2;

    logic [31:0] ex_rs1_value;
    logic [31:0] ex_rs2_value;

    logic        ex_mem_valid;
    logic        ex_mem_register_write;
    logic [4:0]  ex_mem_destination_register;
    logic [31:0] ex_mem_forward_value;
    logic        ex_mem_value_valid;

    logic        mem_wb_valid;
    logic        mem_wb_register_write;
    logic [4:0]  mem_wb_destination_register;
    logic [31:0] mem_wb_forward_value;
    logic        mem_wb_value_valid;

    logic [31:0] forwarded_rs1_value;
    logic [31:0] forwarded_rs2_value;

    logic [1:0] forward_select_rs1;
    logic [1:0] forward_select_rs2;

    logic forwarding_blocked_rs1;
    logic forwarding_blocked_rs2;

    integer errors;

    forwarding_unit dut (
        .ex_uses_rs1                (ex_uses_rs1),
        .ex_uses_rs2                (ex_uses_rs2),

        .ex_rs1                     (ex_rs1),
        .ex_rs2                     (ex_rs2),

        .ex_rs1_value               (ex_rs1_value),
        .ex_rs2_value               (ex_rs2_value),

        .ex_mem_valid               (ex_mem_valid),
        .ex_mem_register_write      (
            ex_mem_register_write
        ),
        .ex_mem_destination_register(
            ex_mem_destination_register
        ),
        .ex_mem_forward_value       (
            ex_mem_forward_value
        ),
        .ex_mem_value_valid         (ex_mem_value_valid),

        .mem_wb_valid               (mem_wb_valid),
        .mem_wb_register_write      (
            mem_wb_register_write
        ),
        .mem_wb_destination_register(
            mem_wb_destination_register
        ),
        .mem_wb_forward_value       (
            mem_wb_forward_value
        ),
        .mem_wb_value_valid         (mem_wb_value_valid),

        .forwarded_rs1_value        (forwarded_rs1_value),
        .forwarded_rs2_value        (forwarded_rs2_value),

        .forward_select_rs1         (forward_select_rs1),
        .forward_select_rs2         (forward_select_rs2),

        .forwarding_blocked_rs1     (
            forwarding_blocked_rs1
        ),
        .forwarding_blocked_rs2     (
            forwarding_blocked_rs2
        )
    );

    task automatic defaults;
        begin
            ex_uses_rs1                 = 1'b1;
            ex_uses_rs2                 = 1'b1;

            ex_rs1                      = 5'd1;
            ex_rs2                      = 5'd2;

            ex_rs1_value                = 32'h11111111;
            ex_rs2_value                = 32'h22222222;

            ex_mem_valid                = 1'b0;
            ex_mem_register_write       = 1'b0;
            ex_mem_destination_register = 5'd0;
            ex_mem_forward_value        = 32'hAAAAAAAA;
            ex_mem_value_valid          = 1'b0;

            mem_wb_valid                = 1'b0;
            mem_wb_register_write       = 1'b0;
            mem_wb_destination_register = 5'd0;
            mem_wb_forward_value        = 32'hBBBBBBBB;
            mem_wb_value_valid          = 1'b0;
        end
    endtask

    task automatic pass(input string name);
        begin
            $display("PASS: %s", name);
        end
    endtask

    task automatic fail(input string name);
        begin
            errors = errors + 1;
            $display("FAIL: %s", name);
        end
    endtask

    initial begin
        errors = 0;

        /*
         * Test 1: no forwarding.
         */
        defaults();
        #1;

        if (forwarded_rs1_value == 32'h11111111 &&
            forwarded_rs2_value == 32'h22222222 &&
            forward_select_rs1 == FORWARD_ORIGINAL &&
            forward_select_rs2 == FORWARD_ORIGINAL &&
            !forwarding_blocked_rs1 &&
            !forwarding_blocked_rs2) begin

            pass("No forwarding required");
        end
        else begin
            fail("No forwarding required");
        end

        /*
         * Test 2: forward rs1 from EX/MEM.
         */
        defaults();

        ex_mem_valid                = 1'b1;
        ex_mem_register_write       = 1'b1;
        ex_mem_destination_register = 5'd1;
        ex_mem_forward_value        = 32'hAAAA0001;
        ex_mem_value_valid          = 1'b1;
        #1;

        if (forwarded_rs1_value == 32'hAAAA0001 &&
            forward_select_rs1 == FORWARD_EX_MEM &&
            forwarded_rs2_value == 32'h22222222) begin

            pass("Forward rs1 from EX/MEM");
        end
        else begin
            fail("Forward rs1 from EX/MEM");
        end

        /*
         * Test 3: forward rs2 from EX/MEM.
         */
        defaults();

        ex_mem_valid                = 1'b1;
        ex_mem_register_write       = 1'b1;
        ex_mem_destination_register = 5'd2;
        ex_mem_forward_value        = 32'hAAAA0002;
        ex_mem_value_valid          = 1'b1;
        #1;

        if (forwarded_rs2_value == 32'hAAAA0002 &&
            forward_select_rs2 == FORWARD_EX_MEM) begin

            pass("Forward rs2 from EX/MEM");
        end
        else begin
            fail("Forward rs2 from EX/MEM");
        end

        /*
         * Test 4: forward rs1 from MEM/WB.
         */
        defaults();

        mem_wb_valid                = 1'b1;
        mem_wb_register_write       = 1'b1;
        mem_wb_destination_register = 5'd1;
        mem_wb_forward_value        = 32'hBBBB0001;
        mem_wb_value_valid          = 1'b1;
        #1;

        if (forwarded_rs1_value == 32'hBBBB0001 &&
            forward_select_rs1 == FORWARD_MEM_WB) begin

            pass("Forward rs1 from MEM/WB");
        end
        else begin
            fail("Forward rs1 from MEM/WB");
        end

        /*
         * Test 5: forward rs2 from MEM/WB.
         */
        defaults();

        mem_wb_valid                = 1'b1;
        mem_wb_register_write       = 1'b1;
        mem_wb_destination_register = 5'd2;
        mem_wb_forward_value        = 32'hBBBB0002;
        mem_wb_value_valid          = 1'b1;
        #1;

        if (forwarded_rs2_value == 32'hBBBB0002 &&
            forward_select_rs2 == FORWARD_MEM_WB) begin

            pass("Forward rs2 from MEM/WB");
        end
        else begin
            fail("Forward rs2 from MEM/WB");
        end

        /*
         * Test 6: EX/MEM has priority over MEM/WB.
         */
        defaults();

        ex_mem_valid                = 1'b1;
        ex_mem_register_write       = 1'b1;
        ex_mem_destination_register = 5'd1;
        ex_mem_forward_value        = 32'hAAAA1111;
        ex_mem_value_valid          = 1'b1;

        mem_wb_valid                = 1'b1;
        mem_wb_register_write       = 1'b1;
        mem_wb_destination_register = 5'd1;
        mem_wb_forward_value        = 32'hBBBB1111;
        mem_wb_value_valid          = 1'b1;
        #1;

        if (forwarded_rs1_value == 32'hAAAA1111 &&
            forward_select_rs1 == FORWARD_EX_MEM) begin

            pass("EX/MEM forwarding priority");
        end
        else begin
            fail("EX/MEM forwarding priority");
        end

        /*
         * Test 7: forward both operands from different stages.
         */
        defaults();

        ex_mem_valid                = 1'b1;
        ex_mem_register_write       = 1'b1;
        ex_mem_destination_register = 5'd1;
        ex_mem_forward_value        = 32'hAAAA1111;
        ex_mem_value_valid          = 1'b1;

        mem_wb_valid                = 1'b1;
        mem_wb_register_write       = 1'b1;
        mem_wb_destination_register = 5'd2;
        mem_wb_forward_value        = 32'hBBBB2222;
        mem_wb_value_valid          = 1'b1;
        #1;

        if (forwarded_rs1_value == 32'hAAAA1111 &&
            forwarded_rs2_value == 32'hBBBB2222 &&
            forward_select_rs1 == FORWARD_EX_MEM &&
            forward_select_rs2 == FORWARD_MEM_WB) begin

            pass("Forward both operands");
        end
        else begin
            fail("Forward both operands");
        end

        /*
         * Test 8: x0 must never be forwarded.
         */
        defaults();

        ex_rs1                      = 5'd0;
        ex_rs1_value                = 32'h00000000;

        ex_mem_valid                = 1'b1;
        ex_mem_register_write       = 1'b1;
        ex_mem_destination_register = 5'd0;
        ex_mem_forward_value        = 32'hFFFFFFFF;
        ex_mem_value_valid          = 1'b1;
        #1;

        if (forwarded_rs1_value == 32'h00000000 &&
            forward_select_rs1 == FORWARD_ORIGINAL) begin

            pass("x0 forwarding suppressed");
        end
        else begin
            fail("x0 forwarding suppressed");
        end

        /*
         * Test 9: unused source register.
         */
        defaults();

        ex_uses_rs1                 = 1'b0;
        ex_mem_valid                = 1'b1;
        ex_mem_register_write       = 1'b1;
        ex_mem_destination_register = 5'd1;
        ex_mem_forward_value        = 32'hFFFFFFFF;
        ex_mem_value_valid          = 1'b1;
        #1;

        if (forwarded_rs1_value == 32'h11111111 &&
            forward_select_rs1 == FORWARD_ORIGINAL) begin

            pass("Unused rs1 is not forwarded");
        end
        else begin
            fail("Unused rs1 is not forwarded");
        end

        /*
         * Test 10: invalid EX/MEM entry.
         */
        defaults();

        ex_mem_valid                = 1'b0;
        ex_mem_register_write       = 1'b1;
        ex_mem_destination_register = 5'd1;
        ex_mem_value_valid          = 1'b1;
        #1;

        if (forward_select_rs1 == FORWARD_ORIGINAL)
            pass("Invalid EX/MEM entry ignored");
        else
            fail("Invalid EX/MEM entry ignored");

        /*
         * Test 11: unavailable matching EX/MEM value blocks rs1.
         */
        defaults();

        ex_mem_valid                = 1'b1;
        ex_mem_register_write       = 1'b1;
        ex_mem_destination_register = 5'd1;
        ex_mem_value_valid          = 1'b0;

        mem_wb_valid                = 1'b1;
        mem_wb_register_write       = 1'b1;
        mem_wb_destination_register = 5'd1;
        mem_wb_forward_value        = 32'hBBBB1111;
        mem_wb_value_valid          = 1'b1;
        #1;

        if (forwarding_blocked_rs1 &&
            forward_select_rs1 == FORWARD_ORIGINAL &&
            forwarded_rs1_value == 32'h11111111) begin

            pass("Unavailable newer rs1 result blocks forwarding");
        end
        else begin
            fail("Unavailable newer rs1 result blocks forwarding");
        end

        /*
         * Test 12: unavailable matching EX/MEM value blocks rs2.
         */
        defaults();

        ex_mem_valid                = 1'b1;
        ex_mem_register_write       = 1'b1;
        ex_mem_destination_register = 5'd2;
        ex_mem_value_valid          = 1'b0;
        #1;

        if (forwarding_blocked_rs2 &&
            forward_select_rs2 == FORWARD_ORIGINAL) begin

            pass("Unavailable newer rs2 result blocks forwarding");
        end
        else begin
            fail("Unavailable newer rs2 result blocks forwarding");
        end

        /*
         * Test 13: MEM/WB value marked invalid.
         */
        defaults();

        mem_wb_valid                = 1'b1;
        mem_wb_register_write       = 1'b1;
        mem_wb_destination_register = 5'd1;
        mem_wb_value_valid          = 1'b0;
        #1;

        if (forward_select_rs1 == FORWARD_ORIGINAL &&
            !forwarding_blocked_rs1) begin

            pass("Invalid MEM/WB forwarding value ignored");
        end
        else begin
            fail("Invalid MEM/WB forwarding value ignored");
        end

        /*
         * Test 14: EX/MEM register-write control disabled.
         */
        defaults();

        ex_mem_valid                = 1'b1;
        ex_mem_register_write       = 1'b0;
        ex_mem_destination_register = 5'd1;
        ex_mem_value_valid          = 1'b1;
        #1;

        if (forward_select_rs1 == FORWARD_ORIGINAL)
            pass("Disabled EX/MEM write ignored");
        else
            fail("Disabled EX/MEM write ignored");

        /*
         * Test 15: no register-number match.
         */
        defaults();

        ex_mem_valid                = 1'b1;
        ex_mem_register_write       = 1'b1;
        ex_mem_destination_register = 5'd10;
        ex_mem_value_valid          = 1'b1;

        mem_wb_valid                = 1'b1;
        mem_wb_register_write       = 1'b1;
        mem_wb_destination_register = 5'd11;
        mem_wb_value_valid          = 1'b1;
        #1;

        if (forward_select_rs1 == FORWARD_ORIGINAL &&
            forward_select_rs2 == FORWARD_ORIGINAL) begin

            pass("Nonmatching destinations ignored");
        end
        else begin
            fail("Nonmatching destinations ignored");
        end

        if (errors == 0) begin
            $display(
                "\nALL 15 FORWARDING UNIT CHECKS PASSED"
            );
        end
        else begin
            $display(
                "\nFORWARDING UNIT TEST FAILED: %0d error(s)",
                errors
            );
        end

        $finish;
    end

endmodule