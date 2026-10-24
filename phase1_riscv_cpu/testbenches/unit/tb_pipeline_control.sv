`timescale 1ns/1ps

module tb_pipeline_control;

    logic        pipeline_halt;
    logic        memory_busy;
    logic        redirect_valid;

    logic        id_valid;
    logic        id_uses_rs1;
    logic        id_uses_rs2;
    logic [4:0]  id_rs1;
    logic [4:0]  id_rs2;

    logic        ex_valid;
    logic        ex_fault;
    logic        ex_illegal;
    logic        ex_memory_read;
    logic        ex_register_write;
    logic [4:0]  ex_destination_register;

    logic        ex_uses_rs1;
    logic        ex_uses_rs2;
    logic [4:0]  ex_rs1;
    logic [4:0]  ex_rs2;
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
    logic [1:0]  forward_select_rs1;
    logic [1:0]  forward_select_rs2;
    logic        forwarding_blocked_rs1;
    logic        forwarding_blocked_rs2;

    logic        load_use_hazard_out;

    logic        pc_enable;
    logic        if_id_enable;
    logic        id_ex_enable;
    logic        ex_mem_enable;
    logic        mem_wb_enable;

    logic        if_id_flush;
    logic        id_ex_flush;
    logic        ex_mem_flush;
    logic        mem_wb_flush;

    logic        pipeline_stalled;
    logic        pipeline_flushed;

    integer error_count;
    integer test_count;

    pipeline_control dut (
        .pipeline_halt              (pipeline_halt),
        .memory_busy                (memory_busy),
        .redirect_valid             (redirect_valid),

        .id_valid                   (id_valid),
        .id_uses_rs1                (id_uses_rs1),
        .id_uses_rs2                (id_uses_rs2),
        .id_rs1                     (id_rs1),
        .id_rs2                     (id_rs2),

        .ex_valid                   (ex_valid),
        .ex_fault                   (ex_fault),
        .ex_illegal                 (ex_illegal),
        .ex_memory_read             (ex_memory_read),
        .ex_register_write          (ex_register_write),
        .ex_destination_register    (ex_destination_register),

        .ex_uses_rs1                (ex_uses_rs1),
        .ex_uses_rs2                (ex_uses_rs2),
        .ex_rs1                     (ex_rs1),
        .ex_rs2                     (ex_rs2),
        .ex_rs1_value               (ex_rs1_value),
        .ex_rs2_value               (ex_rs2_value),

        .ex_mem_valid               (ex_mem_valid),
        .ex_mem_register_write      (ex_mem_register_write),
        .ex_mem_destination_register(ex_mem_destination_register),
        .ex_mem_forward_value       (ex_mem_forward_value),
        .ex_mem_value_valid         (ex_mem_value_valid),

        .mem_wb_valid               (mem_wb_valid),
        .mem_wb_register_write      (mem_wb_register_write),
        .mem_wb_destination_register(mem_wb_destination_register),
        .mem_wb_forward_value       (mem_wb_forward_value),
        .mem_wb_value_valid         (mem_wb_value_valid),

        .forwarded_rs1_value        (forwarded_rs1_value),
        .forwarded_rs2_value        (forwarded_rs2_value),
        .forward_select_rs1         (forward_select_rs1),
        .forward_select_rs2         (forward_select_rs2),
        .forwarding_blocked_rs1     (forwarding_blocked_rs1),
        .forwarding_blocked_rs2     (forwarding_blocked_rs2),

        .load_use_hazard_out        (load_use_hazard_out),

        .pc_enable                  (pc_enable),
        .if_id_enable               (if_id_enable),
        .id_ex_enable               (id_ex_enable),
        .ex_mem_enable              (ex_mem_enable),
        .mem_wb_enable              (mem_wb_enable),

        .if_id_flush                (if_id_flush),
        .id_ex_flush                (id_ex_flush),
        .ex_mem_flush               (ex_mem_flush),
        .mem_wb_flush               (mem_wb_flush),

        .pipeline_stalled           (pipeline_stalled),
        .pipeline_flushed           (pipeline_flushed)
    );

    task automatic clear_inputs;
        begin
            pipeline_halt               = 1'b0;
            memory_busy                 = 1'b0;
            redirect_valid              = 1'b0;

            id_valid                    = 1'b0;
            id_uses_rs1                 = 1'b0;
            id_uses_rs2                 = 1'b0;
            id_rs1                      = 5'd0;
            id_rs2                      = 5'd0;

            ex_valid                    = 1'b0;
            ex_fault                    = 1'b0;
            ex_illegal                  = 1'b0;
            ex_memory_read              = 1'b0;
            ex_register_write           = 1'b0;
            ex_destination_register     = 5'd0;

            ex_uses_rs1                 = 1'b0;
            ex_uses_rs2                 = 1'b0;
            ex_rs1                      = 5'd0;
            ex_rs2                      = 5'd0;
            ex_rs1_value                = 32'h0000_0000;
            ex_rs2_value                = 32'h0000_0000;

            ex_mem_valid                = 1'b0;
            ex_mem_register_write       = 1'b0;
            ex_mem_destination_register = 5'd0;
            ex_mem_forward_value        = 32'h0000_0000;
            ex_mem_value_valid          = 1'b0;

            mem_wb_valid                = 1'b0;
            mem_wb_register_write       = 1'b0;
            mem_wb_destination_register = 5'd0;
            mem_wb_forward_value        = 32'h0000_0000;
            mem_wb_value_valid          = 1'b0;
        end
    endtask

    task automatic check_condition(
        input logic  condition,
        input string test_name
    );
        begin
            test_count = test_count + 1;

            if (condition === 1'b1) begin
                $display("PASS: %s", test_name);
            end
            else begin
                error_count = error_count + 1;
                $display("FAIL: %s", test_name);
            end
        end
    endtask

    initial begin
        error_count = 0;
        test_count  = 0;

        // =====================================================
        // Test 1: Normal operation
        // =====================================================
        clear_inputs();
        ex_rs1_value = 32'h1111_1111;
        ex_rs2_value = 32'h2222_2222;
        #1;

        check_condition(
            pc_enable       &&
            if_id_enable    &&
            id_ex_enable    &&
            ex_mem_enable   &&
            mem_wb_enable   &&
            !if_id_flush    &&
            !id_ex_flush    &&
            !pipeline_stalled &&
            !pipeline_flushed &&
            forwarded_rs1_value == 32'h1111_1111 &&
            forwarded_rs2_value == 32'h2222_2222,
            "Normal integrated pipeline control"
        );

        // =====================================================
        // Test 2: Load-use hazard through rs1
        // =====================================================
        clear_inputs();

        id_valid    = 1'b1;
        id_uses_rs1 = 1'b1;
        id_rs1      = 5'd5;

        ex_valid                = 1'b1;
        ex_memory_read          = 1'b1;
        ex_register_write       = 1'b1;
        ex_destination_register = 5'd5;
        #1;

        check_condition(
            load_use_hazard_out &&
            !pc_enable          &&
            !if_id_enable       &&
            id_ex_enable        &&
            ex_mem_enable       &&
            mem_wb_enable       &&
            !if_id_flush        &&
            id_ex_flush         &&
            pipeline_stalled,
            "Integrated load-use hazard handling"
        );

        // =====================================================
        // Test 3: Forward rs1 from EX/MEM
        // =====================================================
        clear_inputs();

        ex_uses_rs1  = 1'b1;
        ex_rs1       = 5'd6;
        ex_rs1_value = 32'hAAAA_AAAA;

        ex_mem_valid                = 1'b1;
        ex_mem_register_write       = 1'b1;
        ex_mem_destination_register = 5'd6;
        ex_mem_forward_value        = 32'h1234_5678;
        ex_mem_value_valid          = 1'b1;
        #1;

        check_condition(
            forwarded_rs1_value == 32'h1234_5678 &&
            forward_select_rs1  == 2'b01 &&
            !forwarding_blocked_rs1,
            "Forward rs1 from EX/MEM"
        );

        // =====================================================
        // Test 4: Forward rs2 from MEM/WB
        // =====================================================
        clear_inputs();

        ex_uses_rs2  = 1'b1;
        ex_rs2       = 5'd7;
        ex_rs2_value = 32'hBBBB_BBBB;

        mem_wb_valid                = 1'b1;
        mem_wb_register_write       = 1'b1;
        mem_wb_destination_register = 5'd7;
        mem_wb_forward_value        = 32'hCAFE_BABE;
        mem_wb_value_valid          = 1'b1;
        #1;

        check_condition(
            forwarded_rs2_value == 32'hCAFE_BABE &&
            forward_select_rs2  == 2'b10 &&
            !forwarding_blocked_rs2,
            "Forward rs2 from MEM/WB"
        );

        // =====================================================
        // Test 5: Forward both operands
        // =====================================================
        clear_inputs();

        ex_uses_rs1 = 1'b1;
        ex_uses_rs2 = 1'b1;
        ex_rs1      = 5'd8;
        ex_rs2      = 5'd9;

        ex_mem_valid                = 1'b1;
        ex_mem_register_write       = 1'b1;
        ex_mem_destination_register = 5'd8;
        ex_mem_forward_value        = 32'h0000_0008;
        ex_mem_value_valid          = 1'b1;

        mem_wb_valid                = 1'b1;
        mem_wb_register_write       = 1'b1;
        mem_wb_destination_register = 5'd9;
        mem_wb_forward_value        = 32'h0000_0009;
        mem_wb_value_valid          = 1'b1;
        #1;

        check_condition(
            forwarded_rs1_value == 32'h0000_0008 &&
            forwarded_rs2_value == 32'h0000_0009 &&
            forward_select_rs1  == 2'b01 &&
            forward_select_rs2  == 2'b10,
            "Simultaneous EX/MEM and MEM/WB forwarding"
        );

        // =====================================================
        // Test 6: EX/MEM has priority over MEM/WB
        // =====================================================
        clear_inputs();

        ex_uses_rs1 = 1'b1;
        ex_rs1      = 5'd10;

        ex_mem_valid                = 1'b1;
        ex_mem_register_write       = 1'b1;
        ex_mem_destination_register = 5'd10;
        ex_mem_forward_value        = 32'h1111_1111;
        ex_mem_value_valid          = 1'b1;

        mem_wb_valid                = 1'b1;
        mem_wb_register_write       = 1'b1;
        mem_wb_destination_register = 5'd10;
        mem_wb_forward_value        = 32'h2222_2222;
        mem_wb_value_valid          = 1'b1;
        #1;

        check_condition(
            forwarded_rs1_value == 32'h1111_1111 &&
            forward_select_rs1 == 2'b01,
            "EX/MEM forwarding priority"
        );

        // =====================================================
        // Test 7: Memory busy stalls upstream stages
        // =====================================================
        clear_inputs();
        memory_busy = 1'b1;
        #1;

        check_condition(
            !pc_enable       &&
            !if_id_enable    &&
            !id_ex_enable    &&
            !ex_mem_enable   &&
            mem_wb_enable    &&
            pipeline_stalled &&
            !pipeline_flushed,
            "Integrated memory wait control"
        );

        // =====================================================
        // Test 8: Redirect flushes younger instructions
        // =====================================================
        clear_inputs();
        redirect_valid = 1'b1;
        #1;

        check_condition(
            pc_enable        &&
            if_id_enable     &&
            id_ex_enable     &&
            ex_mem_enable    &&
            mem_wb_enable    &&
            if_id_flush      &&
            id_ex_flush      &&
            !ex_mem_flush    &&
            !mem_wb_flush    &&
            !pipeline_stalled &&
            pipeline_flushed,
            "Integrated redirect control"
        );

        // =====================================================
        // Test 9: Pipeline halt has highest priority
        // =====================================================
        clear_inputs();

        pipeline_halt  = 1'b1;
        memory_busy    = 1'b1;
        redirect_valid = 1'b1;

        id_valid                = 1'b1;
        id_uses_rs1             = 1'b1;
        id_rs1                  = 5'd4;
        ex_valid                = 1'b1;
        ex_memory_read          = 1'b1;
        ex_register_write       = 1'b1;
        ex_destination_register = 5'd4;
        #1;

        check_condition(
            !pc_enable       &&
            !if_id_enable    &&
            !id_ex_enable    &&
            !ex_mem_enable   &&
            !mem_wb_enable   &&
            !if_id_flush     &&
            !id_ex_flush     &&
            !ex_mem_flush    &&
            !mem_wb_flush    &&
            pipeline_stalled &&
            !pipeline_flushed,
            "Pipeline halt priority"
        );

        // =====================================================
        // Test 10: Unavailable newer result blocks stale WB value
        // =====================================================
        clear_inputs();

        ex_uses_rs1  = 1'b1;
        ex_rs1       = 5'd11;
        ex_rs1_value = 32'hAAAA_AAAA;

        ex_mem_valid                = 1'b1;
        ex_mem_register_write       = 1'b1;
        ex_mem_destination_register = 5'd11;
        ex_mem_forward_value        = 32'h1111_1111;
        ex_mem_value_valid          = 1'b0;

        mem_wb_valid                = 1'b1;
        mem_wb_register_write       = 1'b1;
        mem_wb_destination_register = 5'd11;
        mem_wb_forward_value        = 32'h2222_2222;
        mem_wb_value_valid          = 1'b1;
        #1;

        check_condition(
            forwarding_blocked_rs1 &&
            forwarded_rs1_value == 32'hAAAA_AAAA &&
            forward_select_rs1 == 2'b00,
            "Unavailable newer result blocks stale forwarding"
        );

        // =====================================================
        // Test 11: x0 must not create hazards or forwarding
        // =====================================================
        clear_inputs();

        id_valid    = 1'b1;
        id_uses_rs1 = 1'b1;
        id_rs1      = 5'd0;

        ex_valid                = 1'b1;
        ex_memory_read          = 1'b1;
        ex_register_write       = 1'b1;
        ex_destination_register = 5'd0;

        ex_uses_rs1  = 1'b1;
        ex_rs1       = 5'd0;
        ex_rs1_value = 32'h0000_0000;

        ex_mem_valid                = 1'b1;
        ex_mem_register_write       = 1'b1;
        ex_mem_destination_register = 5'd0;
        ex_mem_forward_value        = 32'hFFFF_FFFF;
        ex_mem_value_valid          = 1'b1;
        #1;

        check_condition(
            !load_use_hazard_out &&
            forward_select_rs1 == 2'b00 &&
            forwarded_rs1_value == 32'h0000_0000 &&
            !forwarding_blocked_rs1,
            "x0 hazard and forwarding protection"
        );

        // =====================================================
        // Test 12: Redirect priority over load-use hazard
        // =====================================================
        clear_inputs();

        redirect_valid = 1'b1;

        id_valid    = 1'b1;
        id_uses_rs1 = 1'b1;
        id_rs1      = 5'd12;

        ex_valid                = 1'b1;
        ex_memory_read          = 1'b1;
        ex_register_write       = 1'b1;
        ex_destination_register = 5'd12;
        #1;

        check_condition(
            load_use_hazard_out &&
            pc_enable           &&
            if_id_enable        &&
            id_ex_enable        &&
            if_id_flush         &&
            id_ex_flush         &&
            pipeline_flushed    &&
            !pipeline_stalled,
            "Redirect priority over load-use hazard"
        );

        // =====================================================
        // Test 13: Memory wait priority over redirect
        // =====================================================
        clear_inputs();

        memory_busy    = 1'b1;
        redirect_valid = 1'b1;
        #1;

        check_condition(
            !pc_enable       &&
            !if_id_enable    &&
            !id_ex_enable    &&
            !ex_mem_enable   &&
            mem_wb_enable    &&
            !if_id_flush     &&
            !id_ex_flush     &&
            pipeline_stalled &&
            !pipeline_flushed,
            "Memory wait priority over redirect"
        );

        // =====================================================
        // Final result
        // =====================================================
        $display("");

        if (error_count == 0) begin
            $display(
                "ALL %0d INTEGRATED PIPELINE CONTROL CHECKS PASSED",
                test_count
            );
        end
        else begin
            $display(
                "INTEGRATED PIPELINE CONTROL TEST FAILED: %0d error(s)",
                error_count
            );
        end

        $finish;
    end

endmodule